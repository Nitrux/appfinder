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

    property string query: ""
    readonly property bool searchActive: query.trim().length > 0
    property bool detailVisible: false
    property var detailItem: null

    function openDetails(item) {
        control.detailItem = item
        control.detailVisible = true
    }

    function closeDetails() {
        control.detailVisible = false
        control.detailItem = null
    }

    background: null
    headBar.visible: false

    SearchResultsView {
        anchors.fill: parent
        visible: control.searchActive && !control.detailVisible
        sourceModel: appHub.distroboxModel
        query: control.query
        sourceTitle: qsTr("Distrobox")
        sourceDescription: qsTr("Search development containers.")
        emptyTitle: qsTr("No Distrobox results")
        emptyBody: qsTr("Try a different container name or image.")
        busy: appHub.busy
        actionTextResolver: function(item) {
            const status = item && item.status ? String(item.status).toLowerCase() : ""
            return status.indexOf("up") >= 0 || status.indexOf("running") >= 0
                   ? qsTr("Open Terminal")
                   : qsTr("Start Container")
        }
        actionIconResolver: function(item) {
            const status = item && item.status ? String(item.status).toLowerCase() : ""
            return status.indexOf("up") >= 0 || status.indexOf("running") >= 0
                   ? "utilities-terminal"
                   : "media-playback-start"
        }
        actionHandler: function(identifier, item) {
            const status = item && item.status ? String(item.status).toLowerCase() : ""
            if (status.indexOf("up") >= 0 || status.indexOf("running") >= 0)
                appHub.enterDistrobox(identifier)
            else
                appHub.startDistrobox(identifier)
        }
        secondaryActionVisibleResolver: function(item) { return true }
        secondaryActionTextResolver: function(item) { return qsTr("Delete") }
        secondaryActionIconResolver: function(item) { return "edit-delete" }
        secondaryActionHandler: function(identifier, item) { appHub.removeDistrobox(identifier) }
        detailHandler: function(identifier, item) { control.openDetails(item) }
    }

    ColumnLayout {
        visible: !control.searchActive && !control.detailVisible
        anchors.fill: parent
        anchors.margins: Maui.Style.contentMargins
        spacing: Maui.Style.space.small

        RowLayout {
            Layout.fillWidth: true

            Maui.SectionHeader {
                Layout.fillWidth: true
                padding: 0
                text1: qsTr("Distrobox Containers")
                text2: qsTr("Manage isolated development environments and their lifecycles.")
                label2.wrapMode: Text.Wrap
            }

        }


        Maui.ListBrowser {
            id: containersBrowser
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 0
            model: appHub.distroboxModel
            spacing: Maui.Style.space.small
            holder.visible: count === 0
            holder.title: qsTr("No Distrobox containers")
            holder.body: qsTr("Create a development sandbox to manage it from this dashboard.")

            delegate: Item {
                id: containerCard
                width: ListView.view.width
                implicitHeight: cardLayout.implicitHeight + Maui.Style.contentMargins * 2
                height: implicitHeight
                property bool running: {
                    const value = String(model.status).toLowerCase()
                    return value.indexOf("up") >= 0 || value.indexOf("running") >= 0
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Maui.Style.radiusV
                    color: Maui.Theme.alternateBackgroundColor
                    border.color: Maui.Theme.backgroundColor
                    border.width: 1
                }

                RowLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.big

                    Maui.IconItem {
                        Layout.alignment: Qt.AlignTop
                        Layout.preferredWidth: Maui.Style.iconSizes.large
                        Layout.preferredHeight: Maui.Style.iconSizes.large
                        iconSizeHint: Maui.Style.iconSizes.large
                        iconSource: model.icon
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Maui.Style.space.medium

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Maui.Style.space.medium

                            Label {
                                Layout.fillWidth: true
                                text: model.name
                                font: Maui.Style.h2Font
                                elide: Text.ElideRight
                            }

                            Maui.Chip {
                                text: containerCard.running ? qsTr("Running") : qsTr("Stopped")
                                color: containerCard.running ? Maui.Theme.positiveBackgroundColor : Maui.Theme.backgroundColor
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Base image: %1").arg(model.baseImage.length > 0 ? model.baseImage : qsTr("Unavailable"))
                            color: Maui.Theme.disabledTextColor
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Maui.Style.space.medium
                            spacing: Maui.Style.space.medium

                            Button {
                                text: containerCard.running ? qsTr("Open Terminal") : qsTr("Start Container")
                                enabled: !appHub.busy
                                onClicked: containerCard.running ? appHub.enterDistrobox(model.name) : appHub.startDistrobox(model.name)
                            }

                            Button {
                                visible: containerCard.running
                                text: qsTr("Stop Container")
                                enabled: !appHub.busy
                                onClicked: appHub.stopDistrobox(model.name)
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: qsTr("Clone")
                                enabled: !appHub.busy
                                onClicked: control.cloneRequested(model.name)
                            }

                            Button {
                                text: qsTr("Delete")
                                enabled: !appHub.busy
                                onClicked: appHub.removeDistrobox(model.name)
                            }
                        }
                    }
                }
            }
        }
    }

    AppDetailsView {
        anchors.fill: parent
        visible: control.detailVisible
        z: 2
        itemData: control.detailItem
        sourceTitle: qsTr("Distrobox")
        busy: appHub.busy
        actionTextResolver: function(item) {
            const status = item && item.status ? String(item.status).toLowerCase() : ""
            return status.indexOf("up") >= 0 || status.indexOf("running") >= 0
                   ? qsTr("Open Terminal")
                   : qsTr("Start Container")
        }
        actionHandler: function(identifier, item) {
            const status = item && item.status ? String(item.status).toLowerCase() : ""
            if (status.indexOf("up") >= 0 || status.indexOf("running") >= 0)
                appHub.enterDistrobox(identifier)
            else
                appHub.startDistrobox(identifier)
        }
        onBackRequested: control.closeDetails()
    }
}
