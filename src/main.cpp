/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QApplication>
#include <cstdlib>
#include <QCoreApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QSurfaceFormat>
#include <QUrl>
#include <QQmlContext>

#include <MauiKit4/Core/mauiapp.h>
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
