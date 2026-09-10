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
    property bool categoriesView: false
    property string selectedCategory: ""
    property string selectedSubcategory: ""
    property string selectedInstalledScope: ""
    property string selectedInstalledIdentifier: ""
    readonly property var flathubBrowseCategories: [
        { category: "audiovideo", title: qsTr("Multimedia"), icon: "applications-multimedia", color: "#ff7043", filters: [
            { value: "", title: qsTr("All") }, { value: "audioVideoEditing", title: qsTr("Editing") }, { value: "midi", title: qsTr("MIDI") }, { value: "mixer", title: qsTr("Mixer") }, { value: "music", title: qsTr("Music") }, { value: "player", title: qsTr("Player") }, { value: "recorder", title: qsTr("Recorder") }, { value: "sequencer", title: qsTr("Sequencer") }, { value: "tuner", title: qsTr("Tuner") }, { value: "tv", title: qsTr("Television") }
        ] },
        { category: "development", title: qsTr("Development"), icon: "applications-development", color: "#795548", filters: [
            { value: "", title: qsTr("All") }, { value: "building", title: qsTr("Building") }, { value: "debugger", title: qsTr("Debugging") }, { value: "ide", title: qsTr("IDEs") }, { value: "guiDesigner", title: qsTr("GUI Design") }, { value: "profiling", title: qsTr("Profiling") }, { value: "revisionControl", title: qsTr("Revision Control") }, { value: "translation", title: qsTr("Translation") }, { value: "webDevelopment", title: qsTr("Web Development") }
        ] },
        { category: "education", title: qsTr("Learning"), icon: "applications-education", color: "#43a047", filters: [
            { value: "", title: qsTr("All") }, { value: "art", title: qsTr("Art") }, { value: "computerScience", title: qsTr("Computer Science") }, { value: "geography", title: qsTr("Geography") }, { value: "history", title: qsTr("History") }, { value: "languages", title: qsTr("Languages") }, { value: "literature", title: qsTr("Literature") }, { value: "math", title: qsTr("Mathematics") }, { value: "music", title: qsTr("Music") }
        ] },
        { category: "game", title: qsTr("Gaming"), icon: "applications-games", color: "#ec407a", filters: [
            { value: "", title: qsTr("All") }, { value: "actionGame", title: qsTr("Action") }, { value: "adventureGame", title: qsTr("Adventure") }, { value: "arcadeGame", title: qsTr("Arcade") }, { value: "boardGame", title: qsTr("Board") }, { value: "cardGame", title: qsTr("Card") }, { value: "logicGame", title: qsTr("Logic") }, { value: "rolePlaying", title: qsTr("Role Playing") }, { value: "shooter", title: qsTr("Shooter") }, { value: "simulation", title: qsTr("Simulation") }, { value: "sportsGame", title: qsTr("Sports") }, { value: "strategyGame", title: qsTr("Strategy") }
        ] },
        { category: "graphics", title: qsTr("Creation"), icon: "applications-graphics", color: "#8e5cb5", filters: [
            { value: "", title: qsTr("All") }, { value: "2dGraphics", title: qsTr("2D Graphics") }, { value: "3dGraphics", title: qsTr("3D Graphics") }, { value: "photography", title: qsTr("Photography") }, { value: "rasterGraphics", title: qsTr("Raster Graphics") }, { value: "scanning", title: qsTr("Scanning") }, { value: "vectorGraphics", title: qsTr("Vector Graphics") }, { value: "viewer", title: qsTr("Viewers") }
        ] },
        { category: "network", title: qsTr("Internet"), icon: "applications-internet", color: "#f44336", filters: [
            { value: "", title: qsTr("All") }, { value: "chat", title: qsTr("Chat") }, { value: "email", title: qsTr("Email") }, { value: "fileTransfer", title: qsTr("File Transfer") }, { value: "instantMessaging", title: qsTr("Messaging") }, { value: "p2p", title: qsTr("Peer-to-Peer") }, { value: "remoteAccess", title: qsTr("Remote Access") }, { value: "videoConference", title: qsTr("Video Conference") }, { value: "webBrowser", title: qsTr("Web Browsers") }
        ] },
        { category: "office", title: qsTr("Work"), icon: "applications-office", color: "#29b6f6", filters: [
            { value: "", title: qsTr("All") }, { value: "calendar", title: qsTr("Calendar") }, { value: "database", title: qsTr("Database") }, { value: "dictionary", title: qsTr("Dictionary") }, { value: "finance", title: qsTr("Finance") }, { value: "presentation", title: qsTr("Presentation") }, { value: "projectManagement", title: qsTr("Project Management") }, { value: "spreadsheet", title: qsTr("Spreadsheets") }, { value: "wordProcessor", title: qsTr("Word Processing") }
        ] },
        { category: "science", title: qsTr("Science"), icon: "applications-science", color: "#42a5a8", filters: [
            { value: "", title: qsTr("All") }, { value: "artificialIntelligence", title: qsTr("Artificial Intelligence") }, { value: "astronomy", title: qsTr("Astronomy") }, { value: "biology", title: qsTr("Biology") }, { value: "chemistry", title: qsTr("Chemistry") }, { value: "dataVisualization", title: qsTr("Data Visualization") }, { value: "geography", title: qsTr("Geography") }, { value: "math", title: qsTr("Mathematics") }, { value: "physics", title: qsTr("Physics") }, { value: "robotics", title: qsTr("Robotics") }
        ] },
        { category: "system", title: qsTr("System"), icon: "applications-system", color: "#8d6e63", filters: [
            { value: "", title: qsTr("All") }, { value: "emulator", title: qsTr("Emulators") }, { value: "fileManager", title: qsTr("File Managers") }, { value: "fileTools", title: qsTr("File Tools") }, { value: "filesystem", title: qsTr("Filesystems") }, { value: "monitor", title: qsTr("Monitoring") }, { value: "security", title: qsTr("Security") }, { value: "terminalEmulator", title: qsTr("Terminals") }
        ] },
        { category: "utility", title: qsTr("Tools"), icon: "applications-utilities", color: "#ef9a9a", filters: [
            { value: "", title: qsTr("All") }, { value: "accessibility", title: qsTr("Accessibility") }, { value: "archiving", title: qsTr("Archiving") }, { value: "calculator", title: qsTr("Calculators") }, { value: "clock", title: qsTr("Clocks") }, { value: "compression", title: qsTr("Compression") }, { value: "documentation", title: qsTr("Documentation") }, { value: "textEditor", title: qsTr("Text Editors") }, { value: "textTools", title: qsTr("Text Tools") }
        ] }
    ]
    readonly property bool searchActive: query.trim().length > 0
    readonly property var selectedCategoryInfo: categoryInfo(selectedCategory)
    readonly property var flathubCategorySections: [
        { category: "office", title: qsTr("Productivity"), moreTitle: qsTr("More Productivity") },
        { category: "graphics", title: qsTr("Graphics & Photography"), moreTitle: qsTr("More Graphics & Photography") },
        { category: "audiovideo", title: qsTr("Audio & Video"), moreTitle: qsTr("More Audio & Video") },
        { category: "mobile", title: qsTr("Mobile"), moreTitle: qsTr("More Mobile") },
        { category: "education", title: qsTr("Education"), moreTitle: qsTr("More Education") },
        { category: "network", title: qsTr("Networking"), moreTitle: qsTr("More Networking") },
        { category: "game-only", title: qsTr("Gaming"), moreTitle: qsTr("More Gaming") },
        { category: "emulators", title: qsTr("Emulators"), moreTitle: qsTr("More Emulators") },
        { category: "launchers", title: qsTr("Launchers"), moreTitle: qsTr("More Game Launchers") },
        { category: "game-tools", title: qsTr("Game Tools"), moreTitle: qsTr("More Game Tools") },
        { category: "development", title: qsTr("Developer Tools"), moreTitle: qsTr("More Developer Tools") },
        { category: "science", title: qsTr("Science"), moreTitle: qsTr("More Science") },
        { category: "system", title: qsTr("System"), moreTitle: qsTr("More System") },
        { category: "utility", title: qsTr("Utilities"), moreTitle: qsTr("More Utilities") }
    ]

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

    function contrastingForeground(background) {
        const effectiveBackground = background.a > 0
                                  ? background
                                  : control.Maui.Theme.alternateBackgroundColor
        return Maui.ColorUtils.brightnessForColor(effectiveBackground) === Maui.ColorUtils.Light
               ? "#333333"
               : "#fafafa"
    }

    function flathubCollectionTitle(collection) {
        switch (collection) {
        case 1:
            return qsTr("Popular")
        case 2:
            return qsTr("New")
        case 3:
            return qsTr("Updated")
        default:
            return qsTr("Trending")
        }
    }

    function categoryInfo(category) {
        for (let index = 0; index < flathubBrowseCategories.length; ++index) {
            if (flathubBrowseCategories[index].category === category)
                return flathubBrowseCategories[index]
        }
        return null
    }

    function browseCategory(category, subcategory) {
        selectedCategory = category
        selectedSubcategory = subcategory || ""
        appHub.browseFlathubCategory(selectedCategory, selectedSubcategory)
    }

    Maui.SettingsDialog {
        id: flatpakAddonsDialog

        property string applicationName: ""

        Maui.Controls.title: qsTr("Manage Add-ons")
        persistent: true

        Maui.SectionGroup {
            title: flatpakAddonsDialog.applicationName
            description: qsTr("Install or remove optional components for this Flatpak.")

            Repeater {
                model: appHub.flatpakAddonsModel

                delegate: Maui.FlexSectionItem {
                    id: addonDelegate

                    readonly property bool addonInstalled: model.status === "Installed"

                    flat: false
                    iconSource: model.icon
                    iconSizeHint: Maui.Style.iconSizes.big
                    label1.text: model.name
                    label1.font.weight: Font.DemiBold
                    label1.elide: Text.ElideRight
                    label2.text: model.size.length > 0
                                 ? qsTr("%1 • %2").arg(model.summary).arg(control.sizeText(model.size))
                                 : model.summary
                    label2.elide: Text.ElideRight

                    ToolButton {
                        text: addonDelegate.addonInstalled ? qsTr("Remove") : qsTr("Install")
                        icon.name: addonDelegate.addonInstalled ? "edit-delete" : "download"
                        display: ToolButton.IconOnly
                        enabled: !appHub.busy
                        ToolTip.visible: hovered
                        ToolTip.text: text
                        onClicked: {
                            if (addonDelegate.addonInstalled)
                                appHub.removeFlatpakAddon(model.identifier)
                            else
                                appHub.installFlatpakAddon(model.identifier)
                        }
                    }
                }
            }

            Maui.FlexSectionItem {
                visible: appHub.flatpakAddonsModel.count === 0
                flat: true
                label1.text: qsTr("No Add-ons Available")
                label2.text: qsTr("This Flatpak does not publish optional components.")
                label2.wrapMode: Text.Wrap
            }
        }
    }

    Loader {
        id: viewLoader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 0
        sourceComponent: control.searchActive ? searchView : control.installedView ? installedViewComponent : control.categoriesView ? categoryBrowserView : exploreView
    }

    Component {
        id: exploreView

        Maui.ScrollColumn {
            id: exploreScroll
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

                const pageFlickable = exploreScroll.flickable
                const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
                wheel.accepted = true
            }

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
                        text2: qsTr("Apps of the week from Flathub.")
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

            Maui.TabBar {
                id: collectionTabs
                Layout.fillWidth: true
                Layout.maximumWidth: Maui.Style.units.gridUnit * 40
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Maui.Style.space.medium
                Layout.bottomMargin: Maui.Style.space.medium
                showNewTabButton: false
                Maui.Controls.showCSD: false
                currentIndex: appHub.flathubCollection
                clip: true

                readonly property real uniformTabWidth: Math.max(0, (width - leftPadding - rightPadding - spacing * 3) / 4)

                onCurrentIndexChanged: {
                    if (currentIndex >= 0 && appHub.flathubCollection !== currentIndex)
                        appHub.flathubCollection = currentIndex
                }

                background: Rectangle {
                    color: Maui.Theme.alternateBackgroundColor
                    radius: height / 2
                }

                Maui.TabButton {
                    width: collectionTabs.uniformTabWidth
                    text: qsTr("Trending")
                    closeButtonVisible: false
                }

                Maui.TabButton {
                    width: collectionTabs.uniformTabWidth
                    text: qsTr("Popular")
                    closeButtonVisible: false
                }

                Maui.TabButton {
                    width: collectionTabs.uniformTabWidth
                    text: qsTr("New")
                    closeButtonVisible: false
                }

                Maui.TabButton {
                    width: collectionTabs.uniformTabWidth
                    text: qsTr("Updated")
                    closeButtonVisible: false
                }
            }

            Maui.GridBrowser {
                id: collectionGrid
                readonly property real availableLayoutWidth: parent ? parent.width : 0
                readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

                Layout.fillWidth: holder.visible
                Layout.preferredWidth: holder.visible ? availableLayoutWidth : Math.min(availableLayoutWidth, itemSize * fittedColumns)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: holder.visible ? Math.max(holder.implicitHeight, exploreScroll.availableHeight - y) : contentHeight
                padding: 0
                itemSize: Maui.Style.units.gridUnit * 17
                itemHeight: Maui.Style.units.gridUnit * 6
                adaptContent: true
                wheelResizeEnabled: false
                pinchEnabled: false
                verticalScrollBarPolicy: ScrollBar.AlwaysOff
                model: appHub.flathubCollectionModel
                flickable.interactive: false

                holder.visible: count === 0
                holder.title: appHub.flathubCollectionLoading ? qsTr("Loading...") : qsTr("No apps available!")
                holder.body: appHub.flathubCollectionLoading ? qsTr("Fetching from Flathub.") : qsTr("Flathub could not be loaded.")

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Maui.ListBrowserDelegate {
                        anchors.fill: parent
                        anchors.margins: Maui.Style.space.small
                        flat: false
                        imageSource: model.iconUrl
                        iconSource: model.icon
                        iconSizeHint: Maui.Style.iconSizes.big
                        template.leftLabels.spacing: Maui.Style.space.small
                        label1.text: model.name
                        label1.font.weight: Font.DemiBold
                        label1.elide: Text.ElideRight
                        label2.text: model.summary
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
                    onWheel: (wheel) => exploreScroll.forwardGridWheel(wheel)
                }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                visible: appHub.flathubCollectionHasMore
                enabled: !appHub.flathubCollectionLoading
                text: appHub.flathubCollectionLoading
                      ? qsTr("Loading…")
                      : qsTr("More %1").arg(control.flathubCollectionTitle(appHub.flathubCollection))
                onClicked: appHub.loadMoreFlathubCollection()
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: exploreScroll.container.width
                spacing: Maui.Style.space.small

                Repeater {
                    model: control.flathubCategorySections

                    delegate: ColumnLayout {
                        id: categorySection
                        required property var modelData

                        readonly property var apps: appHub.flathubCategoryModel(modelData.category)
                        readonly property bool loading: appHub.flathubCategoryRevision >= 0 && appHub.flathubCategoryLoading(modelData.category)
                        readonly property bool hasMore: appHub.flathubCategoryRevision >= 0 && appHub.flathubCategoryHasMore(modelData.category)

                        Layout.fillWidth: true
                        Layout.preferredWidth: exploreScroll.container.width
                        spacing: Maui.Style.space.small
                        visible: loading || (apps && apps.count > 0)

                        Maui.SectionHeader {
                            Layout.fillWidth: false
                            Layout.preferredWidth: categoryGrid.width
                            Layout.alignment: Qt.AlignHCenter
                            text1: categorySection.modelData.title
                        }

                        Maui.GridBrowser {
                            id: categoryGrid
                            readonly property real availableLayoutWidth: exploreScroll.container.width
                            readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

                            Layout.fillWidth: false
                            Layout.preferredWidth: Math.min(availableLayoutWidth, itemSize * fittedColumns)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: Math.max(contentHeight, holder.visible ? Maui.Style.units.gridUnit * 10 : 0)
                            padding: 0
                            itemSize: Maui.Style.units.gridUnit * 17
                            itemHeight: Maui.Style.units.gridUnit * 6
                            adaptContent: true
                            wheelResizeEnabled: false
                            pinchEnabled: false
                            verticalScrollBarPolicy: ScrollBar.AlwaysOff
                            model: categorySection.apps
                            flickable.interactive: false

                            holder.visible: count === 0
                            holder.title: qsTr("Loading applications")
                            holder.body: qsTr("Fetching this Flathub category.")

                            delegate: Item {
                                width: GridView.view.cellWidth
                                height: GridView.view.cellHeight

                                Maui.ListBrowserDelegate {
                                    anchors.fill: parent
                                    anchors.margins: Maui.Style.space.small
                                    flat: false
                                    imageSource: model.iconUrl
                                    iconSource: model.icon
                                    iconSizeHint: Maui.Style.iconSizes.big
                                    template.leftLabels.spacing: Maui.Style.space.small
                                    label1.text: model.name
                                    label1.font.weight: Font.DemiBold
                                    label1.elide: Text.ElideRight
                                    label2.text: model.summary
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
                                onWheel: (wheel) => exploreScroll.forwardGridWheel(wheel)
                            }
                        }

                        Button {
                            Layout.alignment: Qt.AlignHCenter
                            visible: categorySection.apps && categorySection.apps.count > 0 && categorySection.hasMore
                            enabled: !categorySection.loading
                            text: categorySection.loading ? qsTr("Loading…") : categorySection.modelData.moreTitle
                            onClicked: appHub.loadMoreFlathubCategory(categorySection.modelData.category)
                        }

                    }
                }
            }

        }
    }

    Component {
        id: categoryBrowserView

        Loader {
            anchors.fill: parent
            sourceComponent: control.selectedCategory.length > 0 ? categoryDetailView : categoryOverviewView
        }
    }

    Component {
        id: categoryOverviewView

        Maui.ScrollColumn {
            id: categoryOverviewScroll
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.medium

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Browse Flathub Categories")
                text2: qsTr("Explore applications by purpose.")
                label2.wrapMode: Text.Wrap
            }

            Maui.GridBrowser {
                id: categoryOverviewGrid
                readonly property real availableLayoutWidth: parent ? parent.width : 0
                readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

                Layout.fillWidth: false
                Layout.preferredWidth: Math.min(availableLayoutWidth, itemSize * fittedColumns)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: contentHeight
                padding: 0
                itemSize: Maui.Style.units.gridUnit * 16
                itemHeight: Maui.Style.units.gridUnit * 10
                adaptContent: true
                wheelResizeEnabled: false
                pinchEnabled: false
                verticalScrollBarPolicy: ScrollBar.AlwaysOff
                flickable.interactive: false
                model: control.flathubBrowseCategories

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight
                    required property var modelData

                    Maui.GridBrowserDelegate {
                        anchors.fill: parent
                        anchors.margins: Maui.Style.space.small
                        iconSource: modelData.icon
                        iconSizeHint: Maui.Style.iconSizes.huge
                        label1.text: modelData.title
                        label1.font: Maui.Style.h2Font
                        label1.color: Maui.ColorUtils.brightnessForColor(modelData.color) === Maui.ColorUtils.Light ? "#20202a" : "#ffffff"
                        background: Rectangle {
                            color: modelData.color
                            radius: Maui.Style.radiusV
                        }
                        onClicked: control.browseCategory(modelData.category, "")
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    scrollGestureEnabled: false
                    z: 100
                    onWheel: (wheel) => {
                        const usePixelDelta = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
                        const verticalDelta = usePixelDelta ? wheel.pixelDelta.y : wheel.angleDelta.y
                        const flickable = categoryOverviewScroll.flickable
                        const maximumContentY = Math.max(0, flickable.contentHeight - flickable.height)
                        flickable.contentY = Math.max(0, Math.min(maximumContentY, flickable.contentY - verticalDelta))
                        wheel.accepted = true
                    }
                }
            }
        }
    }

    Component {
        id: categoryDetailView

        Maui.ScrollColumn {
            id: categoryDetailScroll
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Maui.Style.space.small

                ToolButton {
                    text: qsTr("All Categories")
                    display: AbstractButton.IconOnly
                    icon.name: "go-previous"
                    ToolTip.visible: hovered
                    ToolTip.text: text
                    onClicked: {
                        control.selectedCategory = ""
                        control.selectedSubcategory = ""
                    }
                }

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: control.selectedCategoryInfo ? control.selectedCategoryInfo.title : ""
                    text2: qsTr("Showing %1 applications from Flathub.").arg(appHub.flathubBrowseModel.count)
                    label2.wrapMode: Text.Wrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: appHub.flathubBrowseFeaturedModel.count > 0
                implicitHeight: categoryFeaturedFrame.implicitHeight
                color: "transparent"

                Item {
                    id: categoryFeaturedFrame
                    anchors.left: parent.left
                    anchors.right: parent.right
                    implicitHeight: width < Maui.Style.units.gridUnit * 42 ? Maui.Style.units.gridUnit * 13 : Maui.Style.units.gridUnit * 16
                    clip: true

                    Repeater {
                        model: appHub.flathubBrowseFeaturedModel

                        delegate: Rectangle {
                            id: categoryFeaturedSlide
                            anchors.fill: parent
                            radius: Maui.Style.radiusV
                            color: control.selectedCategoryInfo
                                   ? Maui.ColorUtils.tintWithAlpha(Maui.Theme.alternateBackgroundColor, control.selectedCategoryInfo.color, 0.55)
                                   : Maui.Theme.alternateBackgroundColor
                            border.color: Maui.Theme.backgroundColor
                            border.width: 1
                            clip: true

                            readonly property color bannerForeground: Maui.ColorUtils.brightnessForColor(color) === Maui.ColorUtils.Light ? "#20202a" : "#ffffff"
                            readonly property color secondaryForeground: Maui.ColorUtils.tintWithAlpha(bannerForeground, color, 0.55)
                            readonly property real previewMaximumWidth: Math.max(0, (height - Maui.Style.space.medium * 2) * 5 / 2)
                            readonly property real previewWidth: Math.max(0, Math.min(previewMaximumWidth, width * 3 / 5))

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
                                        color: categoryFeaturedSlide.bannerForeground
                                        horizontalAlignment: Text.AlignHCenter
                                        font: Maui.Style.h2Font
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: model.summary
                                        color: categoryFeaturedSlide.secondaryForeground
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
                                    }

                                    Maui.Chip {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: control.selectedCategoryInfo ? control.selectedCategoryInfo.title : model.category
                                        enabled: false
                                        hoverEnabled: false
                                        color: Qt.rgba(0, 0, 0, 0.3)
                                    }
                                }

                                Rectangle {
                                    id: categoryScreenshotFrame
                                    visible: categoryFeaturedSlide.width >= Maui.Style.units.gridUnit * 42
                                    Layout.fillHeight: true
                                    Layout.minimumWidth: categoryFeaturedSlide.previewWidth
                                    Layout.preferredWidth: categoryFeaturedSlide.previewWidth
                                    Layout.maximumWidth: categoryFeaturedSlide.previewWidth
                                    color: "transparent"
                                    radius: Maui.Style.radiusV
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
                                                width: categoryScreenshotFrame.width
                                                height: categoryScreenshotFrame.height
                                                radius: categoryScreenshotFrame.radius
                                            }
                                        }
                                    }

                                    Image {
                                        id: categoryScreenshotImage
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
                                        color: categoryFeaturedSlide.secondaryForeground
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        visible: !categoryScreenshotImage.visible
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: false
                Layout.maximumWidth: parent ? parent.width : implicitWidth
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Maui.Style.space.medium
                Layout.bottomMargin: Maui.Style.space.medium
                spacing: Maui.Style.space.small

                Repeater {
                    model: control.selectedCategoryInfo ? control.selectedCategoryInfo.filters : []

                    delegate: Maui.Chip {
                        required property var modelData
                        text: modelData.title
                        checkable: true
                        autoExclusive: true
                        checked: control.selectedSubcategory === modelData.value
                        color: Maui.Theme.alternateBackgroundColor
                        onClicked: control.browseCategory(control.selectedCategory, modelData.value)
                    }
                }
            }

            Maui.GridBrowser {
                id: categoryBrowseGrid
                readonly property real availableLayoutWidth: parent ? parent.width : 0
                readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

                Layout.fillWidth: holder.visible
                Layout.preferredWidth: holder.visible ? availableLayoutWidth : Math.min(availableLayoutWidth, itemSize * fittedColumns)
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: holder.visible ? Math.max(holder.implicitHeight, categoryDetailScroll.availableHeight - y) : contentHeight
                padding: 0
                itemSize: Maui.Style.units.gridUnit * 17
                itemHeight: Maui.Style.units.gridUnit * 6
                adaptContent: true
                wheelResizeEnabled: false
                pinchEnabled: false
                verticalScrollBarPolicy: ScrollBar.AlwaysOff
                model: appHub.flathubBrowseModel
                flickable.interactive: false

                holder.visible: count === 0
                holder.title: appHub.flathubBrowseLoading ? qsTr("Loading applications") : qsTr("No applications found")
                holder.body: appHub.flathubBrowseLoading ? qsTr("Fetching this Flathub category.") : qsTr("No applications match this category filter.")

                delegate: Item {
                    width: GridView.view.cellWidth
                    height: GridView.view.cellHeight

                    Maui.ListBrowserDelegate {
                        anchors.fill: parent
                        anchors.margins: Maui.Style.space.small
                        flat: false
                        imageSource: model.iconUrl
                        iconSource: model.icon
                        iconSizeHint: Maui.Style.iconSizes.big
                        template.leftLabels.spacing: Maui.Style.space.small
                        label1.text: model.name
                        label1.font.weight: Font.DemiBold
                        label1.elide: Text.ElideRight
                        label2.text: model.summary
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
                    onWheel: (wheel) => {
                        const usePixelDelta = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
                        const verticalDelta = usePixelDelta ? wheel.pixelDelta.y : wheel.angleDelta.y
                        const flickable = categoryDetailScroll.flickable
                        const maximumContentY = Math.max(0, flickable.contentHeight - flickable.height)
                        flickable.contentY = Math.max(0, Math.min(maximumContentY, flickable.contentY - verticalDelta))
                        wheel.accepted = true
                    }
                }
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                visible: control.selectedSubcategory.length === 0 && appHub.flathubBrowseHasMore
                enabled: !appHub.flathubBrowseLoading
                text: appHub.flathubBrowseLoading ? qsTr("Loading…") : qsTr("More Applications")
                onClicked: appHub.loadMoreFlathubBrowseCategory()
            }
        }
    }

    Component {
        id: installedViewComponent

        Maui.ScrollColumn {
            id: installedScroll
            padding: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            function forwardListWheel(wheel) {
                const usePixelDelta = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
                const horizontalDelta = usePixelDelta ? wheel.pixelDelta.x : wheel.angleDelta.x
                const verticalDelta = usePixelDelta ? wheel.pixelDelta.y : wheel.angleDelta.y

                if (Math.abs(verticalDelta) < Math.abs(horizontalDelta)) {
                    wheel.accepted = false
                    return
                }

                const pageFlickable = installedScroll.flickable
                const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
                wheel.accepted = true
            }

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Manage Flatpaks")
                text2: qsTr("Browse and manage installed Flatpak applications.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                visible: appHub.flathubUpdatesModel.count > 0
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: updatesLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: updatesLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Available Updates (%1)").arg(appHub.flathubUpdatesModel.count)
                        text2: qsTr("New Flatpak versions available from Flathub.")
                        label2.wrapMode: Text.Wrap
                    }

                    Repeater {
                        model: appHub.flathubUpdatesModel

                        delegate: Maui.ListBrowserDelegate {
                            id: updateDelegate

                            readonly property bool updating: appHub.flatpakUpdateIdentifier === model.identifier

                            Layout.fillWidth: true
                            iconSource: model.icon
                            iconSizeHint: Maui.Style.iconSizes.big
                            template.leftLabels.spacing: Maui.Style.space.small
                            label1.text: model.name
                            label1.font.weight: Font.DemiBold
                            label1.elide: Text.ElideRight
                            label2.text: updateDelegate.updating
                                         ? (appHub.flatpakUpdateProgress >= 0
                                            ? qsTr("Updating… %1%").arg(appHub.flatpakUpdateProgress)
                                            : qsTr("Preparing update…"))
                                         : (model.version.length > 0
                                            ? qsTr("Version %1 • %2 download").arg(model.version).arg(control.sizeText(model.size))
                                            : qsTr("A new version is available"))
                            label2.elide: Text.ElideRight

                            ProgressBar {
                                visible: updateDelegate.updating
                                Layout.preferredWidth: Maui.Style.units.gridUnit * 8
                                from: 0
                                to: 100
                                indeterminate: appHub.flatpakUpdateProgress < 0
                                value: Math.max(0, appHub.flatpakUpdateProgress)
                            }

                            Button {
                                text: updateDelegate.updating ? qsTr("Updating…") : qsTr("Update")
                                enabled: !appHub.busy
                                onClicked: appHub.updateFlatpak(model.identifier)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: appHub.flathubUpdatesModel.count > 0 ? Math.max(0, 16 - installedScroll.spacing) : 0
                Layout.preferredHeight: installedBrowser.holder.visible ? Math.max(implicitHeight, installedScroll.availableHeight - y) : implicitHeight
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
                        text1: qsTr("User Applications (%1)").arg(appHub.flathubModel.count)
                        text2: qsTr("Flatpaks available to the current user.")
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.ListBrowser {
                        id: installedBrowser
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalScrollBarPolicy: ScrollBar.AlwaysOff
                        padding: 0
                        clip: true
                        model: appHub.flathubModel

                        holder.visible: count === 0
                        holder.title: qsTr("No User Flatpaks Installed")
                        holder.body: qsTr("Flatpaks installed for the current user will appear here.")

                        delegate: Maui.ListBrowserDelegate {
                            id: userInstalledDelegate
                            width: ListView.view.width
                            isCurrentItem: control.selectedInstalledScope === "user" && control.selectedInstalledIdentifier === model.identifier
                            onClicked: {
                                ListView.view.currentIndex = index
                                control.selectedInstalledScope = "user"
                                control.selectedInstalledIdentifier = model.identifier
                            }
                            iconSource: model.icon
                            iconSizeHint: Maui.Style.iconSizes.big
                            template.leftLabels.spacing: Maui.Style.space.small
                            label1.text: model.name
                            label1.font.weight: Font.DemiBold
                            label1.elide: Text.ElideRight
                            label2.text: qsTr("%1 • %2").arg(model.version.length > 0 ? model.version : qsTr("Version unavailable")).arg(control.sizeText(model.size))
                            label2.elide: Text.ElideRight

                            ToolButton {
                                text: qsTr("Manage Add-ons")
                                icon.name: "plugins"
                                icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : userInstalledDelegate.effectiveBackgroundColor))
                                display: ToolButton.IconOnly
                                enabled: !appHub.busy
                                ToolTip.visible: hovered
                                ToolTip.text: text
                                onClicked: {
                                    flatpakAddonsDialog.applicationName = model.name
                                    appHub.loadFlatpakAddons(model.identifier, false)
                                    flatpakAddonsDialog.open()
                                }
                            }

                            ToolButton {
                                text: qsTr("Remove")
                                icon.name: "edit-delete"
                                icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : userInstalledDelegate.effectiveBackgroundColor))
                                display: ToolButton.IconOnly
                                enabled: !appHub.busy
                                ToolTip.visible: hovered
                                ToolTip.text: text
                                onClicked: appHub.removeInstalledFlatpak(model.identifier, false)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                            scrollGestureEnabled: false
                            z: 100
                            onWheel: (wheel) => installedScroll.forwardListWheel(wheel)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Math.max(0, Maui.Style.space.big - installedScroll.spacing)
                visible: appHub.systemFlatpakModel.count > 0
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: systemInstalledLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: systemInstalledLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("System Applications (%1)").arg(appHub.systemFlatpakModel.count)
                        text2: qsTr("Flatpaks installed system-wide.")
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.ListBrowser {
                        id: systemInstalledBrowser
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                        verticalScrollBarPolicy: ScrollBar.AlwaysOff
                        padding: 0
                        clip: true
                        model: appHub.systemFlatpakModel

                        delegate: Maui.ListBrowserDelegate {
                            id: systemInstalledDelegate
                            width: ListView.view.width
                            isCurrentItem: control.selectedInstalledScope === "system" && control.selectedInstalledIdentifier === model.identifier
                            onClicked: {
                                ListView.view.currentIndex = index
                                control.selectedInstalledScope = "system"
                                control.selectedInstalledIdentifier = model.identifier
                            }
                            iconSource: model.icon
                            iconSizeHint: Maui.Style.iconSizes.big
                            template.leftLabels.spacing: Maui.Style.space.small
                            label1.text: model.name
                            label1.font.weight: Font.DemiBold
                            label1.elide: Text.ElideRight
                            label2.text: qsTr("%1 • %2").arg(model.version.length > 0 ? model.version : qsTr("Version unavailable")).arg(control.sizeText(model.size))
                            label2.elide: Text.ElideRight

                            ToolButton {
                                text: qsTr("Manage Add-ons")
                                icon.name: "plugins"
                                icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : systemInstalledDelegate.effectiveBackgroundColor))
                                display: ToolButton.IconOnly
                                enabled: !appHub.busy
                                ToolTip.visible: hovered
                                ToolTip.text: text
                                onClicked: {
                                    flatpakAddonsDialog.applicationName = model.name
                                    appHub.loadFlatpakAddons(model.identifier, true)
                                    flatpakAddonsDialog.open()
                                }
                            }

                            ToolButton {
                                text: qsTr("Remove")
                                icon.name: "edit-delete"
                                icon.color: control.contrastingForeground(down || checked
                                                                          ? Maui.Theme.highlightColor
                                                                          : (hovered
                                                                             ? Maui.Theme.hoverColor
                                                                             : systemInstalledDelegate.effectiveBackgroundColor))
                                display: ToolButton.IconOnly
                                enabled: !appHub.busy
                                ToolTip.visible: hovered
                                ToolTip.text: text
                                onClicked: appHub.removeInstalledFlatpak(model.identifier, true)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                            scrollGestureEnabled: false
                            z: 100
                            onWheel: (wheel) => installedScroll.forwardListWheel(wheel)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: searchView

        Maui.ScrollColumn {
            id: searchScroll
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
                Layout.preferredHeight: searchGrid.holder.visible ? Math.max(implicitHeight, searchScroll.availableHeight - y) : implicitHeight
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
