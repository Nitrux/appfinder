/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
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
                visible: appHub.flathubFeaturedModel.count > 0
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

                        Item {
                            id: featuredCarousel
                            anchors.fill: parent
                            clip: true

                            property int count: appHub.flathubFeaturedModel.count
                            property int currentIndex: 0
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
                                if (count <= 0) {
                                    currentIndex = 0
                                    randomized = false
                                    return
                                }

                                if (currentIndex >= count)
                                    currentIndex = 0

                                if (!randomized && count > 1) {
                                    randomized = true
                                    currentIndex = Math.floor(Math.random() * count)
                                }
                            }

                            onCurrentIndexChanged: {
                                if (featuredRotationTimer.running)
                                    featuredRotationTimer.restart()
                            }

                            Repeater {
                                id: featuredRepeater
                                model: appHub.flathubFeaturedModel

                                delegate: Item {
                                    id: featuredSlide
                                    anchors.fill: parent
                                    property bool currentSlide: index === featuredCarousel.currentIndex
                                    opacity: currentSlide ? 1 : 0
                                    z: currentSlide ? 1 : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Maui.Style.units.longDuration
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    property color bannerAccent: model.accentColor.length > 0 ? model.accentColor : Maui.Theme.alternateBackgroundColor
                                    property color bannerBackground: Maui.ColorUtils.tintWithAlpha(Maui.Theme.alternateBackgroundColor, bannerAccent, 0.28)
                                    property color bannerForeground: Maui.ColorUtils.brightnessForColor(bannerBackground) === Maui.ColorUtils.Light ? "#20202a" : "#ffffff"
                                    property color bannerSecondaryForeground: Maui.ColorUtils.tintWithAlpha(bannerForeground, bannerBackground, 0.55)
                                    readonly property real iconGroupWidth: Maui.Style.units.gridUnit * 10
                                    readonly property real previewMaximumWidth: Math.max(0, (featuredSlide.height - Maui.Style.space.medium * 2) * 5 / 2)
                                    readonly property real previewWidth: Math.max(0, Math.min(previewMaximumWidth, featuredSlide.width * 3 / 5))

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Maui.Style.radiusV
                                        color: featuredSlide.bannerBackground
                                        border.color: Maui.ColorUtils.tintWithAlpha(featuredSlide.bannerBackground, featuredSlide.bannerForeground, 0.18)
                                        border.width: 1
                                        clip: true

                                        RowLayout {
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.topMargin: Maui.Style.space.medium
                                            anchors.bottomMargin: Maui.Style.space.medium
                                            width: Math.min(parent.width - Maui.Style.contentMargins * 2, Maui.Style.units.gridUnit * 64)
                                            spacing: Maui.Style.space.big

                                            ColumnLayout {
                                                Layout.fillHeight: true
                                                Layout.fillWidth: true
                                                Layout.preferredWidth: featuredSlide.iconGroupWidth
                                                Layout.minimumWidth: 0
                                                spacing: Maui.Style.space.small

                                                Maui.IconItem {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    width: Maui.Style.iconSizes.huge
                                                    height: Maui.Style.iconSizes.huge
                                                    iconSizeHint: Maui.Style.iconSizes.huge
                                                    id: appIcon
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
                                                visible: featuredSlide.width >= Maui.Style.units.gridUnit * 42
                                                Layout.fillHeight: true
                                                Layout.fillWidth: false
                                                Layout.minimumWidth: featuredSlide.previewWidth
                                                Layout.preferredWidth: featuredSlide.previewWidth
                                                Layout.maximumWidth: featuredSlide.previewWidth
                                                color: "transparent"
                                                radius: Maui.Style.radiusV
                                                border.color: "transparent"
                                                border.width: 0
                                                clip: true
                                                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                                                layer.effect: MultiEffect {
                                                    maskEnabled: true
                                                    maskThresholdMin: 0.5
                                                    maskSpreadAtMin: 1.0
                                                    maskSpreadAtMax: 0.0
                                                    maskThresholdMax: 1.0
                                                    maskSource: ShaderEffectSource {
                                                        sourceItem: Rectangle {
                                                            width: screenshotFrame.width
                                                            height: screenshotFrame.height
                                                            radius: screenshotFrame.radius
                                                        }
                                                    }
                                                }

                                                Image {
                                                    id: screenshotImage
                                                    anchors.fill: parent
                                                    source: model.screenshot
                                                    fillMode: Image.PreserveAspectCrop
                                                    verticalAlignment: Image.AlignTop
                                                    asynchronous: true
                                                    cache: true
                                                    visible: status === Image.Ready
                                                }

                                                Label {
                                                    anchors.centerIn: parent
                                                    width: parent.width - Maui.Style.space.big * 2
                                                    text: model.screenshotCaption.length > 0 ? model.screenshotCaption : model.summary
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
                        }

                        Timer {
                            id: featuredRotationTimer
                            interval: 6500
                            repeat: true
                            running: featuredCarouselFrame.visible && featuredCarousel.count > 1
                            onTriggered: featuredCarousel.currentIndex = featuredCarousel.nextRandomIndex()
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

}
