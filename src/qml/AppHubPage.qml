/*
 * SPDX-License-Identifier: BSD-3-Clause
 * Copyright 2025-2026 Nitrux Latinoamericana S.C.
 */

import QtQuick
import QtCore
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

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
    }

    function openNewBundleDialog() {
        newProjectDialog.open()
    }

    function buildEditor() {
        if (appHub.busy || !projectIdValid)
            return
        if ((editingProject.length === 0 || editorDirty) && !saveEditor())
            return
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
        appHub.refreshUserBundles()
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
                const title = action === "install" ? qsTr("AppBox installed")
                            : action === "remove" ? qsTr("AppBox removed")
                                                  : qsTr("AppBox restored")
                const body = action === "install" ? qsTr("%1 was installed successfully.").arg(identifier)
                           : action === "remove" ? qsTr("%1 was removed successfully.").arg(identifier)
                                                 : qsTr("%1 was restored successfully.").arg(identifier)
                Maui.App.rootComponent.notify("dialog-ok", title, body)
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
                Maui.App.rootComponent.notify("dialog-ok", qsTr("Bundle project generated"),
                                              qsTr("%1 is ready to edit.").arg(projectId))
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
            if (success) {
                if (projectId === control.editingProject)
                    control.artifactUrl = String(artifact)
                Maui.App.rootComponent.notify("dialog-ok", qsTr("Bundle built"),
                                              qsTr("%1 was built successfully.").arg(projectId))
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
                visible: control.collectionEditorType === "repository" || control.collectionEditorType === "ppa" || control.collectionEditorType === "dependency" || control.collectionEditorType === "environment" || control.collectionEditorType === "bwrapEnvironment"
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

    Loader {
        anchors.fill: parent
        sourceComponent: control.viewMode === AppHubPage.Recipes ? recipesComponent
                         : control.viewMode === AppHubPage.Builder ? builderComponent
                                                                  : installedComponent
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
                                                text: control.appHubCategoryLabel(model.category)
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
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: implicitHeight
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                implicitHeight: projectLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: projectLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Personal Bundles (%1)").arg(appHub.userBundleModel.count)
                        text2: qsTr("Projects stored in %1").arg(control.displayLocalPath(appHub.userBundleRoot))
                        label2.wrapMode: Text.Wrap
                    }

                    Maui.GridBrowser {
                        id: projectGrid
                        readonly property real availableLayoutWidth: projectLayout.width
                        readonly property int fittedColumns: Math.max(1, Math.min(4, count, Math.floor(availableLayoutWidth / itemSize)))

                        Layout.fillWidth: holder.visible
                        Layout.preferredWidth: holder.visible ? availableLayoutWidth : Math.min(availableLayoutWidth, itemSize * fittedColumns)
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: holder.visible ? holder.implicitHeight : contentHeight
                        padding: 0
                        itemSize: Maui.Style.units.gridUnit * 17
                        itemHeight: Maui.Style.units.gridUnit * 7
                        adaptContent: true
                        wheelResizeEnabled: false
                        pinchEnabled: false
                        verticalScrollBarPolicy: ScrollBar.AlwaysOff
                        model: appHub.userBundleModel
                        flickable.interactive: false

                        holder.visible: count === 0
                        holder.title: qsTr("No Personal Bundles")
                        holder.body: qsTr("Open the Personal Bundle Builder from the action bar to create your first bundle.")

                        delegate: Item {
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
                                label2.text: qsTr("%1\n%2 • %3")
                                             .arg(model.summary.length > 0 ? model.summary : model.identifier)
                                             .arg(model.version.length > 0 ? model.version : qsTr("Draft"))
                                             .arg(model.status)
                                label2.wrapMode: Text.WordWrap
                                label2.maximumLineCount: 3
                                label2.elide: Text.ElideRight
                                onClicked: control.openProject(model.identifier)

                                ToolButton {
                                    text: qsTr("Open")
                                    icon.name: "document-edit"
                                    onClicked: control.openProject(model.identifier)
                                }
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
                        Layout.preferredHeight: holder.visible ? holder.implicitHeight : implicitHeight
                        verticalScrollBarPolicy: ScrollBar.AlwaysOff
                        padding: 0
                        clip: true
                        model: appHub.appHubModel
                        flickable.interactive: false

                        holder.visible: count === 0
                        holder.title: qsTr("No AppBoxes Installed")
                        holder.body: qsTr("Build an AppBox to see it here.")

                        delegate: Maui.ListBrowserDelegate {
                            id: installedDelegate
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
        Maui.ScrollColumn {
            id: builderScroll
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
                text1: control.editingProject.length > 0 ? control.bundleName : qsTr("Personal Bundle Builder")
                text2: control.editingProject.length > 0
                       ? qsTr("Project %1 • Personal Bundle • %2").arg(control.editingProject, appHub.userBundleArchitecture)
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
                        text2: control.editingProject.length > 0
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.bundleProjectId
                            readOnly: control.editingProject.length > 0
                            maximumLength: 128
                            placeholderText: qsTr("my-application")
                            validator: RegularExpressionValidator { regularExpression: /^[a-z0-9][a-z0-9._-]{0,127}$/ }
                            onTextEdited: {
                                control.bundleProjectId = text
                                control.markDirty()
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.bundleName; onTextEdited: { control.bundleName = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.bundleVersion; onTextEdited: { control.bundleVersion = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.binaryPath; onTextEdited: { control.binaryPath = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            model: control.runtimeTypes
                            currentIndex: Math.max(0, control.runtimeTypes.indexOf(control.runtimeType))
                            onActivated: { control.runtimeType = currentText; control.markDirty() }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            checked: control.osTargetEnabled
                            onToggled: { control.osTargetEnabled = checked; control.markDirty() }
                        }
                    }
                    Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        enabled: control.osTargetEnabled
                        label1.text: qsTr("OS target")
                        label2.text: qsTr("Target platform identifier written to the build recipe.")
                        label2.wrapMode: Text.Wrap
                        template.content: Maui.TextField {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.osTarget
                            onTextEdited: { control.osTarget = text; control.markDirty() }
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
                        model: repositoryModel
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
                                    onClicked: control.openCollectionEditor("repository", index)
                                }

                                ToolButton {
                                    icon.name: "edit-delete"
                                    display: ToolButton.IconOnly
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Remove repository")
                                    onClicked: {
                                        control.markDirty()
                                        repositoryModel.remove(index)
                                    }
                                }
                            }
                        }
                    }

                    Maui.SectionItem {
                        Layout.fillWidth: true
                        visible: repositoryModel.count === 0
                        flat: true
                        label1.text: qsTr("No repositories configured")
                        label2.text: qsTr("Add a package source for the required dependencies.")
                        label2.wrapMode: Text.Wrap
                        template.iconSource: "documentinfo"
                    }

                    Button {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Add Repository")
                        onClicked: control.openCollectionEditor("repository", -1)
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
                        model: ppaModel
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
                                    onClicked: control.openCollectionEditor("ppa", index)
                                }

                                ToolButton {
                                    icon.name: "edit-delete"
                                    display: ToolButton.IconOnly
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Remove PPA")
                                    onClicked: {
                                        control.markDirty()
                                        ppaModel.remove(index)
                                    }
                                }
                            }
                        }
                    }

                    Maui.SectionItem {
                        Layout.fillWidth: true
                        visible: ppaModel.count === 0
                        flat: true
                        label1.text: qsTr("No optional PPAs configured")
                        label2.text: qsTr("Dependencies can use the configured repositories without a PPA.")
                        label2.wrapMode: Text.Wrap
                        template.iconSource: "documentinfo"
                    }

                    Button {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Add PPA")
                        onClicked: control.openCollectionEditor("ppa", -1)
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
                        model: dependencyModel
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
                                    onClicked: control.openCollectionEditor("dependency", index)
                                }

                                ToolButton {
                                    icon.name: "edit-delete"
                                    display: ToolButton.IconOnly
                                    ToolTip.visible: hovered
                                    ToolTip.text: qsTr("Remove dependency")
                                    onClicked: {
                                        control.markDirty()
                                        dependencyModel.remove(index)
                                    }
                                }
                            }
                        }
                    }

                    Maui.SectionItem {
                        Layout.fillWidth: true
                        visible: dependencyModel.count === 0
                        flat: true
                        label1.text: qsTr("No dependencies configured")
                        label2.text: qsTr("Add every package required by the application.")
                        label2.wrapMode: Text.Wrap
                        template.iconSource: "documentinfo"
                    }

                    Button {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("Add Dependency")
                        onClicked: control.openCollectionEditor("dependency", -1)
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            model: control.integrationTypes
                            currentIndex: Math.max(0, control.integrationTypes.indexOf(control.integrationType))
                            onActivated: {
                                control.integrationType = currentText
                                control.markDirty()
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            checked: control.launcherEnabled
                            onToggled: { control.launcherEnabled = checked; control.markDirty() }
                        }
                    }
                    Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        enabled: control.launcherEnabled
                        label1.text: qsTr("Desktop launcher")
                        label2.text: qsTr("Desktop-file basename ending in .desktop for menu integration.")
                        label2.wrapMode: Text.Wrap
                        template.content: Maui.TextField {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.launcher
                            onTextEdited: { control.launcher = text; control.markDirty() }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.launchExec; onTextEdited: { control.launchExec = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.launchPath; onTextEdited: { control.launchPath = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.launchLibraryPath; onTextEdited: { control.launchLibraryPath = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            checked: control.launchAdvancedVisible
                            onToggled: {
                                control.launchAdvancedVisible = checked
                                control.markDirty()
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        enabled: control.launchAdvancedVisible
                        spacing: Maui.Style.space.small

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            label1.text: qsTr("Environment variables")
                            label1.font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: environmentModel
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
                                        onClicked: control.openCollectionEditor("environment", index)
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Remove environment variable")
                                        onClicked: {
                                            control.markDirty()
                                            environmentModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            visible: environmentModel.count === 0
                            flat: true
                            label1.text: qsTr("No environment variables configured")
                            label2.text: qsTr("Add variables exported by AppRun when the application starts.")
                            label2.wrapMode: Text.Wrap
                            template.iconSource: "documentinfo"
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Add Environment Variable")
                            onClicked: control.openCollectionEditor("environment", -1)
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            label1.text: qsTr("Extra RPATHs")
                            label1.font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: rpathModel
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
                                        onClicked: control.openCollectionEditor("rpath", index)
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Remove RPATH")
                                        onClicked: {
                                            control.markDirty()
                                            rpathModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            visible: rpathModel.count === 0
                            flat: true
                            label1.text: qsTr("No extra RPATHs configured")
                            label2.text: qsTr("Add a runtime library search path when the default paths are insufficient.")
                            label2.wrapMode: Text.Wrap
                            template.iconSource: "documentinfo"
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Add RPATH")
                            onClicked: control.openCollectionEditor("rpath", -1)
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            label1.text: qsTr("Pre-build commands")
                            label1.color: Maui.Theme.negativeTextColor
                            label1.font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: prebuildModel
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
                                        onClicked: control.openCollectionEditor("prebuild", index)
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Remove pre-build command")
                                        onClicked: {
                                            control.markDirty()
                                            prebuildModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            visible: prebuildModel.count === 0
                            flat: true
                            label1.text: qsTr("No pre-build commands configured")
                            label2.text: qsTr("Commands are optional and run before the bundle is built.")
                            label2.wrapMode: Text.Wrap
                            template.iconSource: "documentinfo"
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Add Pre-build Command")
                            onClicked: control.openCollectionEditor("prebuild", -1)
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
                        text2: control.integrationType === "wm" ? qsTr("Desktop sessions and window managers run without a sandbox.") : qsTr("Optional runtime isolation for this personal bundle.")
                        label2.wrapMode: Text.Wrap
                    }
                    Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        enabled: control.integrationType !== "wm"
                        label2.wrapMode: Text.Wrap
                        label1.text: qsTr("Sandbox type")
                        label2.text: qsTr("Choose Bubblewrap for GUI or CLI applications, or Firejail for CLI applications.")
                        template.content: ComboBox {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            model: control.sandboxTypes
                            currentIndex: Math.max(0, control.sandboxTypes.indexOf(control.sandboxType))
                            onActivated: {
                                control.sandboxType = currentText
                                control.markDirty()
                            }
                        }
                    }
                    Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        label2.wrapMode: Text.Wrap
                        visible: control.sandboxType === "firejail"
                        label1.text: qsTr("Firejail profile name")
                        label2.text: qsTr("Required profile name. Firejail sandboxing requires command-line integration.")
                        template.content: Maui.TextField {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.firejailName; onTextEdited: { control.firejailName = text; control.markDirty() } }
                    }
                    Maui.SectionItem {
                        visible: control.sandboxType === "firejail"
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            checked: control.appArmorProfileEnabled
                            onToggled: { control.appArmorProfileEnabled = checked; control.markDirty() }
                        }
                    }
                    Maui.SectionItem {
                        visible: control.sandboxType === "firejail"
                        Layout.fillWidth: true
                        flat: true
                        enabled: control.appArmorProfileEnabled
                        label1.text: qsTr("AppArmor profile")
                        label2.text: qsTr("AppArmor profile name associated with the Firejail sandbox.")
                        label2.wrapMode: Text.Wrap
                        template.content: Maui.TextField {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.appArmorProfile
                            onTextEdited: { control.appArmorProfile = text; control.markDirty() }
                        }
                    }
                    ColumnLayout {
                        visible: control.sandboxType === "bwrap" && control.integrationType !== "wm"
                        Layout.fillWidth: true
                        spacing: Maui.Style.space.small
                        Maui.SectionHeader {
                            Layout.fillWidth: true
                            text1: qsTr("Isolation options")
                            text2: qsTr("Configure filesystem access, namespaces, and process isolation.")
                            label2.wrapMode: Text.Wrap
                        }
                        Repeater {
                            model: sandboxBooleanModel
                            delegate: Maui.SectionItem {
                                Layout.fillWidth: true
                                flat: true
                                label1.text: control.sandboxBooleanLabel(model.option)
                                label2.text: control.sandboxBooleanDescription(model.option)
                                label2.wrapMode: Text.Wrap
                                template.content: Switch {
                                    property Item wideParent
                                    property Item responsiveSectionItem
                                    readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                    function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                    onResponsiveNarrowChanged: updateResponsiveParent()
                                    Component.onCompleted: control.configureResponsiveControl(this)
                                    checked: model.selected
                                    onToggled: {
                                        sandboxBooleanModel.setProperty(index, "selected", checked)
                                        control.markDirty()
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
                            model: bwrapEnvironmentModel
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
                                        onClicked: control.openCollectionEditor("bwrapEnvironment", index)
                                    }

                                    ToolButton {
                                        icon.name: "edit-delete"
                                        display: ToolButton.IconOnly
                                        ToolTip.visible: hovered
                                        ToolTip.text: qsTr("Remove sandbox environment variable")
                                        onClicked: {
                                            control.markDirty()
                                            bwrapEnvironmentModel.remove(index)
                                        }
                                    }
                                }
                            }
                        }

                        Maui.SectionItem {
                            Layout.fillWidth: true
                            visible: bwrapEnvironmentModel.count === 0
                            flat: true
                            label1.text: qsTr("No sandbox environment variables configured")
                            label2.text: qsTr("Add variables that Bubblewrap should expose to the application.")
                            label2.wrapMode: Text.Wrap
                            template.iconSource: "documentinfo"
                        }

                        Button {
                            Layout.alignment: Qt.AlignRight
                            text: qsTr("Add Environment Variable")
                            onClicked: control.openCollectionEditor("bwrapEnvironment", -1)
                        }

                        Maui.SectionHeader {
                            Layout.fillWidth: true
                            text1: qsTr("Bindings and Capabilities")
                            text2: qsTr("Expose paths or adjust capabilities inside the Bubblewrap sandbox.")
                            label2.wrapMode: Text.Wrap
                        }
                        Repeater {
                            model: sandboxStringModel
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: control.sandboxListOptions
                                    currentIndex: Math.max(0, control.sandboxListOptions.indexOf(sandboxStringModel.get(index).option))
                                    onActivated: { sandboxStringModel.setProperty(index, "option", currentText); control.markDirty() }
                                }
                                Maui.TextField { Layout.fillWidth: true; text: model.entryValue; placeholderText: qsTr("Value"); onTextEdited: { sandboxStringModel.setProperty(index, "entryValue", text); control.markDirty() } }
                                ToolButton { text: qsTr("Remove Option"); display: ToolButton.IconOnly; icon.name: "list-remove"; onClicked: { control.markDirty(); sandboxStringModel.remove(index) } }
                            }
                        }
                        Button { Layout.alignment: Qt.AlignRight; text: qsTr("Add Binding or Capability"); onClicked: { sandboxStringModel.append({"option": "bind", "entryValue": ""}); control.markDirty() } }
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
                                Component.onCompleted: control.configureResponsiveControl(this)
                                checked: control.sandboxHostnameEnabled
                                onToggled: { control.sandboxHostnameEnabled = checked; control.markDirty() }
                            }
                        }
                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            enabled: control.sandboxHostnameEnabled
                            label1.text: qsTr("Hostname")
                            label2.text: qsTr("Hostname exposed inside the Bubblewrap sandbox.")
                            label2.wrapMode: Text.Wrap
                            template.content: Maui.TextField {
                                property Item wideParent
                                property Item responsiveSectionItem
                                readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                onResponsiveNarrowChanged: updateResponsiveParent()
                                Component.onCompleted: control.configureResponsiveControl(this)
                                Layout.fillWidth: responsiveNarrow
                                Layout.minimumWidth: responsiveNarrow ? 0 : -1
                                Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                                Layout.preferredWidth: control.settingsControlWidth
                                text: control.sandboxHostname
                                onTextEdited: { control.sandboxHostname = text; control.markDirty() }
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
                                Component.onCompleted: control.configureResponsiveControl(this)
                                checked: control.sandboxWorkingDirectoryEnabled
                                onToggled: { control.sandboxWorkingDirectoryEnabled = checked; control.markDirty() }
                            }
                        }
                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            enabled: control.sandboxWorkingDirectoryEnabled
                            label1.text: qsTr("Working directory")
                            label2.text: qsTr("Directory selected before the sandboxed application starts.")
                            label2.wrapMode: Text.Wrap
                            template.content: Maui.TextField {
                                property Item wideParent
                                property Item responsiveSectionItem
                                readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                onResponsiveNarrowChanged: updateResponsiveParent()
                                Component.onCompleted: control.configureResponsiveControl(this)
                                Layout.fillWidth: responsiveNarrow
                                Layout.minimumWidth: responsiveNarrow ? 0 : -1
                                Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                                Layout.preferredWidth: control.settingsControlWidth
                                text: control.sandboxWorkingDirectory
                                onTextEdited: { control.sandboxWorkingDirectory = text; control.markDirty() }
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
                                Component.onCompleted: control.configureResponsiveControl(this)
                                checked: control.sandboxFileLabelEnabled
                                onToggled: { control.sandboxFileLabelEnabled = checked; control.markDirty() }
                            }
                        }
                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            enabled: control.sandboxFileLabelEnabled
                            label1.text: qsTr("File label")
                            label2.text: qsTr("SELinux file label applied inside the sandbox.")
                            label2.wrapMode: Text.Wrap
                            template.content: Maui.TextField {
                                property Item wideParent
                                property Item responsiveSectionItem
                                readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                onResponsiveNarrowChanged: updateResponsiveParent()
                                Component.onCompleted: control.configureResponsiveControl(this)
                                Layout.fillWidth: responsiveNarrow
                                Layout.minimumWidth: responsiveNarrow ? 0 : -1
                                Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                                Layout.preferredWidth: control.settingsControlWidth
                                text: control.sandboxFileLabel
                                onTextEdited: { control.sandboxFileLabel = text; control.markDirty() }
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
                                Component.onCompleted: control.configureResponsiveControl(this)
                                checked: control.sandboxExecLabelEnabled
                                onToggled: { control.sandboxExecLabelEnabled = checked; control.markDirty() }
                            }
                        }
                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            enabled: control.sandboxExecLabelEnabled
                            label1.text: qsTr("Executable label")
                            label2.text: qsTr("SELinux execution label applied when the application starts.")
                            label2.wrapMode: Text.Wrap
                            template.content: Maui.TextField {
                                property Item wideParent
                                property Item responsiveSectionItem
                                readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                onResponsiveNarrowChanged: updateResponsiveParent()
                                Component.onCompleted: control.configureResponsiveControl(this)
                                Layout.fillWidth: responsiveNarrow
                                Layout.minimumWidth: responsiveNarrow ? 0 : -1
                                Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                                Layout.preferredWidth: control.settingsControlWidth
                                text: control.sandboxExecLabel
                                onTextEdited: { control.sandboxExecLabel = text; control.markDirty() }
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
                                Component.onCompleted: control.configureResponsiveControl(this)
                                checked: control.sandboxSeccompEnabled
                                onToggled: { control.sandboxSeccompEnabled = checked; control.markDirty() }
                            }
                        }
                        Maui.SectionItem {
                            Layout.fillWidth: true
                            flat: true
                            enabled: control.sandboxSeccompEnabled
                            label1.text: qsTr("Seccomp file descriptor")
                            label2.text: qsTr("Non-negative file descriptor containing the seccomp filter.")
                            label2.wrapMode: Text.Wrap
                            template.content: Maui.TextField {
                                property Item wideParent
                                property Item responsiveSectionItem
                                readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                                function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                                onResponsiveNarrowChanged: updateResponsiveParent()
                                Component.onCompleted: control.configureResponsiveControl(this)
                                Layout.fillWidth: responsiveNarrow
                                Layout.minimumWidth: responsiveNarrow ? 0 : -1
                                Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                                Layout.preferredWidth: control.settingsControlWidth
                                validator: IntValidator { bottom: 0 }
                                text: control.sandboxSeccomp
                                onTextEdited: { control.sandboxSeccomp = text; control.markDirty() }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.metadataSummary; onTextEdited: { control.metadataSummary = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.metadataDescription
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            onTextChanged: { if (!control.loadingEditor) { control.metadataDescription = text; control.markDirty() } }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            model: control.metadataCategories
                            currentIndex: Math.max(0, control.metadataCategories.indexOf(control.metadataCategory))
                            onActivated: { control.metadataCategory = currentText; control.markDirty() }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            checked: control.metadataHomepageEnabled
                            onToggled: { control.metadataHomepageEnabled = checked; control.markDirty() }
                        }
                    }
                    Maui.SectionItem {
                        Layout.fillWidth: true
                        flat: true
                        enabled: control.metadataHomepageEnabled
                        label1.text: qsTr("Homepage")
                        label2.text: qsTr("Project or application website stored in the metadata.")
                        label2.wrapMode: Text.Wrap
                        template.content: Maui.TextField {
                            property Item wideParent
                            property Item responsiveSectionItem
                            readonly property bool responsiveNarrow: responsiveSectionItem && (Maui.Handy.isMobile || responsiveSectionItem.width < Maui.Style.units.gridUnit * 30)
                            function updateResponsiveParent() { if (wideParent && responsiveSectionItem && responsiveSectionItem.contentItem) parent = responsiveNarrow ? responsiveSectionItem.contentItem : wideParent }
                            onResponsiveNarrowChanged: updateResponsiveParent()
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth
                            text: control.metadataHomepage
                            onTextEdited: { control.metadataHomepage = text; control.markDirty() }
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
                            Component.onCompleted: control.configureResponsiveControl(this)
                            Layout.fillWidth: responsiveNarrow
                            Layout.minimumWidth: responsiveNarrow ? 0 : -1
                            Layout.maximumWidth: responsiveNarrow ? Number.POSITIVE_INFINITY : control.settingsControlWidth
                            Layout.preferredWidth: control.settingsControlWidth; text: control.metadataLicense; onTextEdited: { control.metadataLicense = text; control.markDirty() } }
                    }
                }
            }

            Rectangle {
                visible: control.editingProject.length > 0 && (appHub.busy || appHub.operationLog.length > 0)
                Layout.fillWidth: true
                color: Maui.Theme.alternateBackgroundColor
                radius: Maui.Style.radiusV
                border.color: Maui.Theme.backgroundColor
                border.width: 1
                implicitHeight: buildOutputLayout.implicitHeight + Maui.Style.contentMargins * 2

                ColumnLayout {
                    id: buildOutputLayout
                    anchors.fill: parent
                    anchors.margins: Maui.Style.contentMargins
                    spacing: Maui.Style.space.small

                    Maui.SectionHeader {
                        Layout.fillWidth: true
                        text1: qsTr("Build Output")
                        text2: appHub.statusMessage
                        label2.wrapMode: Text.Wrap
                    }
                    BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: appHub.busy; visible: running }
                    TextArea {
                        Layout.fillWidth: true
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: appHub.operationLog
                    }
                }
            }
        }
    }
}
