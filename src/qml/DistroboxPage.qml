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

    Connections {
        target: appHub

        function onDistroboxOperationFinished(identifier, action, success, error) {
            if (success)
                return

            const body = String(error || "").trim()
            const normalizedBody = body.toLowerCase()
            const hostServiceUnavailable = action === "start"
                                           && normalizedBody.indexOf("not provided by any") >= 0
                                           && normalizedBody.indexOf("no route to host") >= 0
            const title = hostServiceUnavailable ? qsTr("Container unavailable in this session")
                        : action === "create" ? qsTr("Could not create container")
                        : action === "start" ? qsTr("Could not start container")
                        : action === "open" ? qsTr("Could not open container")
                        : action === "stop" ? qsTr("Could not stop container")
                        : action === "stop-all" ? qsTr("Could not stop containers")
                        : action === "clone" ? qsTr("Could not clone container")
                        : action === "repair" ? qsTr("Could not repair container")
                        : action === "remove" ? qsTr("Could not delete container")
                                              : qsTr("Could not delete containers")
            const message = hostServiceUnavailable
                ? qsTr("The container was created, but this session does not provide the host service needed to start it. Try starting it after booting the installed system.")
                : (body.length > 0 ? body : qsTr("The container operation failed."))
            Maui.App.rootComponent.notify("dialog-error", title, message)
        }
    }

    SearchResultsView {
        anchors.fill: parent
        visible: control.searchActive && !control.detailVisible
        sourceModel: appHub.distroboxModel
        operationPrefix: "distrobox-"
        query: control.query
        sourceTitle: qsTr("Distrobox")
        sourceDescription: qsTr("Search development containers.")
        emptyTitle: qsTr("No Distrobox results")
        emptyBody: qsTr("Try a different container name or image.")
        busy: appHub.busy
        actionTextResolver: function(item) {
            return qsTr("Open Container Environment")
        }
        actionIconResolver: function(item) {
            return "utilities-terminal"
        }
        actionHandler: function(identifier, item) { appHub.openDistrobox(identifier) }
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
                text1: qsTr("Explore Containers")
                text2: qsTr("Manage isolated development environments.")
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
                readonly property bool compactLayout: Maui.Handy.isMobile || width < Maui.Style.units.gridUnit * 30

                Rectangle {
                    anchors.fill: parent
                    radius: Maui.Style.radiusV
                    color: Maui.Theme.alternateBackgroundColor
                    border.color: Maui.Theme.backgroundColor
                    border.width: 1
                }

                Maui.SettingsDialog {
                    id: containerInformationPopup
                    title: qsTr("Container Information")
                    persistent: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Maui.Style.space.small

                        Maui.FlexSectionItem {
                            Layout.fillWidth: true
                            flat: true
                            wide: true
                            label1.text: qsTr("Image")
                            label2.text: qsTr("Base image used by the container.")
                            label2.wrapMode: Text.Wrap

                            Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: model.baseImage.length > 0 ? model.baseImage : qsTr("Unavailable")
                                horizontalAlignment: Text.AlignRight
                                wrapMode: Text.NoWrap
                                elide: Text.ElideMiddle
                            }
                        }

                        Maui.FlexSectionItem {
                            Layout.fillWidth: true
                            flat: true
                            visible: model.uptime.length > 0
                            label1.text: qsTr("Uptime")
                            label2.text: qsTr("Time elapsed since the container started.")
                            label2.wrapMode: Text.Wrap

                            Label {
                                Layout.fillWidth: true
                                text: model.uptime
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Maui.FlexSectionItem {
                            Layout.fillWidth: true
                            flat: true
                            visible: model.size.length > 0
                            label1.text: qsTr("Size")
                            label2.text: qsTr("Container storage usage.")
                            label2.wrapMode: Text.Wrap

                            Label {
                                Layout.fillWidth: true
                                text: model.size
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Maui.FlexSectionItem {
                            Layout.fillWidth: true
                            flat: true
                            visible: model.created.length > 0
                            label1.text: qsTr("Created")
                            label2.text: qsTr("Date the container was created.")
                            label2.wrapMode: Text.Wrap

                            Label {
                                Layout.fillWidth: true
                                text: model.created
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        Maui.FlexSectionItem {
                            Layout.fillWidth: true
                            flat: true
                            visible: model.architecture.length > 0
                            label1.text: qsTr("Architecture")
                            label2.text: qsTr("Container CPU architecture.")
                            label2.wrapMode: Text.Wrap

                            Label {
                                Layout.fillWidth: true
                                text: model.architecture
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
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
                        imageSource: model.iconUrl
                        iconSource: model.icon
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        spacing: Maui.Style.space.medium

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: Maui.Style.space.small

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Maui.Style.space.medium

                                Label {
                                    id: text1
                                    Layout.minimumWidth: 0
                                    text: model.name
                                    font: Maui.Style.h2Font
                                    elide: Text.ElideRight
                                }

                                ToolSeparator {
                                    visible: containerCard.running
                                    Layout.alignment: Qt.AlignVCenter
                                    orientation: Qt.Vertical
                                    topPadding: 10
                                    bottomPadding: 10
                                }

                                ToolButton {
                                    visible: containerCard.running
                                    text: qsTr("Open container")
                                    display: AbstractButton.IconOnly
                                    icon.name: "utilities-terminal"
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: appHub.openDistrobox(model.name)
                                }

                                Item { Layout.fillWidth: true }

                                ToolButton {
                                    text: qsTr("Container information")
                                    display: AbstractButton.IconOnly
                                    icon.name: "documentinfo"
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: containerInformationPopup.open()
                                }

                                ToolSeparator {
                                    Layout.alignment: Qt.AlignVCenter
                                    orientation: Qt.Vertical
                                    topPadding: 10
                                    bottomPadding: 10
                                }

                                AppFinderChip {
                                    text: containerCard.running ? qsTr("Running") : qsTr("Stopped")
                                    color: containerCard.running ? Maui.Theme.positiveBackgroundColor : Maui.Theme.negativeBackgroundColor
                                    textOpacity: 1.00
                                }
                            }

                            Label {
                                id: text2
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                visible: text.length > 0
                                text: model.containerMode === "Rootless"
                                      ? qsTr("Runs without root privileges.")
                                      : model.containerMode === "Rootful"
                                        ? qsTr("Runs with root privileges.")
                                        : ""
                                font.pointSize: Maui.Style.fontSizes.small
                                opacity: 0.6
                                elide: Text.ElideRight
                            }
                        }


                        RowLayout {
                            visible: !containerCard.compactLayout
                            Layout.fillWidth: true
                            Layout.topMargin: Maui.Style.space.medium
                            spacing: Maui.Style.space.medium

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                visible: !containerCard.running
                                text: appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Start")
                                Maui.Controls.status: Maui.Controls.Positive
                                enabled: !appHub.busy
                                onClicked: appHub.startDistrobox(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                visible: containerCard.running
                                text: appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Stop")
                                Maui.Controls.status: Maui.Controls.Negative
                                enabled: !appHub.busy
                                onClicked: appHub.stopDistrobox(model.name)
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Repair")
                                enabled: !appHub.busy
                                onClicked: appHub.repairDistrobox(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: qsTr("Clone")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: control.cloneRequested(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Delete")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: appHub.removeDistrobox(model.name)
                            }
                        }

                        Flow {
                            visible: containerCard.compactLayout
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.topMargin: Maui.Style.space.medium
                            spacing: Maui.Style.space.small

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                visible: !containerCard.running
                                text: appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Start")
                                Maui.Controls.status: Maui.Controls.Positive
                                enabled: !appHub.busy
                                onClicked: appHub.startDistrobox(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                visible: containerCard.running
                                text: appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Stop")
                                Maui.Controls.status: Maui.Controls.Negative
                                enabled: !appHub.busy
                                onClicked: appHub.stopDistrobox(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Repair")
                                enabled: !appHub.busy
                                onClicked: appHub.repairDistrobox(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: qsTr("Clone")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: control.cloneRequested(model.name)
                            }

                            Button {
                                implicitWidth: Math.max(contentItem.implicitWidth + leftPadding + rightPadding, Maui.Style.units.gridUnit * 4)
                                text: appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Delete")
                                enabled: !appHub.busy && !containerCard.running
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
        operationPrefix: "distrobox-"
        busy: appHub.busy
        actionTextResolver: function(item) {
            return qsTr("Open Container Environment")
        }
        actionHandler: function(identifier, item) { appHub.openDistrobox(identifier) }
        onBackRequested: control.closeDetails()
    }
}
