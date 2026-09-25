/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QStringList>

#include <cstdio>
#include <pwd.h>
#include <sys/types.h>
#include <utility>

namespace {

constexpr int CommandTimeoutMs = 30000;
constexpr int LongCommandTimeoutMs = 30 * 60 * 1000;
constexpr qsizetype MaxOutputBytes = 8 * 1024 * 1024;
constexpr qsizetype MaxLauncherIconBytes = 2 * 1024 * 1024;

QString findExecutable(const QString &program)
{
    const QString executable = QStandardPaths::findExecutable(program);
    if (!executable.isEmpty())
        return executable;

    for (const QString &directory : {QStringLiteral("/usr/local/bin"), QStringLiteral("/usr/bin"), QStringLiteral("/bin")}) {
        const QString candidate = directory + QLatin1Char(47) + program;
        const QFileInfo information(candidate);
        if (information.isFile() && information.isExecutable())
            return candidate;
    }
    return {};
}

void writeOutput(const QByteArray &output)
{
    if (!output.isEmpty())
        fwrite(output.constData(), sizeof(char), static_cast<size_t>(output.size()), stdout);
}

bool runCommand(const QString &program, const QStringList &arguments, QByteArray &output, QString &error, int timeout = CommandTimeoutMs, const QProcessEnvironment &environmentOverrides = QProcessEnvironment())
{
    QProcess process;
    QProcessEnvironment environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("LC_ALL"), QStringLiteral("C"));
    environment.insert(QStringLiteral("LANG"), QStringLiteral("C"));
    for (const QString &variable : environmentOverrides.keys())
        environment.insert(variable, environmentOverrides.value(variable));
    process.setProcessEnvironment(environment);
    process.setProcessChannelMode(QProcess::SeparateChannels);
    process.start(program, arguments);
    if (!process.waitForStarted(CommandTimeoutMs)) {
        error = process.errorString();
        return false;
    }
    if (!process.waitForFinished(timeout)) {
        process.kill();
        process.waitForFinished();
        error = QStringLiteral("The command timed out.");
        return false;
    }

    output = process.readAllStandardOutput();
    const QByteArray standardError = process.readAllStandardError();
    if (output.size() + standardError.size() > MaxOutputBytes) {
        error = QStringLiteral("The command produced too much output.");
        return false;
    }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        error = QString::fromLocal8Bit(standardError).trimmed();
        if (error.isEmpty())
            error = QStringLiteral("The command failed.");
        return false;
    }
    return true;
}

bool runAndForward(const QString &program, const QStringList &arguments, QString &error, int timeout = CommandTimeoutMs, const QProcessEnvironment &environmentOverrides = QProcessEnvironment())
{
    QByteArray output;
    if (!runCommand(program, arguments, output, error, timeout, environmentOverrides))
        return false;

    writeOutput(output);
    return true;
}

bool makeRootShared(QString &error)
{
    const QString findmnt = findExecutable(QStringLiteral("findmnt"));
    const QString mount = findExecutable(QStringLiteral("mount"));
    if (findmnt.isEmpty() || mount.isEmpty()) {
        if (findmnt.isEmpty())
            error = QStringLiteral("findmnt is not installed.");
        else
            error = QStringLiteral("mount is not installed.");
        return false;
    }

    QByteArray propagation;
    if (!runCommand(findmnt,
                    {QStringLiteral("--noheadings"), QStringLiteral("--output"), QStringLiteral("PROPAGATION"), QStringLiteral("/")},
                    propagation,
                    error))
        return false;

    if (QString::fromLocal8Bit(propagation).trimmed() == QLatin1String("shared"))
        return true;

    return runAndForward(mount, {QStringLiteral("--make-rshared"), QStringLiteral("/")}, error);
}

bool validContainerName(const QString &name)
{
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$"));
    return pattern.match(name).hasMatch();
}

QByteArray errorResponse(const QString &message)
{
    QJsonObject response;
    response.insert(QStringLiteral("error"), message);
    return QJsonDocument(response).toJson(QJsonDocument::Compact);
}

QString readDesktopIcon(const QString &path)
{
    QFile launcher(path);
    if (!launcher.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    bool desktopEntry = false;
    while (!launcher.atEnd()) {
        const QString line = QString::fromLocal8Bit(launcher.readLine()).trimmed();
        if (line == QLatin1String("[Desktop Entry]")) {
            desktopEntry = true;
            continue;
        }
        if (desktopEntry && line.startsWith(QLatin1Char(91)))
            break;
        if (desktopEntry && line.startsWith(QLatin1String("Icon=")))
            return line.mid(5).trimmed();
    }

    return {};
}

const struct passwd *invokingUser()
{
    bool ok = false;
    const uint uid = QProcessEnvironment::systemEnvironment().value(QStringLiteral("PKEXEC_UID")).toUInt(&ok);
    return ok ? getpwuid(static_cast<uid_t>(uid)) : nullptr;
}

QString invokingUserHome()
{
    const struct passwd *user = invokingUser();
    return user && user->pw_dir ? QString::fromLocal8Bit(user->pw_dir) : QString();
}

QString rootfulLauncherPath(const QString &name)
{
    const QString userHome = invokingUserHome();
    return userHome.isEmpty() || userHome == QLatin1String("/")
        ? QString()
        : QDir(userHome).filePath(QStringLiteral(".local/share/applications/%1.desktop").arg(name));
}

QJsonObject rootfulLauncherIcon(const QString &name)
{
    QStringList launcherPaths;
    const QString userLauncher = rootfulLauncherPath(name);
    if (!userLauncher.isEmpty())
        launcherPaths << userLauncher;
    launcherPaths << QStringLiteral("/root/.local/share/applications/%1.desktop").arg(name);
    launcherPaths << QStringLiteral("/usr/local/share/applications/%1.desktop").arg(name)
                  << QStringLiteral("/usr/share/applications/%1.desktop").arg(name);

    QString iconValue;
    for (const QString &path : std::as_const(launcherPaths)) {
        iconValue = readDesktopIcon(path);
        if (!iconValue.isEmpty())
            break;
    }
    if (iconValue.isEmpty())
        return {};

    QJsonObject icon;
    if (!iconValue.startsWith(QLatin1Char(47))) {
        icon.insert(QStringLiteral("name"), iconValue);
        return icon;
    }

    QFile iconFile(iconValue);
    const QFileInfo iconInfo(iconValue);
    if (!iconInfo.isFile() || iconInfo.size() <= 0 || iconInfo.size() > MaxLauncherIconBytes
        || !iconFile.open(QIODevice::ReadOnly))
        return {};

    const QByteArray data = iconFile.readAll();
    if (data.isEmpty())
        return {};

    QString mimeType = QStringLiteral("image/png");
    if (iconValue.endsWith(QStringLiteral(".svg"), Qt::CaseInsensitive))
        mimeType = QStringLiteral("image/svg+xml");
    else if (iconValue.endsWith(QStringLiteral(".jpg"), Qt::CaseInsensitive)
             || iconValue.endsWith(QStringLiteral(".jpeg"), Qt::CaseInsensitive))
        mimeType = QStringLiteral("image/jpeg");
    else if (iconValue.endsWith(QStringLiteral(".webp"), Qt::CaseInsensitive))
        mimeType = QStringLiteral("image/webp");

    icon.insert(QStringLiteral("url"), QStringLiteral("data:%1;base64,%2").arg(mimeType, QString::fromLatin1(data.toBase64())));
    return icon;
}

QJsonObject rootfulLauncherIcons(const QStringList &names)
{
    QJsonObject icons;
    for (const QString &name : names) {
        const QJsonObject icon = rootfulLauncherIcon(name);
        if (!icon.isEmpty())
            icons.insert(name, icon);
    }
    return icons;
}

bool generateRootfulEntry(const QString &name, QString &error)
{
    const QString generator = findExecutable(QStringLiteral("distrobox-generate-entry"));
    const QString home = invokingUserHome();
    if (generator.isEmpty()) {
        error = QStringLiteral("distrobox-generate-entry is not installed.");
        return false;
    }
    if (home.isEmpty() || home == QLatin1String("/")) {
        error = QStringLiteral("The invoking user home directory could not be determined.");
        return false;
    }

    QProcessEnvironment environment;
    environment.insert(QStringLiteral("HOME"), home);
    environment.insert(QStringLiteral("XDG_DATA_HOME"), QDir(home).filePath(QStringLiteral(".local/share")));
    QByteArray output;
    if (!runCommand(generator, {QStringLiteral("--root"), name}, output, error, CommandTimeoutMs, environment))
        return false;

    const struct passwd *user = invokingUser();
    const QString launcherPath = rootfulLauncherPath(name);
    const QString chown = findExecutable(QStringLiteral("chown"));
    if (!user || launcherPath.isEmpty() || chown.isEmpty()) {
        error = QStringLiteral("The generated rootful Distrobox entry could not be prepared.");
        return false;
    }

    QStringList paths {launcherPath};
    const QString iconPath = readDesktopIcon(launcherPath);
    const QString homePrefix = QDir(home).absolutePath() + QLatin1Char(47);
    if (iconPath.startsWith(homePrefix) && QFileInfo(iconPath).isFile())
        paths.append(iconPath);

    const QString owner = QStringLiteral("%1:%2").arg(static_cast<qulonglong>(user->pw_uid)).arg(static_cast<qulonglong>(user->pw_gid));
    QStringList chownArguments {QStringLiteral("--"), owner};
    chownArguments.append(paths);
    return runAndForward(chown, chownArguments, error);
}

QByteArray rootfulSnapshot()
{
    const QString distrobox = findExecutable(QStringLiteral("distrobox"));
    const QString podman = findExecutable(QStringLiteral("podman"));
    const QString engine = podman.isEmpty() ? findExecutable(QStringLiteral("docker")) : podman;
    if (distrobox.isEmpty())
        return errorResponse(QStringLiteral("distrobox is not installed."));
    if (engine.isEmpty())
        return errorResponse(QStringLiteral("podman or docker is not installed."));

    QByteArray listOutput;
    QString error;
    if (!runCommand(distrobox,
                    {QStringLiteral("list"), QStringLiteral("--root"), QStringLiteral("--no-color")},
                    listOutput,
                    error))
        return errorResponse(error);

    QStringList names;
    for (const QByteArray &line : listOutput.split(char(10))) {
        const QStringList fields = QString::fromLocal8Bit(line).trimmed().split(QChar(124));
        if (fields.size() < 4)
            continue;

        const QString name = fields.at(1).trimmed();
        if (validContainerName(name) && !names.contains(name))
            names.append(name);
    }

    for (const QString &name : std::as_const(names)) {
        const QString launcherPath = rootfulLauncherPath(name);
        if (launcherPath.isEmpty() || QFileInfo(launcherPath).isFile())
            continue;

        QString entryError;
        if (!generateRootfulEntry(name, entryError) && !entryError.isEmpty())
            fprintf(stderr, "Warning: Could not generate the rootful Distrobox entry: %s\n", entryError.toLocal8Bit().constData());
    }

    QByteArray inspectOutput;
    QByteArray infoOutput;
    if (!names.isEmpty()) {
        QStringList inspectArguments {QStringLiteral("container"), QStringLiteral("inspect"), QStringLiteral("--size")};
        inspectArguments.append(names);
        QString ignoredError;
        runCommand(engine, inspectArguments, inspectOutput, ignoredError);
    }

    QString ignoredError;
    runCommand(engine,
               {QStringLiteral("info"), QStringLiteral("--format"), QStringLiteral("json")},
               infoOutput,
               ignoredError);

    QJsonObject response;
    response.insert(QStringLiteral("list"), QString::fromLocal8Bit(listOutput));
    response.insert(QStringLiteral("inspect"), QString::fromLocal8Bit(inspectOutput));
    response.insert(QStringLiteral("info"), QString::fromLocal8Bit(infoOutput));
    response.insert(QStringLiteral("launcherIcons"), rootfulLauncherIcons(names));
    return QJsonDocument(response).toJson(QJsonDocument::Compact);
}

bool runRootfulAction(const QStringList &arguments, QString &error)
{
    if (arguments.isEmpty()) {
        error = QStringLiteral("No rootful container operation was specified.");
        return false;
    }

    const QString action = arguments.constFirst();
    if (action == QLatin1String("make-rshared")) {
        if (arguments.size() != 1) {
            error = QStringLiteral("Invalid mount propagation operation.");
            return false;
        }
        return makeRootShared(error);
    }
    const QString distroboxCreate = findExecutable(QStringLiteral("distrobox-create"));
    const QString distrobox = findExecutable(QStringLiteral("distrobox"));
    const QString podman = findExecutable(QStringLiteral("podman"));
    const QString engine = podman.isEmpty() ? findExecutable(QStringLiteral("docker")) : podman;
    if (engine.isEmpty()) {
        error = QStringLiteral("podman or docker is not installed.");
        return false;
    }

    const auto validNameArgument = [&arguments, &error](int index) {
        if (index >= arguments.size() || !validContainerName(arguments.at(index))) {
            error = QStringLiteral("Invalid Distrobox name.");
            return false;
        }
        return true;
    };

    if (action == QLatin1String("create")) {
        if (distroboxCreate.isEmpty() || arguments.size() < 3 || arguments.size() > 4
            || !validNameArgument(1) || arguments.at(2).isEmpty() || arguments.at(2).startsWith(QLatin1Char(45))
            || (arguments.size() == 4 && arguments.at(3).startsWith(QLatin1Char(45)))) {
            if (error.isEmpty())
                error = QStringLiteral("Invalid rootful container details.");
            return false;
        }

        QStringList createArguments {
            QStringLiteral("--yes"),
            QStringLiteral("--root"),
            QStringLiteral("--name"),
            arguments.at(1),
            QStringLiteral("--image"),
            arguments.at(2)
        };
        if (arguments.size() == 4)
            createArguments << QStringLiteral("--home") << arguments.at(3);
        if (!runAndForward(distroboxCreate, createArguments, error, LongCommandTimeoutMs))
            return false;

        QString entryError;
        if (!generateRootfulEntry(arguments.at(1), entryError))
            fprintf(stderr, "Warning: Could not generate the rootful Distrobox entry: %s\n", entryError.toLocal8Bit().constData());
        return true;
    }

    if (action == QLatin1String("clone")) {
        if (distroboxCreate.isEmpty() || arguments.size() != 3
            || !validNameArgument(1) || !validNameArgument(2))
            return false;

        if (!runAndForward(distroboxCreate,
                           {QStringLiteral("--yes"), QStringLiteral("--root"), QStringLiteral("--clone"), arguments.at(1),
                            QStringLiteral("--name"), arguments.at(2)},
                           error, LongCommandTimeoutMs))
            return false;

        QString entryError;
        if (!generateRootfulEntry(arguments.at(2), entryError))
            fprintf(stderr, "Warning: Could not generate the rootful Distrobox entry: %s\n", entryError.toLocal8Bit().constData());
        return true;
    }

    if (action == QLatin1String("start")) {
        if (arguments.size() != 2 || !validNameArgument(1))
            return false;

        if (!makeRootShared(error))
            return false;

        return runAndForward(engine, {QStringLiteral("container"), QStringLiteral("start"), arguments.at(1)}, error);
    }

    if (action == QLatin1String("repair")) {
        if (arguments.size() != 2 || !validNameArgument(1))
            return false;

        QByteArray runningOutput;
        if (!runCommand(engine,
                        {QStringLiteral("container"), QStringLiteral("inspect"), QStringLiteral("--format"),
                         QStringLiteral("{{.State.Running}}"), arguments.at(1)},
                        runningOutput,
                        error))
            return false;

        const bool wasRunning = QString::fromLocal8Bit(runningOutput).trimmed() == QLatin1String("true");
        if (!wasRunning
            && !runAndForward(engine, {QStringLiteral("container"), QStringLiteral("start"), arguments.at(1)}, error))
            return false;

        const QStringList sudoRepairArguments {
            QStringLiteral("container"), QStringLiteral("exec"), QStringLiteral("--user"), QStringLiteral("0"),
            arguments.at(1), QStringLiteral("chown"), QStringLiteral("0:0"), QStringLiteral("/etc/sudo.conf"),
            QStringLiteral("/usr/bin/sudo")
        };
        if (!runAndForward(engine, sudoRepairArguments, error))
            return false;

        const QStringList modeRepairArguments {
            QStringLiteral("container"), QStringLiteral("exec"), QStringLiteral("--user"), QStringLiteral("0"),
            arguments.at(1), QStringLiteral("chmod"), QStringLiteral("4755"), QStringLiteral("/usr/bin/sudo")
        };
        if (!runAndForward(engine, modeRepairArguments, error))
            return false;

        QByteArray cacheOutput;
        const QStringList cacheCheckArguments {
            QStringLiteral("container"), QStringLiteral("exec"), QStringLiteral("--user"), QStringLiteral("0"),
            arguments.at(1), QStringLiteral("test"), QStringLiteral("-d"), QStringLiteral("/var/cache/man")
        };
        if (runCommand(engine, cacheCheckArguments, cacheOutput, error)) {
            const QStringList cacheOwnerArguments {
                QStringLiteral("container"), QStringLiteral("exec"), QStringLiteral("--user"), QStringLiteral("0"),
                arguments.at(1), QStringLiteral("chown"), QStringLiteral("-R"), QStringLiteral("man:man"),
                QStringLiteral("/var/cache/man")
            };
            if (!runAndForward(engine, cacheOwnerArguments, error))
                return false;

            const QStringList cacheModeArguments {
                QStringLiteral("container"), QStringLiteral("exec"), QStringLiteral("--user"), QStringLiteral("0"),
                arguments.at(1), QStringLiteral("chmod"), QStringLiteral("-R"), QStringLiteral("u+rwX"),
                QStringLiteral("/var/cache/man")
            };
            if (!runAndForward(engine, cacheModeArguments, error))
                return false;
        }

        if (!wasRunning
            && !runAndForward(engine, {QStringLiteral("container"), QStringLiteral("stop"), arguments.at(1)}, error))
            return false;
        return true;
    }

    if (action == QLatin1String("stop") || action == QLatin1String("remove")) {
        if (arguments.size() != 2 || !validNameArgument(1))
            return false;

        const QString subcommand = action == QLatin1String("stop") ? QStringLiteral("kill") : QStringLiteral("rm");
        return runAndForward(engine, {QStringLiteral("container"), subcommand, arguments.at(1)}, error);
    }

    if (action == QLatin1String("stop-all") || action == QLatin1String("remove-all")) {
        if (arguments.size() < 2)
            return false;

        for (int index = 1; index < arguments.size(); ++index) {
            if (!validNameArgument(index))
                return false;
        }

        QStringList commandArguments {
            QStringLiteral("container"),
            action == QLatin1String("stop-all") ? QStringLiteral("stop") : QStringLiteral("rm")
        };
        if (action == QLatin1String("remove-all"))
            commandArguments.append(QStringLiteral("--force"));
        commandArguments.append(arguments.mid(1));
        return runAndForward(engine, commandArguments, error);
    }

    if (action == QLatin1String("list-rootful")) {
        error = QStringLiteral("The inventory operation must be requested separately.");
        return false;
    }

    if (distrobox.isEmpty())
        error = QStringLiteral("distrobox is not installed.");
    else
        error = QStringLiteral("Unsupported rootful container operation.");
    return false;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication application(argc, argv);
    const QStringList arguments = application.arguments().mid(1);
    if (arguments.size() == 1 && arguments.constFirst() == QLatin1String("list-rootful")) {
        const QByteArray response = rootfulSnapshot();
        writeOutput(response);
        fputc(10, stdout);
        return 0;
    }

    QString error;
    if (!runRootfulAction(arguments, error)) {
        if (!error.isEmpty())
            fprintf(stderr, "%s\n", error.toLocal8Bit().constData());
        return 1;
    }
    return 0;
}
