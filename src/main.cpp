/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QApplication>
#include <cstdlib>
#include <QCoreApplication>
#include <QDate>
#include <QIcon>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkRequest>
#include <QQmlApplicationEngine>
#include <QQmlNetworkAccessManagerFactory>
#include <QSurfaceFormat>
#include <QStandardPaths>
#include <QUrl>
#include <QQmlContext>

#include <MauiKit4/Core/mauiapp.h>
#include <KAboutData>
#include <KLocalizedString>
#include <KLocalizedContext>

#include "controllers/apphubbackend.h"

namespace {

class CachedNetworkAccessManager final : public QNetworkAccessManager
{
public:
    explicit CachedNetworkAccessManager(QObject *parent = nullptr)
        : QNetworkAccessManager(parent)
    {
        auto *diskCache = new QNetworkDiskCache(this);
        diskCache->setCacheDirectory(QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                                     + QStringLiteral("/qml-network"));
        setCache(diskCache);
    }

protected:
    QNetworkReply *createRequest(Operation operation,
                                 const QNetworkRequest &request,
                                 QIODevice *outgoingData = nullptr) override
    {
        QNetworkRequest cachedRequest(request);
        const QUrl url = cachedRequest.url();
        if (operation == GetOperation
            && (url.scheme() == QLatin1String("http") || url.scheme() == QLatin1String("https"))
            && url.path().contains(QLatin1String("/screenshots/"))) {
            cachedRequest.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                                       QNetworkRequest::PreferCache);
            cachedRequest.setAttribute(QNetworkRequest::CacheSaveControlAttribute, true);
        }

        return QNetworkAccessManager::createRequest(operation, cachedRequest, outgoingData);
    }
};

class CachedNetworkAccessManagerFactory final : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        return new CachedNetworkAccessManager(parent);
    }
};

bool portalDesktopFileIsAvailable()
{
    return !QStandardPaths::locate(QStandardPaths::ApplicationsLocation,
                                   QStringLiteral("org.nitrux.appfinder.desktop"))
                .isEmpty();
}

} // namespace

int main(int argc, char *argv[])
{
    // The host portal requires the matching installed desktop entry.
    if (!portalDesktopFileIsAvailable())
        qputenv("QT_NO_XDG_DESKTOP_PORTAL", "1");

    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    QApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("appfinder"));
    application.setDesktopFileName(QStringLiteral("org.nitrux.appfinder"));
    application.setOrganizationName(QStringLiteral("Nitrux"));
    application.setWindowIcon(QIcon::fromTheme(QStringLiteral("application-x-iso9660-appimage")));

    KLocalizedString::setApplicationDomain(QByteArrayLiteral("appfinder"));

    KAboutData about(QStringLiteral("appfinder"),
                     i18n("AppFinder"),
                     QStringLiteral("0.1.0"),
                     i18n("Software management for Nitrux."),
                     KAboutLicense::BSD_3_Clause,
                     i18n("© %1 Made by Nitrux | Built with MauiKit", QString::number(QDate::currentDate().year())),
                     QString(GIT_BRANCH) + "/" + QString(GIT_COMMIT_HASH));
    about.addAuthor(QStringLiteral("Uri Herrera"), i18n("Developer"), QStringLiteral("uri_herrera@nxos.org"));
    about.setHomepage(QStringLiteral("https://nxos.org"));
    about.setProductName(QByteArrayLiteral("nitrux/appfinder"));
    about.setBugAddress(QByteArrayLiteral("https://github.com/Nitrux/appfinder/issues"));
    about.setOrganizationDomain(QByteArrayLiteral("org.nitrux.appfinder"));
    about.setDesktopFileName(QByteArrayLiteral("org.nitrux.appfinder"));
    about.setProgramLogo(application.windowIcon());
    KAboutData::setApplicationData(about);

    MauiApp::instance()->setIconName(QStringLiteral("application-x-iso9660-appimage"));

    AppHubBackend backend;
    CachedNetworkAccessManagerFactory networkAccessManagerFactory;
    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(&networkAccessManagerFactory);
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("appHub"), &backend);
    const QUrl url(QStringLiteral("qrc:/org/nitrux/appfinder/qml/Main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return EXIT_FAILURE;

    return application.exec();
}
                     QString(GIT_BRANCH) + "/" + QString(GIT_COMMIT_HASH));
