/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ScrollColumn {
    id: control

    property var sourceModel
    property string query: ""
    property string sourceTitle: ""
    property string sourceDescription: ""
    property string emptyTitle: qsTr("No results")
    property string emptyBody: qsTr("Try a different search query.")
    property bool previewEnabled: false
    property bool busy: false
    property string operationPrefix: ""
    property Component delegateComponent: null
    readonly property bool searching: control.busy && (!control.sourceModel || control.sourceModel.count === 0)
    readonly property real targetItemSize: Maui.Style.units.gridUnit * 18
    readonly property real minimumItemSize: Maui.Style.units.gridUnit * 14
    readonly property real maximumItemSize: Maui.Style.units.gridUnit * 24
    property var actionHandler: null
    property var detailHandler: null
    property var secondaryActionHandler: null
    property var actionTextResolver: function(item) { return item && item.actionText ? String(item.actionText) : "" }
    property var secondaryActionVisibleResolver: function(item) { return false }
    property var secondaryActionTextResolver: function(item) { return "" }
    property var secondaryActionIconResolver: function(item) { return "" }

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

        const pageFlickable = control.flickable
        const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
        pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
        wheel.accepted = true
    }

    Maui.SectionHeader {
        Layout.fillWidth: true
        text1: qsTr("Search Results")
        text2: control.sourceDescription.length > 0
               ? qsTr("%1 Results for \"%2\".").arg(control.sourceDescription).arg(control.query)
               : qsTr("Results for \"%1\" in %2.").arg(control.query).arg(control.sourceTitle)
        label2.wrapMode: Text.Wrap
    }

    Maui.GridBrowser {
                id: resultsGrid
                readonly property real availableLayoutWidth: control.availableWidth
                readonly property int fittedColumns: Math.max(1, Math.min(count, Math.floor(availableLayoutWidth / control.targetItemSize)))
                readonly property real fittedItemSize: Math.max(control.minimumItemSize,
                                                                 Math.min(control.maximumItemSize,
                                                                          availableLayoutWidth / fittedColumns))

                Layout.fillWidth: holder.visible
                Layout.preferredWidth: holder.visible ? availableLayoutWidth : Math.min(availableLayoutWidth, fittedItemSize * fittedColumns)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: holder.visible ? Math.max(holder.implicitHeight, control.availableHeight - y) : contentHeight
                padding: 0
                itemSize: fittedItemSize
                itemHeight: control.previewEnabled ? itemSize + Maui.Style.rowHeight : itemSize * 9 / 20
                adaptContent: true
                wheelResizeEnabled: false
                pinchEnabled: false
                verticalScrollBarPolicy: ScrollBar.AlwaysOff
                model: control.sourceModel
                flickable.interactive: false

                holder.visible: control.searching || !control.sourceModel || control.sourceModel.count === 0
                holder.title: control.searching ? qsTr("Searching…") : control.emptyTitle
                holder.body: control.searching ? qsTr("Fetching search results.") : control.emptyBody
                holder.content: Maui.ProgressIndicator {
                    visible: control.searching
                    width: control.width * 0.7
                }

                delegate: control.delegateComponent ? control.delegateComponent : defaultDelegate

                Component {
                    id: defaultDelegate

                    Item {
                    id: resultDelegate
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    readonly property string itemAccentColor: model && model.accentColor ? String(model.accentColor) : ""
                    readonly property string itemIconUrl: model && model.iconUrl ? String(model.iconUrl) : ""
                    readonly property string itemIcon: model && model.icon ? String(model.icon) : ""
                    readonly property string itemScreenshot: model && model.screenshot ? String(model.screenshot) : ""
                    readonly property string itemName: model && model.name ? String(model.name) : ""
                    readonly property string itemSummary: model && model.summary ? String(model.summary) : ""
                    readonly property string itemIdentifier: model && model.identifier ? String(model.identifier) : ""
                    readonly property string itemStatus: model && model.status ? String(model.status) : ""
                    readonly property color previewBackground: resultDelegate.itemAccentColor.length > 0
                                                               ? Maui.ColorUtils.tintWithAlpha(Maui.Theme.alternateBackgroundColor,
                                                                                                resultDelegate.itemAccentColor,
                                                                                                0.45)
                                                               : Maui.Theme.backgroundColor
                    readonly property string primaryActionText: control.actionTextResolver(model)
                    readonly property string displayActionText: primaryActionText.length > 0
                                                                && appHub.operationAction.startsWith(control.operationPrefix)
                                                                && control.operationPrefix.length > 0
                                                                && appHub.operationIdentifier === itemIdentifier
                                                                ? appHub.operationLabel : primaryActionText
                    readonly property bool secondaryActionVisible: control.secondaryActionVisibleResolver(model)
                    readonly property bool statusPositive: resultDelegate.itemStatus === "Installed" || resultDelegate.itemStatus === "Active"
                                                       || resultDelegate.itemStatus.toLowerCase().indexOf("up") >= 0
                                                       || resultDelegate.itemStatus.toLowerCase().indexOf("running") >= 0
                    readonly property bool itemRunning: {
                        const status = resultDelegate.itemStatus.toLowerCase()
                        return status.indexOf("up") >= 0 || status.indexOf("running") >= 0
                    }

                    Maui.GridBrowserDelegate {
                        id: resultCard
                        width: Math.min(resultsGrid.itemWidth, parent.width - Maui.Style.space.small * 2)
                        height: Math.min(resultsGrid.itemHeight, parent.height - Maui.Style.space.small * 2)
                        anchors.centerIn: parent
                        flat: false
                        selectedBackgroundColor: Maui.Theme.alternateBackgroundColor
                        selectedForegroundColor: Maui.Theme.textColor
                        isCurrentItem: false
                        onClicked: {
                            if (control.detailHandler)
                                control.detailHandler(resultDelegate.itemIdentifier, model)
                        }
                        template.labelsVisible: false
                        template.iconComponent: Component {
                            Item {
                                anchors.fill: parent
                                clip: true

                                ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Item {
                                visible: control.previewEnabled
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: Math.min(width * 3 / 5, Maui.Style.units.gridUnit * 12)
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: resultDelegate.previewBackground
                                }

                                Image {
                                    id: previewImage
                                    anchors.fill: parent
                                    source: resultDelegate.itemScreenshot
                                    fillMode: Image.PreserveAspectCrop
                                    verticalAlignment: Image.AlignTop
                                    asynchronous: true
                                    cache: true
                                    visible: status === Image.Ready
                                }

                                Maui.IconItem {
                                    anchors.centerIn: parent
                                    width: Maui.Style.iconSizes.huge
                                    height: Maui.Style.iconSizes.huge
                                    iconSizeHint: Maui.Style.iconSizes.huge
                                    imageSource: resultDelegate.itemIconUrl
                                    iconSource: resultDelegate.itemIcon
                                    visible: !previewImage.visible
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: false
                                Layout.margins: Maui.Style.space.medium
                                spacing: Maui.Style.space.big

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Maui.Style.space.medium

                                    Maui.IconItem {
                                        Layout.preferredWidth: Maui.Style.iconSizes.big
                                        Layout.preferredHeight: Maui.Style.iconSizes.big
                                        iconSizeHint: Maui.Style.iconSizes.big
                                        maskRadius: Maui.Style.radiusV
                                        imageSource: resultDelegate.itemIconUrl
                                        iconSource: resultDelegate.itemIcon
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        spacing: Maui.Style.space.small

                                        Label {
                                            Layout.fillWidth: true
                                            text: resultDelegate.itemName
                                            font: Maui.Style.h2Font
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: resultDelegate.itemSummary.length > 0 ? resultDelegate.itemSummary : resultDelegate.itemIdentifier
                                            color: Maui.Theme.disabledTextColor
                                            maximumLineCount: 2
                                            wrapMode: Text.WordWrap
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Maui.Style.space.small

                                    AppFinderChip {
                                        visible: resultDelegate.itemStatus.length > 0 && resultDelegate.itemStatus.toLowerCase() !== "available"
                                        text: resultDelegate.itemStatus
                                    }

                                    Item { Layout.fillWidth: true }

                                    Button {
                                        visible: resultDelegate.primaryActionText.length > 0
                                        Layout.minimumWidth: Maui.Style.units.gridUnit * 5
                                        text: resultDelegate.displayActionText
                                        display: Button.TextOnly
                                        flat: false
                                        Maui.Controls.status: {
                                            const action = resultDelegate.primaryActionText.toLowerCase()
                                            return action === "install" || action === "build" || action === "activate" ? Maui.Controls.Positive
                                                   : action === "remove" ? Maui.Controls.Negative
                                                                         : Maui.Controls.Normal
                                        }
                                        enabled: !control.busy
                                        onClicked: {
                                            if (control.actionHandler)
                                                control.actionHandler(resultDelegate.itemIdentifier, model)
                                        }
                                    }

                                    ToolButton {
                                        visible: resultDelegate.secondaryActionVisible
                                        icon.name: control.secondaryActionIconResolver(model)
                                        display: ToolButton.IconOnly
                                        flat: false
                                        enabled: !control.busy && !resultDelegate.itemRunning
                                        ToolTip.visible: hovered
                                        ToolTip.text: control.secondaryActionTextResolver(model)
                                        onClicked: {
                                            if (control.secondaryActionHandler)
                                                control.secondaryActionHandler(resultDelegate.itemIdentifier, model)
                                        }
                                    }
                                }
                            }
                        }

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: resultCard.radius
                                    border.color: resultCard.isCurrentItem ? Maui.Theme.highlightColor : "transparent"
                                    border.width: resultCard.isCurrentItem ? 1 : 0
                                }
                            }
                        }
                    }
                }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    scrollGestureEnabled: true
                    z: 100
                    onWheel: (wheel) => control.forwardGridWheel(wheel)
                }
            }
}
