/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include "apphubbackend.h"

#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QFile>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>

namespace {

constexpr qsizetype MaxProcessOutputBytes = 8 * 1024 * 1024;
constexpr qsizetype MaxOperationLogBytes = 64 * 1024;
constexpr qint64 MaxMetadataBytes = 2 * 1024 * 1024;
constexpr qsizetype MaxQueryLength = 256;
constexpr int MaxCatalogItems = 10000;

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

QString cleanValue(QString value)
{
    value = value.trimmed();
    if (value.startsWith('"') && value.endsWith('"') && value.size() > 1)
        value = value.mid(1, value.size() - 2);
    if (value.startsWith('\'') && value.endsWith('\'') && value.size() > 1)
        value = value.mid(1, value.size() - 2);
    return value.trimmed();
}

} // namespace

AppHubBackend::AppHubBackend(QObject *parent)
    : QObject(parent)
    , m_flathubModel(new AppModel(this))
    , m_appHubModel(new AppModel(this))
    , m_distroboxModel(new AppModel(this))
    , m_process(new QProcess(this))
{
    connect(m_process, &QProcess::finished, this, &AppHubBackend::processFinished);
    connect(m_process, &QProcess::errorOccurred, this, &AppHubBackend::processErrorOccurred);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &AppHubBackend::processOutputReady);
    connect(m_process, &QProcess::readyReadStandardError, this, &AppHubBackend::processOutputReady);
}

AppModel *AppHubBackend::flathubModel()
{
    return m_flathubModel;
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
    refreshAppHubCatalog();
    refreshDistrobox();
    setStatusMessage(QStringLiteral("Sources refreshed."));
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
                           {QStringLiteral("search"), QStringLiteral("--columns=application,name,description,version"), QStringLiteral("--arch=%1").arg(architecture()), QStringLiteral("--"), m_query},
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
                                         {QStringLiteral("list"), QStringLiteral("--user"), QStringLiteral("--app"), QStringLiteral("--columns=application,name,version,arch,size")});
    QList<AppModel::Item> items;
    m_installedFlatpaks.clear();

    for (const QByteArray &line : output.split('\n')) {
        const QStringList fields = QString::fromLocal8Bit(line).split('\t');
        if (fields.size() < 4 || fields.first().trimmed().isEmpty())
            continue;

        const QString identifier = fields.at(0).trimmed();
        if (identifier == QLatin1String("Application") || !isSafeIdentifier(identifier))
            continue;

        m_installedFlatpaks.insert(identifier);
        items.append({
            fields.value(1, identifier).trimmed(),
            QStringLiteral("Installed through Flathub"),
            fields.value(2).trimmed(),
            fields.value(3).trimmed(),
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
            fields.value(4).trimmed()
        });
    }

    m_flathubModel->setItems(filterItems(items));
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
        if (fields.size() < 4 || fields.first().trimmed().isEmpty())
            continue;

        const QString identifier = fields.at(0).trimmed();
        if (identifier == QLatin1String("Application") || !isSafeIdentifier(identifier))
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
            fields.value(4).trimmed()
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
