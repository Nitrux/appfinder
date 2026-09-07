/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ApplicationWindow {
    id: root

    title: currentSection === 0 ? qsTr("Flathub")
                                : currentSection === 1 ? qsTr("NX AppHub")
                                                        : qsTr("Distrobox")
    color: Maui.Theme.backgroundColor

    property int currentSection: 0
    property string searchText

    function selectSection(section) {
        currentSection = section
        appHub.currentSection = section
    }

    Component.onCompleted: appHub.refresh()

    Maui.Page {
        id: page
        anchors.fill: parent
        title: root.title

        headBar.leftContent: [
            Maui.ToolButton {
                icon.name: "applications-internet"
                checked: root.currentSection === 0
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Flathub")
                onClicked: root.selectSection(0)
            },
            Maui.ToolButton {
                icon.name: "application-x-iso9660-appimage"
                checked: root.currentSection === 1
                ToolTip.visible: hovered
                ToolTip.text: qsTr("NX AppHub")
                onClicked: root.selectSection(1)
            },
            Maui.ToolButton {
                icon.name: "utilities-terminal"
                checked: root.currentSection === 2
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Distrobox")
                onClicked: root.selectSection(2)
            }
        ]

        headBar.middleContent: Maui.SearchField {
            Layout.fillWidth: true
            Layout.maximumWidth: Maui.Style.units.gridUnit * 32
            placeholderText: root.currentSection === 0 ? qsTr("Search Flathub")
                                                         : root.currentSection === 1 ? qsTr("Search NX AppHub")
                                                                                       : qsTr("Filter containers")
            onAccepted: {
                root.searchText = text
                appHub.search(text)
            }
            onCleared: {
                root.searchText = ""
                appHub.search("")
            }
        }

        headBar.rightContent: [
            Maui.ToolButton {
                icon.name: "view-refresh"
                enabled: !appHub.busy
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Refresh sources")
                onClicked: appHub.refresh()
            },
            Maui.ToolButton {
                visible: root.currentSection === 1
                icon.name: "repository-update"
                enabled: !appHub.busy
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Refresh NX AppHub repository")
                onClicked: appHub.refreshAppHubRepository()
            }
        ]

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.currentSection === 0 ? flathubPage
                             : root.currentSection === 1 ? appHubPage
                                                          : distroboxPage
        }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Maui.Style.contentMargins
            visible: appHub.statusMessage.length > 0
            text: appHub.statusMessage
            color: Maui.Theme.disabledTextColor
            elide: Text.ElideRight
        }
    }

    Component {
        id: flathubPage
        SourcePage {
            sourceModel: appHub.flathubModel
            emptyTitle: qsTr("Search Flathub")
            emptyBody: qsTr("Search Flathub for desktop applications and install them as Flatpaks.")
            actionHandler: function(identifier, actionText) {
                if (actionText === "Remove")
                    appHub.removeFlatpak(identifier)
                else
                    appHub.installFlatpak(identifier)
            }
        }
    }

    Component {
        id: appHubPage
        SourcePage {
            sourceModel: appHub.appHubModel
            emptyTitle: qsTr("NX AppHub builds AppBoxes")
            emptyBody: qsTr("Search the NX AppHub Apps metadata repository for software that does not fit the Flatpak or Distrobox roles.")
            actionHandler: function(identifier) { appHub.appHubAction(identifier) }
        }
    }

    Component {
        id: distroboxPage
        SourcePage {
            sourceModel: appHub.distroboxModel
            emptyTitle: qsTr("No Distrobox containers")
            emptyBody: qsTr("Distrobox containers are development sandboxes. Create them with Distrobox, then refresh this view to keep track of them.")
            actionHandler: function(identifier) { appHub.enterDistrobox(identifier) }
        }
    }
}
