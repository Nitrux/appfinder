/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include "userbundlestore.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

#include <yaml-cpp/yaml.h>

#include <algorithm>
#include <stdexcept>

namespace {

constexpr qint64 MaxRecipeBytes = 2 * 1024 * 1024;
constexpr qint64 MaxMetadataBytes = 2 * 1024 * 1024;

const QStringList SandboxBooleanKeys = {
    QStringLiteral("ro-root"), QStringLiteral("dev"), QStringLiteral("proc"),
    QStringLiteral("tmpfs"), QStringLiteral("mqueue"), QStringLiteral("ro-home"),
    QStringLiteral("no-net"), QStringLiteral("no-ipc"), QStringLiteral("no-pid"),
    QStringLiteral("unshare-user"), QStringLiteral("unshare-uts"), QStringLiteral("unshare-cgroup"),
    QStringLiteral("new-session"), QStringLiteral("cap-drop-all"),
    QStringLiteral("die-with-parent"), QStringLiteral("clearenv"),
};

const QStringList SandboxListKeys = {
    QStringLiteral("bwrap-unset-env"), QStringLiteral("cap-drop"), QStringLiteral("bind"),
    QStringLiteral("ro-bind"), QStringLiteral("bind-try"), QStringLiteral("ro-bind-try"),
    QStringLiteral("remount-ro"),
};

const QStringList SandboxValueKeys = {
    QStringLiteral("hostname"), QStringLiteral("chdir"), QStringLiteral("file-label"),
    QStringLiteral("exec-label"), QStringLiteral("seccomp"),
};

QByteArray readBoundedFile(const QString &path, qint64 maximumBytes)
{
    const QFileInfo info(path);
    if (!info.isFile() || info.isSymbolicLink() || info.size() < 0 || info.size() > maximumBytes)
        return {};

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    const QByteArray data = file.read(maximumBytes + 1);
    return data.size() <= maximumBytes ? data : QByteArray();
}

QString yamlScalar(const YAML::Node &node)
{
    return node && node.IsScalar() ? QString::fromStdString(node.Scalar()) : QString();
}

QVariant yamlToVariant(const YAML::Node &node)
{
    if (!node)
        return {};
    if (node.IsScalar())
        return yamlScalar(node);
    if (node.IsSequence()) {
        QVariantList list;
        for (const auto &entry : node)
            list.append(yamlToVariant(entry));
        return list;
    }
    if (node.IsMap()) {
        QVariantMap map;
        for (const auto &entry : node) {
            if (entry.first.IsScalar())
                map.insert(yamlScalar(entry.first), yamlToVariant(entry.second));
        }
        return map;
    }
    return {};
}

YAML::Node variantToYaml(const QVariant &value)
{
    if (!value.isValid() || value.isNull())
        return {};
    if (value.metaType().id() == QMetaType::Bool)
        return YAML::Node(value.toBool());
    if (value.metaType().id() == QMetaType::Int || value.metaType().id() == QMetaType::LongLong
        || value.metaType().id() == QMetaType::UInt || value.metaType().id() == QMetaType::ULongLong)
        return YAML::Node(value.toLongLong());
    if (value.metaType().id() == QMetaType::QVariantList) {
        YAML::Node sequence(YAML::NodeType::Sequence);
        for (const QVariant &entry : value.toList())
            sequence.push_back(variantToYaml(entry));
        return sequence;
    }
    if (value.metaType().id() == QMetaType::QVariantMap) {
        YAML::Node map(YAML::NodeType::Map);
        const QVariantMap values = value.toMap();
        for (auto iterator = values.cbegin(); iterator != values.cend(); ++iterator)
            map[iterator.key().toStdString()] = variantToYaml(iterator.value());
        return map;
    }
    return YAML::Node(value.toString().toStdString());
}

QVariantList stringSequence(const YAML::Node &node)
{
    QVariantList result;
    if (!node)
        return result;
    if (node.IsScalar()) {
        result.append(yamlScalar(node));
        return result;
    }
    if (!node.IsSequence())
        throw std::runtime_error("Expected a string or a sequence of strings");
    for (const auto &entry : node) {
        if (!entry.IsScalar())
            throw std::runtime_error("Expected a sequence containing only strings");
        result.append(yamlScalar(entry));
    }
    return result;
}

QVariantList environmentEntries(const YAML::Node &node, bool sequence)
{
    QVariantList result;
    if (!node)
        return result;
    if (!sequence && !node.IsMap())
        throw std::runtime_error("Environment variables must be a mapping");
    if (sequence && !node.IsSequence())
        throw std::runtime_error("Bubblewrap environment variables must be a sequence");

    if (!sequence) {
        for (const auto &entry : node) {
            if (!entry.first.IsScalar() || !entry.second.IsScalar())
                throw std::runtime_error("Environment variable names and values must be strings");
            result.append(QVariantMap{{QStringLiteral("key"), yamlScalar(entry.first)},
                                      {QStringLiteral("value"), yamlScalar(entry.second)}});
        }
        return result;
    }

    for (const auto &entry : node) {
        if (!entry.IsMap() || entry.size() != 1)
            throw std::runtime_error("Each Bubblewrap environment entry must contain one name and value");
        const auto pair = *entry.begin();
        if (!pair.first.IsScalar() || !pair.second.IsScalar())
            throw std::runtime_error("Bubblewrap environment names and values must be strings");
        result.append(QVariantMap{{QStringLiteral("key"), yamlScalar(pair.first)},
                                  {QStringLiteral("value"), yamlScalar(pair.second)}});
    }
    return result;
}

YAML::Node environmentMap(const QVariantList &entries)
{
    YAML::Node map(YAML::NodeType::Map);
    for (const QVariant &entry : entries) {
        const QVariantMap pair = entry.toMap();
        const QString key = pair.value(QStringLiteral("key")).toString().trimmed();
        if (!key.isEmpty())
            map[key.toStdString()] = pair.value(QStringLiteral("value")).toString().toStdString();
    }
    return map;
}

YAML::Node bwrapEnvironment(const QVariantList &entries)
{
    YAML::Node sequence(YAML::NodeType::Sequence);
    for (const QVariant &entry : entries) {
        const QVariantMap pair = entry.toMap();
        const QString key = pair.value(QStringLiteral("key")).toString().trimmed();
        if (key.isEmpty())
            continue;
        YAML::Node map(YAML::NodeType::Map);
        map[key.toStdString()] = pair.value(QStringLiteral("value")).toString().toStdString();
        sequence.push_back(map);
    }
    return sequence;
}

QString markdownSection(const QString &markdown, const QString &heading)
{
    const QRegularExpression expression(
        QStringLiteral("^##\\s+%1\\s*$([\\s\\S]*?)(?=^##\\s+|\\z)").arg(QRegularExpression::escape(heading)),
        QRegularExpression::MultilineOption);
    const QRegularExpressionMatch match = expression.match(markdown);
    if (!match.hasMatch())
        return {};
    QString value = match.captured(1).trimmed();
    if (heading == QLatin1String("Homepage")) {
        const QRegularExpression link(QStringLiteral("^\\[([^]]*)\\]\\(([^)]*)\\)$"));
        const QRegularExpressionMatch linkMatch = link.match(value);
        if (linkMatch.hasMatch())
            value = linkMatch.captured(2).trimmed();
    }
    return value;
}

QVariantMap parseMetadata(const QByteArray &data)
{
    const QString markdown = QString::fromUtf8(data);
    const QRegularExpression titleExpression(QStringLiteral("^#\\s+(.+)$"), QRegularExpression::MultilineOption);
    const QRegularExpressionMatch titleMatch = titleExpression.match(markdown);
    return {
        {QStringLiteral("name"), titleMatch.hasMatch() ? titleMatch.captured(1).trimmed() : QString()},
        {QStringLiteral("summary"), markdownSection(markdown, QStringLiteral("Summary"))},
        {QStringLiteral("description"), markdownSection(markdown, QStringLiteral("Description"))},
        {QStringLiteral("category"), markdownSection(markdown, QStringLiteral("Category"))},
        {QStringLiteral("homepage"), markdownSection(markdown, QStringLiteral("Homepage"))},
        {QStringLiteral("license"), markdownSection(markdown, QStringLiteral("License"))},
    };
}

QByteArray emitMetadata(const QVariantMap &metadata, const QString &fallbackName)
{
    const QString requestedName = metadata.value(QStringLiteral("name")).toString().trimmed();
    const QString name = requestedName.isEmpty() ? fallbackName : requestedName;
    const QString homepage = metadata.value(QStringLiteral("homepage")).toString().trimmed();
    return QStringLiteral("# %1\n\n## Summary\n\n%2\n\n## Description\n\n%3\n\n## Category\n\n%4\n\n## Homepage\n\n%5\n\n## License\n\n%6\n")
        .arg(name,
             metadata.value(QStringLiteral("summary")).toString().trimmed(),
             metadata.value(QStringLiteral("description")).toString().trimmed(),
             metadata.value(QStringLiteral("category")).toString().trimmed(),
             homepage.isEmpty() ? QString() : QStringLiteral("[%1](%1)").arg(homepage),
             metadata.value(QStringLiteral("license")).toString().trimmed())
        .toUtf8();
}

bool writeAtomically(const QString &path, const QByteArray &data, QString *error)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        if (error)
            *error = file.errorString();
        return false;
    }
    if (file.write(data) != data.size() || !file.commit()) {
        if (error)
            *error = file.errorString();
        return false;
    }
    return true;
}

QString outputArchitecture()
{
    const QString architecture = QSysInfo::currentCpuArchitecture().toLower();
    if (architecture == QLatin1String("arm64") || architecture == QLatin1String("aarch64"))
        return QStringLiteral("aarch64");
    return architecture == QLatin1String("amd64") ? QStringLiteral("x86_64") : architecture;
}

QString displayName(const QString &identifier)
{
    QStringList words = identifier.split(QRegularExpression(QStringLiteral("[-_]+")), Qt::SkipEmptyParts);
    for (QString &word : words) {
        if (!word.isEmpty())
            word[0] = word.at(0).toUpper();
    }
    return words.join(QChar(u' '));
}

bool isSafeBundleName(const QString &value)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+-]{0,127}$"));
    return pattern.match(value).hasMatch();
}

bool containsDuplicateKeys(const QVariantList &entries)
{
    QSet<QString> seen;
    for (const QVariant &entry : entries) {
        const QString key = entry.toMap().value(QStringLiteral("key")).toString().trimmed();
        if (key.isEmpty() || seen.contains(key))
            return true;
        seen.insert(key);
    }
    return false;
}

} // namespace

UserBundleStore::UserBundleStore(const QString &rootPath)
    : m_rootPath(rootPath.isEmpty()
                     ? QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
                           .filePath(QStringLiteral("appfinder/user"))
                     : QDir::cleanPath(rootPath))
{
}

QString UserBundleStore::rootPath() const
{
    return m_rootPath;
}

bool UserBundleStore::ensureRoot(QString *error) const
{
    const QFileInfo info(m_rootPath);
    if (info.exists() && (!info.isDir() || info.isSymbolicLink())) {
        if (error)
            *error = QStringLiteral("The personal bundle location is not a safe directory.");
        return false;
    }
    if (!info.exists() && !QDir().mkpath(m_rootPath)) {
        if (error)
            *error = QStringLiteral("Could not create the personal bundle directory.");
        return false;
    }
    return true;
}

bool UserBundleStore::isValidProjectId(const QString &projectId) const
{
    static const QRegularExpression pattern(QStringLiteral("^[a-z0-9][a-z0-9._-]{0,127}$"));
    return pattern.match(projectId).hasMatch() && projectId != QLatin1String(".") && projectId != QLatin1String("..");
}

QString UserBundleStore::checkedProjectPath(const QString &projectId, bool mustExist, QString *error) const
{
    if (!isValidProjectId(projectId)) {
        if (error)
            *error = QStringLiteral("The project ID is invalid.");
        return {};
    }

    const QString path = QDir(m_rootPath).absoluteFilePath(projectId);
    const QFileInfo info(path);
    if (mustExist && (!info.isDir() || info.isSymbolicLink())) {
        if (error)
            *error = QStringLiteral("The project does not exist or is not a safe directory.");
        return {};
    }
    if (!mustExist && info.exists()) {
        if (error)
            *error = QStringLiteral("A project with this ID already exists.");
        return {};
    }
    return path;
}

QString UserBundleStore::projectPath(const QString &projectId) const
{
    return checkedProjectPath(projectId, true);
}

bool UserBundleStore::projectExists(const QString &projectId) const
{
    return !checkedProjectPath(projectId, true).isEmpty();
}

QString UserBundleStore::hostPackageArchitecture() const
{
    const QString architecture = QSysInfo::currentCpuArchitecture();
    if (architecture == QLatin1String("x86_64") || architecture == QLatin1String("amd64"))
        return QStringLiteral("amd64");
    if (architecture == QLatin1String("arm64") || architecture == QLatin1String("aarch64"))
        return QStringLiteral("arm64");
    return architecture;
}

QVariantMap UserBundleStore::load(const QString &projectId) const
{
    QVariantMap result{{QStringLiteral("projectId"), projectId}, {QStringLiteral("valid"), false}};
    QString pathError;
    const QString path = checkedProjectPath(projectId, true, &pathError);
    if (path.isEmpty()) {
        result.insert(QStringLiteral("error"), pathError);
        return result;
    }

    const QByteArray yamlData = readBoundedFile(QDir(path).filePath(QStringLiteral("app.yml")), MaxRecipeBytes);
    if (yamlData.isEmpty()) {
        result.insert(QStringLiteral("error"), QStringLiteral("app.yml is missing, unsafe, empty, or too large."));
        return result;
    }

    try {
        const YAML::Node root = YAML::Load(yamlData.constData());
        if (!root.IsMap())
            throw std::runtime_error("Top-level YAML value must be a mapping");
        const YAML::Node buildinfo = root["buildinfo"];
        const YAML::Node apprunconf = root["apprunconf"];
        YAML::Node sandbox = root["sandbox"];
        YAML::Node integration = root["integration"];
        if (!sandbox)
            sandbox = YAML::Node(YAML::NodeType::Map);
        if (!integration)
            integration = YAML::Node(YAML::NodeType::Map);
        if (!buildinfo.IsMap() || !apprunconf.IsMap() || (sandbox && !sandbox.IsMap()) || (integration && !integration.IsMap()))
            throw std::runtime_error("Recipe sections use an unsupported value type");

        QVariantMap build;
        for (const QString &key : {QStringLiteral("name"), QStringLiteral("version"), QStringLiteral("binarypath"),
                                   QStringLiteral("os-target"), QStringLiteral("runtime")})
            build.insert(key, yamlScalar(buildinfo[key.toStdString()]));

        QVariantList repositories;
        QVariantList ppas;
        const YAML::Node distrorepo = buildinfo["distrorepo"];
        if (distrorepo.IsSequence()) {
            repositories = yamlToVariant(distrorepo).toList();
        } else if (distrorepo.IsMap()) {
            repositories = yamlToVariant(distrorepo["base"]).toList();
            ppas = yamlToVariant(distrorepo["ppas"]).toList();
        } else if (distrorepo) {
            throw std::runtime_error("buildinfo.distrorepo must be a sequence or mapping");
        }
        const YAML::Node dependencies = buildinfo["deps"];
        if (dependencies && !dependencies.IsSequence())
            throw std::runtime_error("buildinfo.deps must be a sequence");
        build.insert(QStringLiteral("repositories"), repositories);
        build.insert(QStringLiteral("ppas"), ppas);
        build.insert(QStringLiteral("dependencies"), yamlToVariant(dependencies).toList());

        QVariantMap launch{
            {QStringLiteral("exec"), yamlScalar(apprunconf["exec"])},
            {QStringLiteral("setpath"), yamlScalar(apprunconf["setpath"])},
            {QStringLiteral("setlibpath"), yamlScalar(apprunconf["setlibpath"])},
            {QStringLiteral("envvars"), environmentEntries(apprunconf["envvars"], false)},
            {QStringLiteral("extra-rpaths"), stringSequence(apprunconf["extra-rpaths"])},
            {QStringLiteral("prebuild-commands"), stringSequence(apprunconf["prebuild-commands"])},
        };

        QVariantMap sandboxValues;
        sandboxValues.insert(QStringLiteral("type"), yamlScalar(sandbox["type"]));
        sandboxValues.insert(QStringLiteral("name"), yamlScalar(sandbox["name"]));
        sandboxValues.insert(QStringLiteral("aa-profile"), yamlScalar(sandbox["aa-profile"]));
        for (const QString &key : SandboxBooleanKeys) {
            const YAML::Node value = sandbox[key.toStdString()];
            sandboxValues.insert(key, value && value.IsScalar() ? value.as<bool>() : false);
        }
        for (const QString &key : SandboxListKeys)
            sandboxValues.insert(key, stringSequence(sandbox[key.toStdString()]));
        for (const QString &key : SandboxValueKeys)
            sandboxValues.insert(key, yamlScalar(sandbox[key.toStdString()]));
        sandboxValues.insert(QStringLiteral("bwrap-env"), environmentEntries(sandbox["bwrap-env"], true));

        QVariantMap integrationValues{
            {QStringLiteral("type"), yamlScalar(integration["type"])},
            {QStringLiteral("launcher"), yamlScalar(integration["launcher"])},
        };

        const QString metadataDirectory = QDir(path).filePath(QStringLiteral("metadata"));
        const QFileInfo metadataDirectoryInfo(metadataDirectory);
        const QString metadataPath = QDir(metadataDirectory).filePath(QStringLiteral("app_description.md"));
        const QFileInfo metadataFileInfo(metadataPath);
        if ((metadataDirectoryInfo.exists() && (!metadataDirectoryInfo.isDir() || metadataDirectoryInfo.isSymbolicLink()))
            || (metadataFileInfo.exists() && (!metadataFileInfo.isFile() || metadataFileInfo.isSymbolicLink())))
            throw std::runtime_error("Metadata paths must remain inside the project");
        const QByteArray metadataData = readBoundedFile(metadataPath, MaxMetadataBytes);
        QVariantMap metadata = parseMetadata(metadataData);
        if (metadata.value(QStringLiteral("name")).toString().isEmpty())
            metadata.insert(QStringLiteral("name"), build.value(QStringLiteral("name")));

        result.insert(QStringLiteral("recipe"), QVariantMap{{QStringLiteral("buildinfo"), build},
                                                              {QStringLiteral("apprunconf"), launch},
                                                              {QStringLiteral("sandbox"), sandboxValues},
                                                              {QStringLiteral("integration"), integrationValues}});
        result.insert(QStringLiteral("metadata"), metadata);
        result.insert(QStringLiteral("architecture"), hostPackageArchitecture());
        const QFileInfo distInfo(QDir(path).filePath(QStringLiteral("dist")));
        if (distInfo.exists() && (!distInfo.isDir() || distInfo.isSymbolicLink()))
            throw std::runtime_error("The build-output path must remain inside the project");
        const QString artifactPath = outputPath(projectId, result.value(QStringLiteral("recipe")).toMap());
        const QFileInfo artifactInfo(artifactPath);
        if (artifactInfo.isFile() && !artifactInfo.isSymbolicLink())
            result.insert(QStringLiteral("outputUrl"), QUrl::fromLocalFile(artifactPath));
        result.insert(QStringLiteral("valid"), true);
    } catch (const std::exception &exception) {
        result.insert(QStringLiteral("error"), QString::fromLocal8Bit(exception.what()));
    }
    return result;
}

QString UserBundleStore::outputPath(const QString &projectId, const QVariantMap &recipe) const
{
    const QString project = checkedProjectPath(projectId, true);
    if (project.isEmpty())
        return {};
    const QVariantMap buildinfo = recipe.value(QStringLiteral("buildinfo")).toMap();
    const QString name = buildinfo.value(QStringLiteral("name")).toString().trimmed();
    const QString version = buildinfo.value(QStringLiteral("version")).toString().trimmed();
    const QString machine = outputArchitecture();
    if (name.isEmpty() || version.isEmpty() || machine.isEmpty() || name.contains(QChar(u'/')) || version.contains(QChar(u'/')))
        return {};
    return QDir(project).filePath(QStringLiteral("dist/%1-%2-%3.AppImage").arg(name, version, machine));
}

QList<AppModel::Item> UserBundleStore::projects() const
{
    QList<AppModel::Item> items;
    const QFileInfo rootInfo(m_rootPath);
    if (!rootInfo.isDir() || rootInfo.isSymbolicLink())
        return items;

    const QDir root(m_rootPath);
    const QStringList entries = root.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &projectId : entries) {
        if (!isValidProjectId(projectId))
            continue;
        const QFileInfo projectInfo(root.filePath(projectId));
        if (!projectInfo.isDir() || projectInfo.isSymbolicLink())
            continue;

        const QVariantMap document = load(projectId);
        const bool valid = document.value(QStringLiteral("valid")).toBool();
        const QVariantMap recipe = document.value(QStringLiteral("recipe")).toMap();
        const QVariantMap buildinfo = recipe.value(QStringLiteral("buildinfo")).toMap();
        const QVariantMap metadata = document.value(QStringLiteral("metadata")).toMap();
        const QFileInfo outputInfo(valid ? outputPath(projectId, recipe) : QString());
        const bool built = outputInfo.isFile() && !outputInfo.isSymbolicLink();

        AppModel::Item item;
        item.name = valid ? buildinfo.value(QStringLiteral("name")).toString() : displayName(projectId);
        if (item.name.isEmpty())
            item.name = displayName(projectId);
        item.summary = valid ? metadata.value(QStringLiteral("summary")).toString()
                             : document.value(QStringLiteral("error")).toString();
        item.version = buildinfo.value(QStringLiteral("version")).toString();
        item.architecture = hostPackageArchitecture();
        item.identifier = projectId;
        item.category = metadata.value(QStringLiteral("category")).toString();
        item.actionText = QStringLiteral("Open");
        item.actionIcon = QStringLiteral("document-edit");
        item.icon = QStringLiteral("application-x-iso9660-appimage");
        item.status = !valid ? QStringLiteral("Invalid Recipe") : built ? QStringLiteral("Bundle Built") : QStringLiteral("Draft");
        item.created = projectInfo.lastModified().toString(Qt::ISODate);
        item.description = item.summary;
        item.type = QStringLiteral("Personal Bundle");
        items.append(item);
    }

    std::stable_sort(items.begin(), items.end(), [](const AppModel::Item &left, const AppModel::Item &right) {
        return left.name.compare(right.name, Qt::CaseInsensitive) < 0;
    });
    return items;
}

QString UserBundleStore::preflight(const QVariantMap &recipe) const
{
    const QVariantMap build = recipe.value(QStringLiteral("buildinfo")).toMap();
    const QVariantMap launch = recipe.value(QStringLiteral("apprunconf")).toMap();
    const QVariantMap integration = recipe.value(QStringLiteral("integration")).toMap();
    const QVariantMap sandbox = recipe.value(QStringLiteral("sandbox")).toMap();

    for (const QString &key : {QStringLiteral("name"), QStringLiteral("version"), QStringLiteral("binarypath")}) {
        const QString value = build.value(key).toString().trimmed();
        if (value.isEmpty() || value.contains(QLatin1String("REPLACE-ME")))
            return QStringLiteral("Complete buildinfo.%1 before building.").arg(key);
    }
    const QString bundleName = build.value(QStringLiteral("name")).toString().trimmed();
    const QString bundleVersion = build.value(QStringLiteral("version")).toString().trimmed();
    if (!isSafeBundleName(bundleName) || bundleVersion.contains(QChar(u'/')) || bundleVersion.contains(QChar(u'\\')))
        return QStringLiteral("The bundle name or version cannot be used safely as an output filename.");
    if (!QStringList{QStringLiteral("classic"), QStringLiteral("go"), QStringLiteral("uruntime")}.contains(build.value(QStringLiteral("runtime")).toString()))
        return QStringLiteral("Choose a valid bundle runtime.");
    const QString binaryPath = build.value(QStringLiteral("binarypath")).toString().trimmed();
    if (!binaryPath.startsWith(QChar(u'/')) || binaryPath.split(QChar(u'/')).contains(QStringLiteral("..")))
        return QStringLiteral("The binary path must be an absolute path inside the bundle.");

    for (const QString &key : {QStringLiteral("exec"), QStringLiteral("setpath"), QStringLiteral("setlibpath")}) {
        const QString value = launch.value(key).toString().trimmed();
        if (value.isEmpty() || value.contains(QLatin1String("REPLACE-ME")))
            return QStringLiteral("Complete apprunconf.%1 before building.").arg(key);
    }
    if (!launch.value(QStringLiteral("exec")).toString().trimmed().startsWith(QChar(u'/')))
        return QStringLiteral("The launch executable must be an absolute path inside the bundle.");

    const QVariantList repositories = build.value(QStringLiteral("repositories")).toList();
    if (repositories.isEmpty())
        return QStringLiteral("Add at least one package repository before building.");
    const QString hostArchitecture = hostPackageArchitecture();
    static const QRegularExpression snapshotPattern(QStringLiteral("^\\d{8}T\\d{6}Z$"));
    bool hasUbuntuRepository = false;
    const QStringList supportedDistributions = {QStringLiteral("debian"), QStringLiteral("debian-snapshot"), QStringLiteral("nitrux"),
                                                QStringLiteral("ubuntu"), QStringLiteral("ubuntu-ports"), QStringLiteral("devuan"),
                                                QStringLiteral("kde-neon")};
    for (const QVariant &value : repositories) {
        const QVariantMap repository = value.toMap();
        const QString distro = repository.value(QStringLiteral("distro")).toString().trimmed();
        const QString release = repository.value(QStringLiteral("release")).toString().trimmed();
        if (!supportedDistributions.contains(distro))
            return QStringLiteral("Choose a supported repository distribution.");
        if (distro == QLatin1String("ubuntu"))
            hasUbuntuRepository = true;
        const QString repositoryArchitecture = repository.value(QStringLiteral("arch")).toString().trimmed();
        if ((distro == QLatin1String("ubuntu") && hostArchitecture != QLatin1String("amd64"))
            || (distro == QLatin1String("ubuntu-ports") && hostArchitecture != QLatin1String("arm64")))
            return QStringLiteral("The selected repository does not support the host architecture.");
        if (distro.isEmpty() || release.isEmpty() || repositoryArchitecture != hostArchitecture)
            return QStringLiteral("Every repository requires a distribution, release, and the host architecture.");
        const QString snapshot = repository.value(QStringLiteral("snapshot")).toString().trimmed();
        if (distro == QLatin1String("debian-snapshot") && !snapshotPattern.match(snapshot).hasMatch())
            return QStringLiteral("Debian snapshots use the YYYYMMDDThhmmssZ format.");
        if (distro != QLatin1String("debian-snapshot") && !snapshot.isEmpty())
            return QStringLiteral("Only Debian snapshot repositories may define a snapshot.");
    }

    QSet<QString> ppaIds;
    for (const QVariant &value : build.value(QStringLiteral("ppas")).toList()) {
        const QVariantMap ppa = value.toMap();
        const QString id = ppa.value(QStringLiteral("id")).toString().trimmed();
        if (id.isEmpty() || ppaIds.contains(id) || ppa.value(QStringLiteral("ppa")).toString().trimmed().isEmpty()
            || ppa.value(QStringLiteral("release")).toString().trimmed().isEmpty()
            || ppa.value(QStringLiteral("distro")).toString() != QLatin1String("ubuntu")
            || ppa.value(QStringLiteral("arch")).toString() != hostArchitecture)
            return QStringLiteral("Every PPA requires a unique ID, PPA name, release, and the host architecture.");
        ppaIds.insert(id);
        if (!hasUbuntuRepository)
            return QStringLiteral("PPAs require an Ubuntu base repository.");
    }
    for (const QVariant &value : build.value(QStringLiteral("dependencies")).toList()) {
        const QVariantMap dependencyObject = value.metaType().id() == QMetaType::QVariantMap ? value.toMap() : QVariantMap();
        const QString dependency = dependencyObject.isEmpty()
            ? value.toString().trimmed()
            : dependencyObject.value(QStringLiteral("name")).toString().trimmed();
        const QString repositoryId = dependencyObject.value(QStringLiteral("repo")).toString().trimmed();
        if (dependency.isEmpty())
            return QStringLiteral("Dependency package names cannot be empty.");
        if (!repositoryId.isEmpty() && !ppaIds.contains(repositoryId))
            return QStringLiteral("Dependency PPA references must name a defined PPA ID.");
    }
    if (containsDuplicateKeys(launch.value(QStringLiteral("envvars")).toList())
        || containsDuplicateKeys(sandbox.value(QStringLiteral("bwrap-env")).toList()))
        return QStringLiteral("Environment variable names must be non-empty and unique.");

    const QString integrationType = integration.value(QStringLiteral("type")).toString();
    const QString sandboxType = sandbox.value(QStringLiteral("type")).toString();
    if (!QStringList{QStringLiteral("none"), QStringLiteral("bwrap"), QStringLiteral("firejail")}.contains(sandboxType))
        return QStringLiteral("Choose a valid sandbox type.");
    if (!QStringList{QStringLiteral("cli"), QStringLiteral("gui"), QStringLiteral("wm")}.contains(integrationType))
        return QStringLiteral("Choose a valid integration type.");
    if (integrationType == QLatin1String("wm") && sandboxType != QLatin1String("none"))
        return QStringLiteral("Window-manager integration cannot use a sandbox.");
    if (sandboxType == QLatin1String("firejail") && integrationType != QLatin1String("cli"))
        return QStringLiteral("Firejail is available only for command-line integration.");
    if (sandboxType == QLatin1String("firejail") && sandbox.value(QStringLiteral("name")).toString().trimmed().isEmpty())
        return QStringLiteral("Firejail requires a profile name.");
    bool validSeccomp = false;
    const QString seccomp = sandbox.value(QStringLiteral("seccomp")).toString().trimmed();
    const qlonglong seccompDescriptor = seccomp.toLongLong(&validSeccomp);
    if (sandboxType == QLatin1String("bwrap") && !seccomp.isEmpty() && (!validSeccomp || seccompDescriptor < 0))
        return QStringLiteral("The seccomp file descriptor must be a non-negative integer.");
    const QString launcher = integration.value(QStringLiteral("launcher")).toString().trimmed();
    if (!launcher.isEmpty() && (launcher.contains(QChar(u'/')) || !launcher.endsWith(QLatin1String(".desktop"))))
        return QStringLiteral("The launcher must be a desktop file name ending in .desktop.");
    return {};
}

bool UserBundleStore::create(const QString &projectId,
                             const QVariantMap &recipe,
                             const QVariantMap &metadata,
                             QString *error) const
{
    if (!ensureRoot(error))
        return false;

    const QString path = checkedProjectPath(projectId, false, error);
    if (path.isEmpty())
        return false;
    if (!QDir().mkpath(path)) {
        if (error)
            *error = QStringLiteral("Could not create the personal-bundle project directory.");
        return false;
    }

    const QFileInfo projectInfo(path);
    if (!projectInfo.isDir() || projectInfo.isSymbolicLink()) {
        if (error)
            *error = QStringLiteral("The new project path is not a safe directory.");
        return false;
    }

    const QString yamlPath = QDir(path).filePath(QStringLiteral("app.yml"));
    const QByteArray skeleton("buildinfo: {}\napprunconf: {}\nintegration: {}\nsandbox: {}\n");
    if (!writeAtomically(yamlPath, skeleton, error) || !save(projectId, recipe, metadata, error)) {
        QDir(path).removeRecursively();
        return false;
    }
    return true;
}

bool UserBundleStore::save(const QString &projectId,
                           const QVariantMap &recipe,
                           const QVariantMap &metadata,
                           QString *error) const
{
    const QString path = checkedProjectPath(projectId, true, error);
    if (path.isEmpty())
        return false;
    const QString yamlPath = QDir(path).filePath(QStringLiteral("app.yml"));
    const QByteArray original = readBoundedFile(yamlPath, MaxRecipeBytes);
    if (original.isEmpty()) {
        if (error)
            *error = QStringLiteral("Refusing to overwrite a missing, unsafe, empty, or oversized app.yml.");
        return false;
    }

    const QString metadataDirectory = QDir(path).filePath(QStringLiteral("metadata"));
    const QFileInfo metadataInfo(metadataDirectory);
    if ((metadataInfo.exists() && (!metadataInfo.isDir() || metadataInfo.isSymbolicLink()))
        || (!metadataInfo.exists() && !QDir().mkpath(metadataDirectory))) {
        if (error)
            *error = QStringLiteral("Could not prepare a safe metadata directory.");
        return false;
    }
    const QString metadataPath = QDir(metadataDirectory).filePath(QStringLiteral("app_description.md"));
    const QFileInfo metadataFileInfo(metadataPath);
    if (metadataFileInfo.exists() && (!metadataFileInfo.isFile() || metadataFileInfo.isSymbolicLink())) {
        if (error)
            *error = QStringLiteral("Refusing to overwrite an unsafe metadata file.");
        return false;
    }


    try {
        YAML::Node root = YAML::Load(original.constData());
        if (!root.IsMap())
            throw std::runtime_error("Top-level YAML value must be a mapping");

        const QVariantMap build = recipe.value(QStringLiteral("buildinfo")).toMap();
        YAML::Node buildNode = root["buildinfo"];
        if (buildNode && !buildNode.IsMap())
            throw std::runtime_error("buildinfo must be a mapping");
        if (!buildNode)
            buildNode = root["buildinfo"] = YAML::Node(YAML::NodeType::Map);
        for (const QString &key : {QStringLiteral("name"), QStringLiteral("version"), QStringLiteral("binarypath"), QStringLiteral("runtime")})
            buildNode[key.toStdString()] = build.value(key).toString().toStdString();
        const QString osTarget = build.value(QStringLiteral("os-target")).toString().trimmed();
        if (osTarget.isEmpty())
            buildNode.remove("os-target");
        else
            buildNode["os-target"] = osTarget.toStdString();

        const QVariantList repositories = build.value(QStringLiteral("repositories")).toList();
        const QVariantList ppas = build.value(QStringLiteral("ppas")).toList();
        const YAML::Node existingRepos = buildNode["distrorepo"];
        if (!ppas.isEmpty() || (existingRepos && existingRepos.IsMap())) {
            YAML::Node repos = existingRepos && existingRepos.IsMap()
                ? existingRepos
                : YAML::Node(YAML::NodeType::Map);
            repos["base"] = variantToYaml(repositories);
            if (ppas.isEmpty())
                repos.remove("ppas");
            else
                repos["ppas"] = variantToYaml(ppas);
            buildNode["distrorepo"] = repos;
        } else {
            buildNode["distrorepo"] = variantToYaml(repositories);
        }
        buildNode["deps"] = variantToYaml(build.value(QStringLiteral("dependencies")));

        const QVariantMap launch = recipe.value(QStringLiteral("apprunconf")).toMap();
        YAML::Node launchNode = root["apprunconf"];
        if (launchNode && !launchNode.IsMap())
            throw std::runtime_error("apprunconf must be a mapping");
        if (!launchNode)
            launchNode = root["apprunconf"] = YAML::Node(YAML::NodeType::Map);
        for (const QString &key : {QStringLiteral("exec"), QStringLiteral("setpath"), QStringLiteral("setlibpath")})
            launchNode[key.toStdString()] = launch.value(key).toString().toStdString();
        launchNode["envvars"] = environmentMap(launch.value(QStringLiteral("envvars")).toList());
        launchNode["extra-rpaths"] = variantToYaml(launch.value(QStringLiteral("extra-rpaths")));
        launchNode["prebuild-commands"] = variantToYaml(launch.value(QStringLiteral("prebuild-commands")));

        const QVariantMap integration = recipe.value(QStringLiteral("integration")).toMap();
        YAML::Node integrationNode = root["integration"];
        if (integrationNode && !integrationNode.IsMap())
            throw std::runtime_error("integration must be a mapping");
        if (!integrationNode)
            integrationNode = YAML::Node(YAML::NodeType::Map);
        const QString integrationType = integration.value(QStringLiteral("type")).toString();
        integrationNode["type"] = integrationType.toStdString();
        const QString launcher = integration.value(QStringLiteral("launcher")).toString().trimmed();
        if (!launcher.isEmpty())
            integrationNode["launcher"] = launcher.toStdString();
        else
            integrationNode.remove("launcher");
        root["integration"] = integrationNode;

        const QVariantMap sandbox = recipe.value(QStringLiteral("sandbox")).toMap();
        const QString effectiveSandbox = integrationType == QLatin1String("wm")
            ? QStringLiteral("none")
            : sandbox.value(QStringLiteral("type"), QStringLiteral("none")).toString();
        YAML::Node sandboxNode = root["sandbox"];
        if (sandboxNode && !sandboxNode.IsMap())
            throw std::runtime_error("sandbox must be a mapping");
        if (!sandboxNode)
            sandboxNode = YAML::Node(YAML::NodeType::Map);
        sandboxNode.remove("type");
        sandboxNode.remove("name");
        sandboxNode.remove("aa-profile");
        for (const QString &key : SandboxBooleanKeys)
            sandboxNode.remove(key.toStdString());
        for (const QString &key : SandboxListKeys)
            sandboxNode.remove(key.toStdString());
        for (const QString &key : SandboxValueKeys)
            sandboxNode.remove(key.toStdString());
        sandboxNode.remove("bwrap-env");
        sandboxNode["type"] = effectiveSandbox.toStdString();
        if (effectiveSandbox == QLatin1String("firejail")) {
            sandboxNode["name"] = sandbox.value(QStringLiteral("name")).toString().toStdString();
            const QString profile = sandbox.value(QStringLiteral("aa-profile")).toString().trimmed();
            if (!profile.isEmpty())
                sandboxNode["aa-profile"] = profile.toStdString();
        } else if (effectiveSandbox == QLatin1String("bwrap")) {
            for (const QString &key : SandboxBooleanKeys) {
                if (sandbox.value(key).toBool())
                    sandboxNode[key.toStdString()] = true;
            }
            for (const QString &key : SandboxListKeys) {
                const QVariantList values = sandbox.value(key).toList();
                if (!values.isEmpty())
                    sandboxNode[key.toStdString()] = variantToYaml(values);
            }
            const QVariantList environment = sandbox.value(QStringLiteral("bwrap-env")).toList();
            if (!environment.isEmpty())
                sandboxNode["bwrap-env"] = bwrapEnvironment(environment);
            for (const QString &key : SandboxValueKeys) {
                const QString value = sandbox.value(key).toString().trimmed();
                if (value.isEmpty())
                    continue;
                if (key == QLatin1String("seccomp"))
                    sandboxNode[key.toStdString()] = value.toLongLong();
                else
                    sandboxNode[key.toStdString()] = value.toStdString();
            }
        }
        root["sandbox"] = sandboxNode;

        YAML::Emitter emitter;
        emitter.SetIndent(2);
        emitter.SetStringFormat(YAML::DoubleQuoted);
        emitter << root;
        if (!emitter.good())
            throw std::runtime_error(emitter.GetLastError());
        QByteArray emitted(emitter.c_str(), static_cast<qsizetype>(emitter.size()));
        emitted.append('\n');
        if (!writeAtomically(yamlPath, emitted, error))
            return false;

        return writeAtomically(metadataPath,
                               emitMetadata(metadata, build.value(QStringLiteral("name")).toString()),
                               error);
    } catch (const std::exception &exception) {
        if (error)
            *error = QString::fromLocal8Bit(exception.what());
    }
    return false;
}
