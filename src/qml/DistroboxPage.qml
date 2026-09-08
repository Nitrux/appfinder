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

    signal createContainerRequested()
    signal cloneRequested(string source)

    background: null
    headBar.visible: false

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Maui.Style.contentMargins
        spacing: Maui.Style.space.medium

        RowLayout {
            Layout.fillWidth: true

            Maui.SectionHeader {
                Layout.fillWidth: true
                padding: 0
                text1: qsTr("Distrobox")
                text2: qsTr("Manage isolated development environments and their lifecycles.")
                label2.wrapMode: Text.Wrap
            }

            ToolButton {
                text: qsTr("New Container")
                icon.name: "list-add"
                display: ToolButton.TextBesideIcon
                enabled: !appHub.busy
                onClicked: control.createContainerRequested()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: containersLayout.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: containersLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Active Containers")
                    text2: qsTr("Manage isolated development environments and their lifecycles.")
                    label2.wrapMode: Text.Wrap
                }

                Maui.ListBrowser {
                    id: containersBrowser
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: appHub.distroboxModel
            spacing: Maui.Style.space.medium
            holder.visible: count === 0
            holder.title: qsTr("No Distrobox containers")
            holder.body: qsTr("Create a development sandbox to manage it from this dashboard.")

            delegate: Item {
                id: containerCard
                width: ListView.view.width
                height: 214
                property bool running: {
                    const value = String(model.status).toLowerCase()
                    return value.indexOf("up") >= 0 || value.indexOf("running") >= 0
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Maui.Style.radiusV
                    color: Maui.Theme.alternateBackgroundColor
                    border.color: Maui.Theme.backgroundColor
                }

                Maui.IconItem {
                    id: containerIcon
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Maui.Style.space.medium
                    anchors.topMargin: Maui.Style.space.medium
                    width: 58
                    height: 58
                    iconSizeHint: 58
                    iconSource: model.icon
                }

                ColumnLayout {
                    anchors.left: containerIcon.right
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
                            text: containerCard.running ? qsTr("RUNNING") : qsTr("STOPPED")
                            color: containerCard.running ? Maui.Theme.positiveBackgroundColor : Maui.Theme.neutralBackgroundColor
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Base: %1").arg(model.baseImage.length > 0 ? model.baseImage : qsTr("Unavailable"))
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Created: %1").arg(model.created.length > 0 ? model.created : qsTr("Unavailable"))
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Integrated Apps: %1").arg(model.integratedApps.length > 0 ? model.integratedApps : "0")
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Maui.Style.space.medium
                    anchors.rightMargin: Maui.Style.space.medium
                    anchors.bottomMargin: Maui.Style.space.medium
                    spacing: Maui.Style.space.small

                    ToolButton {
                        text: containerCard.running ? qsTr("Open Terminal") : qsTr("Start Container")
                        icon.name: containerCard.running ? "utilities-terminal" : "media-playback-start"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: containerCard.running ? appHub.enterDistrobox(model.name) : appHub.startDistrobox(model.name)
                    }

                    ToolButton {
                        visible: containerCard.running
                        text: qsTr("Stop Container")
                        icon.name: "media-playback-stop"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: appHub.stopDistrobox(model.name)
                    }

                    Item { Layout.fillWidth: true }

                    ToolButton {
                        text: qsTr("Clone")
                        icon.name: "edit-copy"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: control.cloneRequested(model.name)
                    }

                    ToolButton {
                        text: qsTr("Delete")
                        icon.name: "edit-delete"
                        display: ToolButton.TextBesideIcon
                        enabled: !appHub.busy
                        onClicked: appHub.removeDistrobox(model.name)
                    }
                }
            }
        }
    }
}

    }
}