/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.Page {
    id: control

    property string selectedCategory: ""

    background: null
    headBar.visible: false

    function categoryMatches(category, type) {
        if (selectedCategory.length === 0)
            return true

        const value = (String(category) + " " + String(type)).toLowerCase()
        switch (selectedCategory) {
        case qsTr("Wayland Compositors"):
            return value.indexOf("wayland") >= 0 || value.indexOf("compositor") >= 0
        case qsTr("CLI Tools"):
            return value.indexOf("cli") >= 0 || value.indexOf("command") >= 0 || value.indexOf("terminal") >= 0
        case qsTr("System Components"):
            return value.indexOf("system") >= 0 || value.indexOf("component") >= 0
        case qsTr("Themes"):
            return value.indexOf("theme") >= 0 || value.indexOf("appearance") >= 0
        }
        return true
    }

    Maui.InfoDialog {
        id: detailsDialog
        title: qsTr("Build Details")
        message: appHub.operationLog.length > 0 ? appHub.operationLog : qsTr("No build output is available yet.")
        standardButtons: Dialog.Close
        template.iconSource: "utilities-terminal"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Maui.Style.contentMargins
        spacing: Maui.Style.space.small

        RowLayout {
            Layout.fillWidth: true

            Maui.SectionHeader {
                Layout.fillWidth: true
                padding: 0
                text1: qsTr("NX AppHub")
                text2: qsTr("Build AppBoxes that extend the Nitrux host system.")
                label2.wrapMode: Text.Wrap
            }

            ToolButton {
                text: qsTr("Refresh Repo")
                icon.name: "repository-update"
                display: ToolButton.TextBesideIcon
                enabled: !appHub.busy
                ToolTip.visible: hovered
                ToolTip.text: qsTr("Refresh NX AppHub repository")
                onClicked: appHub.refreshAppHubRepository()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: categoriesLayout.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: categoriesLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Categories")
                    text2: qsTr("Filter extensions by their purpose.")
                    label2.wrapMode: Text.Wrap
                }

                Flow {
            Layout.fillWidth: true
            spacing: Maui.Style.space.small

            Maui.Chip {
                text: qsTr("Wayland Compositors")
                icon.name: "preferences-desktop-display"
                checkable: false
                checked: control.selectedCategory === text
                onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
            }
            Maui.Chip {
                text: qsTr("CLI Tools")
                icon.name: "utilities-terminal"
                checkable: false
                checked: control.selectedCategory === text
                onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
            }
            Maui.Chip {
                text: qsTr("System Components")
                icon.name: "preferences-system"
                checkable: false
                checked: control.selectedCategory === text
                onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
            }
            Maui.Chip {
                text: qsTr("Themes")
                icon.name: "preferences-desktop-theme"
                checkable: false
                checked: control.selectedCategory === text
                onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
            }
        }
            }
        }

        Maui.ListBrowser {
            id: extensionsBrowser
            padding: 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: appHub.appHubModel
            spacing: Maui.Style.space.small
            holder.visible: count === 0
            holder.title: qsTr("NX AppHub builds AppBoxes")
            holder.body: qsTr("Refresh the repository or search for software that does not fit the Flatpak or Distrobox roles.")

            delegate: Item {
                id: extensionCard
                width: ListView.view.width
                height: categoryVisible ? 182 : 0
                visible: categoryVisible
                property bool categoryVisible: control.categoryMatches(model.category, model.type)
                property bool installed: model.status === "Active Extension" || model.actionText === "Remove"

                Rectangle {
                    anchors.fill: parent
                    radius: Maui.Style.radiusV
                    color: Maui.Theme.alternateBackgroundColor
                    border.color: Maui.Theme.backgroundColor
                }

                Maui.IconItem {
                    id: extensionIcon
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Maui.Style.space.medium
                    anchors.topMargin: Maui.Style.space.medium
                    width: 56
                    height: 56
                    iconSizeHint: 56
                    iconSource: model.icon
                }

                ColumnLayout {
                    anchors.left: extensionIcon.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Maui.Style.space.medium
                    anchors.rightMargin: Maui.Style.space.medium
                    anchors.topMargin: Maui.Style.space.medium
                    spacing: Maui.Style.space.small

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: model.name
                            font: Maui.Style.h2Font
                            elide: Text.ElideRight
                        }
                        Maui.Chip {
                            text: model.status.length > 0 ? model.status : qsTr("Not Built")
                            color: extensionCard.installed ? Maui.Theme.positiveBackgroundColor : Maui.Theme.neutralBackgroundColor
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Type: %1").arg(model.type.length > 0 ? model.type : model.category)
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: model.description.length > 0 ? model.description : model.summary
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        visible: model.integration.length > 0
                        text: qsTr("Integration: %1").arg(model.integration)
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: Maui.Style.space.medium
                    anchors.bottomMargin: Maui.Style.space.medium
                    spacing: Maui.Style.space.small

                    ToolButton {
                        text: extensionCard.installed ? qsTr("Rebuild") : qsTr("Build & Deploy AppBox")
                        icon.name: extensionCard.installed ? "view-refresh" : "run-build"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: extensionCard.installed ? appHub.rebuildAppHub(model.identifier) : appHub.appHubAction(model.identifier)
                    }

                    ToolButton {
                        visible: extensionCard.installed
                        text: qsTr("Remove")
                        icon.name: "edit-delete"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: appHub.appHubAction(model.identifier)
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: queueLayout.implicitHeight + Maui.Style.contentMargins * 2
            radius: Maui.Style.radiusV
            color: Maui.Theme.alternateBackgroundColor
            border.color: Maui.Theme.backgroundColor
            border.width: 1

            ColumnLayout {
                id: queueLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Build Queue")
                    text2: qsTr("Monitor source operations and inspect their output.")
                    label2.wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: appHub.busy ? appHub.statusMessage : qsTr("No active builds")
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                    ToolButton {
                        text: qsTr("Details")
                        icon.name: "utilities-terminal"
                        display: ToolButton.TextBesideIcon
                        enabled: appHub.operationLog.length > 0
                        onClicked: detailsDialog.open()
                    }
                }

                Maui.ProgressIndicator {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: appHub.busy ? 0.8 : 0
                    indeterminate: appHub.busy
                }
            }
        }
    }
}
