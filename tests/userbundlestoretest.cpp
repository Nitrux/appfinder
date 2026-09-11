/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

#include <yaml-cpp/yaml.h>

#include "../src/controllers/userbundlestore.h"
#include "../src/controllers/apphubbackend.h"

namespace {

const QByteArray Recipe = R"YAML(buildinfo:
  name: sample
  version: "1.0"
  binarypath: /usr/bin/sample
  custom-build: keep
  distrorepo:
    base:
      - distro: debian-snapshot
        snapshot: 20260725T202958Z
        release: testing
        arch: amd64
        components: [main]
        custom-repository: keep
    ppas: []
    future-repositories: keep
  deps: [sample]
  runtime: classic
apprunconf:
  exec: /usr/bin/sample
  setpath: /usr/bin
  setlibpath: /usr/lib
  envvars: {}
  custom-launch: keep
sandbox:
  type: none
  custom-sandbox: keep
integration:
  type: cli
  custom-integration: keep
custom-top: keep
)YAML";

const QByteArray Metadata = R"MD(# Sample

## Summary

A sample bundle.

## Description

A longer description.

## Category

AppHub.Utilities

## Homepage

[https://example.com](https://example.com)

## License

BSD-3-Clause
)MD";

bool writeFile(const QString &path, const QByteArray &data)
{
    QFile file(path);
    return file.open(QIODevice::WriteOnly | QIODevice::Truncate) && file.write(data) == data.size();
}

bool createProject(const QString &root, const QString &id, bool metadata = true)
{
    const QString project = QDir(root).filePath(id);
    if (!QDir().mkpath(project) || !writeFile(QDir(project).filePath(QStringLiteral("app.yml")), Recipe))
        return false;
    if (!metadata)
        return true;
    return QDir().mkpath(QDir(project).filePath(QStringLiteral("metadata")))
        && writeFile(QDir(project).filePath(QStringLiteral("metadata/app_description.md")), Metadata);
}

} // namespace

class UserBundleStoreTest final : public QObject
{
    Q_OBJECT

private slots:
    void xdgRoot();
    void identifiersAndSymlinks();
    void roundTripAndPreserveUnknownFields();
    void malformedProjectRemainsVisible();
    void incompatibleNodeTypesAreRejected();
    void saveFailureDoesNotReplaceRecipe();
    void detectsBuiltArtifact();
    void preflight();
    void backendUsesProjectWorkingDirectories();
};

void UserBundleStoreTest::xdgRoot()
{
    QTemporaryDir dataHome;
    QVERIFY(dataHome.isValid());
    const QByteArray oldValue = qgetenv("XDG_DATA_HOME");
    qputenv("XDG_DATA_HOME", dataHome.path().toUtf8());
    UserBundleStore store;
    QCOMPARE(store.rootPath(), QDir(dataHome.path()).filePath(QStringLiteral("appfinder/user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(QFileInfo::exists(store.rootPath()));
    if (oldValue.isNull())
        qunsetenv("XDG_DATA_HOME");
    else
        qputenv("XDG_DATA_HOME", oldValue);
}

void UserBundleStoreTest::identifiersAndSymlinks()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(store.isValidProjectId(QStringLiteral("sample.project-1")));
    QVERIFY(!store.isValidProjectId(QStringLiteral("../sample")));
    QVERIFY(!store.isValidProjectId(QStringLiteral("Sample")));

    const QString outside = QDir(temporary.path()).filePath(QStringLiteral("outside"));
    QVERIFY(QDir().mkpath(outside));
    const QString link = QDir(store.rootPath()).filePath(QStringLiteral("linked"));
    if (!QFile::link(outside, link))
        QSKIP("The test filesystem does not permit directory symlinks.");
    QVERIFY(!store.projectExists(QStringLiteral("linked")));
    QVERIFY(store.projects().isEmpty());
}

void UserBundleStoreTest::roundTripAndPreserveUnknownFields()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(createProject(store.rootPath(), QStringLiteral("sample")));

    QVariantMap document = store.load(QStringLiteral("sample"));
    QVERIFY2(document.value(QStringLiteral("valid")).toBool(), qPrintable(document.value(QStringLiteral("error")).toString()));
    QVariantMap recipe = document.value(QStringLiteral("recipe")).toMap();
    QVariantMap build = recipe.value(QStringLiteral("buildinfo")).toMap();
    build.insert(QStringLiteral("version"), QStringLiteral("2.0"));
    build.insert(QStringLiteral("ppas"), QVariantList{QVariantMap{{QStringLiteral("id"), QStringLiteral("tools")},
                                                                   {QStringLiteral("ppa"), QStringLiteral("example/tools")},
                                                                   {QStringLiteral("distro"), QStringLiteral("ubuntu")},
                                                                   {QStringLiteral("release"), QStringLiteral("noble")},
                                                                   {QStringLiteral("arch"), QStringLiteral("amd64")}}});
    build.insert(QStringLiteral("dependencies"), QVariantList{QStringLiteral("sample"),
                                                                QVariantMap{{QStringLiteral("name"), QStringLiteral("helper")},
                                                                            {QStringLiteral("repo"), QStringLiteral("tools")}}});
    recipe.insert(QStringLiteral("buildinfo"), build);

    QVariantMap launch = recipe.value(QStringLiteral("apprunconf")).toMap();
    launch.insert(QStringLiteral("envvars"), QVariantList{QVariantMap{{QStringLiteral("key"), QStringLiteral("HOME")},
                                                                       {QStringLiteral("value"), QStringLiteral("$HOME")}}});
    launch.insert(QStringLiteral("extra-rpaths"), QVariantList{QStringLiteral("$ORIGIN/lib")});
    launch.insert(QStringLiteral("prebuild-commands"), QVariantList{QStringLiteral("true")});
    recipe.insert(QStringLiteral("apprunconf"), launch);

    QVariantMap sandbox{{QStringLiteral("type"), QStringLiteral("bwrap")},
                        {QStringLiteral("ro-root"), true},
                        {QStringLiteral("dev"), true},
                        {QStringLiteral("bind"), QVariantList{QStringLiteral("$HOME:$HOME")}},
                        {QStringLiteral("bwrap-env"), QVariantList{QVariantMap{{QStringLiteral("key"), QStringLiteral("LANG")},
                                                                                {QStringLiteral("value"), QStringLiteral("C")}}}},
                        {QStringLiteral("hostname"), QStringLiteral("sample")}};
    const QStringList sandboxBooleans = {QStringLiteral("ro-root"), QStringLiteral("dev"), QStringLiteral("proc"), QStringLiteral("tmpfs"),
                                         QStringLiteral("mqueue"), QStringLiteral("ro-home"), QStringLiteral("no-net"), QStringLiteral("no-ipc"),
                                         QStringLiteral("no-pid"), QStringLiteral("unshare-user"), QStringLiteral("unshare-uts"), QStringLiteral("unshare-cgroup"),
                                         QStringLiteral("new-session"), QStringLiteral("cap-drop-all"), QStringLiteral("die-with-parent"), QStringLiteral("clearenv")};
    for (const QString &key : sandboxBooleans)
        sandbox.insert(key, true);
    const QStringList sandboxLists = {QStringLiteral("bwrap-unset-env"), QStringLiteral("cap-drop"), QStringLiteral("bind"),
                                      QStringLiteral("ro-bind"), QStringLiteral("bind-try"), QStringLiteral("ro-bind-try"), QStringLiteral("remount-ro")};
    for (const QString &key : sandboxLists)
        sandbox.insert(key, QVariantList{QStringLiteral("sample-value")});
    sandbox.insert(QStringLiteral("chdir"), QStringLiteral("/tmp"));
    sandbox.insert(QStringLiteral("file-label"), QStringLiteral("sample-file"));
    sandbox.insert(QStringLiteral("exec-label"), QStringLiteral("sample-exec"));
    sandbox.insert(QStringLiteral("seccomp"), QStringLiteral("4"));
    recipe.insert(QStringLiteral("sandbox"), sandbox);

    QVariantMap metadata = document.value(QStringLiteral("metadata")).toMap();
    metadata.insert(QStringLiteral("summary"), QStringLiteral("Updated summary."));
    QString error;
    QVERIFY2(store.save(QStringLiteral("sample"), recipe, metadata, &error), qPrintable(error));

    document = store.load(QStringLiteral("sample"));
    QVERIFY2(document.value(QStringLiteral("valid")).toBool(), qPrintable(document.value(QStringLiteral("error")).toString()));
    QCOMPARE(document.value(QStringLiteral("recipe")).toMap().value(QStringLiteral("buildinfo")).toMap().value(QStringLiteral("version")).toString(), QStringLiteral("2.0"));
    QCOMPARE(document.value(QStringLiteral("metadata")).toMap().value(QStringLiteral("summary")).toString(), QStringLiteral("Updated summary."));
    const QVariantMap loadedSandbox = document.value(QStringLiteral("recipe")).toMap().value(QStringLiteral("sandbox")).toMap();
    for (const QString &key : sandboxBooleans)
        QCOMPARE(loadedSandbox.value(key).toBool(), true);
    for (const QString &key : sandboxLists)
        QCOMPARE(loadedSandbox.value(key).toList(), QVariantList{QStringLiteral("sample-value")});
    QCOMPARE(loadedSandbox.value(QStringLiteral("hostname")).toString(), QStringLiteral("sample"));
    QCOMPARE(loadedSandbox.value(QStringLiteral("chdir")).toString(), QStringLiteral("/tmp"));
    QCOMPARE(loadedSandbox.value(QStringLiteral("file-label")).toString(), QStringLiteral("sample-file"));
    QCOMPARE(loadedSandbox.value(QStringLiteral("exec-label")).toString(), QStringLiteral("sample-exec"));
    QCOMPARE(loadedSandbox.value(QStringLiteral("seccomp")).toString(), QStringLiteral("4"));
    QCOMPARE(loadedSandbox.value(QStringLiteral("bwrap-env")).toList().size(), 1);

    const YAML::Node root = YAML::LoadFile(QDir(store.projectPath(QStringLiteral("sample"))).filePath(QStringLiteral("app.yml")).toStdString());
    QCOMPARE(QString::fromStdString(root["custom-top"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["buildinfo"]["custom-build"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["buildinfo"]["distrorepo"]["future-repositories"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["buildinfo"]["distrorepo"]["base"][0]["custom-repository"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["apprunconf"]["custom-launch"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["sandbox"]["custom-sandbox"].as<std::string>()), QStringLiteral("keep"));
    QCOMPARE(QString::fromStdString(root["integration"]["custom-integration"].as<std::string>()), QStringLiteral("keep"));

    QFile metadataFile(QDir(store.projectPath(QStringLiteral("sample"))).filePath(QStringLiteral("metadata/app_description.md")));
    QVERIFY(metadataFile.open(QIODevice::ReadOnly));
    const QByteArray emittedMetadata = metadataFile.readAll();
    QVERIFY(emittedMetadata.indexOf("## Summary") < emittedMetadata.indexOf("## Description"));
    QVERIFY(emittedMetadata.indexOf("## Description") < emittedMetadata.indexOf("## Category"));
    QVERIFY(emittedMetadata.indexOf("## Category") < emittedMetadata.indexOf("## Homepage"));
    QVERIFY(emittedMetadata.indexOf("## Homepage") < emittedMetadata.indexOf("## License"));
}

void UserBundleStoreTest::malformedProjectRemainsVisible()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    const QString project = QDir(store.rootPath()).filePath(QStringLiteral("broken"));
    QVERIFY(QDir().mkpath(project));
    QVERIFY(writeFile(QDir(project).filePath(QStringLiteral("app.yml")), QByteArray("- not-a-map\n")));
    const QList<AppModel::Item> items = store.projects();
    QCOMPARE(items.size(), 1);
    QCOMPARE(items.first().status, QStringLiteral("Invalid Recipe"));
    QVERIFY(!items.first().summary.isEmpty());
}

void UserBundleStoreTest::incompatibleNodeTypesAreRejected()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    const QString project = QDir(store.rootPath()).filePath(QStringLiteral("incompatible"));
    QVERIFY(QDir().mkpath(QDir(project).filePath(QStringLiteral("metadata"))));
    const QByteArray incompatible = QByteArray("buildinfo: []\napprunconf: {}\n");
    QVERIFY(writeFile(QDir(project).filePath(QStringLiteral("app.yml")), incompatible));
    const QVariantMap document = store.load(QStringLiteral("incompatible"));
    QVERIFY(!document.value(QStringLiteral("valid")).toBool());
    QString error;
    QVERIFY(!store.save(QStringLiteral("incompatible"), {}, {}, &error));
    QVERIFY(!error.isEmpty());
    QFile recipeFile(QDir(project).filePath(QStringLiteral("app.yml")));
    QVERIFY(recipeFile.open(QIODevice::ReadOnly));
    QCOMPARE(recipeFile.readAll(), incompatible);
}

void UserBundleStoreTest::saveFailureDoesNotReplaceRecipe()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(createProject(store.rootPath(), QStringLiteral("blocked"), false));
    const QString project = store.projectPath(QStringLiteral("blocked"));
    QVERIFY(writeFile(QDir(project).filePath(QStringLiteral("metadata")), QByteArray("not a directory")));
    const QByteArray before = Recipe;
    const QVariantMap document = store.load(QStringLiteral("blocked"));
    QString error;
    QVERIFY(!store.save(QStringLiteral("blocked"), document.value(QStringLiteral("recipe")).toMap(), {}, &error));
    QFile recipeFile(QDir(project).filePath(QStringLiteral("app.yml")));
    QVERIFY(recipeFile.open(QIODevice::ReadOnly));
    QCOMPARE(recipeFile.readAll(), before);
}

void UserBundleStoreTest::detectsBuiltArtifact()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(createProject(store.rootPath(), QStringLiteral("sample")));
    const QVariantMap document = store.load(QStringLiteral("sample"));
    const QString artifact = store.outputPath(QStringLiteral("sample"), document.value(QStringLiteral("recipe")).toMap());
    QVERIFY(QDir().mkpath(QFileInfo(artifact).dir().path()));
    QVERIFY(writeFile(artifact, QByteArray("bundle")));
    const QList<AppModel::Item> items = store.projects();
    QCOMPARE(items.size(), 1);
    QCOMPARE(items.first().status, QStringLiteral("Bundle Built"));
    QVERIFY(store.load(QStringLiteral("sample")).contains(QStringLiteral("outputUrl")));
}

void UserBundleStoreTest::preflight()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    UserBundleStore store(QDir(temporary.path()).filePath(QStringLiteral("user")));
    QVERIFY(store.ensureRoot());
    QVERIFY(createProject(store.rootPath(), QStringLiteral("sample")));
    QVariantMap recipe = store.load(QStringLiteral("sample")).value(QStringLiteral("recipe")).toMap();
    QVariantMap build = recipe.value(QStringLiteral("buildinfo")).toMap();
    QVariantList repositories = build.value(QStringLiteral("repositories")).toList();
    QVariantMap repository = repositories.first().toMap();
    repository.insert(QStringLiteral("arch"), store.hostPackageArchitecture());
    repositories[0] = repository;
    build.insert(QStringLiteral("repositories"), repositories);
    recipe.insert(QStringLiteral("buildinfo"), build);
    QVERIFY(store.preflight(recipe).isEmpty());
    build = recipe.value(QStringLiteral("buildinfo")).toMap();
    build.insert(QStringLiteral("binarypath"), QStringLiteral("/usr/bin/REPLACE-ME"));
    recipe.insert(QStringLiteral("buildinfo"), build);
    QVERIFY(!store.preflight(recipe).isEmpty());
}

void UserBundleStoreTest::backendUsesProjectWorkingDirectories()
{
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    const QString bin = QDir(temporary.path()).filePath(QStringLiteral("bin"));
    QVERIFY(QDir().mkpath(bin));
    const QString executable = QDir(bin).filePath(QStringLiteral("nx-apphub-cli"));
    const QByteArray script = R"SH(#!/bin/sh
command="$1"
shift
if [ "$command" = "generate" ]; then
    printf '%s\n' "$@" > "$PWD/generate-arguments.txt"
    output=""
    description=""
    arch=""
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --output) output="$2"; shift 2 ;;
            --description-output) description="$2"; shift 2 ;;
            --arch) arch="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    printf '%s\n' 'buildinfo:' '  name: sample' '  version: "1.0"' '  binarypath: /usr/bin/sample' '  distrorepo:' '    - distro: debian' '      release: testing' "      arch: $arch" '      components: [main]' '  deps: [sample]' '  runtime: classic' 'apprunconf:' '  exec: /usr/bin/sample' '  setpath: /usr/bin' '  setlibpath: /usr/lib' '  envvars: {}' 'sandbox:' '  type: none' 'integration:' '  type: cli' > "$output"
    printf '%s\n' '# Sample' '' '## Summary' '' 'Generated sample.' '' '## Description' '' 'Generated sample.' '' '## Category' '' 'AppHub.Utilities' '' '## Homepage' '' '[https://example.com](https://example.com)' '' '## License' '' 'BSD-3-Clause' > "$description"
    exit 0
fi
if [ "$command" = "build" ]; then
    machine="$(uname -m)"
    artifact="$PWD/sample-1.0-$machine.AppImage"
    printf '%s' "$1" > "$PWD/build-argument.txt"
    printf '%s' "$PWD" > "$PWD/build-working-directory.txt"
    if [ -e "$PWD/fail-build" ]; then
        printf 'partial' > "$artifact"
        exit 1
    fi
    : > "$artifact"
    exit 0
fi
exit 1
)SH";
    QVERIFY(writeFile(executable, script));
    QVERIFY(QFile::setPermissions(executable, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner
                                             | QFileDevice::ReadGroup | QFileDevice::ExeGroup
                                             | QFileDevice::ReadOther | QFileDevice::ExeOther));

    const QByteArray oldDataHome = qgetenv("XDG_DATA_HOME");
    const QByteArray oldPath = qgetenv("PATH");
    const QString dataHome = QDir(temporary.path()).filePath(QStringLiteral("data"));
    qputenv("XDG_DATA_HOME", dataHome.toUtf8());
    qputenv("PATH", (bin.toUtf8() + ':' + oldPath));

    AppHubBackend backend;
    QSignalSpy generated(&backend, &AppHubBackend::userBundleGenerated);
    backend.generateUserBundle(QStringLiteral("sample-project"),
                               {{QStringLiteral("package"), QStringLiteral("sample")},
                                {QStringLiteral("distro"), QStringLiteral("debian")},
                                {QStringLiteral("release"), QStringLiteral("testing")},
                                {QStringLiteral("components"), QStringList{QStringLiteral("main")}},
                                {QStringLiteral("integration"), QStringLiteral("cli")}});
    QVERIFY(!generated.isEmpty() || generated.wait());
    QVERIFY(generated.takeFirst().at(1).toBool());
    const QString project = QDir(dataHome).filePath(QStringLiteral("appfinder/user/sample-project"));
    QFile generatedArguments(QDir(project).filePath(QStringLiteral("generate-arguments.txt")));
    QVERIFY(generatedArguments.open(QIODevice::ReadOnly));
    const QByteArray arguments = generatedArguments.readAll();
    for (const QByteArray &argument : {QByteArray("--package"), QByteArray("sample"), QByteArray("--distro"), QByteArray("debian"),
                                      QByteArray("--release"), QByteArray("testing"), QByteArray("--arch"),
                                      backend.userBundleArchitecture().toUtf8(), QByteArray("--components"), QByteArray("main"),
                                      QByteArray("--integration-type"), QByteArray("cli")})
        QVERIFY(arguments.split('\n').contains(argument));
    const QList<QByteArray> generatedArgumentsList = arguments.split('\n');
    const qsizetype outputIndex = generatedArgumentsList.indexOf(QByteArray("--output"));
    const qsizetype descriptionIndex = generatedArgumentsList.indexOf(QByteArray("--description-output"));
    QVERIFY(outputIndex >= 0 && outputIndex + 1 < generatedArgumentsList.size());
    QVERIFY(descriptionIndex >= 0 && descriptionIndex + 1 < generatedArgumentsList.size());
    const QString generatedRecipePath = QString::fromUtf8(generatedArgumentsList.at(outputIndex + 1));
    const QString generatedMetadataPath = QString::fromUtf8(generatedArgumentsList.at(descriptionIndex + 1));
    QVERIFY(QFileInfo(generatedRecipePath).isAbsolute());
    QVERIFY(QFileInfo(generatedMetadataPath).isAbsolute());
    QCOMPARE(QFileInfo(generatedRecipePath).fileName(), QStringLiteral("app.yml"));
    QVERIFY(generatedMetadataPath.endsWith(QStringLiteral("/metadata/app_description.md")));

    QSignalSpy built(&backend, &AppHubBackend::userBundleBuilt);
    backend.buildUserBundle(QStringLiteral("sample-project"));
    QVERIFY(!built.isEmpty() || built.wait());
    QVERIFY(built.takeFirst().at(1).toBool());

    const QString dist = QDir(dataHome).filePath(QStringLiteral("appfinder/user/sample-project/dist"));
    QFile workingDirectory(QDir(dist).filePath(QStringLiteral("build-working-directory.txt")));
    QVERIFY(workingDirectory.open(QIODevice::ReadOnly));
    QCOMPARE(QString::fromUtf8(workingDirectory.readAll()), dist);
    QFile buildArgument(QDir(dist).filePath(QStringLiteral("build-argument.txt")));
    QVERIFY(buildArgument.open(QIODevice::ReadOnly));
    QCOMPARE(QString::fromUtf8(buildArgument.readAll()), QDir(project).filePath(QStringLiteral("app.yml")));
    const QString artifact = backend.userBundleOutputUrl().toLocalFile();
    QVERIFY(writeFile(artifact, QByteArray("previous-artifact")));
    QVERIFY(writeFile(QDir(dist).filePath(QStringLiteral("fail-build")), QByteArray("fail")));
    QSignalSpy failedBuild(&backend, &AppHubBackend::userBundleBuilt);
    backend.buildUserBundle(QStringLiteral("sample-project"));
    QVERIFY(!failedBuild.isEmpty() || failedBuild.wait());
    QVERIFY(!failedBuild.takeFirst().at(1).toBool());
    QFile restoredArtifact(artifact);
    QVERIFY(restoredArtifact.open(QIODevice::ReadOnly));
    QCOMPARE(restoredArtifact.readAll(), QByteArray("previous-artifact"));

    if (oldDataHome.isNull())
        qunsetenv("XDG_DATA_HOME");
    else
        qputenv("XDG_DATA_HOME", oldDataHome);
    qputenv("PATH", oldPath);
}
QTEST_GUILESS_MAIN(UserBundleStoreTest)
#include "userbundlestoretest.moc"
