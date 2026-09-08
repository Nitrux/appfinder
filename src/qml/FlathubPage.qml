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

    property string query: ""
    property bool installedView: false
    property bool initialInstalledView: false
    signal viewModeChanged(bool installed)
    property string selectedCategory: ""
    property var selectedApp: ({
        name: "",
        summary: "",
        description: "",
        identifier: "",
        category: "",
        size: "",
        icon: "application-x-flatpak",
        accent: "steelblue",
        screenshots: "",
        changelog: "",
        permissions: ""
    })

    readonly property bool searchActive: query.trim().length > 0

    Component.onCompleted: installedView = initialInstalledView

    background: null
    headBar.visible: false

    function flatpakAction(identifier) {
        if (appHub.isFlatpakInstalled(identifier))
            appHub.removeFlatpak(identifier)
        else
            appHub.installFlatpak(identifier)
    }

    function sizeText(value) {
        const text = String(value || "").trim()
        return text.length > 0 ? text : qsTr("Size unavailable")
    }

    function showDetails(app) {
        selectedApp = app
        detailsDialog.open()
    }

    ListModel {
        id: featuredModel
        ListElement {
            name: "Firefox"
            summary: "Fast, private, and independent web browser."
            description: "A browser built for privacy, speed, and a web that works for everyone."
            category: "Productivity"
            identifier: "org.mozilla.firefox"
            icon: "internet-web-browser"
            size: "112 MB"
            accent: "steelblue"
            screenshots: "Browse the web with a focused, private workspace."
            changelog: "The latest Flathub release includes current security and stability updates."
            permissions: "Network access, desktop notifications, and access to selected user files."
        }
        ListElement {
            name: "Steam"
            summary: "Gaming platform for PC games and more."
            description: "A complete gaming platform for discovering, installing, and playing games on Linux."
            category: "Games"
            identifier: "com.valvesoftware.Steam"
            icon: "applications-games"
            size: "1.2 GB"
            accent: "mediumpurple"
            screenshots: "Explore your library and discover new games in the Steam client."
            changelog: "The latest Flathub release includes client updates and compatibility improvements."
            permissions: "Network access, game data in user directories, and device access required by games."
        }
    }

    ListModel {
        id: recommendedModel
        ListElement { name: "Krita"; summary: "Digital painting"; category: "Graphics"; identifier: "org.kde.krita"; icon: "applications-graphics"; size: "286 MB"; accent: "darkorange" }
        ListElement { name: "VLC"; summary: "Media player"; category: "Audio"; identifier: "org.videolan.VLC"; icon: "multimedia-player"; size: "82 MB"; accent: "darkgoldenrod" }
        ListElement { name: "GIMP"; summary: "Image editor"; category: "Graphics"; identifier: "org.gimp.GIMP"; icon: "applications-graphics"; size: "214 MB"; accent: "slateblue" }
        ListElement { name: "Discord"; summary: "Voice and video communication"; category: "Video"; identifier: "com.discordapp.Discord"; icon: "internet-services"; size: "188 MB"; accent: "royalblue" }
    }

    Loader {
        id: viewLoader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 0
        sourceComponent: control.searchActive ? searchView : control.installedView ? installedViewComponent : exploreView
    }

    Component {
        id: exploreView

        Maui.ScrollColumn {
            spacing: Maui.Style.space.medium

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Flathub")
                text2: qsTr("Explore and manage applications from Flathub.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: featuredLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: featuredLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Featured")
                        text2: qsTr("Discover popular desktop software from Flathub.")
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.GridBrowser {
                        id: featuredGrid
                        Layout.fillWidth: true
                        Layout.preferredHeight: width < Maui.Style.units.gridUnit * 42 ? 400 : 204
                        itemSize: 360
                        itemHeight: 188
                        adaptContent: true
                        model: featuredModel
                        holder.visible: false

                        delegate: Item {
                            id: featuredCard
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            Rectangle {
                                anchors.fill: parent
                                radius: Maui.Style.radiusV
                                color: Maui.Theme.alternateBackgroundColor
                                border.color: Maui.Theme.backgroundColor
                                clip: true

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: control.showDetails({
                                        name: model.name,
                                        summary: model.summary,
                                        description: model.description,
                                        identifier: model.identifier,
                                        category: model.category,
                                        size: model.size,
                                        icon: model.icon,
                                        accent: model.accent,
                                        screenshots: model.screenshots,
                                        changelog: model.changelog,
                                        permissions: model.permissions
                                    })
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Maui.Style.space.medium
                                    spacing: Maui.Style.space.medium

                                    Rectangle {
                                        Layout.fillHeight: true
                                        Layout.preferredWidth: 124
                                        radius: Maui.Style.radiusV
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: model.accent }
                                            GradientStop { position: 1.0; color: Maui.Theme.backgroundColor }
                                        }

                                        Maui.IconItem {
                                            anchors.centerIn: parent
                                            width: 64
                                            height: 64
                                            iconSizeHint: 64
                                            iconSource: model.icon
                                        }

                                        Label {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: Maui.Style.space.small
                                            text: qsTr("FLATHUB FEATURE")
                                            color: "white"
                                            font.pointSize: Maui.Style.fontSizes.tiny
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        spacing: Maui.Style.space.small

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.name
                                            font: Maui.Style.h2Font
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.summary
                                            color: Maui.Theme.disabledTextColor
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Item { Layout.fillHeight: true }

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Label {
                                                Layout.fillWidth: true
                                                text: model.category
                                                color: Maui.Theme.disabledTextColor
                                                elide: Text.ElideRight
                                            }

                                            ToolButton {
                                                text: {
                                                    appHub.busy
                                                    appHub.statusMessage
                                                    return appHub.isFlatpakInstalled(model.identifier) ? qsTr("Remove") : qsTr("Install")
                                                }
                                                icon.name: {
                                                    appHub.statusMessage
                                                    return appHub.isFlatpakInstalled(model.identifier) ? "edit-delete" : "list-add"
                                                }
                                                display: ToolButton.TextBesideIcon
                                                enabled: !appHub.busy
                                                onClicked: control.flatpakAction(model.identifier)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                        text2: qsTr("Browse applications by what you want to do.")
                        label2.wrapMode: Text.Wrap
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Maui.Style.space.small

                        Maui.Chip {
                            text: qsTr("Games")
                            icon.name: "applications-games"
                            checkable: false
                            checked: control.selectedCategory === text
                            onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
                        }
                        Maui.Chip {
                            text: qsTr("Productivity")
                            icon.name: "office-calendar"
                            checkable: false
                            checked: control.selectedCategory === text
                            onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
                        }
                        Maui.Chip {
                            text: qsTr("Graphics")
                            icon.name: "applications-graphics"
                            checkable: false
                            checked: control.selectedCategory === text
                            onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
                        }
                        Maui.Chip {
                            text: qsTr("Audio")
                            icon.name: "applications-multimedia"
                            checkable: false
                            checked: control.selectedCategory === text
                            onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
                        }
                        Maui.Chip {
                            text: qsTr("Video")
                            icon.name: "camera-video"
                            checkable: false
                            checked: control.selectedCategory === text
                            onClicked: control.selectedCategory = control.selectedCategory === text ? "" : text
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: popularLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: popularLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Popular Apps")
                        text2: qsTr("Useful applications to get started.")
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.GridBrowser {
                        id: recommendedGrid
                        Layout.fillWidth: true
                        Layout.preferredHeight: width < Maui.Style.units.gridUnit * 42 ? 400 : 204
                        itemSize: 360
                        itemHeight: 96
                        adaptContent: true
                        model: recommendedModel
                        holder.visible: false

                        delegate: Item {
                            id: recommendedCard
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight
                            property bool categoryVisible: control.selectedCategory.length === 0 || model.category === control.selectedCategory
                            visible: categoryVisible

                            Rectangle {
                                anchors.fill: parent
                                radius: Maui.Style.radiusV
                                color: Maui.Theme.alternateBackgroundColor
                                border.color: appHub.isFlatpakInstalled(model.identifier) ? Maui.Theme.positiveBackgroundColor : Maui.Theme.backgroundColor

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: control.showDetails({
                                        name: model.name,
                                        summary: model.summary,
                                        description: model.summary,
                                        identifier: model.identifier,
                                        category: model.category,
                                        size: model.size,
                                        icon: model.icon,
                                        accent: model.accent,
                                        screenshots: qsTr("A preview of the %1 workspace is available from Flathub.").arg(model.name),
                                        changelog: qsTr("The latest Flathub release is ready to install."),
                                        permissions: qsTr("Permissions are managed by the Flatpak sandbox.")
                                    })
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: Maui.Style.space.medium
                                    spacing: Maui.Style.space.medium

                                    Maui.IconItem {
                                        Layout.preferredWidth: 48
                                        Layout.preferredHeight: 48
                                        iconSizeHint: 48
                                        iconSource: model.icon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: Maui.Style.space.small

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.name
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.summary
                                            color: Maui.Theme.disabledTextColor
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.category
                                            color: Maui.Theme.disabledTextColor
                                            font.pointSize: Maui.Style.fontSizes.tiny
                                            elide: Text.ElideRight
                                        }
                                    }

                                    ToolButton {
                                        text: {
                                            appHub.busy
                                            appHub.statusMessage
                                            return appHub.isFlatpakInstalled(model.identifier) ? qsTr("Remove") : qsTr("Install")
                                        }
                                        icon.name: {
                                            appHub.statusMessage
                                            return appHub.isFlatpakInstalled(model.identifier) ? "edit-delete" : "list-add"
                                        }
                                        display: ToolButton.TextBesideIcon
                                        enabled: !appHub.busy
                                        onClicked: control.flatpakAction(model.identifier)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: installedViewComponent

        Maui.ScrollColumn {
            spacing: Maui.Style.space.medium

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Flathub")
                text2: qsTr("Explore and manage applications from Flathub.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: installedLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: installedLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Installed Flathub Applications (%1)").arg(appHub.flathubModel.count)
                        text2: qsTr("Maintain the Flatpak applications installed for this user.")
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.ListBrowser {
                id: installedBrowser
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: appHub.flathubModel
                spacing: Maui.Style.space.small
                holder.visible: count === 0
                holder.title: qsTr("No installed Flathub applications")
                holder.body: qsTr("Applications installed from Flathub will appear here.")

                delegate: Item {
                    id: installedCard
                    width: ListView.view.width
                    height: 96

                    Rectangle {
                        anchors.fill: parent
                        radius: Maui.Style.radiusV
                        color: Maui.Theme.alternateBackgroundColor
                        border.color: Maui.Theme.positiveBackgroundColor

                        MouseArea {
                            anchors.fill: parent
                            onClicked: control.showDetails({
                                name: model.name,
                                summary: model.summary,
                                description: model.description.length > 0 ? model.description : model.summary,
                                identifier: model.identifier,
                                category: model.category,
                                size: control.sizeText(model.size),
                                icon: model.icon,
                                accent: "steelblue",
                                screenshots: qsTr("Screenshots are provided by the Flathub application listing."),
                                changelog: model.version.length > 0 ? qsTr("Version %1 is currently installed.").arg(model.version) : qsTr("The installed version is current for this user."),
                                permissions: qsTr("Permissions are managed by the Flatpak sandbox and the application manifest.")
                            })
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Maui.Style.space.medium
                            spacing: Maui.Style.space.medium

                            Maui.IconItem {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                iconSizeHint: 48
                                iconSource: model.icon
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Maui.Style.space.small

                                Label {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font: Maui.Style.h2Font
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 • %2").arg(model.category.length > 0 ? model.category : qsTr("Desktop Application")).arg(control.sizeText(model.size))
                                    color: Maui.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                }
                            }

                            Maui.Chip {
                                text: qsTr("Installed")
                                color: Maui.Theme.positiveBackgroundColor
                                enabled: false
                            }

                            ToolButton {
                                text: qsTr("Remove")
                                icon.name: "edit-delete"
                                display: ToolButton.TextBesideIcon
                                enabled: !appHub.busy
                                onClicked: control.flatpakAction(model.identifier)
                            }
                        }
                    }
                }
            }
            }
        }
        }
    }

    Component {
        id: searchView

        Maui.ScrollColumn {
            spacing: Maui.Style.space.medium

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Flathub")
                text2: qsTr("Search applications across Flathub.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: searchLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: searchLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Search Results")
                        text2: qsTr("Results for \"%1\".").arg(control.query)
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.GridBrowser {
                id: searchGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                itemSize: 360
                itemHeight: 112
                adaptContent: true
                model: appHub.flathubModel
                holder.visible: appHub.flathubModel.count === 0
                holder.title: qsTr("No Flathub results")
                holder.body: qsTr("Try a different application name or category.")

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Maui.Style.radiusV
                        color: Maui.Theme.alternateBackgroundColor
                        border.color: model.status === "Installed" ? Maui.Theme.positiveBackgroundColor : Maui.Theme.backgroundColor

                        MouseArea {
                            anchors.fill: parent
                            onClicked: control.showDetails({
                                name: model.name,
                                summary: model.summary,
                                description: model.description.length > 0 ? model.description : model.summary,
                                identifier: model.identifier,
                                category: model.category,
                                size: control.sizeText(model.size),
                                icon: model.icon,
                                accent: "steelblue",
                                screenshots: qsTr("Screenshots are provided by the Flathub application listing."),
                                changelog: model.version.length > 0 ? qsTr("Version %1 is available from Flathub.").arg(model.version) : qsTr("The current Flathub release is available."),
                                permissions: qsTr("Permissions are managed by the Flatpak sandbox and the application manifest.")
                            })
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Maui.Style.space.medium
                            spacing: Maui.Style.space.medium

                            Maui.IconItem {
                                Layout.preferredWidth: 48
                                Layout.preferredHeight: 48
                                iconSizeHint: 48
                                iconSource: model.icon
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Maui.Style.space.small

                                Label {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font: Maui.Style.h2Font
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: qsTr("%1 • %2").arg(model.category.length > 0 ? model.category : qsTr("Flathub Application")).arg(control.sizeText(model.size))
                                    color: Maui.Theme.disabledTextColor
                                    elide: Text.ElideRight
                                }
                            }

                            Maui.Chip {
                                text: model.status.length > 0 ? model.status : qsTr("Available")
                                color: model.status === "Installed" ? Maui.Theme.positiveBackgroundColor : Maui.Theme.neutralBackgroundColor
                                enabled: false
                            }

                            ToolButton {
                                text: model.actionText
                                icon.name: model.actionIcon
                                display: ToolButton.TextBesideIcon
                                enabled: !appHub.busy
                                onClicked: control.flatpakAction(model.identifier)
                            }
                        }
                    }
                }
            }
                }
            }
        }
        }

    Maui.InfoDialog {
        id: detailsDialog
        title: selectedApp.name.length > 0 ? selectedApp.name : qsTr("Application Details")
        message: selectedApp.description.length > 0 ? selectedApp.description : selectedApp.summary
        standardButtons: Dialog.Close
        template.iconSource: selectedApp.icon

        Maui.SectionHeader {
            Layout.fillWidth: true
            padding: 0
            text1: qsTr("Application overview")
            text2: qsTr("%1 • Download size: %2").arg(selectedApp.category.length > 0 ? selectedApp.category : qsTr("Flathub Application")).arg(control.sizeText(selectedApp.size))
            label2.wrapMode: Text.Wrap
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Screenshots")
            font.weight: Font.DemiBold
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 128
            radius: Maui.Style.radiusV
            gradient: Gradient {
                GradientStop { position: 0.0; color: selectedApp.accent }
                GradientStop { position: 1.0; color: Maui.Theme.backgroundColor }
            }

            Maui.IconItem {
                anchors.centerIn: parent
                width: 56
                height: 56
                iconSizeHint: 56
                iconSource: selectedApp.icon
            }

            Label {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Maui.Style.space.small
                text: qsTr("Flathub preview")
                color: "white"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Label {
            Layout.fillWidth: true
            text: selectedApp.screenshots
            color: Maui.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Changelog")
            font.weight: Font.DemiBold
        }

        Label {
            Layout.fillWidth: true
            text: selectedApp.changelog
            color: Maui.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("Permissions")
            font.weight: Font.DemiBold
        }

        Label {
            Layout.fillWidth: true
            text: selectedApp.permissions
            color: Maui.Theme.disabledTextColor
            wrapMode: Text.WordWrap
        }

        ToolButton {
            Layout.alignment: Qt.AlignRight
            text: appHub.isFlatpakInstalled(selectedApp.identifier) ? qsTr("Remove") : qsTr("Install")
            icon.name: appHub.isFlatpakInstalled(selectedApp.identifier) ? "edit-delete" : "list-add"
            display: ToolButton.TextBesideIcon
            enabled: selectedApp.identifier.length > 0 && !appHub.busy
            onClicked: {
                control.flatpakAction(selectedApp.identifier)
                detailsDialog.close()
            }
        }
    }
}
