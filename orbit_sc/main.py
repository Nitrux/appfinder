#!/usr/bin/env python3

# SPDX-License-Identifier: BSD-3-Clause
# Copyright 2024-2025 <Nitrux Latinoamericana S.C. <hello@nxos.org>>

import sys
from pathlib import Path
from PySide6.QtCore import QUrl, QObject, Slot, QAbstractListModel, Qt, QModelIndex
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

from nx_apphub_cli.manager import get_search_results


class AppListModel(QAbstractListModel):
    NAME_ROLE = Qt.UserRole + 1
    VERSION_ROLE = Qt.UserRole + 2
    ARCH_ROLE = Qt.UserRole + 3

    def __init__(self, apps=None):
        super().__init__()
        self._apps = apps or []

    def data(self, index, role):
        if not index.isValid():
            return None

        app = self._apps[index.row()]

        if role == self.NAME_ROLE:
            return app.get("name")
        elif role == self.VERSION_ROLE:
            return app.get("version")
        elif role == self.ARCH_ROLE:
            return app.get("arch")

        return None

    def roleNames(self):
        return {
            self.NAME_ROLE: b"name",
            self.VERSION_ROLE: b"version",
            self.ARCH_ROLE: b"arch"
        }

    def rowCount(self, parent=QModelIndex()):
        return len(self._apps)

    def update(self, new_list):
        self.beginResetModel()
        self._apps = new_list
        self.endResetModel()


class AppHubBackend(QObject):
    def __init__(self, search_model, installed_model):
        super().__init__()
        self.search_model = search_model
        self.installed_model = installed_model

    @Slot(str)
    def search_app(self, app_name):
        result_dicts = get_search_results([app_name])
        self.search_model.update(result_dicts)

    @Slot(str)
    def install_app(self, app_name):
        print(f"Installing {app_name}...")
        for app in self.search_model._apps:
            if app["name"] == app_name:
                installed = self.installed_model._apps.copy()
                installed.append(app)
                self.installed_model.update(installed)
                break


if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    search_model = AppListModel()
    installed_model = AppListModel()
    backend = AppHubBackend(search_model, installed_model)

    engine.rootContext().setContextProperty("AppHub", backend)
    engine.rootContext().setContextProperty("appListModel", search_model)
    engine.rootContext().setContextProperty("installedAppListModel", installed_model)

    qml_file = Path(__file__).resolve().parent / "qml" / "AppComponents" / "AppWindow.qml"
    qml_import_path = Path(__file__).resolve().parent / "qml"
    engine.addImportPath(str(qml_import_path))

    print(f"📁 Added QML import path: {qml_import_path}")
    print(f"📄 Loading QML: {qml_file}")
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        sys.exit(-1)
    else:
        print("✅ GUI loaded successfully")

    sys.exit(app.exec())
