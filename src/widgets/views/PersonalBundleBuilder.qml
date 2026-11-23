/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtCore
import QtQml
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.ScrollColumn {
    id: builderScroll
    property var pageController
    property var repositoryModelRef
    property var ppaModelRef
    property var dependencyModelRef
    property var environmentModelRef
    property var rpathModelRef
    property var prebuildModelRef
    property var bwrapEnvironmentModelRef
    property var sandboxStringModelRef
    property var sandboxBooleanModelRef
    anchors.fill: parent
    padding: Maui.Style.contentMargins
    spacing: Maui.Style.space.medium
    function forwardGridWheel(wheel) {
        const usePixelDelta = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0
        const horizontalDelta = usePixelDelta ? wheel.pixelDelta.x : wheel.angleDelta.x
        const verticalDelta = usePixelDelta ? wheel.pixelDelta.y : wheel.angleDelta.y

        if (Math.abs(verticalDelta) < Math.abs(horizontalDelta)) {
            wheel.accepted = false
            return
        }

        const pageFlickable = builderScroll.flickable
        const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
        pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
        wheel.accepted = true
    }


    Maui.SectionHeader {
        Layout.fillWidth: true
        text1: pageController.editingProject.length > 0 ? pageController.bundleName : qsTr("Personal Bundle Builder")
        text2: pageController.editingProject.length > 0
               ? qsTr("Project %1 • Personal Bundle • %2").arg(pageController.editingProject).arg(appHub.userBundleArchitecture)
               : qsTr("Create and maintain local bundles. Personal bundles remain separate from managed AppBoxes.")
        label2.wrapMode: Text.Wrap
    }

    Rectangle {
        Layout.fillWidth: true
        color: Maui.Theme.alternateBackgroundColor
        radius: Maui.Style.radiusV
        border.color: Maui.Theme.backgroundColor
        border.width: 1
        implicitHeight: builderProjectLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: builderProjectLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Project")
                text2: pageController.editingProject.length > 0
                       ? qsTr("Save recipe changes or build the current project as a bundle.")
                       : qsTr("Choose a project ID, complete the recipe, then save it or build it directly.")
                label2.wrapMode: Text.Wrap
            }

            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Project ID")
                label2.text: qsTr("Unique local identifier using lowercase letters, numbers, dots, underscores, or hyphens.")
                label2.wrapMode: Text.Wrap

                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.bundleProjectId
                    readOnly: pageController.editingProject.length > 0
                    maximumLength: 128
                    placeholderText: qsTr("my-application")
                    validator: RegularExpressionValidator { regularExpression: /^[a-z0-9][a-z0-9._-]{0,127}$/ }
                    onTextEdited: {
                        pageController.bundleProjectId = text
                        pageController.markDirty()
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
        implicitHeight: applicationLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: applicationLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Application")
                text2: qsTr("Core bundle identity and target runtime.")
                label2.wrapMode: Text.Wrap
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Bundle name")
                label2.text: qsTr("Name used for the bundle filename and application metadata.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.bundleName; onTextEdited: { pageController.bundleName = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Version")
                label2.text: qsTr("Version written to the recipe and generated bundle filename.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.bundleVersion; onTextEdited: { pageController.bundleVersion = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Binary path")
                label2.text: qsTr("Absolute path inside the bundle")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.binaryPath; onTextEdited: { pageController.binaryPath = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Runtime")
                label2.text: qsTr("Runtime format used to package and start the application.")
                template.content: ComboBox {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    model: pageController.runtimeTypes
                    currentIndex: Math.max(0, pageController.runtimeTypes.indexOf(pageController.runtimeType))
                    onActivated: { pageController.runtimeType = currentText; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Specify OS target")
                label2.text: qsTr("Include an optional target platform identifier in the build recipe.")
                label2.wrapMode: Text.Wrap
                template.content: Switch {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    checked: pageController.osTargetEnabled
                    onToggled: { pageController.osTargetEnabled = checked; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                enabled: pageController.osTargetEnabled
                label1.text: qsTr("OS version target")
                label2.text: qsTr("Target platform version identifier written to the build recipe.")
                label2.wrapMode: Text.Wrap
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.osTarget
                    onTextEdited: { pageController.osTarget = text; pageController.markDirty() }
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
        implicitHeight: repositoriesLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: repositoriesLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Repositories")
                text2: qsTr("Package sources using the host-compatible %1 architecture.").arg(appHub.userBundleArchitecture)
                label2.wrapMode: Text.Wrap
            }

            Repeater {
                model: repositoryModelRef
                delegate: Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("%1 %2").arg(model.distro).arg(model.releaseName)
                    label1.elide: Text.ElideRight
                    label1.wrapMode: Text.NoWrap
                    label2.text: qsTr("%1 components • %2").arg(model.components).arg(model.architecture)
                                 + (model.snapshot.length > 0 ? qsTr(" • Snapshot %1").arg(model.snapshot) : "")
                    label2.elide: Text.ElideRight
                    label2.wrapMode: Text.NoWrap

                    template.content: RowLayout {
                        spacing: Maui.Style.space.tiny

                        ToolButton {
                            icon.name: "document-edit"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Edit repository")
                            onClicked: pageController.openCollectionEditor("repository", index)
                        }

                        ToolButton {
                            icon.name: "edit-delete"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Remove repository")
                            onClicked: {
                                pageController.markDirty()
                                repositoryModelRef.remove(index)
                            }
                        }
                    }
                }
            }

            Maui.SectionItem {
                Layout.fillWidth: true
                visible: repositoryModelRef.count === 0
                flat: true
                label1.text: qsTr("No repositories configured")
                label2.text: qsTr("Add a package source for the required dependencies.")
                label2.wrapMode: Text.Wrap
                template.iconSource: "documentinfo"
            }

            Button {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Add Repository")
                onClicked: pageController.openCollectionEditor("repository", -1)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        color: Maui.Theme.alternateBackgroundColor
        radius: Maui.Style.radiusV
        border.color: Maui.Theme.backgroundColor
        border.width: 1
        implicitHeight: ppasLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: ppasLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("PPAs (Optional)")
                text2: qsTr("Optional package archives that dependencies may reference by PPA ID.")
                label2.wrapMode: Text.Wrap
            }

            Repeater {
                model: ppaModelRef
                delegate: Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: model.ppaName
                    label1.elide: Text.ElideRight
                    label1.wrapMode: Text.NoWrap
                    label2.text: qsTr("ID: %1 • Release: %2").arg(model.ppaId).arg(model.releaseName)
                    label2.elide: Text.ElideRight
                    label2.wrapMode: Text.NoWrap

                    template.content: RowLayout {
                        spacing: Maui.Style.space.tiny

                        ToolButton {
                            icon.name: "document-edit"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Edit PPA")
                            onClicked: pageController.openCollectionEditor("ppa", index)
                        }

                        ToolButton {
                            icon.name: "edit-delete"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Remove PPA")
                            onClicked: {
                                pageController.markDirty()
                                ppaModelRef.remove(index)
                            }
                        }
                    }
                }
            }

            Maui.SectionItem {
                Layout.fillWidth: true
                visible: ppaModelRef.count === 0
                flat: true
                label1.text: qsTr("No optional PPAs configured")
                label2.text: qsTr("Dependencies can use the configured repositories without a PPA.")
                label2.wrapMode: Text.Wrap
                template.iconSource: "documentinfo"
            }

            Button {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Add PPA")
                enabled: pageController.ppaAvailable
                onClicked: pageController.openCollectionEditor("ppa", -1)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        color: Maui.Theme.alternateBackgroundColor
        radius: Maui.Style.radiusV
        border.color: Maui.Theme.backgroundColor
        border.width: 1
        implicitHeight: dependenciesLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: dependenciesLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Dependencies")
                text2: qsTr("Packages required by the application and included in the bundle.")
                label2.wrapMode: Text.Wrap
            }

            Repeater {
                model: dependencyModelRef
                delegate: Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: model.dependencyName
                    label1.elide: Text.ElideRight
                    label1.wrapMode: Text.NoWrap
                    label2.text: model.repositoryId.length > 0 ? qsTr("Provided by PPA %1").arg(model.repositoryId) : qsTr("Provided by the configured repositories")
                    label2.elide: Text.ElideRight
                    label2.wrapMode: Text.NoWrap

                    template.content: RowLayout {
                        spacing: Maui.Style.space.tiny

                        ToolButton {
                            icon.name: "document-edit"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Edit dependency")
                            onClicked: pageController.openCollectionEditor("dependency", index)
                        }

                        ToolButton {
                            icon.name: "edit-delete"
                            display: ToolButton.IconOnly
                            ToolTip.visible: hovered
                            ToolTip.text: qsTr("Remove dependency")
                            onClicked: {
                                pageController.markDirty()
                                dependencyModelRef.remove(index)
                            }
                        }
                    }
                }
            }

            Maui.SectionItem {
                Layout.fillWidth: true
                visible: dependencyModelRef.count === 0
                flat: true
                label1.text: qsTr("No dependencies configured")
                label2.text: qsTr("Add every package required by the application.")
                label2.wrapMode: Text.Wrap
                template.iconSource: "documentinfo"
            }

            Button {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Add Dependency")
                onClicked: pageController.openCollectionEditor("dependency", -1)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        color: Maui.Theme.alternateBackgroundColor
        radius: Maui.Style.radiusV
        border.color: Maui.Theme.backgroundColor
        border.width: 1
        implicitHeight: integrationLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: integrationLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Integration")
                text2: qsTr("Choose how the generated bundle integrates with the host.")
                label2.wrapMode: Text.Wrap
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Integration type")
                label2.text: qsTr("Choose graphical, command-line, or window-manager integration.")
                template.content: ComboBox {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    model: pageController.integrationTypes
                    currentIndex: Math.max(0, pageController.integrationTypes.indexOf(pageController.integrationType))
                    onActivated: {
                        pageController.integrationType = currentText
                        pageController.markDirty()
                    }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Create desktop launcher")
                label2.text: qsTr("Enable menu integration through an optional desktop file.")
                label2.wrapMode: Text.Wrap
                template.content: Switch {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    checked: pageController.launcherEnabled
                    onToggled: { pageController.launcherEnabled = checked; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                enabled: pageController.launcherEnabled
                label1.text: qsTr("Desktop launcher")
                label2.text: qsTr("Desktop-file basename ending in .desktop for menu integration.")
                label2.wrapMode: Text.Wrap
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.launcher
                    onTextEdited: { pageController.launcher = text; pageController.markDirty() }
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
        implicitHeight: launchLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: launchLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Launch Configuration")
                text2: qsTr("Entrypoint and environment used by AppRun.")
                label2.wrapMode: Text.Wrap
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Executable")
                label2.text: qsTr("Absolute path to the program AppRun starts inside the bundle.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.launchExec; onTextEdited: { pageController.launchExec = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("PATH")
                label2.text: qsTr("Executable search path exported when the bundle starts.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.launchPath; onTextEdited: { pageController.launchPath = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Library path")
                label2.text: qsTr("Library search path exported when the bundle starts.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.launchLibraryPath; onTextEdited: { pageController.launchLibraryPath = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Advanced launch options")
                label2.text: qsTr("Enable environment variables, extra runtime search paths, and pre-build commands.")
                label2.wrapMode: Text.Wrap

                template.content: Switch {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    checked: pageController.launchAdvancedVisible
                    onToggled: {
                        pageController.launchAdvancedVisible = checked
                        pageController.markDirty()
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                enabled: pageController.launchAdvancedVisible
                spacing: Maui.Style.space.small

                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Environment variables")
                    label1.font.weight: Font.DemiBold
                }

                Repeater {
                    model: environmentModelRef
                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: model.entryKey
                        label1.elide: Text.ElideRight
                        label1.wrapMode: Text.NoWrap
                        label2.text: model.entryValue
                        label2.elide: Text.ElideRight
                        label2.wrapMode: Text.NoWrap

                        template.content: RowLayout {
                            spacing: Maui.Style.space.tiny

                            ToolButton {
                                icon.name: "document-edit"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Edit environment variable")
                                onClicked: pageController.openCollectionEditor("environment", index)
                            }

                            ToolButton {
                                icon.name: "edit-delete"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Remove environment variable")
                                onClicked: {
                                    pageController.markDirty()
                                    environmentModelRef.remove(index)
                                }
                            }
                        }
                    }
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    visible: environmentModelRef.count === 0
                    flat: true
                    label1.text: qsTr("No environment variables configured")
                    label2.text: qsTr("Add variables exported by AppRun when the application starts.")
                    label2.wrapMode: Text.Wrap
                    template.iconSource: "documentinfo"
                }

                Button {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Add Environment Variable")
                    onClicked: pageController.openCollectionEditor("environment", -1)
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Extra RPATHs")
                    label1.font.weight: Font.DemiBold
                }

                Repeater {
                    model: rpathModelRef
                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: model.entryValue
                        label1.elide: Text.ElideRight
                        label1.wrapMode: Text.NoWrap
                        label2.text: qsTr("Additional runtime library search path")
                        label2.elide: Text.ElideRight
                        label2.wrapMode: Text.NoWrap

                        template.content: RowLayout {
                            spacing: Maui.Style.space.tiny

                            ToolButton {
                                icon.name: "document-edit"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Edit RPATH")
                                onClicked: pageController.openCollectionEditor("rpath", index)
                            }

                            ToolButton {
                                icon.name: "edit-delete"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Remove RPATH")
                                onClicked: {
                                    pageController.markDirty()
                                    rpathModelRef.remove(index)
                                }
                            }
                        }
                    }
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    visible: rpathModelRef.count === 0
                    flat: true
                    label1.text: qsTr("No extra RPATHs configured")
                    label2.text: qsTr("Add a runtime library search path when the default paths are insufficient.")
                    label2.wrapMode: Text.Wrap
                    template.iconSource: "documentinfo"
                }

                Button {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Add RPATH")
                    onClicked: pageController.openCollectionEditor("rpath", -1)
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Pre-build commands")
                    label1.color: Maui.Theme.negativeTextColor
                    label1.font.weight: Font.DemiBold
                }

                Repeater {
                    model: prebuildModelRef
                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: model.entryValue
                        label1.elide: Text.ElideRight
                        label1.wrapMode: Text.NoWrap
                        label2.text: qsTr("Executed by nx-apphub-cli before the build")
                        label2.elide: Text.ElideRight
                        label2.wrapMode: Text.NoWrap

                        template.content: RowLayout {
                            spacing: Maui.Style.space.tiny

                            ToolButton {
                                icon.name: "document-edit"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Edit pre-build command")
                                onClicked: pageController.openCollectionEditor("prebuild", index)
                            }

                            ToolButton {
                                icon.name: "edit-delete"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Remove pre-build command")
                                onClicked: {
                                    pageController.markDirty()
                                    prebuildModelRef.remove(index)
                                }
                            }
                        }
                    }
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    visible: prebuildModelRef.count === 0
                    flat: true
                    label1.text: qsTr("No pre-build commands configured")
                    label2.text: qsTr("Commands are optional and run before the bundle is built.")
                    label2.wrapMode: Text.Wrap
                    template.iconSource: "documentinfo"
                }

                Button {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Add Pre-build Command")
                    onClicked: pageController.openCollectionEditor("prebuild", -1)
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
        implicitHeight: sandboxLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: sandboxLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Sandbox")
                text2: pageController.integrationType === "wm" ? qsTr("Desktop sessions and window managers run without a sandbox.") : qsTr("Optional runtime isolation for this personal bundle.")
                label2.wrapMode: Text.Wrap
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                enabled: pageController.integrationType !== "wm"
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Sandbox type")
                label2.text: qsTr("Choose Bubblewrap for GUI or CLI applications, or Firejail for CLI applications.")
                template.content: ComboBox {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    model: pageController.sandboxTypes
                    currentIndex: Math.max(0, pageController.sandboxTypes.indexOf(pageController.sandboxType))
                    onActivated: {
                        pageController.sandboxType = currentText
                        pageController.markDirty()
                    }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                visible: pageController.sandboxType === "firejail"
                label1.text: qsTr("Firejail profile name")
                label2.text: qsTr("Required profile name. Firejail sandboxing requires command-line integration.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.firejailName; onTextEdited: { pageController.firejailName = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                visible: pageController.sandboxType === "firejail"
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Use AppArmor profile")
                label2.text: qsTr("Associate an optional AppArmor profile with the Firejail sandbox.")
                label2.wrapMode: Text.Wrap
                template.content: Switch {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    checked: pageController.appArmorProfileEnabled
                    onToggled: { pageController.appArmorProfileEnabled = checked; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                visible: pageController.sandboxType === "firejail"
                Layout.fillWidth: true
                flat: true
                enabled: pageController.appArmorProfileEnabled
                label1.text: qsTr("AppArmor profile")
                label2.text: qsTr("AppArmor profile name associated with the Firejail sandbox.")
                label2.wrapMode: Text.Wrap
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.appArmorProfile
                    onTextEdited: { pageController.appArmorProfile = text; pageController.markDirty() }
                }
            }
            ColumnLayout {
                visible: pageController.sandboxType === "bwrap" && pageController.integrationType !== "wm"
                Layout.fillWidth: true
                spacing: Maui.Style.space.small
                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Isolation options")
                    text2: qsTr("Configure filesystem access, namespaces, and process isolation.")
                    label2.wrapMode: Text.Wrap
                }
                Repeater {
                    model: sandboxBooleanModelRef
                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: pageController.sandboxBooleanLabel(model.option)
                        label2.text: pageController.sandboxBooleanDescription(model.option)
                        label2.wrapMode: Text.Wrap
                        template.content: Switch {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: pageController.configureResponsiveControl(this)
                            checked: model.selected
                            onToggled: {
                                sandboxBooleanModelRef.setProperty(index, "selected", checked)
                                pageController.markDirty()
                            }
                        }
                    }
                }
                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Environment Variables")
                    text2: qsTr("Variables added to the Bubblewrap sandbox environment.")
                    label2.wrapMode: Text.Wrap
                }

                Repeater {
                    model: bwrapEnvironmentModelRef
                    delegate: Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label1.text: model.entryKey
                        label1.elide: Text.ElideRight
                        label1.wrapMode: Text.NoWrap
                        label2.text: model.entryValue
                        label2.elide: Text.ElideRight
                        label2.wrapMode: Text.NoWrap

                        template.content: RowLayout {
                            spacing: Maui.Style.space.tiny

                            ToolButton {
                                icon.name: "document-edit"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Edit sandbox environment variable")
                                onClicked: pageController.openCollectionEditor("bwrapEnvironment", index)
                            }

                            ToolButton {
                                icon.name: "edit-delete"
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Remove sandbox environment variable")
                                onClicked: {
                                    pageController.markDirty()
                                    bwrapEnvironmentModelRef.remove(index)
                                }
                            }
                        }
                    }
                }

                Maui.SectionItem {
                    Layout.fillWidth: true
                    visible: bwrapEnvironmentModelRef.count === 0
                    flat: true
                    label1.text: qsTr("No sandbox environment variables configured")
                    label2.text: qsTr("Add variables that Bubblewrap should expose to the application.")
                    label2.wrapMode: Text.Wrap
                    template.iconSource: "documentinfo"
                }

                Button {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Add Environment Variable")
                    onClicked: pageController.openCollectionEditor("bwrapEnvironment", -1)
                }

                Maui.SectionHeader {
                    Layout.fillWidth: true
                    text1: qsTr("Bindings and Capabilities")
                    text2: qsTr("Expose paths or adjust capabilities inside the Bubblewrap sandbox.")
                    label2.wrapMode: Text.Wrap
                }
                Repeater {
                    model: sandboxStringModelRef
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            Layout.fillWidth: true
                            model: pageController.sandboxListOptions
                            currentIndex: Math.max(0, pageController.sandboxListOptions.indexOf(sandboxStringModelRef.get(index).option))
                            onActivated: { sandboxStringModelRef.setProperty(index, "option", currentText); pageController.markDirty() }
                        }
                        Maui.TextField { Layout.fillWidth: true; text: model.entryValue; placeholderText: qsTr("Value"); onTextEdited: { sandboxStringModelRef.setProperty(index, "entryValue", text); pageController.markDirty() } }
                        ToolButton { text: qsTr("Remove Option"); display: ToolButton.IconOnly; icon.name: "list-remove"; onClicked: { pageController.markDirty(); sandboxStringModelRef.remove(index) } }
                    }
                }
                Button { Layout.alignment: Qt.AlignRight; text: qsTr("Add Binding or Capability"); onClicked: { sandboxStringModelRef.append({"option": "bind", "entryValue": ""}); pageController.markDirty() } }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Set sandbox hostname")
                    label2.text: qsTr("Override the hostname exposed inside the Bubblewrap sandbox.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        checked: pageController.sandboxHostnameEnabled
                        onToggled: { pageController.sandboxHostnameEnabled = checked; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    enabled: pageController.sandboxHostnameEnabled
                    label1.text: qsTr("Hostname")
                    label2.text: qsTr("Hostname exposed inside the Bubblewrap sandbox.")
                    label2.wrapMode: Text.Wrap
                    template.content: Maui.TextField {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        Layout.fillWidth: responsiveNarrow
                        Layout.minimumWidth: responsiveNarrow ? 0 : -1
                        Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                        Layout.preferredWidth: pageController.settingsControlWidth
                        text: pageController.sandboxHostname
                        onTextEdited: { pageController.sandboxHostname = text; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Set working directory")
                    label2.text: qsTr("Choose the directory used before the sandboxed application starts.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        checked: pageController.sandboxWorkingDirectoryEnabled
                        onToggled: { pageController.sandboxWorkingDirectoryEnabled = checked; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    enabled: pageController.sandboxWorkingDirectoryEnabled
                    label1.text: qsTr("Working directory")
                    label2.text: qsTr("Directory selected before the sandboxed application starts.")
                    label2.wrapMode: Text.Wrap
                    template.content: Maui.TextField {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        Layout.fillWidth: responsiveNarrow
                        Layout.minimumWidth: responsiveNarrow ? 0 : -1
                        Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                        Layout.preferredWidth: pageController.settingsControlWidth
                        text: pageController.sandboxWorkingDirectory
                        onTextEdited: { pageController.sandboxWorkingDirectory = text; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Set SELinux file label")
                    label2.text: qsTr("Apply an optional SELinux label to files inside the sandbox.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        checked: pageController.sandboxFileLabelEnabled
                        onToggled: { pageController.sandboxFileLabelEnabled = checked; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    enabled: pageController.sandboxFileLabelEnabled
                    label1.text: qsTr("File label")
                    label2.text: qsTr("SELinux file label applied inside the sandbox.")
                    label2.wrapMode: Text.Wrap
                    template.content: Maui.TextField {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        Layout.fillWidth: responsiveNarrow
                        Layout.minimumWidth: responsiveNarrow ? 0 : -1
                        Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                        Layout.preferredWidth: pageController.settingsControlWidth
                        text: pageController.sandboxFileLabel
                        onTextEdited: { pageController.sandboxFileLabel = text; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Set SELinux executable label")
                    label2.text: qsTr("Apply an optional SELinux label when the sandbox starts the application.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        checked: pageController.sandboxExecLabelEnabled
                        onToggled: { pageController.sandboxExecLabelEnabled = checked; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    enabled: pageController.sandboxExecLabelEnabled
                    label1.text: qsTr("Executable label")
                    label2.text: qsTr("SELinux execution label applied when the application starts.")
                    label2.wrapMode: Text.Wrap
                    template.content: Maui.TextField {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        Layout.fillWidth: responsiveNarrow
                        Layout.minimumWidth: responsiveNarrow ? 0 : -1
                        Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                        Layout.preferredWidth: pageController.settingsControlWidth
                        text: pageController.sandboxExecLabel
                        onTextEdited: { pageController.sandboxExecLabel = text; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    label1.text: qsTr("Use seccomp filter")
                    label2.text: qsTr("Enable an optional Bubblewrap seccomp filter.")
                    label2.wrapMode: Text.Wrap
                    template.content: Switch {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        checked: pageController.sandboxSeccompEnabled
                        onToggled: { pageController.sandboxSeccompEnabled = checked; pageController.markDirty() }
                    }
                }
                Maui.SectionItem {
                    Layout.fillWidth: true
                    flat: true
                    enabled: pageController.sandboxSeccompEnabled
                    label1.text: qsTr("Seccomp file descriptor")
                    label2.text: qsTr("Non-negative file descriptor containing the seccomp filter.")
                    label2.wrapMode: Text.Wrap
                    template.content: Maui.TextField {
                        property Item wideParent
                        property Item responsiveSectionItem
                        readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                        function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                        onResponsiveNarrowChanged: updateResponsiveParent()
                        Component.onCompleted: pageController.configureResponsiveControl(this)
                        Layout.fillWidth: responsiveNarrow
                        Layout.minimumWidth: responsiveNarrow ? 0 : -1
                        Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                        Layout.preferredWidth: pageController.settingsControlWidth
                        validator: IntValidator { bottom: 0 }
                        text: pageController.sandboxSeccomp
                        onTextEdited: { pageController.sandboxSeccomp = text; pageController.markDirty() }
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
        implicitHeight: metadataLayout.implicitHeight + Maui.Style.contentMargins * 2

        ColumnLayout {
            id: metadataLayout
            anchors.fill: parent
            anchors.margins: Maui.Style.contentMargins
            spacing: Maui.Style.space.small

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Metadata")
                text2: qsTr("Local project information stored in metadata/app_description.md.")
                label2.wrapMode: Text.Wrap
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Summary")
                label2.text: qsTr("Short description shown for the personal bundle.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.metadataSummary; onTextEdited: { pageController.metadataSummary = text; pageController.markDirty() } }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Description")
                label2.text: qsTr("Detailed information stored with the local project metadata.")
                template.content: TextArea {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.metadataDescription
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    onTextChanged: { if (!pageController.loadingEditor) { pageController.metadataDescription = text; pageController.markDirty() } }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("Category")
                label2.text: qsTr("AppHub category used to classify the generated application.")
                template.content: ComboBox {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    model: pageController.metadataCategories
                    currentIndex: Math.max(0, pageController.metadataCategories.indexOf(pageController.metadataCategory))
                    onActivated: { pageController.metadataCategory = currentText; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Add homepage")
                label2.text: qsTr("Include an optional project or application website.")
                label2.wrapMode: Text.Wrap
                template.content: Switch {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    checked: pageController.metadataHomepageEnabled
                    onToggled: { pageController.metadataHomepageEnabled = checked; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                enabled: pageController.metadataHomepageEnabled
                label1.text: qsTr("Homepage")
                label2.text: qsTr("Project or application website stored in the metadata.")
                label2.wrapMode: Text.Wrap
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth
                    text: pageController.metadataHomepage
                    onTextEdited: { pageController.metadataHomepage = text; pageController.markDirty() }
                }
            }
            Maui.SectionItem {
                Layout.fillWidth: true
                flat: true
                label2.wrapMode: Text.Wrap
                label1.text: qsTr("License")
                label2.text: qsTr("License identifier recorded in the project metadata.")
                template.content: Maui.TextField {
                    property Item wideParent
                    property Item responsiveSectionItem
                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                    onResponsiveNarrowChanged: updateResponsiveParent()
                    Component.onCompleted: pageController.configureResponsiveControl(this)
                    Layout.fillWidth: responsiveNarrow
                    Layout.minimumWidth: responsiveNarrow ? 0 : -1
                    Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : pageController.settingsControlWidth
                    Layout.preferredWidth: pageController.settingsControlWidth; text: pageController.metadataLicense; onTextEdited: { pageController.metadataLicense = text; pageController.markDirty() } }
            }
        }
    }


}
