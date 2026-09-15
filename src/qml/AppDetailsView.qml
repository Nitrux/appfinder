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
    property string developerFallback: ""
    property var actionHandler: null
    property var actionTextResolver: function(item) {
        return item && item.actionText ? String(item.actionText) : ""
    }
    property var actionEnabledResolver: function(item) { return true }
    property bool busy: false
    property bool showFlathubLinks: false
    property bool descriptionIsMarkdown: false
    property bool releasesExpanded: false
    property int screenshotIndex: 0
    property var loadedScreenshotIndexes: []
    signal backRequested()
    signal similarRequested(var item)

    readonly property string itemName: control.value("name") || control.value("identifier") || qsTr("Application")
    readonly property string itemSummary: control.value("summary")
    readonly property string itemDeveloper: {
        const developer = control.value("developer")
        const filteredDeveloper = developer.toLowerCase() === control.sourceTitle.toLowerCase() ? "" : developer
        return filteredDeveloper.length > 0 ? filteredDeveloper : control.developerFallback
    }
    readonly property string itemDescription: control.value("description") || control.itemSummary
    readonly property string itemIdentifier: control.value("identifier")
    readonly property string itemVersion: control.value("version")
    readonly property string itemArchitecture: control.value("architecture")
    readonly property string itemCategory: control.value("category")
    readonly property string itemSize: control.value("size")
    readonly property string itemIntegration: control.value("integration")
    readonly property string itemLicense: control.value("license")
    readonly property string itemHomepage: control.value("homepage")
    readonly property string itemRuntime: control.value("runtime") || control.value("type")
    readonly property string itemOsTarget: control.value("osTarget")
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
        if (control.showFlathubLinks && control.itemIdentifier.length > 0)
            links.push({ title: qsTr("Flathub Page"), url: "https://flathub.org/apps/" + control.itemIdentifier, icon: "applications-internet" })
        if (control.itemHomepage.length > 0)
            links.push({ title: qsTr("Project Website"), url: control.itemHomepage, icon: "globe" })
        return links
    }
    readonly property string actionText: control.actionTextResolver(control.itemData)
    readonly property bool actionEnabled: control.actionEnabledResolver(control.itemData)
    readonly property int actionStatus: {
        const action = control.actionText.toLowerCase()
        return action === "install" || action === "build" ? Maui.Controls.Positive
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

    function advanceScreenshot(offset) {
        const count = control.itemScreenshots.length
        if (count < 2)
            return

        const index = (control.screenshotIndex + offset + count) % count
        control.ensureScreenshotLoaded(index)
        control.screenshotIndex = index
    }

    function ensureScreenshotLoaded(index) {
        if (index < 0 || index >= control.itemScreenshots.length
            || control.loadedScreenshotIndexes.indexOf(index) >= 0)
            return

        const loadedIndexes = control.loadedScreenshotIndexes.slice()
        loadedIndexes.push(index)
        control.loadedScreenshotIndexes = loadedIndexes
    }

    onItemScreenshotsChanged: {
        control.screenshotIndex = 0
        control.loadedScreenshotIndexes = control.itemScreenshots.length > 0 ? [0] : []
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

                    RowLayout {
                        id: titleRow
                        Layout.fillWidth: true
                        spacing: Maui.Style.space.small

                        Label {
                            Layout.minimumWidth: 0
                            text: control.itemName
                            font: Maui.Style.h1Font
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Maui.Chip {
                            id: headerVersionChip
                            Layout.alignment: Qt.AlignVCenter
                            visible: control.itemVersion.length > 0
                            enabled: false
                            hoverEnabled: false
                            color: Qt.rgba(0, 0, 0, 0.3)
                            implicitWidth: headerVersionValue.implicitWidth + Maui.Style.space.medium * 2
                            implicitHeight: headerVersionValue.implicitHeight + Maui.Style.space.small * 2

                            contentItem: Maui.IconLabel {
                                id: headerVersionValue
                                display: ToolButton.TextOnly
                                text: control.itemVersion
                                alignment: Qt.AlignHCenter
                                font.weight: Font.Medium
                                color: Maui.Theme.textColor
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: control.itemDeveloper
                        visible: control.itemDeveloper.length > 0
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
                    enabled: control.actionEnabled && !control.busy
                    Maui.Controls.status: control.actionStatus
                    onClicked: control.actionHandler(control.itemIdentifier, control.itemData)
                }
            }
        }
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
                { value: control.itemCategory, label: qsTr("Category"), positive: false },
                { value: control.itemLicense, label: qsTr("License"), positive: false },
                { value: control.itemArchitecture, label: qsTr("Architecture"), positive: false },
                { value: control.itemOsTarget, label: qsTr("OS Target"), positive: false },
                { value: control.itemRuntime, label: qsTr("Runtime"), positive: false },
                { value: control.itemIntegration, label: qsTr("Integration"), positive: false }
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
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: statColumn.width
                        enabled: false
                        hoverEnabled: false
                        color: modelData.positive ? Maui.Theme.positiveBackgroundColor : Qt.rgba(0, 0, 0, 0.3)
                        implicitWidth: statValue.implicitWidth + Maui.Style.space.medium * 2
                        implicitHeight: statValue.implicitHeight + Maui.Style.space.small * 2

                        contentItem: Maui.IconLabel {
                            id: statValue
                            display: ToolButton.TextOnly
                            text: modelData.value
                            alignment: Qt.AlignHCenter
                            font.weight: Font.Medium
                            color: Maui.Theme.textColor
                            label.wrapMode: Text.WrapAnywhere
                            label.maximumLineCount: 2
                            label.elide: Text.ElideRight
                        }
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

    Rectangle {
        id: screenshotsCarousel
        Layout.fillWidth: false
        Layout.preferredWidth: Math.min(control.availableWidth, Maui.Style.units.gridUnit * 64)
        Layout.alignment: Qt.AlignHCenter
        visible: control.itemScreenshots.length > 0
        implicitHeight: width * 9 / 16
        radius: Maui.Style.radiusV
        color: Maui.Theme.alternateBackgroundColor
        clip: true

        Repeater {
            model: control.itemScreenshots

            delegate: Image {
                required property int index
                required property var modelData
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                source: control.loadedScreenshotIndexes.indexOf(index) >= 0 ? String(modelData) : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                visible: index === control.screenshotIndex

                Maui.ProgressIndicator {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: parent.status === Image.Loading
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: screenshotPreview.open()
        }

        ToolButton {
            anchors.left: parent.left
            anchors.leftMargin: Maui.Style.contentMargins
            anchors.verticalCenter: parent.verticalCenter
            visible: control.itemScreenshots.length > 1
            z: 1
            text: qsTr("Previous screenshot")
            display: AbstractButton.IconOnly
            icon.name: "go-previous"
            ToolTip.visible: hovered
            ToolTip.text: text
            onClicked: control.advanceScreenshot(-1)
        }

        ToolButton {
            anchors.right: parent.right
            anchors.rightMargin: Maui.Style.contentMargins
            anchors.verticalCenter: parent.verticalCenter
            visible: control.itemScreenshots.length > 1
            z: 1
            text: qsTr("Next screenshot")
            display: AbstractButton.IconOnly
            icon.name: "go-next"
            ToolTip.visible: hovered
            ToolTip.text: text
            onClicked: control.advanceScreenshot(1)
        }

        PageIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Maui.Style.contentMargins
            visible: count > 1
            z: 1
            count: control.itemScreenshots.length
            currentIndex: control.screenshotIndex
            padding: Maui.Style.space.small

            background: Rectangle {
                radius: height / 2
                color: Qt.rgba(Maui.Theme.backgroundColor.r,
                               Maui.Theme.backgroundColor.g,
                               Maui.Theme.backgroundColor.b,
                               0.8)
            }

            delegate: Rectangle {
                required property int index
                implicitWidth: Maui.Style.iconSizes.small / 2
                implicitHeight: implicitWidth
                radius: width / 2
                color: index === control.screenshotIndex
                       ? Maui.Theme.highlightColor
                       : Qt.rgba(Maui.Theme.highlightColor.r,
                                 Maui.Theme.highlightColor.g,
                                 Maui.Theme.highlightColor.b,
                                 0.35)
                border.width: 1
                border.color: Maui.Theme.highlightColor
            }
        }

        Timer {
            interval: 7000
            repeat: true
            running: screenshotsCarousel.visible
                     && control.itemScreenshots.length > 1
                     && !screenshotPreview.opened
            onTriggered: control.advanceScreenshot(1)
        }
    }

    Maui.PopupPage {
        id: screenshotPreview
        title: control.itemName
        filling: true
        persistent: true

        stack: Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Maui.ImageViewer {
                anchors.fill: parent
                anchors.margins: Maui.Style.contentMargins
                source: control.itemScreenshots.length > 0 ? control.itemScreenshots[control.screenshotIndex] : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
            }

            ToolButton {
                anchors.left: parent.left
                anchors.leftMargin: Maui.Style.contentMargins
                anchors.verticalCenter: parent.verticalCenter
                visible: control.itemScreenshots.length > 1
                z: 1
                text: qsTr("Previous screenshot")
                display: AbstractButton.IconOnly
                icon.name: "go-previous"
                ToolTip.visible: hovered
                ToolTip.text: text
                onClicked: control.advanceScreenshot(-1)
            }

            ToolButton {
                anchors.right: parent.right
                anchors.rightMargin: Maui.Style.contentMargins
                anchors.verticalCenter: parent.verticalCenter
                visible: control.itemScreenshots.length > 1
                z: 1
                text: qsTr("Next screenshot")
                display: AbstractButton.IconOnly
                icon.name: "go-next"
                ToolTip.visible: hovered
                ToolTip.text: text
                onClicked: control.advanceScreenshot(1)
            }

            PageIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Maui.Style.contentMargins
                visible: count > 1
                z: 1
                count: control.itemScreenshots.length
                currentIndex: control.screenshotIndex
                padding: Maui.Style.space.small

                background: Rectangle {
                    radius: height / 2
                    color: Qt.rgba(Maui.Theme.backgroundColor.r,
                                   Maui.Theme.backgroundColor.g,
                                   Maui.Theme.backgroundColor.b,
                                   0.8)
                }

                delegate: Rectangle {
                    required property int index
                    implicitWidth: Maui.Style.iconSizes.small / 2
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: index === control.screenshotIndex
                           ? Maui.Theme.highlightColor
                           : Qt.rgba(Maui.Theme.highlightColor.r,
                                     Maui.Theme.highlightColor.g,
                                     Maui.Theme.highlightColor.b,
                                     0.35)
                    border.width: 1
                    border.color: Maui.Theme.highlightColor
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
                textFormat: control.descriptionIsMarkdown ? Text.MarkdownText : Text.RichText
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
            itemHeight: itemSize + Maui.Style.rowHeight
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
                                            visible: similarDelegate.itemStatus.length > 0 && similarDelegate.itemStatus.toLowerCase() !== "available"
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

}
