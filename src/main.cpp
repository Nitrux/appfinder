/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QApplication>
#include <cstdlib>
#include <QCoreApplication>
#include <QDate>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include <QUrl>
#include <QQmlContext>

#include <MauiKit4/Core/mauiapp.h>
#include <KAboutData>
#include <KLocalizedString>
#include <KLocalizedContext>

#include "controllers/apphubbackend.h"

int main(int argc, char *argv[])
{
    QSurfaceFormat format;
    format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);

    QApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("appfinder"));
    application.setOrganizationName(QStringLiteral("Nitrux"));
    application.setWindowIcon(QIcon::fromTheme(QStringLiteral("application-x-iso9660-appimage")));

    KLocalizedString::setApplicationDomain(QByteArrayLiteral("appfinder"));

    KAboutData about(QStringLiteral("appfinder"),
                     i18n("Appfinder"),
                     QStringLiteral("0.1.0"),
                     i18n("Software management for Nitrux."),
                     KAboutLicense::BSD_3_Clause,
                     i18n("© %1 Nitrux Latinoamericana S.C.", QString::number(QDate::currentDate().year())));
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
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextObject(new KLocalizedContext(&engine));
    engine.rootContext()->setContextProperty(QStringLiteral("appHub"), &backend);
    const QUrl url(QStringLiteral("qrc:/org/nitrux/appfinder/qml/Main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return EXIT_FAILURE;

    return application.exec();
}
