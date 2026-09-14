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

    property var itemData: null
    property string sourceTitle: ""
    property var actionHandler: null
    property var actionTextResolver: function(item) {
        return item && item.actionText ? String(item.actionText) : qsTr("Install")
    }
    property bool busy: false
    property bool showFlathubLinks: false
    property bool releasesExpanded: false
    signal backRequested()
    signal similarRequested(var item)

    readonly property string itemName: control.value("name") || control.value("identifier") || qsTr("Application")
    readonly property string itemSummary: control.value("summary")
    readonly property string itemDeveloper: control.value("developer") || control.sourceTitle
    readonly property string itemDescription: control.value("description") || control.itemSummary
    readonly property string itemIdentifier: control.value("identifier")
    readonly property string itemVersion: control.value("version")
    readonly property string itemArchitecture: control.value("architecture")
    readonly property string itemCategory: control.value("category")
    readonly property string itemSize: control.value("size")
    readonly property string itemBaseImage: control.value("baseImage")
    readonly property string itemIntegration: control.value("integration")
    readonly property string itemLicense: control.value("license")
    readonly property string itemHomepage: control.value("homepage")
    readonly property string itemRuntime: control.value("runtime") || control.value("type")
    readonly property string itemIconUrl: control.value("iconUrl")
    readonly property string itemIcon: control.value("icon")
    readonly property string itemScreenshot: control.value("screenshot")
    readonly property var itemScreenshots: {
        const values = control.listValue("screenshots")
        return values.length > 0 ? values : control.itemScreenshot.length > 0 ? [control.itemScreenshot] : []
    }
    readonly property var itemReleases: control.objectListValue("releases")
    readonly property var itemSimilarApps: control.objectListValue("similarApps")
    readonly property var itemLinks: {
        const links = []
        if (!control.showFlathubLinks)
            return links
        if (control.itemIdentifier.length > 0)
            links.push({ title: qsTr("Flathub Page"), url: "https://flathub.org/apps/" + control.itemIdentifier, icon: "applications-internet" })
        if (control.itemHomepage.length > 0)
            links.push({ title: qsTr("Project Website"), url: control.itemHomepage, icon: "globe" })
        return links
    }
    readonly property var itemScreenshotEntries: {
        const entries = []
        for (let index = 0; index < control.itemScreenshots.length; ++index)
            entries.push({ source: String(control.itemScreenshots[index]) })
        return entries
    }
    readonly property string actionText: control.actionTextResolver(control.itemData)
    readonly property int actionStatus: {
        const action = control.actionText.toLowerCase()
        return action === "install" ? Maui.Controls.Positive
               : action === "remove" ? Maui.Controls.Negative
                                       : Maui.Controls.Normal
    }

    function value(name) {
        if (!control.itemData)
            return ""

        const value = control.itemData[name]
        return value === undefined || value === null ? "" : String(value).trim()
    }

    function listValue(name) {
        if (!control.itemData)
            return []

        const value = control.itemData[name]
        if (value === undefined || value === null)
            return []
        if (typeof value === "string")
            return value.trim().length > 0 ? [value.trim()] : []
        if (typeof value.length !== "undefined") {
            const result = []
            for (let index = 0; index < value.length; ++index)
                result.push(String(value[index]).trim())
            return result.filter(entry => entry.length > 0)
        }
        return [String(value).trim()]
    }

    function objectListValue(name) {
        if (!control.itemData)
            return []

        const value = control.itemData[name]
        if (value === undefined || value === null || typeof value.length === "undefined")
            return []

        const result = []
        for (let index = 0; index < value.length; ++index) {
            if (value[index] !== undefined && value[index] !== null)
                result.push(value[index])
        }
        return result
    }

    function releaseDate(timestamp) {
        const seconds = Number(timestamp)
        if (!Number.isFinite(seconds) || seconds <= 0)
            return qsTr("Date unavailable")
        return Qt.formatDate(new Date(seconds * 1000), Qt.DefaultLocaleShortDate)
    }

    function forwardGridWheel(wheel) {
        const usePixelDelta = wheel.angleDelta.x === 0 && wheel.angleDelta.y === 0
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

    padding: Maui.Style.contentMargins
    spacing: Maui.Style.space.medium

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerLayout.implicitHeight + Maui.Style.contentMargins * 2
        radius: Maui.Style.radiusV
        color: Maui.Theme.alternateBackgroundColor

        ColumnLayout {
            id: headerLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Maui.Style.space.big

                Maui.IconItem {
                    Layout.preferredWidth: Maui.Style.iconSizes.huge
                    Layout.preferredHeight: Maui.Style.iconSizes.huge
                    iconSizeHint: Maui.Style.iconSizes.huge
                    maskRadius: Maui.Style.radiusV
                    imageSource: control.itemIconUrl
                    iconSource: control.itemIcon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Maui.Style.space.small

                    Label {
                        Layout.fillWidth: true
                        text: control.itemName
                        font: Maui.Style.h1Font
                        wrapMode: Text.WordWrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: control.itemDeveloper
                        color: Maui.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }

                Button {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: Maui.Style.units.gridUnit * 6
                    Layout.minimumHeight: Maui.Style.rowHeight
                    visible: control.actionText.length > 0 && control.actionHandler !== null
                    text: control.actionText
                    display: Button.TextOnly
                    enabled: !control.busy
                    Maui.Controls.status: control.actionStatus
                    onClicked: control.actionHandler(control.itemIdentifier, control.itemData)
                }
            }
        }
    }

    ToolSeparator {
        orientation: Qt.Horizontal
        Layout.fillWidth: true
    }

    GridLayout {
        id: metadataGrid
        Layout.fillWidth: true
        columns: Math.max(1, Math.min(4, Math.floor(width / (Maui.Style.units.gridUnit * 14))))
        columnSpacing: Maui.Style.space.medium
        rowSpacing: Maui.Style.space.medium

        Repeater {
            model: [
                { value: control.itemSize, label: qsTr("Download size"), positive: false },
                { value: control.itemVersion, label: qsTr("Version"), positive: false },
                { value: control.itemCategory, label: qsTr("Category"), positive: false },
                { value: control.itemLicense, label: qsTr("License"), positive: false },
                { value: control.itemArchitecture, label: qsTr("Architecture"), positive: false },
                { value: control.itemRuntime, label: qsTr("Runtime"), positive: false }
            ]

            delegate: Rectangle {
                visible: modelData.value.length > 0
                Layout.fillWidth: true
                Layout.minimumWidth: Maui.Style.units.gridUnit * 10
                Layout.preferredWidth: (metadataGrid.width - metadataGrid.columnSpacing * (metadataGrid.columns - 1))
                                       / metadataGrid.columns
                implicitHeight: statColumn.implicitHeight + Maui.Style.space.medium * 2
                radius: Maui.Style.radiusV
                color: Maui.Theme.alternateBackgroundColor

                ColumnLayout {
                    id: statColumn
                    anchors.fill: parent
                    anchors.margins: Maui.Style.space.medium
                    spacing: Maui.Style.space.small

                    Maui.Chip {
                        Layout.fillWidth: true
                        text: modelData.value
                        color: modelData.positive ? Maui.Theme.positiveBackgroundColor : Maui.Theme.backgroundColor
                        hoverEnabled: false
                        focusPolicy: Qt.NoFocus
                        label.horizontalAlignment: Text.AlignHCenter
                        label.wrapMode: Text.WrapAnywhere
                        label.maximumLineCount: 2
                        label.elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: modelData.label
                        horizontalAlignment: Text.AlignHCenter
                        color: Maui.Theme.disabledTextColor
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    GridLayout {
        id: screenshotsGrid
        Layout.fillWidth: true
        visible: control.itemScreenshotEntries.length > 0
        columns: Math.max(1, Math.min(2, Math.floor(control.availableWidth / (Maui.Style.units.gridUnit * 26))))
        columnSpacing: Maui.Style.space.medium
        rowSpacing: Maui.Style.space.medium

        Repeater {
            model: control.itemScreenshotEntries

            delegate: ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: Maui.Style.units.gridUnit * 14
                Layout.preferredWidth: (screenshotsGrid.width - screenshotsGrid.columnSpacing * (screenshotsGrid.columns - 1))
                                       / screenshotsGrid.columns
                spacing: Maui.Style.space.small

                Rectangle {
                    id: screenshotCard
                    Layout.fillWidth: true
                    implicitHeight: {
                        const contentWidth = Math.max(0, width - Maui.Style.space.small * 2)
                        const imageWidth = screenshotImage.sourceSize.width
                        const imageHeight = screenshotImage.sourceSize.height
                        return imageWidth > 0 && imageHeight > 0
                               ? contentWidth * imageHeight / imageWidth + Maui.Style.space.small * 2
                               : contentWidth * 9 / 16 + Maui.Style.space.small * 2
                    }
                    radius: Maui.Style.radiusV
                    color: Maui.Theme.alternateBackgroundColor
                    clip: true

                    Image {
                        id: screenshotImage
                        anchors.fill: parent
                        anchors.margins: Maui.Style.space.small
                        source: modelData.source
                        sourceSize.width: width
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                    }
                }

            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: aboutColumn.implicitHeight + Maui.Style.contentMargins * 2
        radius: Maui.Style.radiusV
        color: Maui.Theme.alternateBackgroundColor

        ColumnLayout {
            id: aboutColumn
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.medium

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: control.itemSummary.length > 0 ? control.itemSummary : qsTr("Description")
                label1.wrapMode: Text.WrapAnywhere
                text2: control.sourceTitle
                label2.wrapMode: Text.Wrap
            }

            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.leftMargin: Maui.Style.contentMargins
                Layout.rightMargin: Maui.Style.contentMargins
                text: control.itemDescription
                wrapMode: Text.WrapAnywhere
                textFormat: Text.RichText
                color: Maui.Theme.textColor
            }

        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: control.itemReleases.length > 0
        spacing: Maui.Style.space.medium

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Release Notes")
            text2: qsTr("Version history")
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Maui.Style.space.small

            Repeater {
                model: control.releasesExpanded ? control.itemReleases : control.itemReleases.slice(0, 1)

                delegate: Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    padding: Maui.Style.contentMargins * 2
                    flat: false
                    label1.text: modelData.version || qsTr("Release")
                    label1.font.weight: Font.DemiBold
                    label1.elide: Text.ElideRight
                    label2.text: control.releaseDate(modelData.timestamp)
                    label2.color: Maui.Theme.disabledTextColor
                    label2.elide: Text.ElideRight

                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: modelData.description && String(modelData.description).length > 0
                        text: modelData.description || ""
                        textFormat: Text.RichText
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            Button {
                Layout.fillWidth: true
                visible: control.itemReleases.length > 1
                text: control.releasesExpanded ? qsTr("Hide Version History") : qsTr("Version History")
                display: Button.TextOnly
                onClicked: control.releasesExpanded = !control.releasesExpanded
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: control.itemLinks.length > 0
        spacing: Maui.Style.space.small

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Links")
        }

        GridLayout {
            id: linksGrid
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(2, Math.floor(control.availableWidth / (Maui.Style.units.gridUnit * 24))))
            columnSpacing: Maui.Style.space.medium
            rowSpacing: Maui.Style.space.medium

            Repeater {
                model: control.itemLinks

                delegate: Maui.FlexSectionItem {
                    Layout.fillWidth: true
                    Layout.minimumWidth: Maui.Style.units.gridUnit * 16
                    Layout.preferredWidth: (linksGrid.width - linksGrid.columnSpacing * (linksGrid.columns - 1)) / linksGrid.columns
                    flat: false
                    iconSource: modelData.icon
                    iconSizeHint: Maui.Style.iconSizes.small
                    label1.text: modelData.title
                    label1.font.weight: Font.DemiBold
                    label1.elide: Text.ElideRight
                    label2.text: modelData.url
                    label2.color: Maui.Theme.disabledTextColor
                    label2.elide: Text.ElideRight
                    onClicked: Qt.openUrlExternally(modelData.url)
                }
            }
        }
    }

    ColumnLayout {
        id: similarAppsSection
        Layout.fillWidth: true
        visible: control.itemSimilarApps.length > 0
        spacing: Maui.Style.space.small

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Similar Apps")
        }

        Maui.GridBrowser {
            id: similarAppsGrid
            readonly property real availableLayoutWidth: control.availableWidth
            readonly property real targetItemSize: Maui.Style.units.gridUnit * 18
            readonly property real minimumItemSize: Maui.Style.units.gridUnit * 14
            readonly property real maximumItemSize: Maui.Style.units.gridUnit * 24
            readonly property int fittedColumns: Math.max(1, Math.min(count, Math.floor(availableLayoutWidth / targetItemSize)))
            readonly property real fittedItemSize: Math.max(minimumItemSize,
                                                             Math.min(maximumItemSize,
                                                                      availableLayoutWidth / fittedColumns))

            Layout.fillWidth: false
            Layout.preferredWidth: Math.min(availableLayoutWidth, fittedItemSize * fittedColumns)
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: contentHeight
            padding: 0
            itemSize: fittedItemSize
            itemHeight: itemSize * 19 / 20
            adaptContent: true
            wheelResizeEnabled: false
            pinchEnabled: false
            verticalScrollBarPolicy: ScrollBar.AlwaysOff
            model: control.itemSimilarApps
            flickable.interactive: false

            delegate: Item {
                id: similarDelegate
                width: GridView.view.cellWidth
                height: GridView.view.cellHeight

                readonly property string itemAccentColor: modelData.accentColor ? String(modelData.accentColor) : ""
                readonly property string itemIconUrl: modelData.iconUrl ? String(modelData.iconUrl) : ""
                readonly property string itemIcon: modelData.icon ? String(modelData.icon) : ""
                readonly property string itemScreenshot: modelData.screenshot ? String(modelData.screenshot) : ""
                readonly property string itemName: modelData.name ? String(modelData.name) : ""
                readonly property string itemSummary: modelData.summary ? String(modelData.summary) : ""
                readonly property string itemIdentifier: modelData.identifier ? String(modelData.identifier) : ""
                readonly property string itemStatus: modelData.status ? String(modelData.status) : ""
                readonly property string primaryActionText: modelData.actionText ? String(modelData.actionText) : qsTr("Install")
                readonly property color previewBackground: itemAccentColor.length > 0
                                                           ? Maui.ColorUtils.tintWithAlpha(Maui.Theme.alternateBackgroundColor,
                                                                                            itemAccentColor,
                                                                                            0.45)
                                                           : Maui.Theme.backgroundColor
                readonly property bool statusPositive: {
                    const status = itemStatus.toLowerCase()
                    return status === "installed" || status === "active extension"
                           || status.indexOf("up") >= 0 || status.indexOf("running") >= 0
                }

                Maui.GridBrowserDelegate {
                    id: similarCard
                    width: Math.min(similarAppsGrid.itemWidth, parent.width - Maui.Style.space.small * 2)
                    height: Math.min(similarAppsGrid.itemHeight, parent.height - Maui.Style.space.small * 2)
                    anchors.centerIn: parent
                    flat: false
                    selectedBackgroundColor: Maui.Theme.alternateBackgroundColor
                    selectedForegroundColor: Maui.Theme.textColor
                    isCurrentItem: parent.GridView.isCurrentItem
                    template.labelsVisible: false
                    template.iconComponent: Component {
                        Item {
                            anchors.fill: parent
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Math.min(width * 3 / 5, Maui.Style.units.gridUnit * 12)
                                    Layout.maximumHeight: Maui.Style.units.gridUnit * 12
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        color: similarDelegate.previewBackground
                                    }

                                    Image {
                                        id: similarPreviewImage
                                        anchors.fill: parent
                                        source: similarDelegate.itemScreenshot
                                        sourceSize.width: width
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
                                        imageSource: similarDelegate.itemIconUrl
                                        iconSource: similarDelegate.itemIcon
                                        visible: !similarPreviewImage.visible
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
                                            imageSource: similarDelegate.itemIconUrl
                                            iconSource: similarDelegate.itemIcon
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: Maui.Style.space.small

                                            Label {
                                                Layout.fillWidth: true
                                                text: similarDelegate.itemName
                                                font: Maui.Style.h2Font
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }

                                            Label {
                                                Layout.fillWidth: true
                                                text: similarDelegate.itemSummary.length > 0 ? similarDelegate.itemSummary : similarDelegate.itemIdentifier
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

                                        Maui.Chip {
                                            visible: similarDelegate.itemStatus.length > 0
                                            text: similarDelegate.itemStatus
                                            color: similarDelegate.statusPositive
                                                   ? Maui.Theme.positiveBackgroundColor
                                                   : Maui.Theme.backgroundColor
                                            hoverEnabled: false
                                            focusPolicy: Qt.NoFocus
                                            label.font.weight: Font.Medium
                                        }

                                        Item { Layout.fillWidth: true }

                                        ToolButton {
                                            visible: similarDelegate.primaryActionText.length > 0
                                            Layout.minimumWidth: Maui.Style.units.gridUnit * 5
                                            text: similarDelegate.primaryActionText
                                            display: ToolButton.TextOnly
                                            flat: false
                                            enabled: !control.busy
                                            onClicked: {
                                                if (control.actionHandler)
                                                    control.actionHandler(similarDelegate.itemIdentifier, modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    onClicked: control.similarRequested(modelData)
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

    Rectangle {
        Layout.fillWidth: true
        visible: control.itemBaseImage.length > 0 || control.itemIntegration.length > 0
        implicitHeight: detailsColumn.implicitHeight + Maui.Style.contentMargins * 2
        radius: Maui.Style.radiusV
        color: Maui.Theme.alternateBackgroundColor

        ColumnLayout {
            id: detailsColumn
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: control.itemBaseImage.length > 0
                text: qsTr("Base image: %1").arg(control.itemBaseImage)
                wrapMode: Text.WrapAnywhere
            }

            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: control.itemIntegration.length > 0
                text: qsTr("Integration: %1").arg(control.itemIntegration)
                wrapMode: Text.WrapAnywhere
            }

        }
    }
}
