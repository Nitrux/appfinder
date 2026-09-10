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

    background: null
    headBar.visible: false

    property bool installedView: false
    property string selectedInstalledAppBox: ""

    function contrastingForeground(background) {
        const effectiveBackground = background.a > 0
                                  ? background
                                  : control.Maui.Theme.alternateBackgroundColor
        return Maui.ColorUtils.brightnessForColor(effectiveBackground) === Maui.ColorUtils.Light
               ? "#333333"
               : "#fafafa"
    }

    onInstalledViewChanged: appHub.appHubInstalledOnly = installedView
    Component.onCompleted: appHub.appHubInstalledOnly = installedView
    Component.onDestruction: appHub.appHubInstalledOnly = false

    Maui.SettingsDialog {
        id: appHubRestoreDialog

        property string applicationIdentifier: ""
        property string applicationName: ""

        Maui.Controls.title: qsTr("Restore AppBox")
        persistent: true

        Maui.SectionGroup {
            title: appHubRestoreDialog.applicationName
            description: qsTr("Select a backup version to restore.")

            Repeater {
                model: appHub.appHubBackupsModel

                delegate: Maui.FlexSectionItem {
                    flat: false
                    iconSource: model.icon
                    iconSizeHint: Maui.Style.iconSizes.big
                    label1.text: qsTr("Version %1").arg(model.version)
                    label1.font.weight: Font.DemiBold
                    label1.elide: Text.ElideRight
                    label2.text: model.created.length > 0
                                 ? qsTr("Backup created %1").arg(model.created)
                                 : qsTr("Available backup")
                    label2.elide: Text.ElideRight

                    ToolButton {
                        text: qsTr("Restore")
                        icon.name: "document-revert"
                        display: ToolButton.IconOnly
                        enabled: !appHub.busy
                        ToolTip.visible: hovered
                        ToolTip.text: text
                        onClicked: {
                            appHub.restoreAppHubBackup(appHubRestoreDialog.applicationIdentifier,
                                                      model.identifier)
                            appHubRestoreDialog.close()
                        }
                    }
                }
            }

            Maui.FlexSectionItem {
                visible: appHub.appHubBackupsModel.count === 0
                flat: true
                label1.text: qsTr("No Backups Available")
                label2.text: qsTr("This AppBox does not have a backup to restore.")
                label2.wrapMode: Text.Wrap
            }
        }
    }

    Maui.ScrollColumn {
        id: appHubScroll
        anchors.fill: parent
        padding: Maui.Style.contentMargins
        spacing: Maui.Style.space.small

        function forwardGridWheel(wheel) {
            const usePixelDelta = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
            const horizontalDelta = usePixelDelta ? wheel.pixelDelta.x : wheel.angleDelta.x
            const verticalDelta = usePixelDelta ? wheel.pixelDelta.y : wheel.angleDelta.y

            if (Math.abs(verticalDelta) < Math.abs(horizontalDelta)) {
                wheel.accepted = false
                return
            }

            const pageFlickable = appHubScroll.flickable
            const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
            pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
            wheel.accepted = true
        }

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: control.installedView ? qsTr("Installed AppBoxes") : qsTr("Explore NX AppHub")
            text2: control.installedView ? qsTr("Manage AppBoxes installed on this system.") : qsTr("Build AppBoxes to extend Nitrux.")
            label2.wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            visible: !control.installedView && appHub.appHubFeaturedModel.count > 0
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: appHubFeaturedLayout.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: appHubFeaturedLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Featured")
                    text2: qsTr("A random selection from the local NX AppHub catalog.")
                    label2.wrapMode: Text.Wrap
                }

                Item {
                    id: appHubFeaturedFrame
                    Layout.fillWidth: true
                    Layout.preferredHeight: width < Maui.Style.units.gridUnit * 42
                                            ? Maui.Style.units.gridUnit * 13
                                            : Maui.Style.units.gridUnit * 16
                    clip: true

                    Item {
                        id: appHubFeaturedCarousel
                        anchors.fill: parent
                        clip: true

                        property int count: appHub.appHubFeaturedModel.count
                        property int currentIndex: 0
                        property bool randomized: false

                        function nextRandomIndex() {
                            if (count < 2)
                                return currentIndex

                            let nextIndex = currentIndex
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
                            if (appHubFeaturedTimer.running)
                                appHubFeaturedTimer.restart()
                        }

                        Repeater {
                            model: appHub.appHubFeaturedModel

                            delegate: Item {
                                id: appHubFeaturedSlide
                                anchors.fill: parent
                                readonly property bool currentSlide: index === appHubFeaturedCarousel.currentIndex
                                readonly property color bannerBackground: Maui.ColorUtils.tintWithAlpha(Maui.Theme.alternateBackgroundColor,
                                                                                                        Maui.Theme.highlightColor,
                                                                                                        0.28)
                                readonly property color bannerForeground: Maui.ColorUtils.brightnessForColor(bannerBackground) === Maui.ColorUtils.Light
                                                                           ? "#20202a"
                                                                           : "#ffffff"
                                readonly property color bannerSecondaryForeground: Maui.ColorUtils.tintWithAlpha(bannerForeground,
                                                                                                                  bannerBackground,
                                                                                                                  0.55)

                                opacity: currentSlide ? 1 : 0
                                z: currentSlide ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Maui.Style.units.longDuration
                                        easing.type: Easing.InOutQuad
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Maui.Style.radiusV
                                    color: appHubFeaturedSlide.bannerBackground
                                    border.color: Maui.ColorUtils.tintWithAlpha(appHubFeaturedSlide.bannerBackground,
                                                                               appHubFeaturedSlide.bannerForeground,
                                                                               0.18)
                                    border.width: 1

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        width: Math.min(parent.width - Maui.Style.contentMargins * 2,
                                                        Maui.Style.units.gridUnit * 32)
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
                                            color: appHubFeaturedSlide.bannerForeground
                                            horizontalAlignment: Text.AlignHCenter
                                            font: Maui.Style.h2Font
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.description.length > 0 ? model.description : model.summary
                                            color: appHubFeaturedSlide.bannerSecondaryForeground
                                            horizontalAlignment: Text.AlignHCenter
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                        }

                                        Maui.Chip {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: model.type.length > 0 ? model.type : model.integration
                                            visible: text.length > 0
                                            enabled: false
                                            hoverEnabled: false
                                            color: Qt.rgba(0, 0, 0, 0.3)
                                            label.font.weight: Font.Medium
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: appHubFeaturedTimer
                        interval: 6500
                        repeat: true
                        running: appHubFeaturedFrame.visible && appHubFeaturedCarousel.count > 1
                        onTriggered: appHubFeaturedCarousel.currentIndex = appHubFeaturedCarousel.nextRandomIndex()
                    }
                }
            }
        }

        Maui.TabBar {
            id: appHubTabs
            Layout.fillWidth: true
            Layout.maximumWidth: Maui.Style.units.gridUnit * 40
            implicitWidth: Maui.Style.units.gridUnit * 40
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Maui.Style.space.medium
            Layout.bottomMargin: Maui.Style.space.medium
            visible: !control.installedView
            showNewTabButton: false
            Maui.Controls.showCSD: false
            currentIndex: appHub.appHubCategories.indexOf(appHub.appHubCategory)
            clip: true

            readonly property int tabCount: Math.max(1, appHub.appHubCategories.length)
            readonly property real uniformTabWidth: Math.max(0, (width - leftPadding - rightPadding - spacing * (tabCount - 1)) / tabCount)

            onCurrentIndexChanged: {
                if (currentIndex >= 0 && currentIndex < appHub.appHubCategories.length)
                    appHub.appHubCategory = appHub.appHubCategories[currentIndex]
            }

            background: Rectangle {
                color: Maui.Theme.alternateBackgroundColor
                radius: height / 2
            }

            Repeater {
                model: appHub.appHubCategories

                delegate: Maui.TabButton {
                    required property string modelData
                    width: appHubTabs.uniformTabWidth
                    text: modelData
                    closeButtonVisible: false
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: installedAppBoxBrowser.holder.visible
                                    ? Math.max(implicitHeight, appHubScroll.availableHeight - y)
                                    : implicitHeight
            visible: control.installedView
            color: Maui.Theme.alternateBackgroundColor
            radius: Maui.Style.radiusV
            border.color: Maui.Theme.backgroundColor
            border.width: 1
            implicitHeight: installedAppBoxLayout.implicitHeight + Maui.Style.contentMargins * 2

            ColumnLayout {
                id: installedAppBoxLayout
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                spacing: Maui.Style.space.small

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Installed AppBoxes (%1)").arg(appHub.appHubModel.count)
                    text2: qsTr("AppBoxes installed on this system.")
                    label2.wrapMode: Text.Wrap
                }

                Maui.ListBrowser {
                    id: installedAppBoxBrowser
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalScrollBarPolicy: ScrollBar.AlwaysOff
                    padding: 0
                    clip: true
                    model: appHub.appHubModel

                    holder.visible: count === 0
                    holder.title: qsTr("No AppBoxes Installed")
                    holder.body: qsTr("Build an AppBox to see it here.")

                    delegate: Maui.ListBrowserDelegate {
                        id: installedAppBoxDelegate
                        width: ListView.view.width
                        isCurrentItem: control.selectedInstalledAppBox === model.identifier
                        onClicked: {
                            ListView.view.currentIndex = index
                            control.selectedInstalledAppBox = model.identifier
                        }
                        iconSource: model.icon
                        iconSizeHint: Maui.Style.iconSizes.big
                        template.leftLabels.spacing: Maui.Style.space.small
                        label1.text: model.name
                        label1.font.weight: Font.DemiBold
                        label1.elide: Text.ElideRight
                        label2.text: model.description.length > 0 ? model.description : model.summary
                        label2.elide: Text.ElideRight

                        ToolButton {
                            visible: appHub.appHubHasBackups(model.identifier)
                            text: qsTr("Restore Backup")
                            icon.name: "document-revert"
                            icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : installedAppBoxDelegate.effectiveBackgroundColor))
                            display: ToolButton.IconOnly
                            enabled: !appHub.busy
                            ToolTip.visible: hovered
                            ToolTip.text: text
                            onClicked: {
                                appHubRestoreDialog.applicationIdentifier = model.identifier
                                appHubRestoreDialog.applicationName = model.name
                                appHub.loadAppHubBackups(model.identifier)
                                appHubRestoreDialog.open()
                            }
                        }

                        ToolButton {
                            text: qsTr("Remove")
                            icon.name: "edit-delete"
                            icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : installedAppBoxDelegate.effectiveBackgroundColor))
                            display: ToolButton.IconOnly
                            enabled: !appHub.busy
                            ToolTip.visible: hovered
                            ToolTip.text: text
                            onClicked: appHub.appHubAction(model.identifier)
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        propagateComposedEvents: true
                        scrollGestureEnabled: false
                        z: 100
                        onWheel: (wheel) => appHubScroll.forwardGridWheel(wheel)
                    }
                }
            }
        }

        Maui.GridBrowser {
            id: appHubGrid
            visible: !control.installedView
            readonly property real availableLayoutWidth: parent ? parent.width : 0
            readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

            Layout.fillWidth: holder.visible
            Layout.preferredWidth: holder.visible ? availableLayoutWidth : Math.min(availableLayoutWidth, itemSize * fittedColumns)
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: holder.visible ? Math.max(holder.implicitHeight, appHubScroll.availableHeight - y) : contentHeight
            padding: 0
            itemSize: Maui.Style.units.gridUnit * 17
            itemHeight: Maui.Style.units.gridUnit * 6
            adaptContent: true
            wheelResizeEnabled: false
            pinchEnabled: false
            verticalScrollBarPolicy: ScrollBar.AlwaysOff
            model: appHub.appHubModel
            flickable.interactive: false

            holder.visible: count === 0
            holder.title: control.installedView ? qsTr("No AppBoxes installed") : qsTr("No AppBoxes in this group")
            holder.body: control.installedView ? qsTr("Build an AppBox to see it here.") : qsTr("Refresh the local NX AppHub repository or adjust the search.")

            delegate: Item {
                id: extensionCard
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight
                Maui.ListBrowserDelegate {
                    anchors.fill: parent
                    anchors.margins: Maui.Style.space.small
                    flat: false
                    iconSource: model.icon
                    iconSizeHint: Maui.Style.iconSizes.big
                    template.leftLabels.spacing: Maui.Style.space.small
                    label1.text: model.name
                    label1.font.weight: Font.DemiBold
                    label1.elide: Text.ElideRight
                    label2.text: model.description.length > 0 ? model.description : model.summary
                    label2.wrapMode: Text.WordWrap
                    label2.maximumLineCount: 2
                    label2.elide: Text.ElideRight

                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                scrollGestureEnabled: false
                z: 100
                onWheel: (wheel) => appHubScroll.forwardGridWheel(wheel)
            }
        }

    }
}
