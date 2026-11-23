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

import ".."

Maui.Page {
    id: control

    enum ViewMode {
        Recipes,
        Builder,
        Installed
    }

    background: null
    headBar.visible: false

    property int viewMode: AppHubPage.Recipes
    property string query: ""
    readonly property bool searchActive: query.trim().length > 0
    property bool detailVisible: false
    property var detailItem: null

    function openDetails(item) {
        const identifier = item && item.identifier ? String(item.identifier) : ""
        const details = identifier.length > 0 ? appHub.appHubItemDetails(identifier) : ({})
        control.detailItem = details && details.identifier ? details : item
        control.detailVisible = true
    }

    function closeDetails() {
        control.detailVisible = false
        control.detailItem = null
    }

    function distributionDisplayName(identifier) {
        const normalized = String(identifier || "").trim().toLowerCase()
        const knownNames = {
            "debian": "Debian",
            "debian-snapshot": qsTr("Debian (Snapshot)"),
            "devuan": "Devuan",
            "kde-neon": "KDE Neon",
            "nitrux": "Nitrux",
            "ubuntu": "Ubuntu",
            "ubuntu-ports": "Ubuntu Ports",
            "zbkit": "ZBKit"
        }
        if (knownNames[normalized])
            return knownNames[normalized]

        const words = normalized.split(/[-_]+/).filter(word => word.length > 0)
        for (let index = 0; index < words.length; ++index)
            words[index] = words[index].charAt(0).toUpperCase() + words[index].slice(1)
        return words.join(" ")
    }

    property string selectedInstalledAppBox: ""
    property string editingProject: ""
    property string bundleProjectId: ""
    property bool editorDirty: false
    property bool loadingEditor: false
    property string artifactUrl: ""
    property string pendingAction: ""
    property int pendingValue: -1
    property bool launchAdvancedVisible: false
    property bool osTargetEnabled: false
    property bool launcherEnabled: false
    property bool appArmorProfileEnabled: false
    property bool sandboxHostnameEnabled: false
    property bool sandboxWorkingDirectoryEnabled: false
    property bool sandboxFileLabelEnabled: false
    property bool sandboxExecLabelEnabled: false
    property bool sandboxSeccompEnabled: false
    property bool metadataHomepageEnabled: false
    property string collectionEditorType: ""
    property int collectionEditorIndex: -1
    property string buildOutputProject: ""
    property bool buildOutputFinished: false
    property bool buildOutputSucceeded: false
    property string buildOutputError: ""

    property string bundleName: ""
    property string bundleVersion: ""
    property string binaryPath: ""
    property string osTarget: ""
    property string runtimeType: "classic"
    property string launchExec: ""
    property string launchPath: "/usr/bin"
    property string launchLibraryPath: "/usr/lib"
    property string integrationType: "gui"
    property string launcher: ""
    property string sandboxType: "none"
    property string firejailName: ""
    property string appArmorProfile: "none"
    property string sandboxHostname: ""
    property string sandboxWorkingDirectory: ""
    property string sandboxFileLabel: ""
    property string sandboxExecLabel: ""
    property string sandboxSeccomp: ""
    property string metadataSummary: ""
    property string metadataDescription: ""
    property string metadataCategory: "AppHub.Utilities"
    property string metadataHomepage: ""
    property string metadataLicense: ""

    readonly property bool hasUnsavedChanges: editorDirty
    readonly property bool projectIdValid: /^[a-z0-9][a-z0-9._-]{0,127}$/.test(bundleProjectId) && bundleProjectId !== "." && bundleProjectId !== ".."
    readonly property var integrationTypes: ["gui", "cli", "wm"]
    readonly property var runtimeTypes: ["classic", "go", "uruntime"]
    readonly property var sandboxTypes: ["none", "bwrap", "firejail"]
    readonly property var repositoryDistros: ["debian", "debian-snapshot", "ubuntu", "ubuntu-ports", "devuan", "kde-neon", "nitrux"]
    readonly property var metadataCategories: ["AppHub.Development", "AppHub.Graphics", "AppHub.Internet", "AppHub.Games", "AppHub.Multimedia", "AppHub.Office", "AppHub.System", "AppHub.Utilities"]
    readonly property var sandboxListOptions: ["bwrap-unset-env", "cap-drop", "bind", "ro-bind", "bind-try", "ro-bind-try", "remount-ro"]
    readonly property int settingsControlWidth: Maui.Style.units.gridUnit * 13
    readonly property bool ppaAvailable: {
        if (repositoryModel.count === 0)
            return false
        for (let index = 0; index < repositoryModel.count; ++index) {
            const distro = String(repositoryModel.get(index).distro || "").toLowerCase()
            if (distro !== "ubuntu" && distro !== "ubuntu-ports")
                return false
        }
        return true
    }

    signal sectionLeaveApproved(int section)
    signal closeApproved()

    function displayLocalPath(value) {
        let path = String(value)
        if (path.indexOf("file://") === 0)
            path = path.slice(7)
        path = decodeURIComponent(path)

        let homePath = String(StandardPaths.writableLocation(StandardPaths.HomeLocation))
        if (homePath.indexOf("file://") === 0)
            homePath = homePath.slice(7)
        homePath = decodeURIComponent(homePath)
        if (homePath.length > 1 && homePath.charAt(homePath.length - 1) === "/")
            homePath = homePath.slice(0, -1)

        if (path === homePath)
            return "~"
        if (homePath.length > 0 && path.indexOf(homePath + "/") === 0)
            return "~" + path.slice(homePath.length)
        return path
    }

    function appHubCategoryLabel(value) {
        const parts = String(value).split(".")
        const category = parts.length > 0 ? parts[parts.length - 1] : ""
        return category === "Utility" ? "Utilities" : category
    }

    function contrastingForeground(background) {
        const effectiveBackground = background.a > 0 ? background : control.Maui.Theme.alternateBackgroundColor
        return Maui.ColorUtils.brightnessForColor(effectiveBackground) === Maui.ColorUtils.Light ? "#333333" : "#fafafa"
    }

    function sandboxBooleanLabel(value) {
        const labels = {
            "ro-root": qsTr("Read-only root"), "dev": qsTr("Device access"),
            "proc": qsTr("Process filesystem"), "tmpfs": qsTr("Temporary filesystem"),
            "mqueue": qsTr("POSIX message queues"), "ro-home": qsTr("Read-only home"),
            "no-net": qsTr("Isolate network"), "no-ipc": qsTr("Isolate IPC"),
            "no-pid": qsTr("Isolate processes"), "unshare-user": qsTr("Isolate users"),
            "unshare-uts": qsTr("Isolate hostname"), "unshare-cgroup": qsTr("Isolate control groups"),
            "new-session": qsTr("Create a new session"), "cap-drop-all": qsTr("Drop all capabilities"),
            "die-with-parent": qsTr("Exit with parent process"), "clearenv": qsTr("Clear environment")
        }
        return labels[value] || value
    }

    function sandboxBooleanDescription(value) {
        const descriptions = {
            "ro-root": qsTr("Mount the sandbox root filesystem read-only."),
            "ro-home": qsTr("Mount the home directory read-only."),
            "dev": qsTr("Expose device nodes inside the sandbox."),
            "proc": qsTr("Mount the process filesystem inside the sandbox."),
            "tmpfs": qsTr("Provide a temporary in-memory filesystem."),
            "mqueue": qsTr("Expose POSIX message queues inside the sandbox."),
            "no-net": qsTr("Create the sandbox without access to the host network."),
            "no-ipc": qsTr("Use a separate IPC namespace."),
            "no-pid": qsTr("Use a separate process namespace."),
            "unshare-user": qsTr("Use a separate user namespace."),
            "unshare-uts": qsTr("Use a separate hostname namespace."),
            "unshare-cgroup": qsTr("Use a separate control-group namespace."),
            "new-session": qsTr("Start the application in a new session."),
            "cap-drop-all": qsTr("Remove all Linux capabilities from the application."),
            "die-with-parent": qsTr("Stop the application when its parent process exits."),
            "clearenv": qsTr("Start with an empty environment before adding configured variables.")
        }
        return descriptions[value] || ""
    }

    function configureResponsiveControl(item) {
        item.wideParent = item.parent
        let candidate = item.parent
        while (candidate && (typeof candidate.contentItem === "undefined" || !candidate.contentItem))
            candidate = candidate.parent
        if (!candidate)
            return
        item.responsiveSectionItem = candidate
        item.updateResponsiveParent()
    }

    function collectionEditorTitle() {
        const names = {
            "repository": qsTr("Repository"),
            "ppa": qsTr("PPA"),
            "dependency": qsTr("Dependency"),
            "environment": qsTr("Environment Variable"),
            "bwrapEnvironment": qsTr("Sandbox Environment Variable"),
            "rpath": qsTr("RPATH"),
            "prebuild": qsTr("Pre-build Command")
        }
        return (collectionEditorIndex < 0 ? qsTr("Add %1") : qsTr("Edit %1")).arg(names[collectionEditorType] || "")
    }

    function openCollectionEditor(type, index) {
        collectionEditorType = type
        collectionEditorIndex = index
        collectionPrimaryField.clear()
        collectionSecondaryField.clear()
        collectionTertiaryField.clear()
        collectionDistroField.currentIndex = 0
        if (type === "repository")
            collectionSecondaryField.text = "main"

        if (index >= 0) {
            let row
            if (type === "repository") {
                row = repositoryModel.get(index)
                collectionDistroField.currentIndex = Math.max(0, repositoryDistros.indexOf(row.distro))
                collectionPrimaryField.text = row.releaseName
                collectionSecondaryField.text = row.components
                collectionTertiaryField.text = row.snapshot
            } else if (type === "ppa") {
                row = ppaModel.get(index)
                collectionPrimaryField.text = row.ppaId
                collectionSecondaryField.text = row.ppaName
                collectionTertiaryField.text = row.releaseName
            } else if (type === "dependency") {
                row = dependencyModel.get(index)
                collectionPrimaryField.text = row.dependencyName
                collectionSecondaryField.text = row.repositoryId
            } else if (type === "environment" || type === "bwrapEnvironment") {
                row = (type === "environment" ? environmentModel : bwrapEnvironmentModel).get(index)
                collectionPrimaryField.text = row.entryKey
                collectionSecondaryField.text = row.entryValue
            } else if (type === "rpath") {
                collectionPrimaryField.text = rpathModel.get(index).entryValue
            } else if (type === "prebuild") {
                collectionPrimaryField.text = prebuildModel.get(index).entryValue
            }
        }
        collectionEditorDialog.open()
        collectionPrimaryField.forceActiveFocus()
    }

    function applyCollectionEditor() {
        const index = collectionEditorIndex
        const primary = collectionPrimaryField.text.trim()
        const secondary = collectionSecondaryField.text.trim()
        const tertiary = collectionTertiaryField.text.trim()

        if (collectionEditorType === "repository") {
            const values = {"distro": collectionDistroField.currentText, "releaseName": primary, "snapshot": collectionDistroField.currentText === "debian-snapshot" ? tertiary : "", "architecture": appHub.userBundleArchitecture, "components": secondary, "originalData": index >= 0 ? repositoryModel.get(index).originalData : "{}"}
            if (index < 0) repositoryModel.append(values)
            else { for (const key in values) repositoryModel.setProperty(index, key, values[key]) }
        } else if (collectionEditorType === "ppa") {
            const values = {"ppaId": primary, "ppaName": secondary, "releaseName": tertiary, "architecture": appHub.userBundleArchitecture, "originalData": index >= 0 ? ppaModel.get(index).originalData : "{}"}
            if (index < 0) ppaModel.append(values)
            else { for (const key in values) ppaModel.setProperty(index, key, values[key]) }
        } else if (collectionEditorType === "dependency") {
            const values = {"dependencyName": primary, "repositoryId": secondary, "originalData": index >= 0 ? dependencyModel.get(index).originalData : "{}"}
            if (index < 0) dependencyModel.append(values)
            else { for (const key in values) dependencyModel.setProperty(index, key, values[key]) }
        } else if (collectionEditorType === "environment" || collectionEditorType === "bwrapEnvironment") {
            const target = collectionEditorType === "environment" ? environmentModel : bwrapEnvironmentModel
            if (index < 0) target.append({"entryKey": primary, "entryValue": secondary})
            else { target.setProperty(index, "entryKey", primary); target.setProperty(index, "entryValue", secondary) }
        } else if (collectionEditorType === "rpath") {
            if (index < 0) rpathModel.append({"entryValue": primary})
            else rpathModel.setProperty(index, "entryValue", primary)
        } else if (collectionEditorType === "prebuild") {
            if (index < 0) prebuildModel.append({"entryValue": primary})
            else prebuildModel.setProperty(index, "entryValue", primary)
        }
        markDirty()
        collectionEditorDialog.close()
    }

    function markDirty() {
        if (!loadingEditor)
            editorDirty = true
    }

    function joinedValues(value) {
        if (value === undefined || value === null)
            return ""
        return value.join ? value.join(" ") : String(value)
    }

    function fillStringModel(target, values) {
        target.clear()
        if (!values)
            return
        for (let entry of values)
            target.append({"entryValue": String(entry)})
    }

    function modelStrings(source) {
        let result = []
        for (let index = 0; index < source.count; ++index) {
            const value = source.get(index).entryValue.trim()
            if (value.length > 0)
                result.push(value)
        }
        return result
    }

    function fillEnvironmentModel(target, values) {
        target.clear()
        if (!values)
            return
        for (let entry of values)
            target.append({"entryKey": String(entry.key || ""), "entryValue": String(entry.value || "")})
    }

    function environmentValues(source) {
        let result = []
        for (let index = 0; index < source.count; ++index) {
            const entry = source.get(index)
            if (entry.entryKey.trim().length > 0)
                result.push({"key": entry.entryKey.trim(), "value": entry.entryValue})
        }
        return result
    }

    function originalEntry(value) {
        try {
            return JSON.parse(value || "{}")
        } catch (error) {
            return {}
        }
    }

    function requestViewMode(mode) {
        if (mode === viewMode)
            return
        if (hasUnsavedChanges) {
            pendingAction = "mode"
            pendingValue = mode
            unsavedDialog.open()
            return
        }
        viewMode = mode
    }

    function requestSectionLeave(section) {
        if (hasUnsavedChanges) {
            pendingAction = "section"
            pendingValue = section
            unsavedDialog.open()
            return
        }
        sectionLeaveApproved(section)
    }

    function requestClose() {
        if (hasUnsavedChanges) {
            pendingAction = "close"
            pendingValue = -1
            unsavedDialog.open()
            return
        }
        closeApproved()
    }

    function finishPendingAction() {
        const action = pendingAction
        const value = pendingValue
        pendingAction = ""
        pendingValue = -1
        if (action === "mode")
            viewMode = value
        else if (action === "section")
            sectionLeaveApproved(value)
        else if (action === "close")
            closeApproved()
        else if (action === "editor") {
            editingProject = ""
            artifactUrl = ""
            viewMode = AppHubPage.Recipes
        }
    }

    function openProject(projectId) {
        const document = appHub.loadUserBundle(projectId)
        if (!document.valid) {
            messageDialog.title = qsTr("Invalid Recipe")
            messageDialog.message = document.error || qsTr("The project could not be opened.")
            messageDialog.open()
            return
        }

        loadingEditor = true
        editingProject = projectId
        bundleProjectId = projectId
        artifactUrl = document.outputUrl ? String(document.outputUrl) : ""
        const recipe = document.recipe
        const build = recipe.buildinfo
        const launch = recipe.apprunconf
        const integration = recipe.integration
        const sandbox = recipe.sandbox
        const metadata = document.metadata

        bundleName = build.name || ""
        bundleVersion = build.version || ""
        binaryPath = build.binarypath || ""
        osTarget = build["os-target"] || ""
        runtimeType = build.runtime || "classic"
        integrationType = integration.type || "gui"
        launcher = integration.launcher || ""
        sandboxType = sandbox.type || "none"
        firejailName = sandbox.name || ""
        appArmorProfile = sandbox["aa-profile"] || ""
        sandboxHostname = sandbox.hostname || ""
        sandboxWorkingDirectory = sandbox.chdir || ""
        sandboxFileLabel = sandbox["file-label"] || ""
        sandboxExecLabel = sandbox["exec-label"] || ""
        sandboxSeccomp = sandbox.seccomp || ""
        launchExec = launch.exec || ""
        launchPath = launch.setpath || "/usr/bin"
        launchLibraryPath = launch.setlibpath || "/usr/lib"
        metadataSummary = metadata.summary || ""
        metadataDescription = metadata.description || ""
        metadataCategory = metadata.category || "AppHub.Utilities"
        metadataHomepage = metadata.homepage || ""
        metadataLicense = metadata.license || ""

        repositoryModel.clear()
        for (let repository of build.repositories || []) {
            repositoryModel.append({
                "distro": String(repository.distro || "debian"),
                "releaseName": String(repository.release || ""),
                "snapshot": String(repository.snapshot || ""),
                "architecture": String(document.architecture),
                "components": joinedValues(repository.components),
                "originalData": JSON.stringify(repository)
            })
        }
        ppaModel.clear()
        for (let ppa of build.ppas || []) {
            ppaModel.append({
                "ppaId": String(ppa.id || ""),
                "ppaName": String(ppa.ppa || ""),
                "releaseName": String(ppa.release || ""),
                "architecture": String(document.architecture),
                "originalData": JSON.stringify(ppa)
            })
        }
        dependencyModel.clear()
        for (let dependency of build.dependencies || []) {
            if (typeof dependency === "string")
                dependencyModel.append({"dependencyName": dependency, "repositoryId": "", "originalData": JSON.stringify(dependency)})
            else
                dependencyModel.append({"dependencyName": String(dependency.name || ""), "repositoryId": String(dependency.repo || ""), "originalData": JSON.stringify(dependency)})
        }
        fillEnvironmentModel(environmentModel, launch.envvars)
        fillStringModel(rpathModel, launch["extra-rpaths"])
        fillStringModel(prebuildModel, launch["prebuild-commands"])
        fillEnvironmentModel(bwrapEnvironmentModel, sandbox["bwrap-env"])

        sandboxStringModel.clear()
        for (let option of sandboxListOptions) {
            for (let entry of sandbox[option] || [])
                sandboxStringModel.append({"option": option, "entryValue": String(entry)})
        }
        for (let index = 0; index < sandboxBooleanModel.count; ++index) {
            const option = sandboxBooleanModel.get(index).option
            sandboxBooleanModel.setProperty(index, "selected", Boolean(sandbox[option]))
        }

        launchAdvancedVisible = environmentModel.count > 0 || rpathModel.count > 0 || prebuildModel.count > 0
        osTargetEnabled = osTarget.length > 0
        launcherEnabled = launcher.length > 0
        appArmorProfileEnabled = appArmorProfile.length > 0
        sandboxHostnameEnabled = sandboxHostname.length > 0
        sandboxWorkingDirectoryEnabled = sandboxWorkingDirectory.length > 0
        sandboxFileLabelEnabled = sandboxFileLabel.length > 0
        sandboxExecLabelEnabled = sandboxExecLabel.length > 0
        sandboxSeccompEnabled = sandboxSeccomp.length > 0
        metadataHomepageEnabled = metadataHomepage.length > 0
        editorDirty = false
        loadingEditor = false
        viewMode = AppHubPage.Builder
    }

    function collectRecipe() {
        let repositories = []
        for (let index = 0; index < repositoryModel.count; ++index) {
            const row = repositoryModel.get(index)
            let repository = control.originalEntry(row.originalData)
            if (typeof repository !== "object" || repository === null || Array.isArray(repository))
                repository = {}
            repository.distro = row.distro
            repository.release = row.releaseName
            repository.arch = row.architecture
            repository.components = row.components.trim().length > 0 ? row.components.trim().split(/\s+/) : []
            if (row.distro === "debian-snapshot" && row.snapshot.trim().length > 0)
                repository.snapshot = row.snapshot.trim()
            else
                delete repository.snapshot
            repositories.push(repository)
        }

        let ppas = []
        for (let index = 0; index < ppaModel.count; ++index) {
            const row = ppaModel.get(index)
            let ppa = control.originalEntry(row.originalData)
            if (typeof ppa !== "object" || ppa === null || Array.isArray(ppa))
                ppa = {}
            ppa.id = row.ppaId.trim()
            ppa.ppa = row.ppaName.trim()
            ppa.distro = "ubuntu"
            ppa.release = row.releaseName.trim()
            ppa.arch = row.architecture
            ppas.push(ppa)
        }

        let dependencies = []
        for (let index = 0; index < dependencyModel.count; ++index) {
            const row = dependencyModel.get(index)
            const original = control.originalEntry(row.originalData)
            if (row.repositoryId.trim().length > 0 || (typeof original === "object" && original !== null && !Array.isArray(original))) {
                let dependency = typeof original === "object" && original !== null && !Array.isArray(original) ? original : {}
                dependency.name = row.dependencyName.trim()
                if (row.repositoryId.trim().length > 0)
                    dependency.repo = row.repositoryId.trim()
                else
                    delete dependency.repo
                dependencies.push(Object.keys(dependency).length === 1 ? dependency.name : dependency)
            } else {
                dependencies.push(row.dependencyName.trim())
            }
        }

        let sandbox = {
            "type": integrationType === "wm" ? "none" : sandboxType,
            "name": firejailName,
            "aa-profile": appArmorProfileEnabled ? appArmorProfile : "",
            "bwrap-env": environmentValues(bwrapEnvironmentModel),
            "hostname": sandboxHostnameEnabled ? sandboxHostname : "",
            "chdir": sandboxWorkingDirectoryEnabled ? sandboxWorkingDirectory : "",
            "file-label": sandboxFileLabelEnabled ? sandboxFileLabel : "",
            "exec-label": sandboxExecLabelEnabled ? sandboxExecLabel : "",
            "seccomp": sandboxSeccompEnabled ? sandboxSeccomp : ""
        }
        for (let index = 0; index < sandboxBooleanModel.count; ++index) {
            const row = sandboxBooleanModel.get(index)
            sandbox[row.option] = row.selected
        }
        for (let option of sandboxListOptions)
            sandbox[option] = []
        for (let index = 0; index < sandboxStringModel.count; ++index) {
            const row = sandboxStringModel.get(index)
            if (row.entryValue.trim().length > 0)
                sandbox[row.option].push(row.entryValue.trim())
        }

        return {
            "buildinfo": {
                "name": bundleName,
                "version": bundleVersion,
                "binarypath": binaryPath,
                "os-target": osTargetEnabled ? osTarget : "",
                "runtime": runtimeType,
                "repositories": repositories,
                "ppas": ppas,
                "dependencies": dependencies
            },
            "apprunconf": {
                "exec": launchExec,
                "setpath": launchPath,
                "setlibpath": launchLibraryPath,
                "envvars": launchAdvancedVisible ? environmentValues(environmentModel) : [],
                "extra-rpaths": launchAdvancedVisible ? modelStrings(rpathModel) : [],
                "prebuild-commands": launchAdvancedVisible ? modelStrings(prebuildModel) : []
            },
            "integration": {"type": integrationType, "launcher": launcherEnabled ? launcher : ""},
            "sandbox": sandbox
        }
    }

    function collectMetadata() {
        return {
            "name": bundleName,
            "summary": metadataSummary,
            "description": metadataDescription,
            "category": metadataCategory,
            "homepage": metadataHomepageEnabled ? metadataHomepage : "",
            "license": metadataLicense
        }
    }

    function saveEditor() {
        const creatingProject = editingProject.length === 0
        const projectId = creatingProject ? bundleProjectId.trim() : editingProject
        if (!projectIdValid) {
            messageDialog.title = qsTr("Invalid Project ID")
            messageDialog.message = qsTr("Enter a valid project ID using lowercase letters, numbers, dots, underscores, or hyphens.")
            messageDialog.open()
            return false
        }

        const saved = creatingProject
                    ? appHub.createUserBundle(projectId, collectRecipe(), collectMetadata())
                    : appHub.saveUserBundle(projectId, collectRecipe(), collectMetadata())
        if (saved) {
            editingProject = projectId
            bundleProjectId = projectId
            editorDirty = false
        }
        return saved
    }

    function closeEditor() {
        if (hasUnsavedChanges) {
            pendingAction = "editor"
            unsavedDialog.open()
            return
        }
        editingProject = ""
        artifactUrl = ""
        viewMode = AppHubPage.Recipes
    }

    function openNewBundleDialog() {
        newProjectDialog.open()
    }

    function buildEditor() {
        if (appHub.busy || !projectIdValid)
            return
        if ((editingProject.length === 0 || editorDirty) && !saveEditor())
            return
        buildOutputProject = editingProject
        buildOutputFinished = false
        buildOutputSucceeded = false
        buildOutputError = ""
        buildOutputDialog.animatedEllipsis = ""
        buildOutputDialog.open()
        appHub.buildUserBundle(editingProject)
    }
    function revealEditorOutput() {
        if (artifactUrl.length > 0)
            Qt.openUrlExternally(artifactUrl.toString().replace(/\/[^\/]*$/, ""))
    }

    onViewModeChanged: {
        appHub.appHubInstalledOnly = viewMode === AppHubPage.Installed
        if (viewMode === AppHubPage.Builder)
            appHub.refreshUserBundles()
    }

    Component.onCompleted: {
        appHub.appHubInstalledOnly = viewMode === AppHubPage.Installed
        appHub.initializeUserBundles()
    }
    Component.onDestruction: appHub.appHubInstalledOnly = false

    ListModel { id: repositoryModel }
    ListModel { id: ppaModel }
    ListModel { id: dependencyModel }
    ListModel { id: environmentModel }
    ListModel { id: rpathModel }
    ListModel { id: prebuildModel }
    ListModel { id: bwrapEnvironmentModel }
    ListModel { id: sandboxStringModel }
    ListModel {
        id: sandboxBooleanModel
        ListElement { option: "ro-root"; selected: false }
        ListElement { option: "ro-home"; selected: false }
        ListElement { option: "dev"; selected: false }
        ListElement { option: "proc"; selected: false }
        ListElement { option: "tmpfs"; selected: false }
        ListElement { option: "mqueue"; selected: false }
        ListElement { option: "no-net"; selected: false }
        ListElement { option: "no-ipc"; selected: false }
        ListElement { option: "no-pid"; selected: false }
        ListElement { option: "unshare-user"; selected: false }
        ListElement { option: "unshare-uts"; selected: false }
        ListElement { option: "unshare-cgroup"; selected: false }
        ListElement { option: "new-session"; selected: false }
        ListElement { option: "cap-drop-all"; selected: false }
        ListElement { option: "die-with-parent"; selected: false }
        ListElement { option: "clearenv"; selected: false }
    }

    Connections {
        target: appHub

        function errorBody(error) {
            const body = String(error || "").trim()
            return body.length > 0 ? body : qsTr("The requested operation failed.")
        }

        function onAppHubOperationFinished(identifier, action, success, error) {
            if (success) {
                if (control.detailVisible && (action === "install" || action === "remove")) {
                    const installed = action === "install"
                    control.detailItem = appHubDetailsView.itemDataWithAction(identifier,
                                                                              installed ? qsTr("Remove") : qsTr("Activate"),
                                                                              installed ? "edit-delete" : "run-build",
                                                                              installed ? qsTr("Active") : qsTr("Inactive"))
                }
                return
            }

            const title = action === "install" ? qsTr("Installation failed")
                        : action === "remove" ? qsTr("Removal failed")
                                              : qsTr("Restore failed")
            Maui.App.rootComponent.notify("dialog-error", title, errorBody(error))
        }

        function onUserBundleGenerated(projectId, success, error) {
            if (success) {
                control.openProject(projectId)
            } else {
                Maui.App.rootComponent.notify("dialog-error", qsTr("Project generation failed"), errorBody(error))
            }
        }

        function onUserBundleSaved(projectId, success, error) {
            const creatingProject = control.editingProject.length === 0
            if (success) {
                Maui.App.rootComponent.notify("dialog-ok",
                                              creatingProject ? qsTr("Bundle created") : qsTr("Bundle saved"),
                                              creatingProject ? qsTr("%1 was created successfully.").arg(projectId)
                                                              : qsTr("%1 was saved successfully.").arg(projectId))
            } else {
                Maui.App.rootComponent.notify("dialog-error",
                                              creatingProject ? qsTr("Bundle creation failed") : qsTr("Save failed"),
                                              errorBody(error))
            }
        }

        function onUserBundleBuilt(projectId, success, artifact, error) {
            if (projectId === control.buildOutputProject) {
                control.buildOutputFinished = true
                control.buildOutputSucceeded = success
                control.buildOutputError = String(error || "")
            }
            if (success) {
                if (projectId === control.editingProject)
                    control.artifactUrl = String(artifact)
            } else {
                Maui.App.rootComponent.notify("dialog-error", qsTr("Build failed"), errorBody(error))
            }
        }
    }

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
                    label2.text: model.created.length > 0 ? qsTr("Backup created %1").arg(model.created) : qsTr("Available backup")
                    label2.elide: Text.ElideRight
                    ToolButton {
                        text: qsTr("Restore")
                        icon.name: "document-revert"
                        display: ToolButton.IconOnly
                        enabled: !appHub.busy
                        ToolTip.visible: hovered
                        ToolTip.text: text
                        onClicked: {
                            appHub.restoreAppHubBackup(appHubRestoreDialog.applicationIdentifier, model.identifier)
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

    Maui.InfoDialog {
        id: newProjectDialog
        title: qsTr("New Personal Bundle")
        message: qsTr("Generate a local recipe from package metadata. The result is a personal bundle, not a managed AppBox.")
        standardButtons: Dialog.Ok | Dialog.Cancel
        property bool projectIdEdited: false

        Maui.SectionGroup {
            title: qsTr("Template Options")
            description: qsTr("The project ID remains fixed even if the bundle name changes later.")

            Maui.FlexSectionItem {
                label1.text: qsTr("Package name")
                Maui.TextField {
                    id: packageField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Package name")
                    onTextEdited: {
                        if (!newProjectDialog.projectIdEdited)
                            projectIdField.text = text.toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[^a-z0-9]+|[^a-z0-9]+$/g, "")
                    }
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Project ID")
                label2.text: qsTr("Lowercase letters, digits, dots, underscores, and hyphens")
                Maui.TextField {
                    id: projectIdField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Fixed project ID")
                    maximumLength: 128
                    validator: RegularExpressionValidator { regularExpression: /^[a-z0-9][a-z0-9._-]{0,127}$/ }
                    onTextEdited: newProjectDialog.projectIdEdited = true
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Distribution")
                ComboBox {
                    id: distributionField
                    Layout.fillWidth: true
                    model: ["debian", "ubuntu", "devuan", "kde-neon", "nitrux"]
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Release")
                Maui.TextField {
                    id: releaseField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Distribution release")
                    text: "testing"
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Architecture")
                Maui.TextField {
                    Layout.fillWidth: true
                    readOnly: true
                    text: appHub.userBundleArchitecture
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Components")
                Maui.TextField {
                    id: componentsField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Repository components separated by spaces")
                    text: "main"
                }
            }

            Maui.FlexSectionItem {
                label1.text: qsTr("Integration")
                ComboBox {
                    id: generationIntegrationField
                    Layout.fillWidth: true
                    model: control.integrationTypes
                }
            }
        }

        onOpened: {
            packageField.clear()
            projectIdField.clear()
            projectIdEdited = false
            releaseField.text = "testing"
            componentsField.text = "main"
        }
        onAccepted: {
            const components = componentsField.text.trim().length > 0 ? componentsField.text.trim().split(/\s+/) : ["main"]
            appHub.generateUserBundle(projectIdField.text.trim(), {
                "package": packageField.text.trim(),
                "distro": distributionField.currentText,
                "release": releaseField.text.trim(),
                "components": components,
                "integration": generationIntegrationField.currentText
            })
        }
    }

    Maui.SettingsDialog {
        id: collectionEditorDialog
        title: control.collectionEditorTitle()
        persistent: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Maui.Style.space.small

            Maui.FlexSectionItem {
                visible: control.collectionEditorType === "repository"
                Layout.fillWidth: true
                flat: true
                label1.text: qsTr("Distribution")
                label2.text: qsTr("Repository family used to resolve packages.")
                label2.wrapMode: Text.Wrap

                ComboBox {
                    id: collectionDistroField
                    Layout.fillWidth: true
                    model: control.repositoryDistros
                }
            }

            Maui.FlexSectionItem {
                Layout.fillWidth: true
                flat: true
                label1.text: control.collectionEditorType === "repository" ? qsTr("Release")
                             : control.collectionEditorType === "ppa" ? qsTr("PPA ID")
                             : control.collectionEditorType === "dependency" ? qsTr("Package")
                             : control.collectionEditorType === "environment" || control.collectionEditorType === "bwrapEnvironment" ? qsTr("Variable")
                             : control.collectionEditorType === "rpath" ? qsTr("RPATH")
                             : qsTr("Command")
                label2.text: control.collectionEditorType === "repository" ? qsTr("Distribution release used by this source.")
                             : control.collectionEditorType === "ppa" ? qsTr("Identifier used to reference this optional PPA from dependencies.")
                             : control.collectionEditorType === "dependency" ? qsTr("Required package included in the bundle.")
                             : control.collectionEditorType === "environment" || control.collectionEditorType === "bwrapEnvironment" ? qsTr("Environment variable name.")
                             : control.collectionEditorType === "rpath" ? qsTr("Additional runtime library search path.")
                             : qsTr("Command executed before the build starts.")
                label2.wrapMode: Text.Wrap

                Maui.TextField {
                    id: collectionPrimaryField
                    Layout.fillWidth: true
                    placeholderText: control.collectionEditorType === "repository" ? qsTr("Release")
                                     : control.collectionEditorType === "ppa" ? qsTr("PPA ID")
                                     : control.collectionEditorType === "dependency" ? qsTr("Package name")
                                     : control.collectionEditorType === "environment" || control.collectionEditorType === "bwrapEnvironment" ? qsTr("VARIABLE_NAME")
                                     : control.collectionEditorType === "rpath" ? qsTr("/path/to/libraries")
                                     : qsTr("Command")
                }
            }

            Maui.FlexSectionItem {
                visible: control.collectionEditorType === "repository" || control.collectionEditorType === "ppa" || (control.collectionEditorType === "dependency" && control.ppaAvailable && ppaModel.count > 0) || control.collectionEditorType === "environment" || control.collectionEditorType === "bwrapEnvironment"
                Layout.fillWidth: true
                flat: true
                label1.text: control.collectionEditorType === "repository" ? qsTr("Components")
                             : control.collectionEditorType === "ppa" ? qsTr("PPA")
                             : control.collectionEditorType === "dependency" ? qsTr("PPA ID")
                             : qsTr("Value")
                label2.text: control.collectionEditorType === "repository" ? qsTr("Repository components separated by spaces.")
                             : control.collectionEditorType === "ppa" ? qsTr("Launchpad PPA name.")
                             : control.collectionEditorType === "dependency" ? qsTr("Optional PPA ID that provides this dependency.")
                             : qsTr("Value exported for this variable.")
                label2.wrapMode: Text.Wrap

                Maui.TextField {
                    id: collectionSecondaryField
                    Layout.fillWidth: true
                    placeholderText: control.collectionEditorType === "repository" ? qsTr("main")
                                     : control.collectionEditorType === "ppa" ? qsTr("ppa:owner/name")
                                     : control.collectionEditorType === "dependency" ? qsTr("Optional PPA ID")
                                     : qsTr("Value")
                }
            }

            Maui.FlexSectionItem {
                visible: control.collectionEditorType === "ppa" || (control.collectionEditorType === "repository" && collectionDistroField.currentText === "debian-snapshot")
                Layout.fillWidth: true
                flat: true
                label1.text: control.collectionEditorType === "ppa" ? qsTr("Release") : qsTr("Snapshot")
                label2.text: control.collectionEditorType === "ppa" ? qsTr("Distribution release used by this optional PPA.") : qsTr("Debian snapshot timestamp.")
                label2.wrapMode: Text.Wrap

                Maui.TextField {
                    id: collectionTertiaryField
                    Layout.fillWidth: true
                    placeholderText: control.collectionEditorType === "ppa" ? qsTr("Release") : qsTr("YYYYMMDDThhmmssZ")
                }
            }
        }

        actions: [
            Action {
                text: qsTr("Cancel")
                onTriggered: collectionEditorDialog.close()
            },
            Action {
                text: control.collectionEditorIndex < 0 ? qsTr("Add") : qsTr("Apply")
                enabled: collectionPrimaryField.text.trim().length > 0
                         && (control.collectionEditorType !== "repository" || collectionSecondaryField.text.trim().length > 0)
                         && (control.collectionEditorType !== "ppa" || collectionSecondaryField.text.trim().length > 0)
                onTriggered: control.applyCollectionEditor()
            }
        ]

        onClosed: {
            control.collectionEditorType = ""
            control.collectionEditorIndex = -1
        }
    }

    Maui.InfoDialog {
        id: unsavedDialog
        title: qsTr("Unsaved Changes")
        message: qsTr("Save the current personal-bundle recipe before leaving it?")
        standardButtons: Dialog.Save | Dialog.Discard | Dialog.Cancel
        onAccepted: {
            if (control.saveEditor())
                control.finishPendingAction()
        }
        onDiscarded: {
            control.editorDirty = false
            if (control.pendingAction === "editor") {
                control.pendingAction = ""
                control.editingProject = ""
                control.artifactUrl = ""
                control.viewMode = AppHubPage.Recipes
            } else {
                control.finishPendingAction()
            }
        }
        onRejected: {
            control.pendingAction = ""
            control.pendingValue = -1
        }
    }

    Maui.InfoDialog {
        id: messageDialog
        standardButtons: Dialog.Close
    }

    Maui.InfoDialog {
        id: buildOutputDialog
        property string animatedEllipsis: ""
        implicitWidth: Math.min(control.width - Maui.Style.contentMargins * 2, Maui.Style.units.gridUnit * 40)
        title: control.buildOutputFinished
               ? (control.buildOutputSucceeded ? qsTr("Bundle Built") : qsTr("Build Failed"))
               : qsTr("Building Bundle")
        message: control.buildOutputFinished
                 ? (control.buildOutputSucceeded
                    ? qsTr("%1 was built successfully.").arg(control.buildOutputProject)
                    : qsTr("The build failed. Review the nx-apphub-cli output below."))
                 : qsTr("Building %1 with nx-apphub-cli%2").arg(control.buildOutputProject).arg(buildOutputDialog.animatedEllipsis)
        template.iconSource: "run-build"
        standardButtons: control.buildOutputFinished || !appHub.busy ? Dialog.Close : Dialog.Cancel

        Timer {
            id: buildOutputEllipsisTimer
            interval: 400
            repeat: true
            running: buildOutputDialog.visible && !control.buildOutputFinished
            onTriggered: buildOutputDialog.animatedEllipsis = buildOutputDialog.animatedEllipsis.length >= 3
                ? ""
                : buildOutputDialog.animatedEllipsis + "."
        }

        Maui.SectionHeader {
            Layout.fillWidth: true
            text1: qsTr("Command Output")
            text2: appHub.busy ? qsTr("nx-apphub-cli is still running.") : qsTr("The operation has finished.")
            label2.wrapMode: Text.Wrap
        }

        onRejected: {
            if (!control.buildOutputFinished && appHub.busy && appHub.operationAction === "apphub-build-bundle") {
                appHub.cancelUserBundleBuild()
                return
            }
            close()
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Maui.Style.units.gridUnit * 18
            clip: true

            TextArea {
                width: parent.width
                readOnly: true
                selectByMouse: true
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.WrapAnywhere
                text: appHub.operationLog.length > 0
                      ? appHub.operationLog
                      : (control.buildOutputError.length > 0
                         ? control.buildOutputError
                         : qsTr("Waiting for nx-apphub-cli output…"))
            }
        }
    }

    Loader {
        anchors.fill: parent
        visible: !control.detailVisible
        sourceComponent: control.searchActive ? searchComponent
                         : control.viewMode === AppHubPage.Recipes ? recipesComponent
                         : control.viewMode === AppHubPage.Builder ? builderComponent
                                                                    : installedComponent
        onLoaded: {
            if (item) {
                item.opacity = 0
                viewTransition.target = item
                viewTransition.start()
            }
        }

        OpacityAnimator {
            id: viewTransition
            from: 0
            to: 1
            duration: Maui.Style.units.longDuration
            easing.type: Easing.InOutQuad
        }
    }

    Component {
        id: searchComponent

        SearchResultsView {
            sourceModel: appHub.appHubModel
            operationPrefix: "apphub-"
            query: control.query
            sourceTitle: qsTr("NX AppHub")
            sourceDescription: qsTr("Search AppBox recipes in NX AppHub.")
            emptyTitle: qsTr("No NX AppHub results")
            emptyBody: qsTr("Try a different recipe name or category.")
            previewEnabled: true
            busy: appHub.busy
            actionHandler: function(identifier) { appHub.appHubAction(identifier) }
            detailHandler: function(identifier, item) { control.openDetails(item) }
        }
    }

    AppDetailsView {
        id: appHubDetailsView
        anchors.fill: parent
        visible: control.detailVisible
        z: 2
        itemData: control.detailItem
        sourceTitle: qsTr("NX AppHub")
        operationPrefix: "apphub-"
        developerFallback: {
            const distribution = control.detailItem && control.detailItem.baseImage
                                 ? control.distributionDisplayName(control.detailItem.baseImage)
                                 : ""
            return distribution.length > 0 ? qsTr("Source: %1").arg(distribution) : ""
        }
        descriptionIsMarkdown: true
        busy: appHub.busy
        openHandler: function(identifier) { appHub.launchAppHub(identifier) }
        openVisibleResolver: function(item) {
            return item && item.status === "Active" && String(item.integration).toLowerCase() === "gui"
        }
        actionTextResolver: function(item) {
            const action = item && item.actionText ? String(item.actionText) : ""
            return action.toLowerCase() === "activate" && !appHub.appHubOsTargetMatches(item.osTarget)
                   ? qsTr("Unavailable")
                   : action
        }
        actionEnabledResolver: function(item) {
            const action = item && item.actionText ? String(item.actionText).toLowerCase() : ""
            return action !== "activate" || appHub.appHubOsTargetMatches(item.osTarget)
        }
        actionHandler: function(identifier) { appHub.appHubAction(identifier) }
        onBackRequested: control.closeDetails()
        onSimilarRequested: function(item) { control.openDetails(item) }
    }

    Component {
        id: recipesComponent

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
                text1: qsTr("Explore NX AppHub")
                text2: qsTr("Use AppBoxes to extend Nitrux.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                visible: appHub.appHubFeaturedModel.count > 0
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
                        text2: qsTr("Recipes selection from the local NX AppHub repository.")
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
                                    TapHandler {
                                        enabled: appHubFeaturedSlide.currentSlide
                                        onTapped: control.openDetails(model)
                                    }
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
                                    readonly property real iconGroupWidth: Maui.Style.units.gridUnit * 10
                                    readonly property real previewMaximumWidth: Math.max(0, (appHubFeaturedSlide.height - Maui.Style.space.medium * 2) * 5 / 2)
                                    readonly property real previewWidth: Math.max(0, Math.min(previewMaximumWidth, appHubFeaturedSlide.width * 3 / 5))

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
                                                Layout.preferredWidth: appHubFeaturedSlide.iconGroupWidth
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
                                                    color: appHubFeaturedSlide.bannerForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    font: Maui.Style.h2Font
                                                    elide: Text.ElideRight
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: model.summary.length > 0 ? model.summary : model.description
                                                    color: appHubFeaturedSlide.bannerSecondaryForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.WordWrap
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                }

                                                AppFinderChip {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: control.appHubCategoryLabel(model.category)
                                                    visible: text.length > 0

                                                }
                                            }

                                            Rectangle {
                                                id: appHubFeaturedScreenshotFrame
                                                visible: appHubFeaturedSlide.width >= Maui.Style.units.gridUnit * 42
                                                Layout.fillHeight: true
                                                Layout.fillWidth: false
                                                Layout.minimumWidth: appHubFeaturedSlide.previewWidth
                                                Layout.preferredWidth: appHubFeaturedSlide.previewWidth
                                                Layout.maximumWidth: appHubFeaturedSlide.previewWidth
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
                                                            width: appHubFeaturedScreenshotFrame.width
                                                            height: appHubFeaturedScreenshotFrame.height
                                                            radius: appHubFeaturedScreenshotFrame.radius
                                                        }
                                                    }
                                                }

                                                Image {
                                                    id: appHubFeaturedScreenshot
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
                                                    color: appHubFeaturedSlide.bannerSecondaryForeground
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.WordWrap
                                                    visible: !appHubFeaturedScreenshot.visible
                                                }
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

                Instantiator {
                    model: appHub.appHubCategories

                    delegate: Maui.TabButton {
                        required property string modelData
                        width: appHubTabs.uniformTabWidth
                        text: modelData
                        closeButtonVisible: false
                    }

                    onObjectAdded: (index, object) => appHubTabs.insertItem(index, object)
                    onObjectRemoved: (index, object) => appHubTabs.removeItem(object)
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
                holder.title: qsTr("No AppBoxes in this group")
                holder.body: qsTr("Refresh the local NX AppHub repository or adjust the search.")

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

                        onClicked: control.openDetails(model)

                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    scrollGestureEnabled: true
                    z: 100
                    onWheel: (wheel) => appHubScroll.forwardGridWheel(wheel)
                }
            }

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Personal Bundles")
                text2: qsTr("Create and manage local bundles.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                id: userRecipeCard
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: userRecipeLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: userRecipeLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Saved Recipes (%1)").arg(appHub.userBundleRecipesModel.count)
                        text2: qsTr("Personal bundle recipes saved for later editing.")
                        label2.wrapMode: Text.Wrap
                    }

                    Item {
                        id: userRecipeListContainer
                        Layout.fillWidth: true
                        implicitHeight: userRecipeBrowser.holder.visible ? userRecipeBrowser.holder.implicitHeight : userRecipeBrowser.contentHeight
                        Layout.preferredHeight: implicitHeight

                        Maui.ListBrowser {
                            id: userRecipeBrowser
                            anchors.fill: parent
                            verticalScrollBarPolicy: ScrollBar.AlwaysOff
                            padding: 0
                            clip: true
                            model: appHub.userBundleRecipesModel
                            flickable.interactive: false
                            flickable.reuseItems: false

                            holder.visible: count === 0
                            holder.title: qsTr("No Saved Recipes")
                            holder.body: qsTr("Save a bundle recipe.")
                            holder.label1.horizontalAlignment: Text.AlignLeft
                            holder.label2.horizontalAlignment: Text.AlignLeft

                            delegate: Maui.ListBrowserDelegate {
                                id: userRecipeDelegate
                                width: ListView.view.width
                                isCurrentItem: false
                                iconSource: model.icon
                                iconSizeHint: Maui.Style.iconSizes.big
                                template.leftLabels.spacing: Maui.Style.space.small
                                label1.text: model.name
                                label1.font.weight: Font.DemiBold
                                label1.elide: Text.ElideRight
                                label2.text: qsTr("%1 • %2").arg(model.summary.length > 0 ? model.summary : model.identifier).arg(model.status)
                                label2.elide: Text.ElideRight

                                ToolButton {
                                    text: qsTr("Edit")
                                    icon.name: "document-edit"
                                    icon.color: control.contrastingForeground(down || checked
                                                                                  ? Maui.Theme.highlightColor
                                                                                  : (hovered
                                                                                     ? Maui.Theme.hoverColor
                                                                                     : userRecipeDelegate.effectiveBackgroundColor))
                                    display: ToolButton.IconOnly
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: control.openProject(model.identifier)
                                }

                                ToolButton {
                                    text: qsTr("Remove")
                                    icon.name: "edit-delete"
                                    icon.color: control.contrastingForeground(down || checked
                                                                                  ? Maui.Theme.highlightColor
                                                                                  : (hovered
                                                                                     ? Maui.Theme.hoverColor
                                                                                     : userRecipeDelegate.effectiveBackgroundColor))
                                    display: ToolButton.IconOnly
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: appHub.removeUserBundle(model.identifier)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                                scrollGestureEnabled: true
                                z: 100
                                onWheel: (wheel) => appHubScroll.forwardGridWheel(wheel)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: builtBundleCard
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: builtBundleLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: builtBundleLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Built Bundles (%1)").arg(appHub.userBundleBuildsModel.count)
                        text2: qsTr("Personal bundles built from saved recipes.")
                        label2.wrapMode: Text.Wrap
                    }

                    Item {
                        id: builtBundleListContainer
                        Layout.fillWidth: true
                        implicitHeight: builtBundleBrowser.holder.visible ? builtBundleBrowser.holder.implicitHeight : builtBundleBrowser.contentHeight
                        Layout.preferredHeight: implicitHeight

                        Maui.ListBrowser {
                            id: builtBundleBrowser
                            anchors.fill: parent
                            verticalScrollBarPolicy: ScrollBar.AlwaysOff
                            padding: 0
                            clip: true
                            model: appHub.userBundleBuildsModel
                            flickable.interactive: false
                            flickable.reuseItems: false

                            holder.visible: count === 0
                            holder.title: qsTr("No Built Bundles")
                            holder.body: qsTr("Build a personal recipe.")
                            holder.label1.horizontalAlignment: Text.AlignLeft
                            holder.label2.horizontalAlignment: Text.AlignLeft

                            delegate: Maui.ListBrowserDelegate {
                                id: builtBundleDelegate
                                width: ListView.view.width
                                isCurrentItem: false
                                onClicked: control.openProject(model.identifier)
                                iconSource: model.icon
                                iconSizeHint: Maui.Style.iconSizes.big
                                template.leftLabels.spacing: Maui.Style.space.small
                                label1.text: model.name
                                label1.font.weight: Font.DemiBold
                                label1.elide: Text.ElideRight
                                label2.text: qsTr("%1 • %2").arg(model.summary.length > 0 ? model.summary : model.identifier).arg(model.status)
                                label2.elide: Text.ElideRight

                                ToolButton {
                                    text: qsTr("Move to Applications")
                                    icon.name: "document-export"
                                    icon.color: control.contrastingForeground(down || checked
                                                                                  ? Maui.Theme.highlightColor
                                                                                  : (hovered
                                                                                     ? Maui.Theme.hoverColor
                                                                                     : builtBundleDelegate.effectiveBackgroundColor))
                                    display: ToolButton.IconOnly
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: appHub.moveUserBundleToApplications(model.identifier)
                                }

                                ToolSeparator {
                                    topPadding: Maui.Style.space.small + Maui.Style.space.tiny
                                    bottomPadding: Maui.Style.space.small + Maui.Style.space.tiny
                                }

                                ToolButton {
                                    text: qsTr("Edit")
                                    icon.name: "document-edit"
                                    icon.color: control.contrastingForeground(down || checked
                                                                                  ? Maui.Theme.highlightColor
                                                                                  : (hovered
                                                                                     ? Maui.Theme.hoverColor
                                                                                     : builtBundleDelegate.effectiveBackgroundColor))
                                    display: ToolButton.IconOnly
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: control.openProject(model.identifier)
                                }

                                ToolButton {
                                    text: qsTr("Remove")
                                    icon.name: "edit-delete"
                                    icon.color: control.contrastingForeground(down || checked
                                                                                  ? Maui.Theme.highlightColor
                                                                                  : (hovered
                                                                                     ? Maui.Theme.hoverColor
                                                                                     : builtBundleDelegate.effectiveBackgroundColor))
                                    display: ToolButton.IconOnly
                                    enabled: !appHub.busy
                                    ToolTip.visible: hovered
                                    ToolTip.text: text
                                    onClicked: appHub.removeUserBundleArtifact(model.identifier)
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                propagateComposedEvents: true
                                scrollGestureEnabled: true
                                z: 100
                                onWheel: (wheel) => appHubScroll.forwardGridWheel(wheel)
                            }
                        }
                    }
                }
            }

        }
    }

    Component {
        id: installedComponent

        Maui.ScrollColumn {
            id: appHubInstalledScroll
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

                const pageFlickable = appHubInstalledScroll.flickable
                const maximumContentY = Math.max(0, pageFlickable.contentHeight - pageFlickable.height)
                pageFlickable.contentY = Math.max(0, Math.min(maximumContentY, pageFlickable.contentY - verticalDelta))
                wheel.accepted = true
            }

            Maui.SectionHeader {
                Layout.fillWidth: true
                text1: qsTr("Installed AppBoxes")
                text2: qsTr("Manage AppBoxes installed on this system.")
                label2.wrapMode: Text.Wrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: implicitHeight
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
                        Layout.preferredHeight: holder.visible ? holder.implicitHeight : -1
                        verticalScrollBarPolicy: ScrollBar.AlwaysOff
                        padding: 0
                        clip: true
                        model: appHub.appHubModel
                        flickable.interactive: false

                        holder.visible: count === 0
                        holder.title: qsTr("No AppBoxes Installed")
                        holder.body: qsTr("Activate an AppBox to see it here.")

                        delegate: Maui.ListBrowserDelegate {
                            id: installedDelegate
                            width: ListView.view.width
                            isCurrentItem: control.selectedInstalledAppBox === model.identifier
                            onClicked: control.openDetails(model)
                            iconSource: model.icon
                            iconSizeHint: Maui.Style.iconSizes.big
                            template.leftLabels.spacing: Maui.Style.space.small
                            label1.text: model.name
                            label1.font.weight: Font.DemiBold
                            label1.elide: Text.ElideRight
                            label2.text: model.summary.length > 0 ? model.summary : model.identifier
                            label2.elide: Text.ElideRight

                            ToolButton {
                                visible: appHub.appHubHasBackups(model.identifier)
                                text: qsTr("Restore Backup")
                                icon.name: "document-revert"
                                icon.color: control.contrastingForeground(down || checked
                                                                              ? Maui.Theme.highlightColor
                                                                              : (hovered
                                                                                 ? Maui.Theme.hoverColor
                                                                                 : installedDelegate.effectiveBackgroundColor))
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
                                                                                 : installedDelegate.effectiveBackgroundColor))
                                display: ToolButton.IconOnly
                                ToolTip.visible: hovered
                                ToolTip.text: text
                                onClicked: appHub.appHubAction(model.identifier)
                                ActionBusyIndicator {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Maui.Style.space.tiny
                                    anchors.verticalCenter: parent.verticalCenter
                                    running: appHub.busy && appHub.operationAction === "apphub-remove" && appHub.operationIdentifier === model.identifier
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            propagateComposedEvents: true
                            scrollGestureEnabled: true
                            z: 100
                            onWheel: (wheel) => appHubInstalledScroll.forwardListWheel(wheel)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: builderComponent

        PersonalBundleBuilder {
            anchors.fill: parent
            pageController: control
            repositoryModelRef: repositoryModel
            ppaModelRef: ppaModel
            dependencyModelRef: dependencyModel
            environmentModelRef: environmentModel
            rpathModelRef: rpathModel
            prebuildModelRef: prebuildModel
            bwrapEnvironmentModelRef: bwrapEnvironmentModel
            sandboxStringModelRef: sandboxStringModel
            sandboxBooleanModelRef: sandboxBooleanModel
        }
    }

}
