/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include "apphubbackend.h"

#include <QColor>
#include <QDate>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QImage>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSaveFile>
#include <QProcessEnvironment>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

#include <algorithm>
#include <array>
#include <cmath>
#include <utility>

namespace {

constexpr qsizetype MaxProcessOutputBytes = 8 * 1024 * 1024;
constexpr qsizetype MaxOperationLogBytes = 64 * 1024;
constexpr qint64 MaxMetadataBytes = 2 * 1024 * 1024;
constexpr qsizetype MaxQueryLength = 256;
constexpr int MaxCatalogItems = 10000;
constexpr int MaxFeaturedItems = 8;
constexpr int FlathubCollectionPageSize = 12;
constexpr qsizetype MaxFeaturedResponseBytes = 8 * 1024 * 1024;
constexpr qsizetype MaxFeaturedIconBytes = 2 * 1024 * 1024;

bool isSafeIdentifier(const QString &value)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$"));
    return pattern.match(value).hasMatch();
}

struct FlatpakExtensionPoint
{
    QString identifier;
    QStringList branches;
    bool subdirectories = false;
};

QList<FlatpakExtensionPoint> flatpakExtensionPoints(const QByteArray &metadata, const QString &defaultBranch)
{
    QList<FlatpakExtensionPoint> points;
    int currentPoint = -1;

    for (const QByteArray &rawLine : metadata.split(10)) {
        const QString line = QString::fromUtf8(rawLine).trimmed();
        if (line.startsWith(QLatin1String("[Extension ")) && line.endsWith(QLatin1String("]"))) {
            QString identifier = line.mid(11, line.size() - 12).trimmed();
            const qsizetype tagSeparator = identifier.indexOf(QLatin1String("@"));
            if (tagSeparator > 0)
                identifier.truncate(tagSeparator);

            FlatpakExtensionPoint point;
            point.identifier = identifier;
            points.append(point);
            currentPoint = points.size() - 1;
            continue;
        }

        if (line.startsWith(QLatin1String("["))) {
            currentPoint = -1;
            continue;
        }

        if (currentPoint < 0 || line.isEmpty() || line.startsWith(QLatin1String("#")))
            continue;

        const qsizetype separator = line.indexOf(QLatin1String("="));
        if (separator <= 0)
            continue;

        const QString key = line.left(separator).trimmed();
        const QString value = line.mid(separator + 1).trimmed();
        FlatpakExtensionPoint &point = points[currentPoint];
        if (key == QLatin1String("version")) {
            if (!value.isEmpty())
                point.branches.append(value);
        } else if (key == QLatin1String("versions")) {
            point.branches.append(value.split(QLatin1String(";"), Qt::SkipEmptyParts));
        } else if (key == QLatin1String("subdirectories")) {
            point.subdirectories = value.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0;
        }
    }

    QList<FlatpakExtensionPoint> result;
    for (FlatpakExtensionPoint &point : points) {
        if (!isSafeIdentifier(point.identifier))
            continue;
        if (point.branches.isEmpty() && !defaultBranch.isEmpty())
            point.branches.append(defaultBranch);
        point.branches.removeDuplicates();
        result.append(point);
    }
    return result;
}

bool splitFlatpakRuntimeRef(const QString &ref, QString *identifier = nullptr, QString *architecture = nullptr, QString *branch = nullptr)
{
    const QStringList parts = ref.split(QLatin1String("/"));
    if (parts.size() != 4 || parts.at(0) != QLatin1String("runtime")
        || !isSafeIdentifier(parts.at(1)) || !isSafeIdentifier(parts.at(2)) || !isSafeIdentifier(parts.at(3)))
        return false;

    if (identifier)
        *identifier = parts.at(1);
    if (architecture)
        *architecture = parts.at(2);
    if (branch)
        *branch = parts.at(3);
    return true;
}

QString appHubDisplayName(const QString &identifier)
{
    QStringList words = identifier.split(QRegularExpression(QStringLiteral("[-_]+")), Qt::SkipEmptyParts);
    for (QString &word : words) {
        if (word.size() <= 2)
            word = word.toUpper();
        else
            word[0] = word.at(0).toUpper();
    }
    return words.join(QChar(u' '));
}

double flatpakSizeBytes(QString size)
{
    size.remove(QRegularExpression(QStringLiteral("[\\s\\x{00A0}]+")));
    static const QRegularExpression pattern(
        QStringLiteral("^([0-9]+(?:\\.[0-9]+)?)([KMGTPE]?)(?:I?B|BYTES?)$"),
        QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch match = pattern.match(size);
    if (!match.hasMatch())
        return -1.0;

    bool ok = false;
    const double value = match.captured(1).toDouble(&ok);
    if (!ok)
        return -1.0;

    const QString prefix = match.captured(2).toUpper();
    const int exponent = prefix.isEmpty() ? 0 : QStringLiteral("KMGTPE").indexOf(prefix) + 1;
    return exponent > 0 ? value * std::pow(1000.0, exponent) : value;
}

QByteArray readBoundedFile(const QString &path, qint64 maximumBytes)
{
    const QFileInfo info(path);
    if (!info.isFile() || info.isSymbolicLink() || info.size() < 0 || info.size() > maximumBytes)
        return {};

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const QByteArray content = file.read(maximumBytes + 1);
    return content.size() <= maximumBytes ? content : QByteArray();
}

QColor clampAccentColor(const QColor &color)
{
    const QColor hslColor = color.toHsl();
    qreal hue = hslColor.hslHueF();
    if (hue < 0.0)
        hue = 0.55;

    const qreal saturation = std::clamp<qreal>(hslColor.hslSaturationF(), 0.35, 0.95);
    const qreal lightness = std::clamp<qreal>(hslColor.lightnessF(), 0.35, 0.62);

    QColor result;
    result.setHslF(hue, saturation, lightness, 1.0);
    return result;
}

QColor accentFromArtwork(const QImage &sourceImage)
{
    if (sourceImage.isNull())
        return {};

    const QImage image = sourceImage.convertToFormat(QImage::Format_ARGB32)
                             .scaled(96, 96, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    if (image.isNull())
        return {};

    struct Bucket
    {
        double weight = 0.0;
        double red = 0.0;
        double green = 0.0;
        double blue = 0.0;
        double saturation = 0.0;
        double lightness = 0.0;
    };

    constexpr int HueBuckets = 24;
    constexpr int SaturationBuckets = 6;
    constexpr int LightnessBuckets = 6;
    std::array<Bucket, HueBuckets * SaturationBuckets * LightnessBuckets> buckets;

    const auto bucketIndexFor = [=](const QColor &color) {
        const int hue = qMax(0, color.hslHue());
        const int hueIndex = std::clamp(hue / 15, 0, HueBuckets - 1);
        const int saturationIndex = std::clamp(static_cast<int>(color.hslSaturationF() * SaturationBuckets), 0, SaturationBuckets - 1);
        const int lightnessIndex = std::clamp(static_cast<int>(color.lightnessF() * LightnessBuckets), 0, LightnessBuckets - 1);
        return hueIndex + saturationIndex * HueBuckets + lightnessIndex * HueBuckets * SaturationBuckets;
    };

    for (int y = 0; y < image.height(); ++y) {
        for (int x = 0; x < image.width(); ++x) {
            const QColor color = image.pixelColor(x, y).toHsl();
            if (color.alpha() < 24)
                continue;

            const double saturation = color.hslSaturationF();
            const double lightness = color.lightnessF();
            if (lightness <= 0.02 || lightness >= 0.98)
                continue;
            if (saturation < 0.06 && (lightness <= 0.18 || lightness >= 0.82))
                continue;

            const double vividness = std::clamp((saturation - 0.08) / 0.92, 0.0, 1.0);
            const double midtoneBalance = 1.0 - std::min(1.0, std::abs(lightness - 0.52) / 0.52);
            const double weight = 0.12 + vividness * vividness * 0.7 + midtoneBalance * 0.18;

            auto &bucket = buckets[bucketIndexFor(color)];
            bucket.weight += weight;
            bucket.red += color.redF() * weight;
            bucket.green += color.greenF() * weight;
            bucket.blue += color.blueF() * weight;
            bucket.saturation += saturation * weight;
            bucket.lightness += lightness * weight;
        }
    }

    double bestScore = 0.0;
    QColor bestColor;
    for (const auto &bucket : buckets) {
        if (bucket.weight <= 0.0)
            continue;

        const double averageSaturation = bucket.saturation / bucket.weight;
        const double averageLightness = bucket.lightness / bucket.weight;
        if (averageSaturation < 0.12)
            continue;

        const double score = bucket.weight * (0.4 + averageSaturation * 0.9)
            * (1.0 - std::min(0.85, std::abs(averageLightness - 0.5)));
        if (score <= bestScore)
            continue;

        bestScore = score;
        bestColor.setRgbF(bucket.red / bucket.weight,
                          bucket.green / bucket.weight,
                          bucket.blue / bucket.weight,
                          1.0);
    }

    return bestColor.isValid() ? clampAccentColor(bestColor) : QColor();
}

QString cleanValue(QString value)
{
    value = value.trimmed();
    if (value.startsWith('"') && value.endsWith('"') && value.size() > 1)
        value = value.mid(1, value.size() - 2);
    if (value.startsWith('\'') && value.endsWith('\'') && value.size() > 1)
        value = value.mid(1, value.size() - 2);
    return value.trimmed();
}

QString displayCategory(QString category)
{
    category = category.trimmed();
    QString key = category.toCaseFolded();
    key.remove(QStringLiteral(" "));
    key.remove(QStringLiteral("-"));
    key.remove(QStringLiteral("_"));
    key.remove(QStringLiteral("/"));

    static const QHash<QString, QString> labels = {
        {QStringLiteral("audiovideo"), QStringLiteral("Audio/Video")},
        {QStringLiteral("audioandvideo"), QStringLiteral("Audio/Video")},
        {QStringLiteral("development"), QStringLiteral("Development")},
        {QStringLiteral("education"), QStringLiteral("Education")},
        {QStringLiteral("game"), QStringLiteral("Games")},
        {QStringLiteral("games"), QStringLiteral("Games")},
        {QStringLiteral("graphics"), QStringLiteral("Graphics")},
        {QStringLiteral("network"), QStringLiteral("Network")},
        {QStringLiteral("office"), QStringLiteral("Office")},
        {QStringLiteral("science"), QStringLiteral("Science")},
        {QStringLiteral("settings"), QStringLiteral("Settings")},
        {QStringLiteral("system"), QStringLiteral("System")},
        {QStringLiteral("utilities"), QStringLiteral("Utilities")},
        {QStringLiteral("utility"), QStringLiteral("Utilities")},
    };

    const auto label = labels.constFind(key);
    if (label != labels.cend())
        return label.value();

    if (!category.isEmpty())
        category[0] = category.at(0).toUpper();
    return category;
}

bool isFlathubRemote(const QString value)
{
    const auto remotes = value.split(QStringLiteral(","), Qt::SkipEmptyParts);
    for (const auto &remote : remotes) {
        if (remote.trimmed().compare(QStringLiteral("flathub"), Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

QString flathubCollectionSlug(int collection)
{
    switch (collection) {
    case AppHubBackend::PopularCollection:
        return QStringLiteral("popular");
    case AppHubBackend::RecentlyAddedCollection:
        return QStringLiteral("recently-added");
    case AppHubBackend::RecentlyUpdatedCollection:
        return QStringLiteral("recently-updated");
    case AppHubBackend::TrendingCollection:
    default:
        return QStringLiteral("trending");
    }
}

const QStringList &flathubCategorySlugs()
{
    static const QStringList categories = {
        QStringLiteral("office"),
        QStringLiteral("graphics"),
        QStringLiteral("audiovideo"),
        QStringLiteral("mobile"),
        QStringLiteral("education"),
        QStringLiteral("network"),
        QStringLiteral("game-only"),
        QStringLiteral("emulators"),
        QStringLiteral("launchers"),
        QStringLiteral("game-tools"),
        QStringLiteral("development"),
        QStringLiteral("science"),
        QStringLiteral("system"),
        QStringLiteral("utility"),
    };
    return categories;
}

QString flathubCategoryEndpoint(const QString &category)
{
    if (category == QLatin1String("mobile"))
        return QStringLiteral("mobile?sort_by=trending");
    if (category == QLatin1String("game-only"))
        return QStringLiteral("category/game?exclude_subcategories=emulator&exclude_subcategories=packageManager&exclude_subcategories=utility&exclude_subcategories=network&exclude_subcategories=gameTool&exclude_subcategories=launcherStore&sort_by=trending");
    if (category == QLatin1String("emulators"))
        return QStringLiteral("category/game/subcategories?subcategory=emulator&sort_by=trending");
    if (category == QLatin1String("launchers"))
        return QStringLiteral("category/game/subcategories?subcategory=packageManager&subcategory=launcherStore&sort_by=trending");
    if (category == QLatin1String("game-tools"))
        return QStringLiteral("category/game/subcategories?subcategory=utility&subcategory=network&subcategory=gameTool&sort_by=trending");
    return QStringLiteral("category/%1?sort_by=trending").arg(category);
}

const QStringList &flathubBrowseCategorySlugs()
{
    static const QStringList categories = {
        QStringLiteral("audiovideo"),
        QStringLiteral("development"),
        QStringLiteral("education"),
        QStringLiteral("game"),
        QStringLiteral("graphics"),
        QStringLiteral("network"),
        QStringLiteral("office"),
        QStringLiteral("science"),
        QStringLiteral("system"),
        QStringLiteral("utility"),
    };
    return categories;
}

QString flathubBrowseEndpoint(const QString &category, const QString &subcategory)
{
    if (subcategory.isEmpty())
        return QStringLiteral("category/%1?sort_by=trending").arg(category);

    return QStringLiteral("category/%1/subcategories?subcategory=%2&sort_by=trending").arg(category, subcategory);
}

QString flathubBrowseCacheKey(const QString &category, const QString &subcategory)
{
    return category + QLatin1Char(':') + subcategory;
}

QList<AppModel::Item> appendFlathubHits(QList<AppModel::Item> items, const QJsonArray &hits)
{
    QSet<QString> identifiers;
    for (const AppModel::Item &item : std::as_const(items))
        identifiers.insert(item.identifier);

    for (const QJsonValue &value : hits) {
        if (!value.isObject())
            continue;

        const QJsonObject object = value.toObject();
        const QString identifier = object.value(QStringLiteral("app_id")).toString().trimmed();
        if (!isSafeIdentifier(identifier) || identifiers.contains(identifier))
            continue;

        AppModel::Item item;
        item.name = object.value(QStringLiteral("name")).toString(identifier).trimmed();
        item.summary = object.value(QStringLiteral("summary")).toString().trimmed();
        item.identifier = identifier;
        item.icon = QStringLiteral("application-x-flatpak");
        item.iconUrl = object.value(QStringLiteral("icon")).toString().trimmed();
        items.append(item);
        identifiers.insert(identifier);
    }

    return items;
}

} // namespace

AppHubBackend::AppHubBackend(QObject *parent)
    : QObject(parent)
    , m_flathubModel(new AppModel(this))
    , m_flathubUpdatesModel(new AppModel(this))
    , m_systemFlatpakModel(new AppModel(this))
    , m_flatpakAddonsModel(new AppModel(this))
    , m_flathubFeaturedModel(new AppModel(this))
    , m_flathubBrowseModel(new AppModel(this))
    , m_flathubBrowseFeaturedModel(new AppModel(this))
    , m_flathubCollectionModel(new AppModel(this))
    , m_appHubModel(new AppModel(this))
    , m_appHubFeaturedModel(new AppModel(this))
    , m_userBundleModel(new AppModel(this))
    , m_appHubBackupsModel(new AppModel(this))
    , m_distroboxModel(new AppModel(this))
    , m_process(new QProcess(this))
    , m_network(new QNetworkAccessManager(this))
{
    for (const QString &category : flathubCategorySlugs())
        m_flathubCategoryModels.insert(category, new AppModel(this));

    connect(m_process, &QProcess::finished, this, &AppHubBackend::processFinished);
    connect(m_process, &QProcess::errorOccurred, this, &AppHubBackend::processErrorOccurred);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &AppHubBackend::processOutputReady);
    connect(m_process, &QProcess::readyReadStandardError, this, &AppHubBackend::processOutputReady);
}

AppModel *AppHubBackend::flathubModel()
{
    return m_flathubModel;
}

AppModel *AppHubBackend::flathubUpdatesModel()
{
    return m_flathubUpdatesModel;
}

AppModel *AppHubBackend::systemFlatpakModel()
{
    return m_systemFlatpakModel;
}

AppModel *AppHubBackend::flatpakAddonsModel()
{
    return m_flatpakAddonsModel;
}

AppModel *AppHubBackend::flathubFeaturedModel()
{
    return m_flathubFeaturedModel;
}

AppModel *AppHubBackend::flathubBrowseModel()
{
    return m_flathubBrowseModel;
}

AppModel *AppHubBackend::flathubBrowseFeaturedModel()
{
    return m_flathubBrowseFeaturedModel;
}

AppModel *AppHubBackend::flathubCollectionModel()
{
    return m_flathubCollectionModel;
}

int AppHubBackend::flathubCollection() const
{
    return m_flathubCollection;
}

void AppHubBackend::setFlathubCollection(int collection)
{
    if (collection < TrendingCollection || collection > RecentlyUpdatedCollection || collection == m_flathubCollection)
        return;

    cancelFlathubCollectionRequest();
    m_flathubCollection = collection;
    emit flathubCollectionChanged();

    const auto cached = m_flathubCollectionCache.constFind(collection);
    if (cached != m_flathubCollectionCache.cend()) {
        m_flathubCollectionModel->setItems(cached.value());
        emit flathubCollectionHasMoreChanged();
        return;
    }

    m_flathubCollectionModel->setItems({});
    emit flathubCollectionHasMoreChanged();
    refreshFlathubCollection();
}

bool AppHubBackend::flathubCollectionLoading() const
{
    return m_flathubCollectionLoading;
}

bool AppHubBackend::flathubCollectionHasMore() const
{
    const int nextPage = m_flathubCollectionNextPage.value(m_flathubCollection, 1);
    const int totalPages = m_flathubCollectionTotalPages.value(m_flathubCollection, 0);
    return totalPages > 0 && nextPage <= totalPages;
}

int AppHubBackend::flathubCategoryRevision() const
{
    return m_flathubCategoryRevision;
}

bool AppHubBackend::flathubBrowseLoading() const
{
    return m_flathubBrowseLoading;
}

bool AppHubBackend::flathubBrowseHasMore() const
{
    return m_flathubBrowseTotalPages > 0 && m_flathubBrowseNextPage <= m_flathubBrowseTotalPages;
}

QString AppHubBackend::flatpakSortMode() const
{
    return m_flatpakSortMode;
}

void AppHubBackend::setFlatpakSortMode(const QString &mode)
{
    const QString normalizedMode = mode.trimmed().toLower();
    if ((normalizedMode != QLatin1String("name") && normalizedMode != QLatin1String("size"))
        || normalizedMode == m_flatpakSortMode)
        return;

    m_flatpakSortMode = normalizedMode;
    emit flatpakSortModeChanged();

    if (m_currentSection == Flathub && m_query.isEmpty()) {
        m_flathubModel->setItems(sortedInstalledFlatpaks(m_flathubModel->items()));
        m_systemFlatpakModel->setItems(sortedInstalledFlatpaks(m_systemFlatpakModel->items()));
    }
}

QString AppHubBackend::flatpakUpdateIdentifier() const
{
    return m_flatpakUpdateIdentifier;
}

int AppHubBackend::flatpakUpdateProgress() const
{
    return m_flatpakUpdateProgress;
}

QStringList AppHubBackend::appHubCategories() const
{
    return m_appHubCategories;
}

QString AppHubBackend::appHubCategory() const
{
    return m_appHubCategory;
}

void AppHubBackend::setAppHubCategory(const QString &category)
{
    if (!m_appHubCategories.contains(category) || category == m_appHubCategory)
        return;

    m_appHubCategory = category;
    emit appHubCategoryChanged();
    m_appHubModel->setItems(filterAppHubItems(m_allAppHubItems));
}

bool AppHubBackend::appHubInstalledOnly() const
{
    return m_appHubInstalledOnly;
}

void AppHubBackend::setAppHubInstalledOnly(bool installedOnly)
{
    if (installedOnly == m_appHubInstalledOnly)
        return;

    m_appHubInstalledOnly = installedOnly;
    emit appHubInstalledOnlyChanged();
    m_appHubModel->setItems(filterAppHubItems(m_allAppHubItems));
}

AppModel *AppHubBackend::appHubModel()
{
    return m_appHubModel;
}

AppModel *AppHubBackend::appHubFeaturedModel()
{
    return m_appHubFeaturedModel;
}

AppModel *AppHubBackend::userBundleModel()
{
    return m_userBundleModel;
}

QUrl AppHubBackend::userBundleRoot() const
{
    return QUrl::fromLocalFile(m_userBundleStore.rootPath());
}

QUrl AppHubBackend::userBundleOutputUrl() const
{
    return m_userBundleOutputUrl;
}

QString AppHubBackend::userBundleArchitecture() const
{
    return m_userBundleStore.hostPackageArchitecture();
}

AppModel *AppHubBackend::appHubBackupsModel()
{
    return m_appHubBackupsModel;
}

AppModel *AppHubBackend::distroboxModel()
{
    return m_distroboxModel;
}

int AppHubBackend::currentSection() const
{
    return m_currentSection;
}

void AppHubBackend::setCurrentSection(int section)
{
    if (section < Flathub || section > Distrobox || section == m_currentSection)
        return;

    m_currentSection = section;
    emit currentSectionChanged();
    search(m_query);
}

bool AppHubBackend::busy() const
{
    return m_busy;
}

QString AppHubBackend::statusMessage() const
{
    return m_statusMessage;
}

QString AppHubBackend::operationLog() const
{
    return m_operationLog;
}

void AppHubBackend::setBusy(bool busy)
{
    if (m_busy == busy)
        return;

    m_busy = busy;
    emit busyChanged();
}

void AppHubBackend::setStatusMessage(const QString &message)
{
    if (m_statusMessage == message)
        return;

    m_statusMessage = message;
    emit statusMessageChanged();
}

QString AppHubBackend::findExecutable(const QString &program) const
{
    if (program.contains('/'))
        return program;

    return QStandardPaths::findExecutable(program);
}

QByteArray AppHubBackend::runCommand(const QString &program, const QStringList &arguments, int timeout) const
{
    const QString executable = findExecutable(program);
    if (executable.isEmpty())
        return {};

    QProcess process;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    environment.insert(QStringLiteral("LANG"), QStringLiteral("C"));
    process.setProcessEnvironment(environment);
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start(executable, arguments);
    if (!process.waitForStarted(timeout))
        return {};

    QElapsedTimer timer;
    timer.start();
    QByteArray output;
    QByteArray errorOutput;
    while (process.state() != QProcess::NotRunning) {
        const int remaining = timeout - static_cast<int>(timer.elapsed());
        if (remaining <= 0) {
            process.kill();
            process.waitForFinished();
            return {};
        }

        process.waitForFinished(qMin(remaining, 100));
        output += process.readAllStandardOutput();
        errorOutput += process.readAllStandardError();
        if (output.size() + errorOutput.size() > MaxProcessOutputBytes) {
            process.kill();
            process.waitForFinished();
            return {};
        }
    }

    output += process.readAllStandardOutput();
    errorOutput += process.readAllStandardError();
    if (output.size() + errorOutput.size() > MaxProcessOutputBytes || process.exitCode() != 0)
        return {};

    return output;
}

bool AppHubBackend::startOperation(const QString &program,
                                   const QStringList &arguments,
                                   Operation operation,
                                   const QString &identifier,
                                   const QString &workingDirectory)
{
    if (m_process->state() != QProcess::NotRunning) {
        setStatusMessage(QStringLiteral("Another operation is still running."));
        return false;
    }

    const QString executable = findExecutable(program);
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("%1 is not installed.").arg(program));
        return false;
    }

    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    environment.insert(QStringLiteral("LANG"), QStringLiteral("C"));
    if (operation == Operation::FlatpakUpdate)
        environment.insert(QStringLiteral("FLATPAK_FANCY_OUTPUT"), QStringLiteral("0"));
    m_process->setProcessEnvironment(environment);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);
    m_process->setWorkingDirectory(workingDirectory);
    m_processOutput.clear();
    m_processErrorOutput.clear();
    m_processOutputTooLarge = false;
    m_operation = operation;
    m_operationIdentifier = identifier;
    if (operation == Operation::FlatpakUpdate) {
        m_flatpakUpdateIdentifier = identifier;
        m_flatpakUpdateProgress = -1;
        emit flatpakUpdateStateChanged();
    }
    m_operationLog = QStringLiteral("Starting %1…").arg(program);
    emit operationLogChanged();
    setBusy(true);
    m_process->start(executable, arguments);
    return true;
}

void AppHubBackend::emitFlatpakOperationResult(Operation operation,
                                               const QString &identifier,
                                               bool success,
                                               const QString &error)
{
    QString action;
    switch (operation) {
    case Operation::FlatpakInstall:
        action = QStringLiteral("install");
        break;
    case Operation::FlatpakUpdate:
        action = QStringLiteral("update");
        break;
    case Operation::FlatpakRemove:
        action = QStringLiteral("remove");
        break;
    default:
        return;
    }

    emit flatpakOperationFinished(identifier, action, success, error);
}

void AppHubBackend::emitAppHubOperationResult(Operation operation,
                                             const QString &identifier,
                                             bool success,
                                             const QString &error)
{
    QString action;
    switch (operation) {
    case Operation::AppHubInstall:
        action = QStringLiteral("install");
        break;
    case Operation::AppHubRemove:
        action = QStringLiteral("remove");
        break;
    case Operation::AppHubRestore:
        action = QStringLiteral("restore");
        break;
    default:
        return;
    }

    emit appHubOperationFinished(identifier, action, success, error);
}

void AppHubBackend::refresh()
{
    refreshFlatpakInstalled();
    refreshFlathubFeatured();
    m_flathubCollectionCache.clear();
    m_flathubCollectionNextPage.clear();
    m_flathubCollectionTotalPages.clear();
    refreshFlathubCollection();
    refreshFlathubCategories();
    refreshAppHubCatalog();
    refreshUserBundles();
    refreshDistrobox();
    setStatusMessage(QStringLiteral("Sources refreshed."));
}

void AppHubBackend::loadMoreFlathubCollection()
{
    if (m_flathubCollectionLoading || !flathubCollectionHasMore())
        return;

    requestFlathubCollectionPage(m_flathubCollectionNextPage.value(m_flathubCollection, 1));
}

AppModel *AppHubBackend::flathubCategoryModel(const QString &category) const
{
    return m_flathubCategoryModels.value(category, nullptr);
}

bool AppHubBackend::flathubCategoryLoading(const QString &category) const
{
    return m_flathubCategoryReplies.contains(category);
}

bool AppHubBackend::flathubCategoryHasMore(const QString &category) const
{
    const int nextPage = m_flathubCategoryNextPage.value(category, 1);
    const int totalPages = m_flathubCategoryTotalPages.value(category, 0);
    return totalPages > 0 && nextPage <= totalPages;
}

void AppHubBackend::loadMoreFlathubCategory(const QString &category)
{
    if (!m_flathubCategoryModels.contains(category) || flathubCategoryLoading(category) || !flathubCategoryHasMore(category))
        return;

    requestFlathubCategoryPage(category, m_flathubCategoryNextPage.value(category, 1));
}

void AppHubBackend::browseFlathubCategory(const QString &category, const QString &subcategory)
{
    if (!flathubBrowseCategorySlugs().contains(category) || (!subcategory.isEmpty() && !isSafeIdentifier(subcategory)))
        return;

    if (category == m_flathubBrowseCategory && subcategory == m_flathubBrowseSubcategory)
        return;

    const bool categoryChanged = category != m_flathubBrowseCategory;
    cancelFlathubBrowseRequests(categoryChanged);
    m_flathubBrowseCategory = category;
    m_flathubBrowseSubcategory = subcategory;
    const QString cacheKey = flathubBrowseCacheKey(category, subcategory);
    m_flathubBrowseNextPage = m_flathubBrowseNextPageCache.value(cacheKey, 1);
    m_flathubBrowseTotalPages = m_flathubBrowseTotalPagesCache.value(cacheKey, 0);
    m_flathubBrowseModel->setItems(m_flathubBrowseCache.value(cacheKey));

    if (categoryChanged) {
        const auto featured = m_flathubBrowseFeaturedCache.constFind(category);
        m_flathubBrowseFeaturedModel->setItems(featured == m_flathubBrowseFeaturedCache.cend()
                                                   ? QList<AppModel::Item>()
                                                   : QList<AppModel::Item>{featured.value()});
    }

    emit flathubBrowseStateChanged();

    if (!m_flathubBrowseCache.contains(cacheKey)) {
        requestFlathubBrowseCategoryPage(1);
    } else if (!subcategory.isEmpty() && flathubBrowseHasMore()) {
        requestFlathubBrowseCategoryPage(m_flathubBrowseNextPage);
    } else if (categoryChanged && m_flathubBrowseFeaturedModel->items().isEmpty()
               && !m_flathubBrowseModel->items().isEmpty()) {
        requestFlathubBrowseFeatured(m_flathubBrowseModel->items().first());
    }
}

void AppHubBackend::loadMoreFlathubBrowseCategory()
{
    if (m_flathubBrowseLoading || !flathubBrowseHasMore())
        return;

    requestFlathubBrowseCategoryPage(m_flathubBrowseNextPage);
}

void AppHubBackend::refreshAppHubRepository()
{
    const QString executable = findExecutable(QStringLiteral("nx-apphub-cli"));
    if (executable.isEmpty()) {
        refreshAppHubCatalog();
        setStatusMessage(QStringLiteral("nx-apphub-cli is not installed; using the local AppHub repository."));
        return;
    }

    if (!startOperation(executable,
                       {QStringLiteral("search"), QStringLiteral("--"), m_query.isEmpty() ? QStringLiteral("app") : m_query},
                       Operation::AppHubSync))
        return;
    setStatusMessage(QStringLiteral("Refreshing NX AppHub metadata…"));
}

void AppHubBackend::search(const QString &query)
{
    const QString normalizedQuery = query.trimmed();
    if (normalizedQuery.size() > MaxQueryLength) {
        setStatusMessage(QStringLiteral("Search text is too long."));
        return;
    }
    m_query = normalizedQuery;

    switch (m_currentSection) {
    case Flathub:
        if (m_query.isEmpty()) {
            refreshFlatpakInstalled();
        } else {
            startOperation(QStringLiteral("flatpak"),
                           {QStringLiteral("search"), QStringLiteral("--columns=application,name,description,version,remotes"), QStringLiteral("--arch=%1").arg(architecture()), QStringLiteral("--"), m_query},
                           Operation::FlatpakSearch);
        }
        break;
    case AppHub:
        if (m_allAppHubItems.isEmpty())
            refreshAppHubCatalog();
        m_appHubModel->setItems(filterAppHubItems(m_allAppHubItems));
        break;
    case Distrobox:
        m_distroboxModel->setItems(filterItems(m_allDistroboxItems));
        break;
    }
}

void AppHubBackend::installFlatpak(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        const QString error = QStringLiteral("Invalid Flatpak identifier.");
        setStatusMessage(error);
        emitFlatpakOperationResult(Operation::FlatpakInstall, identifier, false, error);
        return;
    }
    if (!startOperation(QStringLiteral("flatpak"),
                       {QStringLiteral("install"), QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--app"), QStringLiteral("flathub"), identifier},
                       Operation::FlatpakInstall,
                       identifier)) {
        emitFlatpakOperationResult(Operation::FlatpakInstall, identifier, false, statusMessage());
        return;
    }
    setStatusMessage(QStringLiteral("Installing %1 from Flathub…").arg(identifier));
}

void AppHubBackend::updateFlatpak(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        const QString error = QStringLiteral("Invalid Flatpak identifier.");
        setStatusMessage(error);
        emitFlatpakOperationResult(Operation::FlatpakUpdate, identifier, false, error);
        return;
    }
    if (!startOperation(QStringLiteral("flatpak"),
                        {QStringLiteral("update"), QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--app"), identifier},
                        Operation::FlatpakUpdate,
                        identifier)) {
        emitFlatpakOperationResult(Operation::FlatpakUpdate, identifier, false, statusMessage());
        return;
    }
    setStatusMessage(QStringLiteral("Updating %1 from Flathub…").arg(identifier));
}

void AppHubBackend::removeFlatpak(const QString &identifier)
{
    removeInstalledFlatpak(identifier, !m_userInstalledFlatpaks.contains(identifier) && m_systemInstalledFlatpaks.contains(identifier));
}

void AppHubBackend::removeInstalledFlatpak(const QString &identifier, bool systemWide)
{
    const QSet<QString> &installed = systemWide ? m_systemInstalledFlatpaks : m_userInstalledFlatpaks;
    if (!isSafeIdentifier(identifier) || !installed.contains(identifier)) {
        const QString error = QStringLiteral("Invalid or uninstalled Flatpak identifier.");
        setStatusMessage(error);
        emitFlatpakOperationResult(Operation::FlatpakRemove, identifier, false, error);
        return;
    }

    if (!startOperation(QStringLiteral("flatpak"),
                        {QStringLiteral("uninstall"), systemWide ? QStringLiteral("--system") : QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--app"), identifier},
                        Operation::FlatpakRemove,
                        identifier)) {
        emitFlatpakOperationResult(Operation::FlatpakRemove, identifier, false, statusMessage());
        return;
    }
    setStatusMessage(QStringLiteral("Removing %1…").arg(identifier));
}

void AppHubBackend::loadFlatpakAddons(const QString &identifier, bool systemWide)
{
    const QSet<QString> &installed = systemWide ? m_systemInstalledFlatpaks : m_userInstalledFlatpaks;
    if (!isSafeIdentifier(identifier) || !installed.contains(identifier)) {
        m_flatpakAddonsApplication.clear();
        m_flatpakAddonsModel->setItems({});
        setStatusMessage(QStringLiteral("Invalid or uninstalled Flatpak identifier."));
        return;
    }

    m_flatpakAddonsApplication = identifier;
    m_flatpakAddonsSystemWide = systemWide;
    refreshFlatpakAddons();
}

void AppHubBackend::installFlatpakAddon(const QString &ref)
{
    if (!splitFlatpakRuntimeRef(ref)) {
        setStatusMessage(QStringLiteral("Invalid Flatpak add-on reference."));
        return;
    }

    if (!startOperation(QStringLiteral("flatpak"),
                        {QStringLiteral("install"), m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--runtime"), QStringLiteral("flathub"), ref},
                        Operation::FlatpakAddonInstall,
                        ref))
        return;
    setStatusMessage(QStringLiteral("Installing Flatpak add-on…"));
}

void AppHubBackend::removeFlatpakAddon(const QString &ref)
{
    if (!splitFlatpakRuntimeRef(ref)) {
        setStatusMessage(QStringLiteral("Invalid Flatpak add-on reference."));
        return;
    }

    if (!startOperation(QStringLiteral("flatpak"),
                        {QStringLiteral("uninstall"), m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--runtime"), ref},
                        Operation::FlatpakAddonRemove,
                        ref))
        return;
    setStatusMessage(QStringLiteral("Removing Flatpak add-on…"));
}

void AppHubBackend::appHubAction(const QString &identifier)
{
    const bool installed = appHubItemInstalled(identifier);
    const Operation operation = installed ? Operation::AppHubRemove : Operation::AppHubInstall;
    if (!isSafeIdentifier(identifier)) {
        const QString error = QStringLiteral("Invalid NX AppHub identifier.");
        setStatusMessage(error);
        emitAppHubOperationResult(operation, identifier, false, error);
        return;
    }
    const QString action = installed ? QStringLiteral("remove") : QStringLiteral("install");
    if (!startOperation(QStringLiteral("nx-apphub-cli"), {action, identifier},
                       operation, identifier)) {
        emitAppHubOperationResult(operation, identifier, false, statusMessage());
        return;
    }
    setStatusMessage(QStringLiteral("%1 %2 through NX AppHub…").arg(installed ? QStringLiteral("Removing") : QStringLiteral("Building"), identifier));
}

void AppHubBackend::refreshUserBundles()
{
    QString error;
    if (!m_userBundleStore.ensureRoot(&error)) {
        m_userBundleModel->setItems({});
        setStatusMessage(error);
        return;
    }
    m_userBundleModel->setItems(m_userBundleStore.projects());
}

void AppHubBackend::generateUserBundle(const QString &projectId, const QVariantMap &options)
{
    QString error;
    if (!m_userBundleStore.ensureRoot(&error)) {
        setStatusMessage(error);
        emit userBundleGenerated(projectId, false, error);
        return;
    }
    if (!m_userBundleStore.isValidProjectId(projectId) || m_userBundleStore.projectExists(projectId)) {
        error = QStringLiteral("Choose a valid, unused project ID.");
        setStatusMessage(error);
        emit userBundleGenerated(projectId, false, error);
        return;
    }

    const QString package = options.value(QStringLiteral("package")).toString().trimmed();
    const QString distro = options.value(QStringLiteral("distro")).toString().trimmed().toLower();
    const QString release = options.value(QStringLiteral("release")).toString().trimmed();
    const QString integration = options.value(QStringLiteral("integration")).toString().trimmed().toLower();
    const QVariant componentsOption = options.value(QStringLiteral("components"));
    QStringList components = componentsOption.toStringList();
    if (components.isEmpty()) {
        for (const QVariant &component : componentsOption.toList())
            components.append(component.toString());
    }
    components.removeAll(QString());
    if (components.isEmpty())
        components.append(QStringLiteral("main"));

    const QStringList distributions = {QStringLiteral("debian"), QStringLiteral("ubuntu"),
                                       QStringLiteral("devuan"), QStringLiteral("kde-neon"),
                                       QStringLiteral("nitrux")};
    const QStringList integrations = {QStringLiteral("cli"), QStringLiteral("gui"), QStringLiteral("wm")};
    if (!isSafeIdentifier(package) || !distributions.contains(distro) || !isSafeIdentifier(release)
        || !integrations.contains(integration)
        || std::any_of(components.cbegin(), components.cend(), [](const QString &component) {
               return !isSafeIdentifier(component);
           })) {
        error = QStringLiteral("The template-generation details are invalid.");
        setStatusMessage(error);
        emit userBundleGenerated(projectId, false, error);
        return;
    }

    m_userBundleGenerationDirectory = std::make_unique<QTemporaryDir>(
        QDir(m_userBundleStore.rootPath()).filePath(QStringLiteral(".appfinder-XXXXXX")));
    if (!m_userBundleGenerationDirectory->isValid()) {
        error = QStringLiteral("Could not create a temporary project directory.");
        m_userBundleGenerationDirectory.reset();
        setStatusMessage(error);
        emit userBundleGenerated(projectId, false, error);
        return;
    }

    const QString staging = m_userBundleGenerationDirectory->path();
    if (!QDir(staging).mkpath(QStringLiteral("metadata"))
        || !QDir(staging).mkpath(QStringLiteral("scripts"))
        || !QDir(staging).mkpath(QStringLiteral("dist"))) {
        error = QStringLiteral("Could not prepare the project directories.");
        m_userBundleGenerationDirectory.reset();
        setStatusMessage(error);
        emit userBundleGenerated(projectId, false, error);
        return;
    }

    QStringList arguments{
        QStringLiteral("generate"),
        QStringLiteral("--package"), package,
        QStringLiteral("--distro"), distro,
        QStringLiteral("--release"), release,
        QStringLiteral("--arch"), m_userBundleStore.hostPackageArchitecture(),
        QStringLiteral("--components")
    };
    arguments.append(components);
    arguments << QStringLiteral("--output") << QDir(staging).filePath(QStringLiteral("app.yml"))
              << QStringLiteral("--description-output") << QDir(staging).filePath(QStringLiteral("metadata/app_description.md"))
              << QStringLiteral("--integration-type") << integration;

    if (!startOperation(QStringLiteral("nx-apphub-cli"), arguments,
                        Operation::UserBundleGenerate, projectId, staging)) {
        error = statusMessage();
        m_userBundleGenerationDirectory.reset();
        emit userBundleGenerated(projectId, false, error);
        return;
    }
    setStatusMessage(QStringLiteral("Generating the %1 personal-bundle project…").arg(projectId));
}

QVariantMap AppHubBackend::loadUserBundle(const QString &projectId) const
{
    return m_userBundleStore.load(projectId);
}

bool AppHubBackend::createUserBundle(const QString &projectId,
                                     const QVariantMap &recipe,
                                     const QVariantMap &metadata)
{
    QString error;
    const bool created = m_userBundleStore.create(projectId, recipe, metadata, &error);
    if (created) {
        refreshUserBundles();
        setStatusMessage(QStringLiteral("Created the %1 personal-bundle project.").arg(projectId));
    } else {
        setStatusMessage(error);
    }
    emit userBundleSaved(projectId, created, error);
    return created;
}

bool AppHubBackend::saveUserBundle(const QString &projectId,
                                   const QVariantMap &recipe,
                                   const QVariantMap &metadata)
{
    QString error;
    const bool saved = m_userBundleStore.save(projectId, recipe, metadata, &error);
    if (saved) {
        refreshUserBundles();
        setStatusMessage(QStringLiteral("Saved the %1 personal-bundle project.").arg(projectId));
    } else {
        setStatusMessage(error);
    }
    emit userBundleSaved(projectId, saved, error);
    return saved;
}

void AppHubBackend::buildUserBundle(const QString &projectId)
{
    const QVariantMap document = m_userBundleStore.load(projectId);
    if (!document.value(QStringLiteral("valid")).toBool()) {
        const QString error = document.value(QStringLiteral("error")).toString();
        setStatusMessage(error);
        emit userBundleBuilt(projectId, false, {}, error);
        return;
    }

    const QVariantMap recipe = document.value(QStringLiteral("recipe")).toMap();
    const QString preflightError = m_userBundleStore.preflight(recipe);
    if (!preflightError.isEmpty()) {
        setStatusMessage(preflightError);
        emit userBundleBuilt(projectId, false, {}, preflightError);
        return;
    }

    const QString project = m_userBundleStore.projectPath(projectId);
    const QString dist = QDir(project).filePath(QStringLiteral("dist"));
    if (!QDir().mkpath(dist) || QFileInfo(dist).isSymbolicLink()) {
        const QString error = QStringLiteral("Could not prepare a safe build-output directory.");
        setStatusMessage(error);
        emit userBundleBuilt(projectId, false, {}, error);
        return;
    }

    m_userBundleOutputPath = m_userBundleStore.outputPath(projectId, recipe);
    const QFileInfo previousOutput(m_userBundleOutputPath);
    if (previousOutput.exists() && (!previousOutput.isFile() || previousOutput.isSymbolicLink())) {
        const QString error = QStringLiteral("The expected build output is not a safe regular file.");
        m_userBundleOutputPath.clear();
        setStatusMessage(error);
        emit userBundleBuilt(projectId, false, {}, error);
        return;
    }
    m_userBundleOutputPreviouslyExisted = previousOutput.isFile();
    m_userBundlePreviousOutputModified = previousOutput.lastModified();
    m_userBundlePreviousOutputSize = previousOutput.size();
    m_userBundleArtifactBackupDirectory.reset();
    if (m_userBundleOutputPreviouslyExisted) {
        m_userBundleArtifactBackupDirectory = std::make_unique<QTemporaryDir>();
        const QString backupPath = QDir(m_userBundleArtifactBackupDirectory->path()).filePath(QStringLiteral("previous.AppImage"));
        if (!m_userBundleArtifactBackupDirectory->isValid() || !QFile::copy(m_userBundleOutputPath, backupPath)) {
            const QString error = QStringLiteral("The existing personal bundle could not be preserved before building.");
            m_userBundleArtifactBackupDirectory.reset();
            m_userBundleOutputPath.clear();
            setStatusMessage(error);
            emit userBundleBuilt(projectId, false, {}, error);
            return;
        }
    }
    if (!m_userBundleOutputUrl.isEmpty()) {
        m_userBundleOutputUrl.clear();
        emit userBundleOutputUrlChanged();
    }

    if (!startOperation(QStringLiteral("nx-apphub-cli"),
                        {QStringLiteral("build"), QDir(project).filePath(QStringLiteral("app.yml"))},
                        Operation::UserBundleBuild, projectId, dist)) {
        const QString error = statusMessage();
        m_userBundleArtifactBackupDirectory.reset();
        m_userBundleOutputPath.clear();
        emit userBundleBuilt(projectId, false, {}, error);
        return;
    }
    setStatusMessage(QStringLiteral("Building the %1 personal bundle…").arg(projectId));
}

bool AppHubBackend::appHubHasBackups(const QString &identifier) const
{
    return !appHubBackupItems(identifier).isEmpty();
}

void AppHubBackend::loadAppHubBackups(const QString &identifier)
{
    m_appHubBackupsModel->setItems(appHubBackupItems(identifier));
}

void AppHubBackend::restoreAppHubBackup(const QString &identifier, const QString &backup)
{
    const QList<AppModel::Item> backups = appHubBackupItems(identifier);
    const auto selectedBackup = std::find_if(backups.cbegin(), backups.cend(), [&backup](const AppModel::Item &item) {
        return item.identifier == backup;
    });
    if (selectedBackup == backups.cend()) {
        const QString error = QStringLiteral("Invalid or unavailable NX AppHub backup.");
        setStatusMessage(error);
        emitAppHubOperationResult(Operation::AppHubRestore, identifier, false, error);
        return;
    }

    if (!startOperation(QStringLiteral("nx-apphub-cli"),
                        {QStringLiteral("downgrade"), identifier, QStringLiteral("--backup"), backup},
                        Operation::AppHubRestore,
                        identifier)) {
        emitAppHubOperationResult(Operation::AppHubRestore, identifier, false, statusMessage());
        return;
    }
    setStatusMessage(QStringLiteral("Restoring a backup for %1…").arg(identifier));
}

bool AppHubBackend::isFlatpakInstalled(const QString &identifier) const
{
    return isSafeIdentifier(identifier) && m_installedFlatpaks.contains(identifier);
}

void AppHubBackend::createDistrobox(const QString &name, const QString &image, const QString &home)
{
    const QString normalizedName = name.trimmed();
    const QString normalizedImage = image.trimmed();
    const QString normalizedHome = home.trimmed();
    if (!isSafeIdentifier(normalizedName) || normalizedImage.isEmpty() || normalizedImage.size() > MaxQueryLength
        || normalizedImage.startsWith(QLatin1Char('-')) || normalizedHome.startsWith(QLatin1Char('-'))) {
        setStatusMessage(QStringLiteral("Invalid Distrobox details."));
        return;
    }

    const QString executable = findExecutable(QStringLiteral("distrobox-create"));
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("distrobox-create is not installed."));
        return;
    }

    QStringList arguments {QStringLiteral("--name"), normalizedName, QStringLiteral("--image"), normalizedImage};
    if (!normalizedHome.isEmpty())
        arguments << QStringLiteral("--home") << normalizedHome;

    if (!startOperation(executable, arguments, Operation::DistroboxCreate, normalizedName))
        return;
    setStatusMessage(QStringLiteral("Creating %1…").arg(normalizedName));
}

void AppHubBackend::startDistrobox(const QString &name)
{
    if (!isSafeIdentifier(name)) {
        setStatusMessage(QStringLiteral("Invalid Distrobox name."));
        return;
    }
    const QString executable = containerEngine();
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("Neither podman nor docker is installed."));
        return;
    }
    if (!startOperation(executable, {QStringLiteral("start"), name}, Operation::DistroboxStart, name))
        return;
    setStatusMessage(QStringLiteral("Starting %1…").arg(name));
}

void AppHubBackend::stopDistrobox(const QString &name)
{
    if (!isSafeIdentifier(name)) {
        setStatusMessage(QStringLiteral("Invalid Distrobox name."));
        return;
    }
    const QString executable = containerEngine();
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("Neither podman nor docker is installed."));
        return;
    }
    if (!startOperation(executable, {QStringLiteral("stop"), name}, Operation::DistroboxStop, name))
        return;
    setStatusMessage(QStringLiteral("Stopping %1…").arg(name));
}

void AppHubBackend::cloneDistrobox(const QString &source, const QString &name)
{
    if (!isSafeIdentifier(source) || !isSafeIdentifier(name)) {
        setStatusMessage(QStringLiteral("Invalid Distrobox name."));
        return;
    }
    const QString executable = findExecutable(QStringLiteral("distrobox-create"));
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("distrobox-create is not installed."));
        return;
    }
    if (!startOperation(executable, {QStringLiteral("--clone"), source, QStringLiteral("--name"), name}, Operation::DistroboxClone, name))
        return;
    setStatusMessage(QStringLiteral("Cloning %1 as %2…").arg(source, name));
}

void AppHubBackend::removeDistrobox(const QString &name)
{
    if (!isSafeIdentifier(name)) {
        setStatusMessage(QStringLiteral("Invalid Distrobox name."));
        return;
    }
    const QString executable = containerEngine();
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("Neither podman nor docker is installed."));
        return;
    }
    if (!startOperation(executable, {QStringLiteral("rm"), QStringLiteral("--force"), name}, Operation::DistroboxRemove, name))
        return;
    setStatusMessage(QStringLiteral("Removing %1…").arg(name));
}

void AppHubBackend::enterDistrobox(const QString &name)
{
    if (!isSafeIdentifier(name)) {
        setStatusMessage(QStringLiteral("Invalid Distrobox name."));
        return;
    }
    const QString executable = findExecutable(QStringLiteral("distrobox"));
    if (executable.isEmpty()) {
        setStatusMessage(QStringLiteral("distrobox is not installed."));
        return;
    }

    const QString terminal = findExecutable(QStringLiteral("xdg-terminal-exec"));
    if (terminal.isEmpty()) {
        setStatusMessage(QStringLiteral("xdg-terminal-exec is not installed."));
        return;
    }

    if (QProcess::startDetached(terminal, {executable, QStringLiteral("enter"), QStringLiteral("--name"), name}))
        setStatusMessage(QStringLiteral("Opening a terminal in %1.").arg(name));
    else
        setStatusMessage(QStringLiteral("Could not enter %1.").arg(name));
}

void AppHubBackend::refreshFlatpakInstalled()
{
    m_installedFlatpaks.clear();
    m_userInstalledFlatpaks.clear();
    m_systemInstalledFlatpaks.clear();

    const auto installedItems = [this](const QByteArray &output, bool systemWide) {
        QList<AppModel::Item> items;
        for (const QByteArray &line : output.split(10)) {
            const QStringList fields = QString::fromLocal8Bit(line).split(QLatin1String("\t"));
            if (fields.size() < 6 || fields.first().trimmed().isEmpty())
                continue;

            const QString identifier = fields.at(0).trimmed();
            if (identifier == QLatin1String("Application") || !isSafeIdentifier(identifier))
                continue;

            m_installedFlatpaks.insert(identifier);
            if (systemWide)
                m_systemInstalledFlatpaks.insert(identifier);
            else
                m_userInstalledFlatpaks.insert(identifier);

            items.append({
                fields.value(1, identifier).trimmed(),
                QStringLiteral("Installed through Flatpak"),
                fields.value(3).trimmed(),
                fields.value(4).trimmed(),
                identifier,
                QStringLiteral("Desktop Application"),
                QStringLiteral("Remove"),
                QStringLiteral("edit-delete"),
                identifier,
                QStringLiteral("Installed"),
                {},
                {},
                {},
                QStringLiteral("Installed through Flatpak"),
                systemWide ? QStringLiteral("system") : QStringLiteral("user"),
                QStringLiteral("GUI Application"),
                fields.value(5).trimmed(),
                {},
                {},
                {}
            });
        }
        return items;
    };

    const QByteArray userOutput = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("list"), QStringLiteral("--user"), QStringLiteral("--app"), QStringLiteral("--columns=application,name,origin,version,arch,size")});
    const QByteArray systemOutput = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("list"), QStringLiteral("--system"), QStringLiteral("--app"), QStringLiteral("--columns=application,name,origin,version,arch,size")});

    m_flathubModel->setItems(filterItems(sortedInstalledFlatpaks(installedItems(userOutput, false))));
    m_systemFlatpakModel->setItems(filterItems(sortedInstalledFlatpaks(installedItems(systemOutput, true))));
    refreshFlatpakUpdates();
}

void AppHubBackend::refreshFlatpakUpdates()
{
    const QByteArray output = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("remote-ls"),
         QStringLiteral("--user"),
         QStringLiteral("--app"),
         QStringLiteral("--updates"),
         QStringLiteral("--arch=%1").arg(architecture()),
         QStringLiteral("--columns=application,name,version,download-size"),
         QStringLiteral("flathub")});
    QList<AppModel::Item> items;

    for (const QByteArray &line : output.split('\n')) {
        const QStringList fields = QString::fromLocal8Bit(line).split('\t');
        if (fields.size() < 4)
            continue;

        const QString identifier = fields.at(0).trimmed();
        if (!isSafeIdentifier(identifier) || !m_userInstalledFlatpaks.contains(identifier))
            continue;

        QString name = fields.value(1).trimmed();
        if (name.isEmpty())
            name = identifier;

        items.append({
            name,
            QStringLiteral("Update available"),
            fields.value(2).trimmed(),
            architecture(),
            identifier,
            QStringLiteral("Desktop Application"),
            {},
            {},
            identifier,
            QStringLiteral("Update Available"),
            {},
            {},
            {},
            QStringLiteral("An updated version is available from Flathub."),
            {},
            QStringLiteral("GUI Application"),
            fields.value(3).trimmed(),
            {},
            {},
            {},
            {}
        });
    }

    std::stable_sort(items.begin(), items.end(), [](const AppModel::Item &left, const AppModel::Item &right) {
        const int nameComparison = left.name.compare(right.name, Qt::CaseInsensitive);
        if (nameComparison != 0)
            return nameComparison < 0;
        return left.identifier.compare(right.identifier, Qt::CaseInsensitive) < 0;
    });
    m_flathubUpdatesModel->setItems(items);
}

void AppHubBackend::refreshFlatpakAddons()
{
    QList<AppModel::Item> items;
    if (m_flatpakAddonsApplication.isEmpty()) {
        m_flatpakAddonsModel->setItems(items);
        return;
    }

    const QString appRef = QString::fromLocal8Bit(
        runCommand(QStringLiteral("flatpak"),
                   {QStringLiteral("info"), m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"), QStringLiteral("--show-ref"), m_flatpakAddonsApplication}))
                               .trimmed();
    const QStringList appRefParts = appRef.split(QLatin1String("/"));
    if (appRefParts.size() != 4 || appRefParts.at(0) != QLatin1String("app")
        || appRefParts.at(1) != m_flatpakAddonsApplication || !isSafeIdentifier(appRefParts.at(2))
        || !isSafeIdentifier(appRefParts.at(3))) {
        m_flatpakAddonsModel->setItems(items);
        return;
    }

    const QString appArchitecture = appRefParts.at(2);
    const QString appBranch = appRefParts.at(3);
    const QByteArray metadata = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("info"), m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"), QStringLiteral("--show-metadata"), m_flatpakAddonsApplication});
    const QList<FlatpakExtensionPoint> extensionPoints = flatpakExtensionPoints(metadata, appBranch);
    if (extensionPoints.isEmpty()) {
        m_flatpakAddonsModel->setItems(items);
        return;
    }

    QSet<QString> installedRefs;
    const QByteArray installedOutput = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("list"),
         m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"),
         QStringLiteral("--runtime"),
         QStringLiteral("--all"),
         QStringLiteral("--columns=application,arch,branch")});
    for (const QByteArray &rawLine : installedOutput.split(10)) {
        const QStringList fields = QString::fromLocal8Bit(rawLine).split(QLatin1String("\t"));
        if (fields.size() < 3)
            continue;

        const QString identifier = fields.at(0).trimmed();
        const QString refArchitecture = fields.at(1).trimmed();
        const QString branch = fields.at(2).trimmed();
        if (!isSafeIdentifier(identifier) || !isSafeIdentifier(refArchitecture) || !isSafeIdentifier(branch))
            continue;

        installedRefs.insert(QStringLiteral("runtime/%1/%2/%3").arg(identifier, refArchitecture, branch));
    }

    const QByteArray remoteOutput = runCommand(
        QStringLiteral("flatpak"),
        {QStringLiteral("remote-ls"),
         m_flatpakAddonsSystemWide ? QStringLiteral("--system") : QStringLiteral("--user"),
         QStringLiteral("--runtime"),
         QStringLiteral("--arch=%1").arg(appArchitecture),
         QStringLiteral("--columns=application,name,description,version,branch,arch,download-size"),
         QStringLiteral("flathub")});
    QSet<QString> seenRefs;

    for (const QByteArray &rawLine : remoteOutput.split(10)) {
        const QStringList fields = QString::fromLocal8Bit(rawLine).split(QLatin1String("\t"));
        if (fields.size() < 7)
            continue;

        const QString identifier = fields.at(0).trimmed();
        const QString branch = fields.at(4).trimmed();
        const QString refArchitecture = fields.at(5).trimmed();
        if (!isSafeIdentifier(identifier) || !isSafeIdentifier(branch) || refArchitecture != appArchitecture)
            continue;

        bool matchesExtensionPoint = false;
        for (const FlatpakExtensionPoint &point : extensionPoints) {
            if (!point.identifier.startsWith(m_flatpakAddonsApplication + QLatin1String(".")))
                continue;

            const bool identifierMatches = identifier == point.identifier
                || (point.subdirectories && identifier.startsWith(point.identifier + QLatin1String(".")));
            if (identifierMatches && point.branches.contains(branch)) {
                matchesExtensionPoint = true;
                break;
            }
        }
        if (!matchesExtensionPoint)
            continue;

        const QString ref = QStringLiteral("runtime/%1/%2/%3").arg(identifier, refArchitecture, branch);
        if (seenRefs.contains(ref))
            continue;
        seenRefs.insert(ref);

        const bool installed = installedRefs.contains(ref);
        AppModel::Item item;
        item.name = fields.at(1).trimmed();
        if (item.name.isEmpty())
            item.name = appHubDisplayName(identifier.split(QLatin1String(".")).constLast());
        item.summary = fields.at(2).trimmed();
        if (item.summary.isEmpty())
            item.summary = QStringLiteral("Optional Flatpak add-on");
        item.version = fields.at(3).trimmed();
        item.architecture = refArchitecture;
        item.identifier = ref;
        item.category = QStringLiteral("Add-on");
        item.actionText = installed ? QStringLiteral("Remove") : QStringLiteral("Install");
        item.actionIcon = installed ? QStringLiteral("edit-delete") : QStringLiteral("download");
        item.icon = m_flatpakAddonsApplication;
        item.status = installed ? QStringLiteral("Installed") : QStringLiteral("Available");
        item.description = item.summary;
        item.type = QStringLiteral("Runtime Extension");
        item.size = fields.at(6).trimmed();
        items.append(item);
    }

    std::stable_sort(items.begin(), items.end(), [](const AppModel::Item &left, const AppModel::Item &right) {
        const int nameComparison = left.name.compare(right.name, Qt::CaseInsensitive);
        if (nameComparison != 0)
            return nameComparison < 0;
        return left.identifier.compare(right.identifier, Qt::CaseInsensitive) < 0;
    });
    m_flatpakAddonsModel->setItems(items);
}

void AppHubBackend::cancelFlathubFeaturedRequests()
{
    if (m_featuredCollectionReply) {
        m_featuredCollectionReply->abort();
        m_featuredCollectionReply->deleteLater();
        m_featuredCollectionReply = nullptr;
    }

    const auto detailReplies = m_featuredDetailReplies.keys();
    m_featuredDetailReplies.clear();
    for (QNetworkReply *reply : detailReplies) {
        reply->abort();
        reply->deleteLater();
    }

    const auto iconReplies = m_featuredIconReplies.keys();
    m_featuredIconReplies.clear();
    for (QNetworkReply *reply : iconReplies) {
        reply->abort();
        reply->deleteLater();
    }
}

void AppHubBackend::refreshFlathubFeatured()
{
    cancelFlathubFeaturedRequests();
    m_featuredItems.clear();
    m_flathubFeaturedModel->setItems({});

    const QString date = QDate::currentDate().toString(Qt::ISODate);
    QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/app-picks/apps-of-the-week/%1").arg(date)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
    m_featuredCollectionReply = m_network->get(request);
    QNetworkReply *reply = m_featuredCollectionReply;
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_featuredCollectionReply != reply) {
            reply->deleteLater();
            return;
        }

        m_featuredCollectionReply = nullptr;
        const QByteArray response = reply->readAll();
        const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
        reply->deleteLater();
        if (valid)
            parseFlathubFeaturedCollection(response);
    });
}

void AppHubBackend::parseFlathubFeaturedCollection(const QByteArray &output)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    const QJsonArray apps = document.object().value(QStringLiteral("apps")).toArray();
    for (const QJsonValue &value : apps) {
        if (m_featuredItems.size() >= MaxFeaturedItems)
            break;
        if (!value.isObject())
            continue;

        const QString identifier = value.toObject().value(QStringLiteral("app_id")).toString().trimmed();
        if (!isSafeIdentifier(identifier))
            continue;

        AppModel::Item item;
        item.name = identifier;
        item.identifier = identifier;
        item.actionText = m_installedFlatpaks.contains(identifier) ? QStringLiteral("Remove") : QStringLiteral("Install");
        item.actionIcon = m_installedFlatpaks.contains(identifier) ? QStringLiteral("edit-delete") : QStringLiteral("list-add");
        item.icon = QStringLiteral("application-x-flatpak");
        item.status = m_installedFlatpaks.contains(identifier) ? QStringLiteral("Installed") : QStringLiteral("Available");
        m_featuredItems.append(item);
    }

    for (int index = 0; index < m_featuredItems.size(); ++index) {
        const QString encodedIdentifier = QString::fromUtf8(QUrl::toPercentEncoding(m_featuredItems.at(index).identifier));
        QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/appstream/%1").arg(encodedIdentifier)));
        request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
        QNetworkReply *reply = m_network->get(request);
        m_featuredDetailReplies.insert(reply, index);
        connect(reply, &QNetworkReply::finished, this, [this, reply] {
            const auto iterator = m_featuredDetailReplies.find(reply);
            if (iterator == m_featuredDetailReplies.end()) {
                reply->deleteLater();
                return;
            }

            const int index = iterator.value();
            m_featuredDetailReplies.erase(iterator);
            const QByteArray response = reply->readAll();
            const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
            reply->deleteLater();
            if (valid)
                parseFlathubFeaturedAppstream(response, index);
            if (m_featuredDetailReplies.isEmpty())
                finalizeFlathubFeatured();
        });
    }
}

void AppHubBackend::parseFlathubFeaturedAppstream(const QByteArray &output, int index)
{
    if (index < 0 || index >= m_featuredItems.size())
        return;

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    const QJsonObject object = document.object();
    AppModel::Item &item = m_featuredItems[index];
    item.name = object.value(QStringLiteral("name")).toString(item.identifier).trimmed();
    item.summary = object.value(QStringLiteral("summary")).toString().trimmed();
    item.description = object.value(QStringLiteral("description")).toString().trimmed();
    item.type = object.value(QStringLiteral("type")).toString().trimmed();
    item.iconUrl = object.value(QStringLiteral("icon")).toString().trimmed();

    const QJsonArray categories = object.value(QStringLiteral("categories")).toArray();
    for (const QJsonValue &category : categories) {
        const QString value = category.toString().trimmed();
        if (!value.isEmpty()) {
            item.category = displayCategory(value);
            break;
        }
    }
    if (item.category.isEmpty())
        item.category = QStringLiteral("Application");

    QString screenshotUrl;
    QString screenshotCaption;
    qint64 largestArea = -1;
    const QJsonArray screenshots = object.value(QStringLiteral("screenshots")).toArray();
    for (const QJsonValue &screenshotValue : screenshots) {
        if (!screenshotValue.isObject())
            continue;

        const QJsonObject screenshot = screenshotValue.toObject();
        const QString caption = screenshot.value(QStringLiteral("caption")).toString().trimmed();
        const QJsonArray sizes = screenshot.value(QStringLiteral("sizes")).toArray();
        for (const QJsonValue &sizeValue : sizes) {
            if (!sizeValue.isObject())
                continue;

            const QJsonObject size = sizeValue.toObject();
            const QString source = size.value(QStringLiteral("src")).toString().trimmed();
            const qint64 width = size.value(QStringLiteral("width")).toString().toLongLong();
            const qint64 height = size.value(QStringLiteral("height")).toString().toLongLong();
            const qint64 area = width > 0 && height > 0 ? width * height : 0;
            if (!source.isEmpty() && area > largestArea) {
                screenshotUrl = source;
                screenshotCaption = caption;
                largestArea = area;
            }
        }
    }

    if (screenshotUrl.isEmpty())
        return;

    item.screenshot = screenshotUrl;
    item.screenshotCaption = screenshotCaption;
}

void AppHubBackend::finalizeFlathubFeatured()
{
    QList<AppModel::Item> readyItems;
    for (const AppModel::Item &item : m_featuredItems) {
        if (!item.iconUrl.isEmpty() && !item.screenshot.isEmpty())
            readyItems.append(item);
    }

    m_featuredItems = readyItems;
    m_flathubFeaturedModel->setItems(m_featuredItems);

    for (int index = 0; index < m_featuredItems.size(); ++index) {
        QNetworkRequest iconRequest(QUrl(m_featuredItems.at(index).iconUrl));
        iconRequest.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
        QNetworkReply *iconReply = m_network->get(iconRequest);
        m_featuredIconReplies.insert(iconReply, index);
        connect(iconReply, &QNetworkReply::finished, this, [this, iconReply] {
            const auto iterator = m_featuredIconReplies.find(iconReply);
            if (iterator == m_featuredIconReplies.end()) {
                iconReply->deleteLater();
                return;
            }

            const int index = iterator.value();
            m_featuredIconReplies.erase(iterator);
            const QByteArray response = iconReply->readAll();
            const bool valid = iconReply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedIconBytes;
            iconReply->deleteLater();
            if (valid && index >= 0 && index < m_featuredItems.size()) {
                const QImage image = QImage::fromData(response);
                if (!image.isNull()) {
                    const QColor accentColor = accentFromArtwork(image);
                    if (accentColor.isValid()) {
                        m_featuredItems[index].accentColor = accentColor.name(QColor::HexRgb);
                        m_flathubFeaturedModel->setItems(m_featuredItems);
                    }
                }
            }
        });
    }
}

void AppHubBackend::setFlathubCollectionLoading(bool loading)
{
    if (m_flathubCollectionLoading == loading)
        return;

    m_flathubCollectionLoading = loading;
    emit flathubCollectionLoadingChanged();
}

void AppHubBackend::cancelFlathubCollectionRequest()
{
    if (!m_flathubCollectionReply)
        return;

    m_flathubCollectionReply->abort();
    m_flathubCollectionReply->deleteLater();
    m_flathubCollectionReply = nullptr;
    setFlathubCollectionLoading(false);
}

void AppHubBackend::refreshFlathubCollection()
{
    cancelFlathubCollectionRequest();
    m_flathubCollectionCache.remove(m_flathubCollection);
    m_flathubCollectionNextPage.remove(m_flathubCollection);
    m_flathubCollectionTotalPages.remove(m_flathubCollection);
    m_flathubCollectionModel->setItems({});
    emit flathubCollectionHasMoreChanged();
    requestFlathubCollectionPage(1);
}

void AppHubBackend::requestFlathubCollectionPage(int page)
{
    if (m_flathubCollectionReply || page < 1)
        return;

    const int requestedCollection = m_flathubCollection;
    const QString slug = flathubCollectionSlug(requestedCollection);
    QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/collection/%1?page=%2&per_page=%3")
                                     .arg(slug)
                                     .arg(page)
                                     .arg(FlathubCollectionPageSize)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
    m_flathubCollectionReply = m_network->get(request);
    QNetworkReply *reply = m_flathubCollectionReply;
    setFlathubCollectionLoading(true);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestedCollection, page] {
        if (m_flathubCollectionReply != reply) {
            reply->deleteLater();
            return;
        }

        m_flathubCollectionReply = nullptr;
        const QByteArray response = reply->readAll();
        const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
        reply->deleteLater();
        setFlathubCollectionLoading(false);
        if (valid)
            parseFlathubCollection(response, requestedCollection, page);
    });
}

void AppHubBackend::parseFlathubCollection(const QByteArray &output, int collection, int page)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    const QJsonObject root = document.object();
    const QList<AppModel::Item> items = appendFlathubHits(page == 1 ? QList<AppModel::Item>() : m_flathubCollectionCache.value(collection),
                                                         root.value(QStringLiteral("hits")).toArray());

    m_flathubCollectionCache.insert(collection, items);
    m_flathubCollectionNextPage.insert(collection, page + 1);
    m_flathubCollectionTotalPages.insert(collection, root.value(QStringLiteral("totalPages")).toInt(page));

    if (collection == m_flathubCollection) {
        m_flathubCollectionModel->setItems(items);
        emit flathubCollectionHasMoreChanged();
    }
}

void AppHubBackend::cancelFlathubCategoryRequests()
{
    const auto replies = m_flathubCategoryReplies;
    m_flathubCategoryReplies.clear();
    for (auto iterator = replies.cbegin(); iterator != replies.cend(); ++iterator) {
        iterator.value()->abort();
        iterator.value()->deleteLater();
    }
    if (!replies.isEmpty()) {
        ++m_flathubCategoryRevision;
        emit flathubCategoryRevisionChanged();
    }
}

void AppHubBackend::refreshFlathubCategories()
{
    cancelFlathubCategoryRequests();
    m_flathubCategoryNextPage.clear();
    m_flathubCategoryTotalPages.clear();

    for (auto iterator = m_flathubCategoryModels.cbegin(); iterator != m_flathubCategoryModels.cend(); ++iterator) {
        iterator.value()->setItems({});
        requestFlathubCategoryPage(iterator.key(), 1);
    }
}

void AppHubBackend::requestFlathubCategoryPage(const QString &category, int page)
{
    if (!m_flathubCategoryModels.contains(category) || m_flathubCategoryReplies.contains(category) || page < 1)
        return;

    const QString endpoint = flathubCategoryEndpoint(category);
    QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/collection/%1&page=%2&per_page=%3")
                                     .arg(endpoint)
                                     .arg(page)
                                     .arg(FlathubCollectionPageSize)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
    QNetworkReply *reply = m_network->get(request);
    m_flathubCategoryReplies.insert(category, reply);
    ++m_flathubCategoryRevision;
    emit flathubCategoryRevisionChanged();

    connect(reply, &QNetworkReply::finished, this, [this, reply, category, page] {
        if (m_flathubCategoryReplies.value(category) != reply) {
            reply->deleteLater();
            return;
        }

        m_flathubCategoryReplies.remove(category);
        const QByteArray response = reply->readAll();
        const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
        reply->deleteLater();
        if (valid)
            parseFlathubCategory(response, category, page);
        ++m_flathubCategoryRevision;
        emit flathubCategoryRevisionChanged();
    });
}

void AppHubBackend::parseFlathubCategory(const QByteArray &output, const QString &category, int page)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    AppModel *model = m_flathubCategoryModels.value(category, nullptr);
    if (!model)
        return;

    const QJsonObject root = document.object();
    model->setItems(appendFlathubHits(page == 1 ? QList<AppModel::Item>() : model->items(),
                                     root.value(QStringLiteral("hits")).toArray()));
    m_flathubCategoryNextPage.insert(category, page + 1);
    m_flathubCategoryTotalPages.insert(category, root.value(QStringLiteral("totalPages")).toInt(page));
}

void AppHubBackend::cancelFlathubBrowseRequests(bool cancelFeatured)
{
    if (m_flathubBrowseReply) {
        m_flathubBrowseReply->abort();
        m_flathubBrowseReply->deleteLater();
        m_flathubBrowseReply = nullptr;
    }
    if (cancelFeatured && m_flathubBrowseFeaturedReply) {
        m_flathubBrowseFeaturedReply->abort();
        m_flathubBrowseFeaturedReply->deleteLater();
        m_flathubBrowseFeaturedReply = nullptr;
    }
    if (m_flathubBrowseLoading) {
        m_flathubBrowseLoading = false;
        emit flathubBrowseStateChanged();
    }
}

void AppHubBackend::requestFlathubBrowseCategoryPage(int page)
{
    if (m_flathubBrowseCategory.isEmpty() || m_flathubBrowseReply || page < 1)
        return;

    const QString endpoint = flathubBrowseEndpoint(m_flathubBrowseCategory, m_flathubBrowseSubcategory);
    QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/collection/%1&page=%2&per_page=%3")
                                     .arg(endpoint)
                                     .arg(page)
                                     .arg(FlathubCollectionPageSize)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
    m_flathubBrowseReply = m_network->get(request);
    QNetworkReply *reply = m_flathubBrowseReply;
    m_flathubBrowseLoading = true;
    emit flathubBrowseStateChanged();

    connect(reply, &QNetworkReply::finished, this, [this, reply, page] {
        if (m_flathubBrowseReply != reply) {
            reply->deleteLater();
            return;
        }

        m_flathubBrowseReply = nullptr;
        const QByteArray response = reply->readAll();
        const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
        reply->deleteLater();
        if (valid)
            parseFlathubBrowseCategory(response, page);

        if (valid && !m_flathubBrowseSubcategory.isEmpty() && flathubBrowseHasMore()) {
            requestFlathubBrowseCategoryPage(m_flathubBrowseNextPage);
            return;
        }

        m_flathubBrowseLoading = false;
        emit flathubBrowseStateChanged();
    });
}

void AppHubBackend::parseFlathubBrowseCategory(const QByteArray &output, int page)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    const QJsonObject root = document.object();
    const QList<AppModel::Item> items = appendFlathubHits(
        page == 1 ? QList<AppModel::Item>() : m_flathubBrowseModel->items(),
        root.value(QStringLiteral("hits")).toArray());
    m_flathubBrowseModel->setItems(items);
    m_flathubBrowseNextPage = page + 1;
    m_flathubBrowseTotalPages = root.value(QStringLiteral("totalPages")).toInt(page);
    const QString cacheKey = flathubBrowseCacheKey(m_flathubBrowseCategory, m_flathubBrowseSubcategory);
    m_flathubBrowseCache.insert(cacheKey, items);
    m_flathubBrowseNextPageCache.insert(cacheKey, m_flathubBrowseNextPage);
    m_flathubBrowseTotalPagesCache.insert(cacheKey, m_flathubBrowseTotalPages);

    if (page == 1 && m_flathubBrowseSubcategory.isEmpty() && !items.isEmpty()
        && !m_flathubBrowseFeaturedCache.contains(m_flathubBrowseCategory))
        requestFlathubBrowseFeatured(items.first());
}

void AppHubBackend::requestFlathubBrowseFeatured(const AppModel::Item &item)
{
    m_flathubBrowseFeaturedItem = item;
    m_flathubBrowseFeaturedCategory = m_flathubBrowseCategory;
    const QString encodedIdentifier = QString::fromUtf8(QUrl::toPercentEncoding(item.identifier));
    QNetworkRequest request(QUrl(QStringLiteral("https://flathub.org/api/v2/appstream/%1").arg(encodedIdentifier)));
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("AppFinder"));
    m_flathubBrowseFeaturedReply = m_network->get(request);
    QNetworkReply *reply = m_flathubBrowseFeaturedReply;

    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        if (m_flathubBrowseFeaturedReply != reply) {
            reply->deleteLater();
            return;
        }

        m_flathubBrowseFeaturedReply = nullptr;
        const QByteArray response = reply->readAll();
        const bool valid = reply->error() == QNetworkReply::NoError && response.size() <= MaxFeaturedResponseBytes;
        reply->deleteLater();
        if (valid)
            parseFlathubBrowseFeatured(response);
    });
}

void AppHubBackend::parseFlathubBrowseFeatured(const QByteArray &output)
{
    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(output, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return;

    const QJsonObject object = document.object();
    AppModel::Item item = m_flathubBrowseFeaturedItem;
    const QString identifier = item.identifier;
    if (!isSafeIdentifier(identifier))
        return;
    item.name = object.value(QStringLiteral("name")).toString(identifier).trimmed();
    item.summary = object.value(QStringLiteral("summary")).toString().trimmed();
    item.description = object.value(QStringLiteral("description")).toString().trimmed();
    item.type = object.value(QStringLiteral("type")).toString().trimmed();
    item.icon = QStringLiteral("application-x-flatpak");
    item.iconUrl = object.value(QStringLiteral("icon")).toString().trimmed();
    item.category = displayCategory(m_flathubBrowseCategory);
    item.actionText = m_installedFlatpaks.contains(identifier) ? QStringLiteral("Remove") : QStringLiteral("Install");
    item.actionIcon = m_installedFlatpaks.contains(identifier) ? QStringLiteral("edit-delete") : QStringLiteral("list-add");
    item.status = m_installedFlatpaks.contains(identifier) ? QStringLiteral("Installed") : QStringLiteral("Available");

    qint64 largestArea = -1;
    const QJsonArray screenshots = object.value(QStringLiteral("screenshots")).toArray();
    for (const QJsonValue &screenshotValue : screenshots) {
        if (!screenshotValue.isObject())
            continue;

        const QJsonObject screenshot = screenshotValue.toObject();
        const QString caption = screenshot.value(QStringLiteral("caption")).toString().trimmed();
        const QJsonArray sizes = screenshot.value(QStringLiteral("sizes")).toArray();
        for (const QJsonValue &sizeValue : sizes) {
            if (!sizeValue.isObject())
                continue;

            const QJsonObject size = sizeValue.toObject();
            const QString source = size.value(QStringLiteral("src")).toString().trimmed();
            const qint64 width = size.value(QStringLiteral("width")).toVariant().toLongLong();
            const qint64 height = size.value(QStringLiteral("height")).toVariant().toLongLong();
            const qint64 area = width > 0 && height > 0 ? width * height : 0;
            if (!source.isEmpty() && area > largestArea) {
                item.screenshot = source;
                item.screenshotCaption = caption;
                largestArea = area;
            }
        }
    }

    m_flathubBrowseFeaturedCache.insert(m_flathubBrowseFeaturedCategory, item);
    if (m_flathubBrowseFeaturedCategory == m_flathubBrowseCategory)
        m_flathubBrowseFeaturedModel->setItems({item});
}

void AppHubBackend::refreshAppHubCatalog()
{
    m_allAppHubItems = loadAppHubItems();

    QList<AppModel::Item> featuredItems = m_allAppHubItems;
    for (qsizetype index = featuredItems.size() - 1; index > 0; --index) {
        const qsizetype randomIndex = QRandomGenerator::global()->bounded(static_cast<int>(index + 1));
        featuredItems.swapItemsAt(index, randomIndex);
    }
    if (featuredItems.size() > MaxFeaturedItems)
        featuredItems.resize(MaxFeaturedItems);
    m_appHubFeaturedModel->setItems(featuredItems);
    refreshAppHubCategories();
    m_appHubModel->setItems(filterAppHubItems(m_allAppHubItems));
}

void AppHubBackend::refreshDistrobox()
{
    m_allDistroboxItems = loadDistroboxItems(runCommand(QStringLiteral("distrobox"), {QStringLiteral("list"), QStringLiteral("--no-color")}));
    m_distroboxModel->setItems(filterItems(m_allDistroboxItems));
}

void AppHubBackend::parseFlatpakSearch(const QByteArray &output)
{
    QList<AppModel::Item> items;
    for (const QByteArray &line : output.split('\n')) {
        const QStringList fields = QString::fromLocal8Bit(line).split('\t');
        if (fields.size() < 5 || fields.first().trimmed().isEmpty())
            continue;

        const QString identifier = fields.at(0).trimmed();
        if (identifier == QLatin1String("Application") || !isSafeIdentifier(identifier) || !isFlathubRemote(fields.value(4)))
            continue;

        const bool installed = m_installedFlatpaks.contains(identifier);
        items.append({
            fields.value(1, identifier).trimmed(),
            fields.value(2).trimmed(),
            fields.value(3).trimmed(),
            architecture(),
            identifier,
            QStringLiteral("Flathub Application"),
            installed ? QStringLiteral("Remove") : QStringLiteral("Install"),
            installed ? QStringLiteral("edit-delete") : QStringLiteral("list-add"),
            QStringLiteral("application-x-flatpak"),
            installed ? QStringLiteral("Installed") : QStringLiteral("Available"),
            {},
            {},
            {},
            fields.value(2).trimmed(),
            {},
            QStringLiteral("GUI Application"),
            QString(),
            {},
            {},
            {}
        });
    }

    m_flathubModel->setItems(items);
}

QList<AppModel::Item> AppHubBackend::sortedInstalledFlatpaks(const QList<AppModel::Item> &items) const
{
    QList<AppModel::Item> sorted = items;
    const auto nameLessThan = [](const AppModel::Item &left, const AppModel::Item &right) {
        const int nameComparison = left.name.compare(right.name, Qt::CaseInsensitive);
        if (nameComparison != 0)
            return nameComparison < 0;
        return left.identifier.compare(right.identifier, Qt::CaseInsensitive) < 0;
    };

    std::stable_sort(sorted.begin(), sorted.end(), [this, nameLessThan](const AppModel::Item &left, const AppModel::Item &right) {
        if (m_flatpakSortMode == QLatin1String("size")) {
            const double leftSize = flatpakSizeBytes(left.size);
            const double rightSize = flatpakSizeBytes(right.size);
            if (leftSize != rightSize)
                return leftSize > rightSize;
        }
        return nameLessThan(left, right);
    });
    return sorted;
}

QList<AppModel::Item> AppHubBackend::filterItems(const QList<AppModel::Item> &items) const
{
    if (m_query.isEmpty())
        return items;

    QList<AppModel::Item> filtered;
    for (const auto &item : items) {
        if (matches(item))
            filtered.append(item);
    }
    return filtered;
}

QList<AppModel::Item> AppHubBackend::filterAppHubItems(const QList<AppModel::Item> &items) const
{
    QList<AppModel::Item> filtered;
    for (const AppModel::Item &item : items) {
        if (!m_query.isEmpty() && !matches(item))
            continue;
        if (m_appHubInstalledOnly && item.status != QLatin1String("Active Extension"))
            continue;
        if (m_appHubInstalledOnly || m_appHubCategory.isEmpty() || normalizedAppHubCategory(item) == m_appHubCategory)
            filtered.append(item);
    }
    return filtered;
}

QString AppHubBackend::normalizedAppHubCategory(const AppModel::Item &item) const
{
    QString category = item.category.section(QChar(u'.'), -1).trimmed();
    if (category.compare(QLatin1String("Utility"), Qt::CaseInsensitive) == 0)
        category = QStringLiteral("Utilities");
    return category;
}

void AppHubBackend::refreshAppHubCategories()
{
    const QStringList categoryOrder = {
        QStringLiteral("Development"),
        QStringLiteral("Graphics"),
        QStringLiteral("Internet"),
        QStringLiteral("Games"),
        QStringLiteral("Multimedia"),
        QStringLiteral("Office"),
        QStringLiteral("System"),
        QStringLiteral("Utilities"),
    };

    QSet<QString> availableCategories;
    for (const AppModel::Item &item : std::as_const(m_allAppHubItems)) {
        const QString category = normalizedAppHubCategory(item);
        if (!category.isEmpty())
            availableCategories.insert(category);
    }

    QStringList categories;
    for (const QString &category : categoryOrder) {
        if (availableCategories.remove(category))
            categories.append(category);
    }

    QStringList additionalCategories = availableCategories.values();
    additionalCategories.sort(Qt::CaseInsensitive);
    categories.append(additionalCategories);

    if (categories != m_appHubCategories) {
        m_appHubCategories = categories;
        emit appHubCategoriesChanged();
    }

    if (!m_appHubCategories.contains(m_appHubCategory)) {
        m_appHubCategory = m_appHubCategories.value(0);
        emit appHubCategoryChanged();
    }
}

QList<AppModel::Item> AppHubBackend::loadAppHubItems() const
{
    const QString repositoryPath = appHubRepositoryPath();
    const QString appsPath = QDir(repositoryPath).filePath(QStringLiteral("apps"));
    const QString architecturePath = QDir(appsPath).filePath(architecture());
    const QFileInfo repositoryInfo(repositoryPath);
    const QFileInfo appsInfo(appsPath);
    const QFileInfo architectureInfo(architecturePath);
    if (!repositoryInfo.isDir() || repositoryInfo.isSymbolicLink()
        || !appsInfo.isDir() || appsInfo.isSymbolicLink()
        || !architectureInfo.isDir() || architectureInfo.isSymbolicLink())
        return {};

    const QDir architectureDirectory(architecturePath);

    QList<AppModel::Item> items;
    const QStringList applications = architectureDirectory.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &application : applications) {
        if (items.size() >= MaxCatalogItems)
            break;
        if (!isSafeIdentifier(application))
            continue;

        const QFileInfo applicationInfo(architectureDirectory.filePath(application));
        if (!applicationInfo.isDir() || applicationInfo.isSymbolicLink())
            continue;

        const QDir applicationDirectory(applicationInfo.filePath());
        const QByteArray yamlData = readBoundedFile(applicationDirectory.filePath(QStringLiteral("app.yml")), MaxMetadataBytes);
        if (yamlData.isEmpty())
            continue;

        const QString yaml = QString::fromUtf8(yamlData);
        const QString yamlName = appHubValue(yaml, QStringLiteral("name"));
        const QString name = appHubDisplayName(yamlName.isEmpty() ? application : yamlName.simplified());

        QString markdown;
        const QFileInfo metadataDirectoryInfo(applicationDirectory.filePath(QStringLiteral("metadata")));
        if (metadataDirectoryInfo.isDir() && !metadataDirectoryInfo.isSymbolicLink()) {
            const QByteArray metadataData = readBoundedFile(applicationDirectory.filePath(QStringLiteral("metadata/app_description.md")), MaxMetadataBytes);
            if (!metadataData.isEmpty())
                markdown = QString::fromUtf8(metadataData);
        }

        const QString category = markdownSection(markdown, QStringLiteral("Category"));
        const QString integration = integrationType(yaml);
        const QString runtime = appHubValue(yaml, QStringLiteral("runtime"));
        const QRegularExpression distroExpression(QStringLiteral("^\\s+distro\\s*:\\s*(.+)$"), QRegularExpression::MultilineOption);
        const QString distro = cleanValue(distroExpression.match(yaml).captured(1));
        const QString summary = markdownSection(markdown, QStringLiteral("Summary"));
        const QString version = appHubValue(yaml, QStringLiteral("version"));

        const bool installed = appHubItemInstalled(application);
        items.append({
            name,
            summary,
            version,
            architecture(),
            application,
            category,
            installed ? QStringLiteral("Remove") : QStringLiteral("Build AppBox"),
            installed ? QStringLiteral("edit-delete") : QStringLiteral("run-build"),
            QStringLiteral("application-x-iso9660-appimage"),
            installed ? QStringLiteral("Active Extension") : QStringLiteral("Not Built"),
            distro,
            {},
            {},
            summary,
            integration,
            runtime,
            {},
            {},
            {},
            {}
        });
    }

    return items;
}

QList<AppModel::Item> AppHubBackend::appHubBackupItems(const QString &identifier) const
{
    if (!isSafeIdentifier(identifier))
        return {};

    const QString backupPath = QFileInfo(appHubRepositoryPath()).dir().filePath(QStringLiteral("backups"));
    const QFileInfo backupDirectoryInfo(backupPath);
    if (!backupDirectoryInfo.isDir() || backupDirectoryInfo.isSymbolicLink())
        return {};

    const QDir backupDirectory(backupPath);
    const QString prefix = identifier + QLatin1Char('-');
    const QString suffix = QLatin1Char('-') + architecture() + QStringLiteral(".tar");
    const QStringList backupFiles = backupDirectory.entryList(
        {prefix + QLatin1Char('*') + suffix},
        QDir::Files | QDir::NoSymLinks,
        QDir::Time);

    QList<AppModel::Item> items;
    for (const QString &backupFile : backupFiles) {
        const QFileInfo backupInfo(backupDirectory.filePath(backupFile));
        if (!backupInfo.isFile() || backupInfo.isSymbolicLink()
            || !backupFile.startsWith(prefix) || !backupFile.endsWith(suffix))
            continue;

        const QString version = backupFile.mid(prefix.size(), backupFile.size() - prefix.size() - suffix.size());
        if (version.isEmpty())
            continue;

        items.append({
            version,
            backupFile,
            version,
            architecture(),
            backupFile,
            QStringLiteral("Backup"),
            QStringLiteral("Restore"),
            QStringLiteral("document-revert"),
            QStringLiteral("document-revert"),
            QStringLiteral("Available"),
            {},
            backupInfo.lastModified().toString(Qt::ISODate),
            {},
            {},
            {},
            {},
            {},
            {},
            {},
            {},
            {},
        });
    }

    return items;
}

QList<AppModel::Item> AppHubBackend::loadDistroboxItems(const QByteArray &output) const
{
    QList<AppModel::Item> items;
    for (const QByteArray &line : output.split('\n')) {
        const QString text = QString::fromLocal8Bit(line).trimmed();
        if (!text.contains('|') || text.startsWith(QLatin1String("ID")))
            continue;

        const QStringList fields = text.split('|');
        if (fields.size() < 4)
            continue;

        const QString name = fields.at(1).trimmed();
        if (name.isEmpty() || name == QLatin1String("NAME") || !isSafeIdentifier(name))
            continue;

        const QString status = fields.at(2).trimmed();
        const QString baseImage = fields.at(3).trimmed();
        items.append({
            name,
            QStringLiteral("%1 · %2").arg(status, baseImage),
            {},
            {},
            name,
            QStringLiteral("Distrobox"),
            QStringLiteral("Enter"),
            QStringLiteral("utilities-terminal"),
            QStringLiteral("utilities-terminal"),
            status,
            baseImage,
            {},
            QStringLiteral("0"),
            {},
            {},
            QStringLiteral("Development Sandbox"),
            {},
            {},
            {},
            {}
        });
    }
    return items;
}

QString AppHubBackend::appHubRepositoryPath() const
{
    const QString overridePath = qEnvironmentVariable("NX_APPHUB_REPO");
    if (!overridePath.isEmpty())
        return overridePath;

    return QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation))
        .filePath(QStringLiteral(".local/share/nx-apphub-cli/repo"));
}

QString AppHubBackend::architecture() const
{
    const QString hostArchitecture = QSysInfo::currentCpuArchitecture();
    if (hostArchitecture == QLatin1String("x86_64") || hostArchitecture == QLatin1String("amd64"))
        return QStringLiteral("x86_64");
    if (hostArchitecture == QLatin1String("arm64") || hostArchitecture == QLatin1String("aarch64"))
        return QStringLiteral("aarch64");
    return hostArchitecture;
}

QString AppHubBackend::appHubValue(const QString &yaml, const QString &key) const
{
    const QRegularExpression expression(QStringLiteral("^\\s{2}%1\\s*:\\s*(.+)$").arg(QRegularExpression::escape(key)),
                                        QRegularExpression::MultilineOption);
    const auto match = expression.match(yaml);
    return match.hasMatch() ? cleanValue(match.captured(1)) : QString();
}

QString AppHubBackend::integrationType(const QString &yaml) const
{
    bool inIntegration = false;
    for (const QString &line : yaml.split(QChar('\n'))) {
        if (line.trimmed() == QLatin1String("integration:")) {
            inIntegration = true;
            continue;
        }
        if (inIntegration && !line.startsWith(QLatin1String("  ")))
            break;
        if (inIntegration && line.startsWith(QLatin1String("  type:")))
            return cleanValue(line.mid(7));
    }
    return {};
}

QString AppHubBackend::markdownSection(const QString &markdown, const QString &heading) const
{
    const QRegularExpression expression(
        QStringLiteral("^##\\s+%1\\s*$([\\s\\S]*?)(?=^##\\s+|\\z)").arg(QRegularExpression::escape(heading)),
        QRegularExpression::MultilineOption);
    const auto match = expression.match(markdown);
    if (!match.hasMatch())
        return {};

    QString value = match.captured(1).trimmed();
    value.replace(QRegularExpression(QStringLiteral("\\[([^]]+)\\]\\([^)]*\\)")), QStringLiteral("\\1"));
    return value;
}

bool AppHubBackend::appHubItemInstalled(const QString &name) const
{
    if (!isSafeIdentifier(name))
        return false;
    const QDir installDirectory(QDir(QStandardPaths::writableLocation(QStandardPaths::HomeLocation))
                                    .filePath(QStringLiteral(".local/bin/nx-apphub")));
    return !installDirectory.entryList({QStringLiteral("%1-*-%2.AppBox").arg(name, architecture())},
                                       QDir::Files).isEmpty();
}

bool AppHubBackend::matches(const AppModel::Item &item) const
{
    const Qt::CaseSensitivity sensitivity = Qt::CaseInsensitive;
    return item.name.contains(m_query, sensitivity)
        || item.summary.contains(m_query, sensitivity)
        || item.identifier.contains(m_query, sensitivity)
        || item.category.contains(m_query, sensitivity);
}

QString AppHubBackend::containerEngine() const
{
    const QString podman = findExecutable(QStringLiteral("podman"));
    if (!podman.isEmpty())
        return podman;
    return findExecutable(QStringLiteral("docker"));
}

void AppHubBackend::appendOperationLog(const QByteArray &output)
{
    if (output.isEmpty())
        return;

    QString log = m_operationLog + QString::fromLocal8Bit(output);
    if (log.size() > MaxOperationLogBytes)
        log = log.right(MaxOperationLogBytes);
    if (log == m_operationLog)
        return;

    m_operationLog = log;
    emit operationLogChanged();
}

void AppHubBackend::clearFlatpakUpdateState()
{
    if (m_flatpakUpdateIdentifier.isEmpty() && m_flatpakUpdateProgress < 0)
        return;

    m_flatpakUpdateIdentifier.clear();
    m_flatpakUpdateProgress = -1;
    emit flatpakUpdateStateChanged();
}

void AppHubBackend::restoreUserBundleArtifact()
{
    if (!m_userBundleArtifactBackupDirectory) {
        if (!m_userBundleOutputPreviouslyExisted)
            QFile::remove(m_userBundleOutputPath);
        return;
    }

    QFile input(QDir(m_userBundleArtifactBackupDirectory->path()).filePath(QStringLiteral("previous.AppImage")));
    QSaveFile output(m_userBundleOutputPath);
    bool restored = input.open(QIODevice::ReadOnly) && output.open(QIODevice::WriteOnly);
    while (restored && !input.atEnd()) {
        const QByteArray chunk = input.read(1024 * 1024);
        if ((chunk.isEmpty() && input.error() != QFileDevice::NoError) || output.write(chunk) != chunk.size())
            restored = false;
    }
    if (restored) {
        restored = output.commit();
        if (restored)
            restored = QFile::setPermissions(m_userBundleOutputPath, input.permissions());
    } else if (output.isOpen()) {
        output.cancelWriting();
    }

    if (restored) {
        const QUrl restoredUrl = QUrl::fromLocalFile(m_userBundleOutputPath);
        if (m_userBundleOutputUrl != restoredUrl) {
            m_userBundleOutputUrl = restoredUrl;
            emit userBundleOutputUrlChanged();
        }
    }
    m_userBundleArtifactBackupDirectory.reset();
    if (!restored)
        appendOperationLog(QByteArray("\nWarning: the previous personal bundle could not be restored.\n"));
}

void AppHubBackend::processErrorOccurred(QProcess::ProcessError error)
{
    if (error != QProcess::FailedToStart)
        return;

    const Operation operation = m_operation;
    const QString identifier = m_operationIdentifier;
    const QString message = QStringLiteral("Could not start the requested operation.");
    if (operation == Operation::UserBundleGenerate) {
        m_userBundleGenerationDirectory.reset();
        emit userBundleGenerated(identifier, false, message);
    } else if (operation == Operation::UserBundleBuild) {
        restoreUserBundleArtifact();
        m_userBundleOutputPath.clear();
        emit userBundleBuilt(identifier, false, {}, message);
    }

    emitFlatpakOperationResult(operation, identifier, false, message);
    emitAppHubOperationResult(operation, identifier, false, message);

    m_operation = Operation::None;
    clearFlatpakUpdateState();
    setBusy(false);
    setStatusMessage(message);
}

void AppHubBackend::processOutputReady()
{
    if (m_processOutputTooLarge) {
        m_process->readAllStandardOutput();
        m_process->readAllStandardError();
        return;
    }

    const QByteArray standardOutput = m_process->readAllStandardOutput();
    const QByteArray standardError = m_process->readAllStandardError();
    m_processOutput += standardOutput;
    m_processErrorOutput += standardError;

    if (m_operation == Operation::FlatpakUpdate) {
        static const QRegularExpression progressPattern(QStringLiteral("(?:^|[^0-9])(100|[0-9]{1,2})%"));
        QRegularExpressionMatchIterator matches = progressPattern.globalMatch(
            QString::fromLocal8Bit(m_processOutput + m_processErrorOutput));
        int progress = -1;
        while (matches.hasNext())
            progress = matches.next().captured(1).toInt();
        if (progress >= 0 && progress != m_flatpakUpdateProgress) {
            m_flatpakUpdateProgress = progress;
            emit flatpakUpdateStateChanged();
        }
    }

    appendOperationLog(standardOutput);
    appendOperationLog(standardError);
    if (m_processOutput.size() + m_processErrorOutput.size() > MaxProcessOutputBytes) {
        m_processOutputTooLarge = true;
        m_process->kill();
    }
}

void AppHubBackend::processFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    processOutputReady();
    const QByteArray processOutput = m_processOutput;
    const QByteArray processErrorOutput = m_processErrorOutput;
    const Operation operation = m_operation;
    const QString identifier = m_operationIdentifier;
    if (operation == Operation::FlatpakUpdate
        && exitStatus == QProcess::NormalExit
        && exitCode == 0
        && m_flatpakUpdateProgress != 100) {
        m_flatpakUpdateProgress = 100;
        emit flatpakUpdateStateChanged();
    }
    m_operation = Operation::None;
    clearFlatpakUpdateState();
    setBusy(false);

    QString failure;
    if (m_processOutputTooLarge) {
        failure = QStringLiteral("The operation produced too much output.");
    } else if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        failure = QString::fromLocal8Bit(processErrorOutput).trimmed();
        if (failure.isEmpty())
            failure = QStringLiteral("The operation failed.");
    }
    if (!failure.isEmpty()) {
        if (operation == Operation::UserBundleGenerate) {
            m_userBundleGenerationDirectory.reset();
            emit userBundleGenerated(identifier, false, failure);
        } else if (operation == Operation::UserBundleBuild) {
            restoreUserBundleArtifact();
            m_userBundleOutputPath.clear();
            emit userBundleBuilt(identifier, false, {}, failure);
        }
        emitFlatpakOperationResult(operation, identifier, false, failure);
        emitAppHubOperationResult(operation, identifier, false, failure);
        setStatusMessage(failure);
        return;
    }

    switch (operation) {
    case Operation::FlatpakSearch:
        parseFlatpakSearch(processOutput);
        setStatusMessage(QStringLiteral("Flathub search completed."));
        break;
    case Operation::AppHubSync:
        refreshAppHubCatalog();
        setStatusMessage(QStringLiteral("NX AppHub metadata refreshed."));
        break;
    case Operation::FlatpakInstall:
    case Operation::FlatpakUpdate:
    case Operation::FlatpakRemove:
        refreshFlatpakInstalled();
        setStatusMessage(QStringLiteral("Flathub operation completed."));
        emitFlatpakOperationResult(operation, identifier, true);
        break;
    case Operation::FlatpakAddonInstall:
    case Operation::FlatpakAddonRemove:
        refreshFlatpakAddons();
        setStatusMessage(QStringLiteral("Flatpak add-ons updated."));
        break;
    case Operation::AppHubInstall:
    case Operation::AppHubRemove:
    case Operation::AppHubRestore:
        refreshAppHubCatalog();
        setStatusMessage(QStringLiteral("NX AppHub operation completed."));
        emitAppHubOperationResult(operation, identifier, true);
        break;
    case Operation::UserBundleGenerate: {
        const QString staging = m_userBundleGenerationDirectory ? m_userBundleGenerationDirectory->path() : QString();
        const QFileInfo generatedRecipe(QDir(staging).filePath(QStringLiteral("app.yml")));
        const QFileInfo generatedMetadata(QDir(staging).filePath(QStringLiteral("metadata/app_description.md")));
        if (!m_userBundleGenerationDirectory || !generatedRecipe.isFile() || generatedRecipe.isSymbolicLink()
            || !generatedMetadata.isFile() || generatedMetadata.isSymbolicLink()) {
            const QString error = QStringLiteral("The CLI did not produce a complete project.");
            m_userBundleGenerationDirectory.reset();
            setStatusMessage(error);
            emit userBundleGenerated(identifier, false, error);
            break;
        }
        const QString target = QDir(m_userBundleStore.rootPath()).filePath(identifier);
        if (QFileInfo::exists(target) || !QDir().rename(staging, target)) {
            const QString error = QStringLiteral("The generated project could not be moved into its final directory.");
            m_userBundleGenerationDirectory.reset();
            setStatusMessage(error);
            emit userBundleGenerated(identifier, false, error);
            break;
        }
        m_userBundleGenerationDirectory.reset();
        refreshUserBundles();
        setStatusMessage(QStringLiteral("Generated the %1 personal-bundle project.").arg(identifier));
        emit userBundleGenerated(identifier, true, {});
        break;
    }
    case Operation::UserBundleBuild: {
        const QFileInfo outputInfo(m_userBundleOutputPath);
        const bool currentOutput = outputInfo.isFile() && !outputInfo.isSymbolicLink();
        const bool changedOutput = currentOutput
            && (!m_userBundleOutputPreviouslyExisted
                || outputInfo.size() != m_userBundlePreviousOutputSize
                || outputInfo.lastModified() != m_userBundlePreviousOutputModified);
        if (!changedOutput) {
            const QString error = QStringLiteral("The CLI completed but the expected bundle was not created or updated.");
            restoreUserBundleArtifact();
            m_userBundleOutputPath.clear();
            setStatusMessage(error);
            emit userBundleBuilt(identifier, false, {}, error);
            break;
        }
        m_userBundleArtifactBackupDirectory.reset();
        m_userBundleOutputUrl = QUrl::fromLocalFile(m_userBundleOutputPath);
        emit userBundleOutputUrlChanged();
        refreshUserBundles();
        setStatusMessage(QStringLiteral("Built the %1 personal bundle.").arg(identifier));
        emit userBundleBuilt(identifier, true, m_userBundleOutputUrl, {});
        break;
    }
    case Operation::DistroboxCreate:
    case Operation::DistroboxStart:
    case Operation::DistroboxStop:
    case Operation::DistroboxClone:
    case Operation::DistroboxRemove:
        refreshDistrobox();
        setStatusMessage(QStringLiteral("Distrobox operation completed."));
        break;
    case Operation::None:
        break;
    }
}
