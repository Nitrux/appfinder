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
#include <QProcessEnvironment>
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
    , m_flathubFeaturedModel(new AppModel(this))
    , m_flathubCollectionModel(new AppModel(this))
    , m_appHubModel(new AppModel(this))
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

AppModel *AppHubBackend::flathubFeaturedModel()
{
    return m_flathubFeaturedModel;
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

AppModel *AppHubBackend::appHubModel()
{
    return m_appHubModel;
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
                                   const QString &identifier)
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
    m_process->setProcessEnvironment(environment);
    m_process->setProcessChannelMode(QProcess::SeparateChannels);
    m_processOutput.clear();
    m_processErrorOutput.clear();
    m_processOutputTooLarge = false;
    m_operation = operation;
    m_operationIdentifier = identifier;
    m_operationLog = QStringLiteral("Starting %1…").arg(program);
    emit operationLogChanged();
    setBusy(true);
    m_process->start(executable, arguments);
    return true;
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
        m_appHubModel->setItems(filterItems(m_allAppHubItems));
        break;
    case Distrobox:
        m_distroboxModel->setItems(filterItems(m_allDistroboxItems));
        break;
    }
}

void AppHubBackend::installFlatpak(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        setStatusMessage(QStringLiteral("Invalid Flatpak identifier."));
        return;
    }
    if (!startOperation(QStringLiteral("flatpak"),
                       {QStringLiteral("install"), QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--app"), QStringLiteral("flathub"), identifier},
                       Operation::FlatpakInstall,
                       identifier))
        return;
    setStatusMessage(QStringLiteral("Installing %1 from Flathub…").arg(identifier));
}

void AppHubBackend::removeFlatpak(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        setStatusMessage(QStringLiteral("Invalid Flatpak identifier."));
        return;
    }
    if (!startOperation(QStringLiteral("flatpak"),
                       {QStringLiteral("uninstall"), QStringLiteral("--user"), QStringLiteral("-y"), QStringLiteral("--app"), identifier},
                       Operation::FlatpakRemove,
                       identifier))
        return;
    setStatusMessage(QStringLiteral("Removing %1 from Flathub…").arg(identifier));
}

void AppHubBackend::appHubAction(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        setStatusMessage(QStringLiteral("Invalid NX AppHub identifier."));
        return;
    }
    const bool installed = appHubItemInstalled(identifier);
    const QString action = installed ? QStringLiteral("remove") : QStringLiteral("install");
    if (!startOperation(QStringLiteral("nx-apphub-cli"), {action, identifier},
                       installed ? Operation::AppHubRemove : Operation::AppHubInstall,
                       identifier))
        return;
    setStatusMessage(QStringLiteral("%1 %2 through NX AppHub…").arg(installed ? QStringLiteral("Removing") : QStringLiteral("Building"), identifier));
}

void AppHubBackend::rebuildAppHub(const QString &identifier)
{
    if (!isSafeIdentifier(identifier)) {
        setStatusMessage(QStringLiteral("Invalid NX AppHub identifier."));
        return;
    }
    if (!startOperation(QStringLiteral("nx-apphub-cli"),
                        {QStringLiteral("install"), identifier},
                        Operation::AppHubInstall,
                        identifier))
        return;
    setStatusMessage(QStringLiteral("Rebuilding %1 through NX AppHub…").arg(identifier));
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
    const QByteArray output = runCommand(QStringLiteral("flatpak"),
                                         {QStringLiteral("list"), QStringLiteral("--user"), QStringLiteral("--app"), QStringLiteral("--columns=application,name,origin,version,arch,size")});
    QList<AppModel::Item> items;
    m_installedFlatpaks.clear();

    for (const QByteArray &line : output.split('\n')) {
        const QStringList fields = QString::fromLocal8Bit(line).split('\t');
        if (fields.size() < 6 || fields.first().trimmed().isEmpty())
            continue;

        const QString identifier = fields.at(0).trimmed();
        const QString origin = fields.value(2).trimmed();
        if (identifier == QLatin1String("Application") || !isSafeIdentifier(identifier) || !isFlathubRemote(origin))
            continue;

        m_installedFlatpaks.insert(identifier);
        items.append({
            fields.value(1, identifier).trimmed(),
            QStringLiteral("Installed through Flathub"),
            fields.value(3).trimmed(),
            fields.value(4).trimmed(),
            identifier,
            QStringLiteral("Desktop Application"),
            QStringLiteral("Remove"),
            QStringLiteral("edit-delete"),
            QStringLiteral("application-x-flatpak"),
            QStringLiteral("Installed"),
            {},
            {},
            {},
            QStringLiteral("Installed through Flathub"),
            {},
            QStringLiteral("GUI Application"),
            fields.value(5).trimmed(),
            {},
            {},
            {}
        });
    }

    m_flathubModel->setItems(filterItems(items));
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

void AppHubBackend::refreshAppHubCatalog()
{
    m_allAppHubItems = loadAppHubItems();
    m_appHubModel->setItems(filterItems(m_allAppHubItems));
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
        const QString name = yamlName.isEmpty() ? application : yamlName;

        QString markdown;
        const QFileInfo metadataDirectoryInfo(applicationDirectory.filePath(QStringLiteral("metadata")));
        if (metadataDirectoryInfo.isDir() && !metadataDirectoryInfo.isSymbolicLink()) {
            const QByteArray metadataData = readBoundedFile(applicationDirectory.filePath(QStringLiteral("metadata/app_description.md")), MaxMetadataBytes);
            if (!metadataData.isEmpty())
                markdown = QString::fromUtf8(metadataData);
        }

        const QString category = markdownSection(markdown, QStringLiteral("Category"));
        const QString integration = integrationType(yaml);
        const QString summary = markdownSection(markdown, QStringLiteral("Summary"));
        const QString version = appHubValue(yaml, QStringLiteral("version"));
        QString details = summary;
        if (!integration.isEmpty())
            details += QStringLiteral(" · ") + integration;
        if (!category.isEmpty())
            details += QStringLiteral(" · ") + category.section(QChar(u'.'), -1);
        if (!version.isEmpty())
            details += QStringLiteral(" · ") + version;

        const bool installed = appHubItemInstalled(application);
        items.append({
            name,
            details,
            version,
            architecture(),
            application,
            category,
            installed ? QStringLiteral("Remove") : QStringLiteral("Build AppBox"),
            installed ? QStringLiteral("edit-delete") : QStringLiteral("run-build"),
            QStringLiteral("application-x-iso9660-appimage"),
            installed ? QStringLiteral("Active Extension") : QStringLiteral("Not Built"),
            {},
            {},
            {},
            summary,
            integration,
            category.section(QChar(u'.'), -1),
            {},
            {},
            {},
            {}
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

void AppHubBackend::processErrorOccurred(QProcess::ProcessError error)
{
    if (error != QProcess::FailedToStart)
        return;

    m_operation = Operation::None;
    setBusy(false);
    setStatusMessage(QStringLiteral("Could not start the requested operation."));
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
    m_operation = Operation::None;
    setBusy(false);

    if (m_processOutputTooLarge) {
        setStatusMessage(QStringLiteral("The operation produced too much output."));
        return;
    }

    if (exitStatus != QProcess::NormalExit || exitCode != 0) {
        QString error = QString::fromLocal8Bit(processErrorOutput).trimmed();
        if (error.isEmpty())
            error = QStringLiteral("The operation failed.");
        setStatusMessage(error);
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
    case Operation::FlatpakRemove:
        refreshFlatpakInstalled();
        setStatusMessage(QStringLiteral("Flathub operation completed."));
        break;
    case Operation::AppHubInstall:
    case Operation::AppHubRemove:
        refreshAppHubCatalog();
        setStatusMessage(QStringLiteral("NX AppHub operation completed."));
        break;
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
