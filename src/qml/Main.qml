/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ApplicationWindow {
    id: root

    title: currentTitle
    color: "transparent"
    background: null

    property int currentSection: 0
    property string searchText: ""
    property bool suppressStartupNotification: false
    readonly property alias appSettings: settings

    Settings {
        id: settings
        category: "AppFinder"
        property bool sidebarVisible: true
        property bool refreshOnStartup: true
        property bool showOperationNotifications: true
        property bool startInInstalledView: false
    }

    readonly property string currentTitle: currentSection === 0 ? qsTr("Flathub")
                                           : currentSection === 1 ? qsTr("NX AppHub")
                                           : currentSection === 2 ? qsTr("Distrobox")
                                           : currentSection === 3 ? qsTr("Updates")
                                                                   : qsTr("Settings")

    function selectSection(section) {
        if (section === 4) {
            openSettingsDialog()
            return
        }

        currentSection = section
        if (section <= 2)
            appHub.currentSection = section
        if (sidebar.sideBar.collapsed)
            sidebar.sideBar.close()
    }

    function openSettingsDialog() {
        const dialog = settingsDialogComponent.createObject(root)
        dialog.open()
    }

    function submitSearch() {
        if (root.currentSection <= 2)
            appHub.search(root.searchText)
    }

    Component.onCompleted: {
        if (settings.refreshOnStartup) {
            suppressStartupNotification = true
            appHub.refresh()
            suppressStartupNotification = false
        }
    }

    Maui.WindowBlur {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    Rectangle {
        anchors.fill: parent
        color: Maui.Theme.backgroundColor
        opacity: 0.76
        radius: Maui.Style.radiusV
    }

    Maui.SideBarView {
        id: sidebar
        anchors.fill: parent
        sideBar.preferredWidth: Maui.Style.units.gridUnit * 12
        sideBar.minimumWidth: Maui.Style.units.gridUnit * 12
        sideBar.autoShow: settings.sidebarVisible
        sideBar.autoHide: true
        sideBar.floats: sideBar.collapsed
        background: null
        Maui.Theme.colorSet: Maui.Theme.View

        sideBarContent: Item {
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            anchors.rightMargin: 0

            NavigationSidebar {
                anchors.fill: parent
                anchors.rightMargin: 0
                currentSection: root.currentSection
                onSectionSelected: function(section) { root.selectSection(section) }
            }
        }

        Connections {
            target: sidebar.sideBar
            function onOpened() { settings.sidebarVisible = true }
            function onClosed() { settings.sidebarVisible = false }
        }

        Maui.PageLayout {
            id: page
            anchors.fill: parent
            clip: true
            background: null

            split: false
            splitIn: ToolBar.Header
            altHeader: Maui.Handy.isMobile
            Maui.Controls.showCSD: true

            headBar.visible: true
            headBar.forceCenterMiddleContent: false
            headerMargins: Maui.Handy.isMobile ? 0 : Maui.Style.contentMargins
            footerMargins: headerMargins

            Maui.Theme.colorSet: Maui.Theme.View

            headBar.leftContent: [
                ToolButton {
                    text: qsTr("Toggle Sidebar")
                    display: AbstractButton.IconOnly
                    checkable: true
                    icon.name: sidebar.sideBar.visible ? "sidebar-collapse" : "sidebar-expand"
                    checked: sidebar.sideBar.visible
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Toggle navigation")
                    onClicked: sidebar.sideBar.toggle()
                },

                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
                }
            ]

            headBar.middleContent: Maui.SearchField {
                id: globalSearch
                Layout.preferredWidth: Maui.Style.units.gridUnit * 18
                Layout.maximumWidth: Maui.Style.units.gridUnit * 26
                Layout.alignment: Qt.AlignCenter
                visible: root.currentSection <= 2
                enabled: visible
                placeholderText: qsTr("Search %1").arg(root.currentTitle)
                text: root.searchText

                onTextChanged: {
                    root.searchText = text
                    searchTimer.restart()
                }
                onAccepted: {
                    searchTimer.stop()
                    root.submitSearch()
                }
                onCleared: {
                    root.searchText = ""
                    searchTimer.stop()
                    root.submitSearch()
                }
            }

            headBar.rightContent: [
                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
                },

                ToolButton {
                    visible: root.currentSection === 0 && contentLoader.item !== null
                    text: root.currentSection === 0 && contentLoader.item && contentLoader.item.installedView ? qsTr("Explore Flathub") : qsTr("Installed applications")
                    display: AbstractButton.IconOnly
                    checkable: true
                    checked: root.currentSection === 0 && contentLoader.item && contentLoader.item.installedView
                    icon.name: checked ? "go-home" : "view-list-details"
                    ToolTip.visible: hovered
                    ToolTip.text: text
                    onClicked: {
                        root.searchText = ""
                        if (contentLoader.item) {
                            const nextView = !contentLoader.item.installedView
                            contentLoader.item.installedView = nextView
                            settings.startInInstalledView = nextView
                        }
                    }
                },

                Maui.ToolButtonMenu {
                icon.name: "overflow-menu"
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Menu")

                MenuItem {
                    text: qsTr("Settings")
                    icon.name: "settings-configure"
                    onTriggered: root.selectSection(4)
                }

                MenuSeparator {}

                MenuItem {
                    text: qsTr("About")
                    icon.name: "documentinfo"
                    onTriggered: Maui.App.aboutDialog()
                }
                }
            ]

            Loader {
                id: contentLoader
                anchors.fill: parent
                sourceComponent: root.currentSection === 0 ? flathubPage
                                 : root.currentSection === 1 ? appHubPage
                                 : root.currentSection === 2 ? distroboxPage
                                                              : updatesPage
            }
        }
    }

    Maui.Notification {
        id: statusNotification
        iconName: "dialog-information"
        title: qsTr("AppFinder")
        message: appHub.statusMessage
    }

    Connections {
        target: appHub
        function onStatusMessageChanged() {
            if (root.suppressStartupNotification)
                return
            if (settings.showOperationNotifications && appHub.statusMessage.length > 0)
                statusNotification.dispatch()
        }
    }

    Timer {
        id: searchTimer
        interval: 250
        repeat: false
        onTriggered: root.submitSearch()
    }

    Component {
        id: flathubPage
        FlathubPage {
            query: root.searchText
            initialInstalledView: settings.startInInstalledView
            onViewModeChanged: settings.startInInstalledView = installed
        }
    }

    Component {
        id: settingsDialogComponent
        SettingsDialog {
            appSettings: root.appSettings
            onClosed: destroy()
        }
    }

    Component {
        id: appHubPage
        AppHubPage {}
    }

    Component {
        id: distroboxPage
        DistroboxPage {
            onCreateContainerRequested: createDialog.open()
            onCloneRequested: function(source) {
                cloneDialog.sourceName = source
                cloneDialog.open()
            }
        }
    }

    Component {
        id: updatesPage
        Maui.Page {
            background: null
            headBar.visible: false
            Maui.Holder {
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                emoji: "system-software-update"
                title: qsTr("Updates available")
                body: qsTr("Three software updates are ready to review. Update details will appear here when the update service is available.")
            }
        }
    }

    Maui.InfoDialog {
        id: createDialog
        title: qsTr("New Container")
        message: qsTr("Create a development sandbox with Distrobox.")
        standardButtons: Dialog.Ok | Dialog.Cancel

        Maui.TextField {
            id: containerNameField
            Layout.fillWidth: true
            placeholderText: qsTr("Container name")
        }

        Maui.TextField {
            id: containerImageField
            Layout.fillWidth: true
            placeholderText: qsTr("Base image (for example, ubuntu:24.04)")
            text: "ubuntu:24.04"
        }

        Maui.TextField {
            id: containerHomeField
            Layout.fillWidth: true
            placeholderText: qsTr("Custom home directory (optional)")
        }

        onAccepted: {
            appHub.createDistrobox(containerNameField.text, containerImageField.text, containerHomeField.text)
            containerNameField.clear()
            containerHomeField.clear()
            close()
        }
        onRejected: close()
    }

    Maui.InputDialog {
        id: cloneDialog
        property string sourceName: ""
        title: qsTr("Clone Container")
        message: qsTr("Choose a name for the cloned Distrobox container.")
        textEntry.placeholderText: qsTr("New container name")
        onFinished: function(text) {
            appHub.cloneDistrobox(sourceName, text)
        }
    }
}
