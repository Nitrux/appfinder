/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ApplicationWindow {
    id: root

    title: currentTitle
    color: "transparent"
    background: null

    property int currentSection: 1
    property string searchText: ""
    property bool compactSearchOpen: false
    property bool closeApproved: false
    readonly property bool searchAvailable: currentSection <= 2 && !(currentSection === 1 && contentLoader.item && contentLoader.item.viewMode === AppHubPage.Builder)
    readonly property alias appSettings: settings

    Settings {
        id: settings
        category: "AppFinder"
        property bool sidebarVisible: true
        property bool refreshOnStartup: true
        property bool startInInstalledView: false
        property string flatpakSortMode: "name"
    }

    readonly property string currentTitle: currentSection === 0 ? qsTr("Flathub")
                                           : currentSection === 1 ? qsTr("NX AppHub")
                                                                  : qsTr("Distrobox")

    readonly property var actionBarActions: [
        flathubExploreAction,
        flathubCategoriesAction,
        flathubInstalledAction,
        appHubExploreAction,
        appHubBuilderAction,
        appHubInstalledAction,
        appHubWikiAction,
        appHubRefreshAction,
        appHubBackAction,
        appHubRevealAction
    ]

    Action {
        id: flathubExploreAction
        property bool actionVisible: root.currentSection === 0 && contentLoader.item !== null && typeof contentLoader.item.installedView !== "undefined"

        text: qsTr("Explore Flathub")
        icon.name: "go-home"
        checkable: true
        checked: root.currentSection === 0 && contentLoader.item !== null && contentLoader.item.installedView === false && contentLoader.item.categoriesView === false
        onTriggered: {
            root.searchText = ""
            if (contentLoader.item) {
                contentLoader.item.installedView = false
                contentLoader.item.categoriesView = false
                settings.startInInstalledView = false
            }
        }
    }

    Action {
        id: flathubCategoriesAction
        property bool actionVisible: root.currentSection === 0 && contentLoader.item !== null && typeof contentLoader.item.categoriesView !== "undefined"

        text: qsTr("Browse Categories")
        icon.name: "appfinder-flathub-store"
        checkable: true
        checked: root.currentSection === 0 && contentLoader.item !== null && contentLoader.item.categoriesView === true
        onTriggered: {
            root.searchText = ""
            if (contentLoader.item) {
                contentLoader.item.installedView = false
                contentLoader.item.categoriesView = true
                contentLoader.item.selectedCategory = ""
                settings.startInInstalledView = false
            }
        }
    }

    Action {
        id: flathubInstalledAction
        property bool actionVisible: root.currentSection === 0 && contentLoader.item !== null && typeof contentLoader.item.installedView !== "undefined"

        text: qsTr("Installed Flatpaks")
        icon.name: "appfinder-library"
        checkable: true
        checked: root.currentSection === 0 && contentLoader.item !== null && contentLoader.item.installedView === true
        onTriggered: {
            root.searchText = ""
            if (contentLoader.item) {
                contentLoader.item.installedView = true
                contentLoader.item.categoriesView = false
                settings.startInInstalledView = true
            }
        }
    }

    Action {
        id: appHubExploreAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined"

        text: qsTr("Explore NX AppHub")
        icon.name: "go-home"
        checkable: true
        checked: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Recipes
        onTriggered: {
            root.searchText = ""
            if (contentLoader.item)
                contentLoader.item.requestViewMode(AppHubPage.Recipes)
        }
    }

    Action {
        id: appHubBuilderAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined"

        text: qsTr("Personal Bundle Builder")
        icon.name: "run-build"
        checkable: true
        checked: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Builder
        onTriggered: {
            root.searchText = ""
            root.compactSearchOpen = false
            appHub.search("")
            if (contentLoader.item)
                contentLoader.item.requestViewMode(AppHubPage.Builder)
        }
    }

    Action {
        id: appHubInstalledAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined"

        text: qsTr("Installed AppBoxes")
        icon.name: "appfinder-appboxes"
        checkable: true
        checked: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Installed
        onTriggered: {
            root.searchText = ""
            if (contentLoader.item)
                contentLoader.item.requestViewMode(AppHubPage.Installed)
        }
    }

    Action {
        id: appHubWikiAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Builder

        text: qsTr("NX AppHub Wiki")
        icon.name: "help-contents"
        onTriggered: Qt.openUrlExternally("https://github.com/Nitrux/nx-apphub/wiki")
    }

    Action {
        id: appHubRefreshAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Recipes

        text: qsTr("Refresh Apps Repo")
        icon.name: "appfinder-repo-apphub"
        enabled: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Recipes && !appHub.busy
        onTriggered: appHub.refreshAppHubRepository()
    }

    Action {
        id: appHubBackAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0

        text: qsTr("Back to Projects")
        icon.name: "go-previous"
        enabled: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0 && !appHub.busy
        onTriggered: contentLoader.item.closeEditor()
    }

    Action {
        id: appHubSaveAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0

        text: qsTr("Save Bundle")
        icon.name: "document-save"
        enabled: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.projectIdValid && (contentLoader.item.editingProject.length === 0 || contentLoader.item.editorDirty) && !appHub.busy
        onTriggered: contentLoader.item.saveEditor()
    }

    Action {
        id: appHubBuildAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0

        text: qsTr("Build Bundle")
        icon.name: "run-build"
        enabled: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.projectIdValid && !appHub.busy
        onTriggered: contentLoader.item.buildEditor()
    }

    Action {
        id: appHubRevealAction
        property bool actionVisible: root.currentSection === 1 && contentLoader.item !== null && typeof contentLoader.item.viewMode !== "undefined" && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0 && contentLoader.item.artifactUrl.length > 0

        text: qsTr("Reveal Output")
        icon.name: "folder-open"
        enabled: root.currentSection === 1 && contentLoader.item !== null && contentLoader.item.viewMode === AppHubPage.Builder && contentLoader.item.editingProject.length > 0 && contentLoader.item.artifactUrl.length > 0 && !appHub.busy
        onTriggered: contentLoader.item.revealEditorOutput()
    }

    function applySection(section) {
        currentSection = section
        if (section <= 2)
            appHub.currentSection = section
        if (sidebar.sideBar.collapsed)
            sidebar.sideBar.close()
    }

    function selectSection(section) {
        if (section === 4) {
            openSettingsDialog()
            return
        }
        if (section === 1 && currentSection === section && contentLoader.item) {
            root.searchText = ""
            contentLoader.item.requestViewMode(AppHubPage.Recipes)
            return
        }
        if (currentSection === 1 && section !== 1 && contentLoader.item) {
            contentLoader.item.requestSectionLeave(section)
            return
        }
        applySection(section)
    }

    function openSettingsDialog() {
        const dialog = settingsDialogComponent.createObject(root)
        dialog.open()
    }

    function submitSearch() {
        if (root.searchAvailable)
            appHub.search(root.searchText)
    }

    onClosing: function(close) {
        if (!root.closeApproved && root.currentSection === 1 && contentLoader.item && contentLoader.item.hasUnsavedChanges) {
            close.accepted = false
            contentLoader.item.requestClose()
        }
    }

    Component.onCompleted: {
        appHub.flatpakSortMode = settings.flatpakSortMode
        if (settings.refreshOnStartup)
            appHub.refresh()
    }

    Maui.WindowBlur {
        view: root
        geometry: Qt.rect(0, 0, root.width, root.height)
        windowRadius: Maui.Style.radiusV
        enabled: true
    }

    Rectangle {
        anchors.fill: parent
        color: Maui.Theme.backgroundColor
        opacity: 0.76
        radius: Maui.Style.radiusV
    }

    Maui.SideBarView {
        id: sidebar
        anchors.fill: parent
        sideBar.preferredWidth: Maui.Style.units.gridUnit * 12
        sideBar.minimumWidth: Maui.Style.units.gridUnit * 12
        sideBar.autoShow: settings.sidebarVisible
        sideBar.autoHide: true
        sideBar.floats: sideBar.collapsed
        background: null
        Maui.Theme.colorSet: Maui.Theme.View

        sideBarContent: Item {
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            anchors.rightMargin: 0

            NavigationSidebar {
                anchors.fill: parent
                anchors.rightMargin: 0
                currentSection: root.currentSection
                onSectionSelected: function(section) { root.selectSection(section) }
            }
        }

        Connections {
            target: sidebar.sideBar
            function onOpened() { settings.sidebarVisible = true }
            function onClosed() { settings.sidebarVisible = false }
        }

        Maui.PageLayout {
            id: page
            anchors.fill: parent
            clip: true
            background: null

            readonly property bool compactSearch: width < Maui.Style.units.gridUnit * 42

            split: compactSearch && root.compactSearchOpen && root.searchAvailable
            splitSection: Maui.PageLayout.Section.Middle
            splitIn: ToolBar.Header
            altHeader: Maui.Handy.isMobile
            Maui.Controls.showCSD: true

            onCompactSearchChanged: {
                if (!compactSearch)
                    root.compactSearchOpen = false
            }

            headBar.visible: true
            headBar.forceCenterMiddleContent: !page.compactSearch
            headerMargins: Maui.Handy.isMobile ? 0 : Maui.Style.contentMargins
            footerMargins: headerMargins

            Maui.Theme.colorSet: Maui.Theme.View

            headBar.leftContent: [
                ToolButton {
                    text: qsTr("Toggle Sidebar")
                    display: AbstractButton.IconOnly
                    checkable: true
                    icon.name: sidebar.sideBar.visible ? "sidebar-collapse" : "sidebar-expand"
                    checked: sidebar.sideBar.visible
                    ToolTip.visible: hovered
                    ToolTip.text: qsTr("Toggle navigation")
                    onClicked: sidebar.sideBar.toggle()
                },

                ToolSeparator {
                    visible: (root.currentSection === 0
                              && contentLoader.item !== null
                              && typeof contentLoader.item.categoriesView !== "undefined"
                              && contentLoader.item.categoriesView
                              && !contentLoader.item.searchActive
                              && contentLoader.item.selectedCategory.length > 0)
                             || (root.currentSection === 1
                                 && contentLoader.item !== null
                                 && typeof contentLoader.item.viewMode !== "undefined"
                                 && contentLoader.item.viewMode === AppHubPage.Builder)
                    bottomPadding: 10
                    topPadding: 10
                },

                ToolButton {
                    visible: root.currentSection === 0
                             && contentLoader.item !== null
                             && typeof contentLoader.item.categoriesView !== "undefined"
                             && contentLoader.item.categoriesView
                             && !contentLoader.item.searchActive
                             && contentLoader.item.selectedCategory.length > 0
                    text: qsTr("All Categories")
                    display: AbstractButton.IconOnly
                    icon.name: "go-previous"
                    ToolTip.visible: hovered
                    ToolTip.text: text
                    onClicked: {
                        contentLoader.item.selectedCategory = ""
                        contentLoader.item.selectedSubcategory = ""
                    }
                },

                ToolButton {
                    visible: root.currentSection === 1
                             && contentLoader.item !== null
                             && typeof contentLoader.item.viewMode !== "undefined"
                             && contentLoader.item.viewMode === AppHubPage.Builder
                    action: appHubSaveAction
                    display: AbstractButton.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: text
                },

                ToolButton {
                    visible: root.currentSection === 1
                             && contentLoader.item !== null
                             && typeof contentLoader.item.viewMode !== "undefined"
                             && contentLoader.item.viewMode === AppHubPage.Builder
                    action: appHubBuildAction
                    display: AbstractButton.IconOnly
                    ToolTip.visible: hovered
                    ToolTip.text: text
                }
            ]

            middleContent: [
                Maui.SearchField {
                    id: globalSearch
                    Layout.preferredWidth: Maui.Style.units.gridUnit * 18
                    Layout.maximumWidth: Maui.Style.units.gridUnit * 26
                    Layout.alignment: Qt.AlignCenter
                    visible: root.searchAvailable && !page.compactSearch
                    enabled: visible
                    placeholderText: qsTr("Search %1...").arg(root.currentTitle)
                    text: root.searchText

                    onTextChanged: {
                        root.searchText = text
                        searchTimer.restart()
                    }
                    onAccepted: {
                        searchTimer.stop()
                        root.submitSearch()
                    }
                    onCleared: {
                        root.searchText = ""
                        searchTimer.stop()
                        root.submitSearch()
                    }
                },

                Maui.SearchField {
                    id: compactGlobalSearch
                    Layout.fillWidth: true
                    Layout.maximumWidth: Maui.Style.units.gridUnit * 26
                    Layout.alignment: Qt.AlignCenter
                    visible: page.compactSearch && root.compactSearchOpen && root.searchAvailable
                    enabled: visible
                    placeholderText: qsTr("Search %1...").arg(root.currentTitle)
                    text: root.searchText

                    onVisibleChanged: {
                        if (visible)
                            forceActiveFocus()
                    }

                    onTextChanged: {
                        root.searchText = text
                        searchTimer.restart()
                    }
                    onAccepted: {
                        searchTimer.stop()
                        root.submitSearch()
                    }
                    onCleared: {
                        root.searchText = ""
                        searchTimer.stop()
                        root.submitSearch()
                    }
                }
            ]

            headBar.rightContent: [
                ToolButton {
                    visible: root.searchAvailable && page.compactSearch
                    text: qsTr("Search %1...").arg(root.currentTitle)
                    display: AbstractButton.IconOnly
                    checkable: true
                    checked: root.compactSearchOpen
                    icon.name: "edit-find"
                    ToolTip.visible: hovered
                    ToolTip.text: text
                    onClicked: root.compactSearchOpen = !root.compactSearchOpen
                },

                ToolSeparator {
                    bottomPadding: 10
                    topPadding: 10
                },

                Maui.ToolButtonMenu {
                    icon.name: "overflow-menu"

                    Menu {
                        title: qsTr("Sort Installed Flatpaks")
                        icon.name: "view-sort"
                        enabled: root.currentSection === 0 && contentLoader.item !== null && contentLoader.item.installedView
                        Maui.Controls.component: Component {
                            Item {
                                visible: false
                            }
                        }

                        MenuItem {
                            text: qsTr("Name")
                            checkable: true
                            autoExclusive: true
                            checked: appHub.flatpakSortMode === "name"
                            onTriggered: {
                                settings.flatpakSortMode = "name"
                                appHub.flatpakSortMode = "name"
                            }
                        }

                        MenuItem {
                            text: qsTr("Size")
                            checkable: true
                            autoExclusive: true
                            checked: appHub.flatpakSortMode === "size"
                            onTriggered: {
                                settings.flatpakSortMode = "size"
                                appHub.flatpakSortMode = "size"
                            }
                        }
                    }

                    MenuItem {
                        text: qsTr("Preferences")
                        icon.name: "settings-configure"
                        onTriggered: root.selectSection(4)
                    }

                    MenuItem {
                        text: qsTr("About")
                        icon.name: "documentinfo"
                        onTriggered: Maui.App.aboutDialog()
                    }
                }
            ]

            Loader {
                id: contentLoader
                anchors.fill: parent
                sourceComponent: root.currentSection === 0 ? flathubPage
                                 : root.currentSection === 1 ? appHubPage
                                                              : distroboxPage
            }
            AppFinderActionBar {
                id: actionBar
                z: 1
                anchors.fill: parent
                dragTarget: actionBar
                actions: root.actionBarActions
            }
        }
    }

    Timer {
        id: searchTimer
        interval: 250
        repeat: false
        onTriggered: root.submitSearch()
    }

    Component {
        id: flathubPage
        FlathubPage {
            query: root.searchText
            initialInstalledView: settings.startInInstalledView
            onViewModeChanged: settings.startInInstalledView = installed
        }
    }

    Component {
        id: settingsDialogComponent
        SettingsDialog {
            appSettings: root.appSettings
            onClosed: destroy()
        }
    }

    Component {
        id: appHubPage
        AppHubPage {
            onSectionLeaveApproved: function(section) { root.applySection(section) }
            onCloseApproved: {
                root.closeApproved = true
                root.close()
            }
        }
    }

    Component {
        id: distroboxPage
        DistroboxPage {
            onCreateContainerRequested: createDialog.open()
            onCloneRequested: function(source) {
                cloneDialog.sourceName = source
                cloneDialog.open()
            }
        }
    }

    Maui.InfoDialog {
        id: createDialog
        title: qsTr("New Container")
        message: qsTr("Create a development sandbox with Distrobox.")
        standardButtons: Dialog.Ok | Dialog.Cancel

        Maui.TextField {
            id: containerNameField
            Layout.fillWidth: true
            placeholderText: qsTr("Container name")
        }

        Maui.TextField {
            id: containerImageField
            Layout.fillWidth: true
            placeholderText: qsTr("Base image (for example, ubuntu:24.04)")
            text: "ubuntu:24.04"
        }

        Maui.TextField {
            id: containerHomeField
            Layout.fillWidth: true
            placeholderText: qsTr("Custom home directory (optional)")
        }

        onAccepted: {
            appHub.createDistrobox(containerNameField.text, containerImageField.text, containerHomeField.text)
            containerNameField.clear()
            containerHomeField.clear()
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
