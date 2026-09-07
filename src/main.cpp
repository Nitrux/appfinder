/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

#include <QApplication>
#include <cstdlib>
#include <QCoreApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QUrl>
#include <QQmlContext>

#include <MauiKit4/Core/mauiapp.h>

#include "controllers/apphubbackend.h"

int main(int argc, char *argv[])
{
    QApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("appfinder"));
    application.setOrganizationName(QStringLiteral("Nitrux"));
    application.setWindowIcon(QIcon::fromTheme(QStringLiteral("application-x-iso9660-appimage")));

    MauiApp::instance()->setIconName(QStringLiteral("application-x-iso9660-appimage"));

    AppHubBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("appHub"), &backend);
    const QUrl url(QStringLiteral("qrc:/org/nitrux/appfinder/qml/Main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty())
        return EXIT_FAILURE;

    return application.exec();
}
