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

    onInstalledViewChanged: appHub.appHubInstalledOnly = installedView
    Component.onCompleted: appHub.appHubInstalledOnly = installedView
    Component.onDestruction: appHub.appHubInstalledOnly = false

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

        Maui.GridBrowser {
            id: appHubGrid
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
                readonly property bool installed: model.status === "Active Extension" || model.actionText === "Remove"

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

                    RowLayout {
                        spacing: Maui.Style.space.small

                        ToolButton {
                            visible: extensionCard.installed
                            text: qsTr("Rebuild")
                            icon.name: "view-refresh"
                            display: ToolButton.IconOnly
                            enabled: !appHub.busy
                            ToolTip.visible: hovered
                            ToolTip.text: text
                            onClicked: appHub.rebuildAppHub(model.identifier)
                        }

                        ToolButton {
                            visible: extensionCard.installed
                            text: qsTr("Remove")
                            icon.name: "edit-delete"
                            display: ToolButton.IconOnly
                            enabled: !appHub.busy
                            ToolTip.visible: hovered
                            ToolTip.text: text
                            onClicked: appHub.appHubAction(model.identifier)
                        }
                    }
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
