/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

import ".."

Maui.Page {
    id: control

    signal createContainerRequested()
    signal cloneRequested(string source)

    onCreateContainerRequested: createDialog.open()
    onCloneRequested: function(source) {
        cloneDialog.sourceName = source
        cloneDialog.open()
    }

    function openDeleteAllContainersDialog() {
        deleteAllContainersDialog.open()
    }

    property string query: ""
    readonly property bool searchActive: query.trim().length > 0

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
                        : action === "image-remove" ? qsTr("Could not remove container image")
                                              : qsTr("Could not delete containers")
            const message = hostServiceUnavailable
                ? qsTr("The container was created, but this session does not provide the host service needed to start it. Try starting it after booting the installed system.")
                : (body.length > 0 ? body : qsTr("The container operation failed."))
            Maui.App.rootComponent.notify("dialog-error", title, message)
        }

        function onRootfulDistroboxesLoadFinished(success, error) {
            if (success)
                return

            const body = String(error || "").trim()
            Maui.App.rootComponent.notify(
                "dialog-error",
                qsTr("Could not load rootful containers"),
                body.length > 0 ? body : qsTr("The rootful container inventory could not be loaded.")
            )
        }
    }

    SearchResultsView {
        anchors.fill: parent
        visible: control.searchActive
        sourceModel: appHub.distroboxModel
        query: control.query
        sourceTitle: qsTr("Distrobox")
        sourceDescription: qsTr("Search development containers.")
        emptyTitle: qsTr("No Distrobox results")
        emptyBody: qsTr("Try a different container name or image.")
        busy: appHub.busy
        delegateComponent: Component {
            Item {
                id: distroboxResult
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                readonly property bool running: {
                    const value = String(model.status).toLowerCase()
                    return value.indexOf("up") >= 0 || value.indexOf("running") >= 0
                }

                Maui.GridBrowserDelegate {
                    id: resultCard
                    width: parent.width - Maui.Style.space.small * 2
                    height: implicitHeight
                    anchors.centerIn: parent
                    flat: false
                    selectedBackgroundColor: Maui.Theme.alternateBackgroundColor
                    selectedForegroundColor: Maui.Theme.textColor
                    isCurrentItem: false
                    template.labelsVisible: false
                    template.iconComponent: Component {
                        Item {
                            id: resultContent
                            anchors.fill: parent
                            implicitHeight: resultLayout.implicitHeight + Maui.Style.space.small * 2
                            clip: true

                            ColumnLayout {
                                id: resultLayout
                                anchors.fill: parent
                                anchors.leftMargin: Maui.Style.space.medium
                                anchors.rightMargin: Maui.Style.space.medium
                                anchors.topMargin: Maui.Style.space.small
                                anchors.bottomMargin: Maui.Style.space.small
                                spacing: Maui.Style.space.medium

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Maui.Style.space.medium

                                    Maui.IconItem {
                                        Layout.alignment: Qt.AlignTop
                                        Layout.preferredWidth: Maui.Style.iconSizes.big
                                        Layout.preferredHeight: Maui.Style.iconSizes.big
                                        iconSizeHint: Maui.Style.iconSizes.big
                                        imageSource: model.iconUrl
                                        iconSource: model.icon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: Maui.Style.space.small

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.name
                                            font: Maui.Style.h2Font
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            visible: text.length > 0
                                            text: model.containerMode === "Rootless"
                                                  ? qsTr("Runs without root privileges.")
                                                  : model.containerMode === "Rootful"
                                                    ? qsTr("Runs with root privileges.")
                                                    : ""
                                            color: Maui.Theme.disabledTextColor
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.topMargin: Maui.Style.space.medium
                                            spacing: Maui.Style.space.small

                                            Button {
                                                visible: !distroboxResult.running
                                                text: appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name
                                                      ? appHub.operationLabel : qsTr("Start")
                                                Maui.Controls.status: Maui.Controls.Positive
                                                enabled: !appHub.busy
                                                onClicked: appHub.startDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name }
                                            }

                                            Button {
                                                visible: distroboxResult.running
                                                text: appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name
                                                      ? appHub.operationLabel : qsTr("Stop")
                                                Maui.Controls.status: Maui.Controls.Negative
                                                enabled: !appHub.busy
                                                onClicked: appHub.stopDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name }
                                            }
                                        }
                                    }

                                    AppFinderChip {
                                        Layout.alignment: Qt.AlignTop
                                        text: distroboxResult.running ? qsTr("Running") : qsTr("Stopped")
                                        color: distroboxResult.running ? Maui.Theme.positiveBackgroundColor : Maui.Theme.negativeBackgroundColor
                                        textOpacity: 1.00
                                    }
                                }

                            }
                        }
                    }
                }
            }
        }
    }

    Maui.ScrollColumn {
        visible: !control.searchActive
        anchors.fill: parent
        padding: Maui.Style.contentMargins
        spacing: Maui.Style.space.big

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
            Layout.preferredHeight: holder.visible ? Math.max(holder.implicitHeight, Maui.Style.rowHeight) : contentHeight
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

                Maui.InfoDialog {
                    id: containerInformationPopup
                    title: qsTr("Container Information")

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
                                visible: !containerCard.running
                                text: appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Start")
                                Maui.Controls.status: Maui.Controls.Positive
                                enabled: !appHub.busy
                                onClicked: appHub.startDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                visible: containerCard.running
                                text: appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Stop")
                                Maui.Controls.status: Maui.Controls.Negative
                                enabled: !appHub.busy
                                onClicked: appHub.stopDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name }
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Repair")
                                enabled: !appHub.busy && containerCard.running
                                onClicked: appHub.repairDistrobox(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                text: appHub.operationAction === "distrobox-clone" && appHub.operationIdentifier === model.name ? appHub.operationLabel : qsTr("Clone")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: control.cloneRequested(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-clone" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                text: appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Delete")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: appHub.removeDistrobox(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name }
                            }
                        }

                        Flow {
                            visible: containerCard.compactLayout
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.topMargin: Maui.Style.space.medium
                            spacing: Maui.Style.space.small

                            Button {
                                visible: !containerCard.running
                                text: appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Start")
                                Maui.Controls.status: Maui.Controls.Positive
                                enabled: !appHub.busy
                                onClicked: appHub.startDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-start" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                visible: containerCard.running
                                text: appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Stop")
                                Maui.Controls.status: Maui.Controls.Negative
                                enabled: !appHub.busy
                                onClicked: appHub.stopDistrobox(model.name)
                                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-stop" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                text: appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Repair")
                                enabled: !appHub.busy && containerCard.running
                                onClicked: appHub.repairDistrobox(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-repair" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                text: appHub.operationAction === "distrobox-clone" && appHub.operationIdentifier === model.name ? appHub.operationLabel : qsTr("Clone")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: control.cloneRequested(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-clone" && appHub.operationIdentifier === model.name }
                            }

                            Button {
                                text: appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name
                                      ? appHub.operationLabel : qsTr("Delete")
                                enabled: !appHub.busy && !containerCard.running
                                onClicked: appHub.removeDistrobox(model.name)
                                contentItem: ActionOperationLabel { text: parent.text; busy: appHub.busy && appHub.operationAction === "distrobox-remove" && appHub.operationIdentifier === model.name }
                            }
                        }
                    }
                }
            }
        }

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Container Images")
            text2: qsTr("Manage images stored for Distrobox containers.")
            label2.wrapMode: Text.Wrap
        }

        Rectangle {
            id: savedImagesCard
            Layout.fillWidth: true
            implicitHeight: savedImagesLayout.implicitHeight + Maui.Style.contentMargins * 2
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1

            ColumnLayout {
                id: savedImagesLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Available Images (%1)").arg(appHub.distroboxImagesModel.count)
                    text2: qsTr("Remove downloaded images that are no longer needed by a container.")
                    label2.wrapMode: Text.Wrap
                }

                Repeater {
                    model: appHub.distroboxImagesModel

                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: model.name
                        label1.elide: Text.ElideRight
                        label1.wrapMode: Text.NoWrap
                        label2.text: model.summary
                        label2.elide: Text.ElideRight
                        label2.wrapMode: Text.NoWrap
                        template.iconSource: "package-x-generic"

                        template.content: Row {
                            spacing: Maui.Style.space.tiny

                            ToolButton {
                                icon.name: "edit-delete"
                                display: ToolButton.IconOnly
                                enabled: !appHub.busy
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Remove image")
                                onClicked: appHub.removeDistroboxImage(model.identifier, model.containerMode === "Rootful")
                            }
                        }
                    }
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    visible: appHub.distroboxImagesModel.count === 0
                    flat: true
                    label1.text: qsTr("No Saved Container Images")
                    label2.text: qsTr("Images downloaded for Distrobox containers will appear here.")
                    template.iconSource: "package-x-generic"
                }
            }
        }
    }

    Maui.InfoDialog {
        id: createDialog
        property bool customHomeEnabled: false
        property bool advancedOptionsEnabled: false
        property bool rootfulEnabled: false
        property bool initEnabled: false
        property bool nvidiaEnabled: false
        title: qsTr("New Container")
        standardButtons: Dialog.Ok | Dialog.Cancel
        Component.onCompleted: standardButton(Dialog.Ok).text = qsTr("Create")

        Maui.FlexSectionItem {
            label1.text: qsTr("Container name")
            label2.text: qsTr("Name used to identify the container.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: containerNameField
                Layout.fillWidth: true
                placeholderText: qsTr("my-container")
            }
        }

        Maui.FlexSectionItem {
            label1.text: qsTr("Base image")
            label2.text: qsTr("Image used as the container's operating system and package base.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: containerImageField
                Layout.fillWidth: true
                placeholderText: qsTr("ubuntu:24.04")
            }
        }

        Maui.FlexSectionItem {
            label1.text: qsTr("Create rootful container")
            label2.text: qsTr("Create the container with real root privileges.")
            label2.wrapMode: Text.Wrap
            template.content: Switch {
                checkable: true
                checked: createDialog.rootfulEnabled
                onToggled: createDialog.rootfulEnabled = checked
            }
        }

        Label {
            visible: createDialog.rootfulEnabled
            Layout.fillWidth: true
            Layout.leftMargin: Maui.Style.contentMargins
            Layout.rightMargin: Maui.Style.contentMargins
            text: qsTr("Warning: Rootful containers can modify host-owned resources. Enable this only when required.")
            color: Maui.Theme.negativeBackgroundColor
            font.pointSize: Maui.Style.fontSizes.small
            wrapMode: Text.Wrap
        }

        Maui.FlexSectionItem {
            label1.text: qsTr("Show advanced options")
            label2.text: qsTr("Configure additional container creation options.")
            label2.wrapMode: Text.Wrap
            template.content: Switch {
                checkable: true
                checked: createDialog.advancedOptionsEnabled
                onToggled: createDialog.advancedOptionsEnabled = checked
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Use custom home directory")
            label2.text: qsTr("Mount a host directory as the container home.")
            label2.wrapMode: Text.Wrap
            template.content: Switch {
                checkable: true
                checked: createDialog.customHomeEnabled
                onToggled: createDialog.customHomeEnabled = checked
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled && createDialog.customHomeEnabled
            label1.text: qsTr("Home directory")
            label2.text: qsTr("Host directory used as the container home.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: containerHomeField
                Layout.fillWidth: true
                placeholderText: qsTr("/path/to/container-home")
            }
        }
        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Additional flags")
            label2.text: qsTr("Extra flags passed to the container manager command.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: additionalFlagsField
                Layout.fillWidth: true
                placeholderText: qsTr("--pids-limit -1")
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Additional packages")
            label2.text: qsTr("Packages installed during initial container setup.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: additionalPackagesField
                Layout.fillWidth: true
                placeholderText: qsTr("git vim tmux")
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Pre-init hooks")
            label2.text: qsTr("Commands executed at the start of container initialization.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: preInitHooksField
                Layout.fillWidth: true
                placeholderText: qsTr("command")
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Init hooks")
            label2.text: qsTr("Commands executed at the end of container initialization.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: initHooksField
                Layout.fillWidth: true
                placeholderText: qsTr("command")
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Use init system")
            label2.text: qsTr("Use a separate init system inside the container.")
            label2.wrapMode: Text.Wrap
            template.content: Switch {
                checkable: true
                checked: createDialog.initEnabled
                onToggled: createDialog.initEnabled = checked
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled && createDialog.initEnabled
            label1.text: qsTr("Init packages")
            label2.text: qsTr("Packages required by the container image for its init system.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: initPackagesField
                Layout.fillWidth: true
                placeholderText: qsTr("init-package init-package-extra")
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("NVIDIA integration")
            label2.text: qsTr("Try to integrate the host NVIDIA drivers in the container.")
            label2.wrapMode: Text.Wrap
            template.content: Switch {
                checkable: true
                checked: createDialog.nvidiaEnabled
                onToggled: createDialog.nvidiaEnabled = checked
            }
        }

        Maui.FlexSectionItem {
            visible: createDialog.advancedOptionsEnabled
            label1.text: qsTr("Platform")
            label2.text: qsTr("Platform to use for the container image, e.g., as linux/amd64.")
            label2.wrapMode: Text.Wrap

            Maui.TextField {
                id: platformField
                Layout.fillWidth: true
                placeholderText: qsTr("linux/amd64")
            }
        }

        onAccepted: {
            appHub.createDistrobox(containerNameField.text, containerImageField.text, advancedOptionsEnabled && customHomeEnabled ? containerHomeField.text : "", rootfulEnabled, {
                additionalFlags: advancedOptionsEnabled ? additionalFlagsField.text : "",
                additionalPackages: advancedOptionsEnabled ? additionalPackagesField.text : "",
                initPackages: advancedOptionsEnabled && initEnabled ? initPackagesField.text : "",
                initHooks: advancedOptionsEnabled ? initHooksField.text : "",
                preInitHooks: advancedOptionsEnabled ? preInitHooksField.text : "",
                init: advancedOptionsEnabled && createDialog.initEnabled,
                nvidia: advancedOptionsEnabled && createDialog.nvidiaEnabled,
                platform: advancedOptionsEnabled ? platformField.text : ""
            })
            containerNameField.clear()
            containerImageField.clear()
            containerHomeField.clear()
            additionalFlagsField.clear()
            additionalPackagesField.clear()
            initPackagesField.clear()
            initHooksField.clear()
            preInitHooksField.clear()
            platformField.clear()
            customHomeEnabled = false
            rootfulEnabled = false
            advancedOptionsEnabled = false
            initEnabled = false
            nvidiaEnabled = false
            close()
        }
        onRejected: {
            containerHomeField.clear()
            additionalFlagsField.clear()
            additionalPackagesField.clear()
            initPackagesField.clear()
            initHooksField.clear()
            preInitHooksField.clear()
            platformField.clear()
            customHomeEnabled = false
            rootfulEnabled = false
            advancedOptionsEnabled = false
            initEnabled = false
            nvidiaEnabled = false
            close()
        }
    }

    Connections {
        target: appHub

        function onBusyChanged() {
            if (!appHub.busy || appHub.operationAction !== "distrobox-create")
                return

            createOutputDialog.operationFinished = false
            createOutputDialog.operationSucceeded = false
            createOutputDialog.operationError = ""
            createOutputDialog.open()
        }

        function onDistroboxOperationFinished(identifier, action, success, error) {
            if (action !== "create" || !createOutputDialog.visible)
                return

            createOutputDialog.operationFinished = true
            createOutputDialog.operationSucceeded = success
            createOutputDialog.operationError = String(error || "").trim()
        }
    }

    Maui.InfoDialog {
        id: createOutputDialog
        property bool operationFinished: false
        property bool operationSucceeded: false
        property string operationError: ""

        title: operationFinished
               ? (operationSucceeded ? qsTr("Container Created") : qsTr("Container Creation Failed"))
               : qsTr("Creating Container")
        message: operationFinished
                 ? (operationSucceeded
                    ? qsTr("The container was created successfully.")
                    : (operationError.length > 0 ? operationError : qsTr("The container could not be created.")))
                 : qsTr("distrobox-create is still running.")
        template.iconSource: "utilities-terminal"
        standardButtons: Dialog.Close

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Command Output")
            text2: createOutputDialog.operationFinished
                   ? qsTr("The operation has finished.")
                   : qsTr("distrobox-create is still running.")
            label2.wrapMode: Text.Wrap
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Maui.Style.units.gridUnit * 18
            clip: true

            TextArea {
                width: parent.width
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WrapAnywhere
                text: appHub.operationLog.length > 0
                      ? appHub.operationLog
                      : qsTr("Waiting for distrobox-create output…")
            }
        }
    }

    Maui.InfoDialog {
        id: deleteAllContainersDialog
        title: qsTr("Delete All Containers")
        message: qsTr("This will stop and permanently delete all Distrobox containers. Container data may be lost.")
        template.iconSource: "dialog-warning"
        standardButtons: Dialog.Discard | Dialog.Cancel
        Component.onCompleted: standardButton(Dialog.Discard).text = qsTr("Delete")
        onDiscarded: {
            appHub.removeAllDistroboxes()
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
