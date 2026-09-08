/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
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
            iconUrl: "https://dl.flathub.org/media/icons/128x128/org.mozilla.firefox.png"
            size: "112 MB"
            accent: "steelblue"
            screenshots: "Browse the web with a focused, private workspace."
            screenshot: "https://dl.flathub.org/media/org.mozilla.firefox-stable/1248x702/org.mozilla.firefox-af5d1ae7c121ea4864b3c5a1098f8f9c.png"
            screenshotCaption: "Browse the web with a focused, private workspace."
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
            iconUrl: "https://dl.flathub.org/media/com/valvesoftware/Steam/f0343a4b277e822cce53b904454d3a7d/icons/128x128/com.valvesoftware.Steam.png"
            size: "1.2 GB"
            accent: "mediumpurple"
            screenshots: "Explore your library and discover new games in the Steam client."
            screenshot: "https://dl.flathub.org/media/com/valvesoftware/Steam/f0343a4b277e822cce53b904454d3a7d/screenshots/image-2_1248x702@1.png"
            screenshotCaption: "Explore the Steam store and your game library."
            changelog: "The latest Flathub release includes client updates and compatibility improvements."
            permissions: "Network access, game data in user directories, and device access required by games."
        }
        ListElement {
            name: "Krita"
            summary: "Digital painting for artists."
            description: "A professional application for concept art, illustration, comics, and texture painting."
            category: "Graphics"
            identifier: "org.kde.krita"
            icon: "applications-graphics"
            iconUrl: "https://dl.flathub.org/media/org/kde/krita/2d1e8935a00814a3aae96df66090a85a/icons/128x128/org.kde.krita.png"
            size: "286 MB"
            accent: "darkorange"
            screenshots: "Paint, illustrate, and create with a professional digital art workspace."
            screenshot: "https://dl.flathub.org/media/org/kde/krita/2d1e8935a00814a3aae96df66090a85a/screenshots/image-1_1248x677@1.png"
            screenshotCaption: "Create digital paintings and illustrations."
            changelog: "The latest Flathub release includes current painting tools and stability updates."
            permissions: "Access to selected user files and graphics hardware."
        }
        ListElement {
            name: "VLC"
            summary: "Play almost anything."
            description: "A versatile media player that supports a wide range of audio and video formats."
            category: "Audio"
            identifier: "org.videolan.VLC"
            icon: "multimedia-player"
            iconUrl: "https://dl.flathub.org/media/org/videolan/VLC/34e7c2b6a026c5c290606225a84582d3/icons/128x128/org.videolan.VLC.png"
            size: "82 MB"
            accent: "darkgoldenrod"
            screenshots: "Play local and network media from a familiar, capable player."
            screenshot: "https://dl.flathub.org/media/org/videolan/VLC/34e7c2b6a026c5c290606225a84582d3/screenshots/image-1_1248x702@1.png"
            screenshotCaption: "Play local and network media."
            changelog: "The latest Flathub release includes playback and compatibility improvements."
            permissions: "Access to selected media files, removable devices, and network media."
        }
        ListElement {
            name: "GIMP"
            summary: "Powerful image editor."
            description: "A flexible image editor for photo retouching, composition, and original artwork."
            category: "Graphics"
            identifier: "org.gimp.GIMP"
            icon: "applications-graphics"
            iconUrl: "https://dl.flathub.org/media/org/gimp/GIMP/ab48223ba11e3bad9493fcda45e9ac04/icons/128x128/org.gimp.GIMP.png"
            size: "214 MB"
            accent: "slateblue"
            screenshots: "Edit images and compose artwork with a flexible creative toolkit."
            screenshot: "https://dl.flathub.org/media/org/gimp/GIMP/ab48223ba11e3bad9493fcda45e9ac04/screenshots/image-1_1248x702@1.png"
            screenshotCaption: "Edit images and compose original artwork."
            changelog: "The latest Flathub release includes image processing and stability updates."
            permissions: "Access to selected user files and graphics hardware."
        }
        ListElement {
            name: "Discord"
            summary: "Voice and video communication."
            description: "A place to talk, share, and build communities with voice, video, and text."
            category: "Video"
            identifier: "com.discordapp.Discord"
            icon: "internet-services"
            iconUrl: "https://dl.flathub.org/media/com/discordapp/Discord/bf53f3a5ea595d82659f2ef73fbd51f7/icons/128x128/com.discordapp.Discord.png"
            size: "188 MB"
            accent: "royalblue"
            screenshots: "Stay connected with communities through text, voice, and video."
            screenshot: "https://dl.flathub.org/media/com/discordapp/Discord/bf53f3a5ea595d82659f2ef73fbd51f7/screenshots/image-1_1248x957@1.png"
            screenshotCaption: "Connect with communities through text, voice, and video."
            changelog: "The latest Flathub release includes current communication and stability updates."
            permissions: "Network access, notifications, microphone, and camera access."
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
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Explore Flathub")
                text2: qsTr("Find and install hundreds of apps and games for Linux.")
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
                        text2: qsTr("Popular picks from Flathub.")
                        label2.wrapMode: Text.Wrap
                    }

                    Item {
                        id: featuredCarouselFrame
                        Layout.fillWidth: true
                        Layout.preferredHeight: width < Maui.Style.units.gridUnit * 42 ? 400 : Maui.Style.units.gridUnit * 16
                        clip: true

                        ListView {
                            id: featuredCarousel
                            anchors.fill: parent
                            interactive: true
                            clip: true
                            orientation: ListView.Horizontal
                            snapMode: ListView.SnapOneItem
                            boundsBehavior: Flickable.StopAtBounds
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            highlightFollowsCurrentItem: true
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: width
                            highlightMoveDuration: Maui.Style.units.longDuration * 2
                            highlightMoveVelocity: -1

                            property bool randomized: false

                            function nextRandomIndex() {
                                if (count < 2)
                                    return currentIndex

                                var nextIndex = currentIndex
                                while (nextIndex === currentIndex)
                                    nextIndex = Math.floor(Math.random() * count)
                                return nextIndex
                            }

                            onCountChanged: {
                                if (!randomized && count > 1) {
                                    randomized = true
                                    currentIndex = Math.floor(Math.random() * count)
                                }
                            }

                            onCurrentIndexChanged: {
                                if (featuredRotationTimer.running)
                                    featuredRotationTimer.restart()
                            }

                            model: featuredModel

                            delegate: Item {
                                    id: featuredSlide
                                    width: featuredCarousel.width
                                    height: featuredCarousel.height

                                    onVisibleChanged: {
                                        if (visible && screenshotImage.status === Image.Ready)
                                            bannerColors.update()
                                    }

                                    property color bannerBackground: Maui.ColorUtils.tintWithAlpha(bannerColors.dominant, Maui.Theme.backgroundColor, 0.28)
                                    property color bannerForeground: Maui.ColorUtils.brightnessForColor(bannerBackground) === Maui.ColorUtils.Light ? "#20202a" : "#ffffff"
                                    property color bannerSecondaryForeground: Maui.ColorUtils.tintWithAlpha(bannerForeground, bannerBackground, 0.55)
                                    readonly property bool paletteSourceReady: visible && Window.window && Window.window.visible && screenshotImage.status === Image.Ready
                                    readonly property real previewWidth: Math.max(Maui.Style.units.gridUnit * 24, Math.min(Maui.Style.units.gridUnit * 48, featuredSlide.width * 0.5))

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Maui.Style.radiusV
                                        color: featuredSlide.bannerBackground
                                        border.color: Maui.ColorUtils.tintWithAlpha(featuredSlide.bannerBackground, featuredSlide.bannerForeground, 0.18)
                                        border.width: 1
                                        clip: true

                                        Maui.ImageColors {
                                            id: bannerColors
                                            source: featuredSlide.paletteSourceReady ? screenshotImage : null
                                            fallbackDominant: model.accent
                                            fallbackForeground: Maui.Theme.textColor
                                            fallbackBackground: Maui.Theme.backgroundColor
                                        }

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
                                            anchors.centerIn: parent
                                            height: parent.height - Maui.Style.space.medium * 2
                                            spacing: Maui.Style.space.big

                                            ColumnLayout {
                                                Layout.fillHeight: true
                                                Layout.preferredWidth: Maui.Style.units.gridUnit * 10
                                                Layout.minimumWidth: 0
                                                spacing: Maui.Style.space.small

                                                Maui.IconItem {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    width: Maui.Style.iconSizes.huge
                                                    height: Maui.Style.iconSizes.huge
                                                    iconSizeHint: Maui.Style.iconSizes.huge
                                                    imageSource: model.iconUrl
                                                    iconSource: model.icon
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: model.name
                                                    color: featuredSlide.bannerForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    font: Maui.Style.h2Font
                                                    elide: Text.ElideRight
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: model.summary
                                                    color: featuredSlide.bannerSecondaryForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                }

                                                Maui.Chip {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: model.category
                                                    enabled: false
                                                    hoverEnabled: false
                                                    color: Qt.rgba(0, 0, 0, 0.3)
                                                    label.font.weight: Font.Medium
                                                }

                                            }

                                            Rectangle {
                                                id: screenshotFrame
                                                Layout.fillHeight: true
                                                Layout.preferredWidth: featuredSlide.previewWidth
                                                Layout.minimumWidth: 0
                                                color: Maui.ColorUtils.tintWithAlpha(featuredSlide.bannerBackground, featuredSlide.bannerForeground, 0.08)
                                                radius: Maui.Style.radiusV
                                                border.color: Maui.ColorUtils.tintWithAlpha(featuredSlide.bannerBackground, featuredSlide.bannerForeground, 0.32)
                                                border.width: 1
                                                clip: true
                                                Image {
                                                    id: screenshotImage
                                                    anchors.fill: parent
                                                    anchors.margins: screenshotFrame.border.width
                                                    source: model.screenshot
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                    visible: status === Image.Ready
                                                    onStatusChanged: if (status === Image.Ready) bannerColors.update()
                                                    layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                                    layer.effect: MultiEffect {
                                                        maskEnabled: true
                                                        maskThresholdMin: 0.5
                                                        maskSpreadAtMin: 1.0
                                                        maskSpreadAtMax: 0.0
                                                        maskThresholdMax: 1.0
                                                        maskSource: ShaderEffectSource {
                                                            sourceItem: Rectangle {
                                                                width: screenshotImage.width
                                                                height: screenshotImage.height
                                                                radius: screenshotFrame.radius
                                                            }
                                                        }
                                                    }
                                                }

                                                Label {
                                                    anchors.centerIn: parent
                                                    width: parent.width - Maui.Style.space.big * 2
                                                    text: model.screenshotCaption
                                                    color: featuredSlide.bannerSecondaryForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.WordWrap
                                                    visible: !screenshotImage.visible
                                                }
                                            }
                                        }
                                    }
                                }
                        }

                        Timer {
                            id: featuredRotationTimer
                            interval: 6500
                            repeat: true
                            running: featuredCarouselFrame.visible && featuredCarousel.count > 1
                            onTriggered: featuredCarousel.currentIndex = featuredCarousel.nextRandomIndex()
                        }

                        ToolButton {
                            anchors.left: parent.left
                            anchors.leftMargin: Maui.Style.space.small
                            anchors.verticalCenter: parent.verticalCenter
                            z: 2
                            icon.name: "go-previous"
                            display: ToolButton.IconOnly
                            Accessible.name: qsTr("Previous featured application")
                            onClicked: featuredCarousel.currentIndex = featuredCarousel.nextRandomIndex()
                        }

                        ToolButton {
                            anchors.right: parent.right
                            anchors.rightMargin: Maui.Style.space.small
                            anchors.verticalCenter: parent.verticalCenter
                            z: 2
                            icon.name: "go-next"
                            display: ToolButton.IconOnly
                            Accessible.name: qsTr("Next featured application")
                            onClicked: featuredCarousel.currentIndex = featuredCarousel.nextRandomIndex()
                        }
                    }
                }
            }

        }
    }

    Component {
        id: installedViewComponent

        Maui.ScrollColumn {
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

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
                padding: 0
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
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

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
                padding: 0
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
