const targetDirectoriesValidationState = {
    Impacto: false,
    Gamedata: false,
    Patches: false,
    Profiles: false,
};

function Component() {
    installer.wizardPageInsertionRequested.connect(this, Component.prototype.onWizardPageInsertionRequested);
}

Component.prototype.isDefault = function () {
    return true;
}

function GetAppDataDir() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");
    const appDataDir = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;
    return appDataDir;
}

function TargetDirDefault() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    let localApplicationInstall = ""
    if (systemInfo.productType === "windows") {
        localApplicationInstall = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;
    } else if (systemInfo.kernelType === "linux") {
        localApplicationInstall = `${installer.value("HomeDir")}/opt/${publisher}/${productName}`;
    } else if (systemInfo.productType === "macos") {
        localApplicationInstall = `${installer.value("ApplicationsDirUser")}/${publisher}`;
    } else {
        localApplicationInstall = `${installer.value("HomeDir")}/${publisher}/${productName}`;
    }

    return localApplicationInstall;
}
function TargetDirGamedataDefault() {
    if(systemInfo.productType === "windows") {
        return installer.value("TargetDir") + "/gamedata";
    }
    return `${GetAppDataDir()}/gamedata`
}
function TargetDirPatchesDefault() {
    if(systemInfo.productType === "windows") {
        return installer.value("TargetDir") + "/gamedata";
    }
    return `${GetAppDataDir()}/patches`
}
function TargetDirProfilesDefault() {
    return `${GetAppDataDir()}/profiles`;
}

Component.prototype.onWizardPageInsertionRequested = (widget, page) => {
    if (widget.objectName !== "TargetWidget") return;
    console.log("Setting up Target Directories Page for Desktop Install");
    installer.setValidatorForCustomPage(component, "TargetWidget", "validatePage");

    gui.findChild(widget, "labelImpactoError").setVisible(false);
    gui.findChild(widget, "labelGamedataError").setVisible(false);
    gui.findChild(widget, "labelPatchesError").setVisible(false);
    gui.findChild(widget, "labelProfilesError").setVisible(false);

    gui.findChild(widget, "targetChooserImpacto").clicked.connect(this,
        () => Component.prototype.chooseTarget("targetDirectoryImpacto", "TargetDir")
    );
    gui.findChild(widget, "targetChooserGamedata").clicked.connect(this,
        () => Component.prototype.chooseTarget("targetDirectoryGamedata", "TargetDirGamedata")
    );
    gui.findChild(widget, "targetChooserPatches").clicked.connect(this,
        () => Component.prototype.chooseTarget("targetDirectoryPatches", "TargetDirPatches")
    );
    gui.findChild(widget, "targetChooserProfiles").clicked.connect(this,
        () => Component.prototype.chooseTarget("targetDirectoryProfiles", "TargetDirProfiles")
    );

    const targetDirectoryGamedata = gui.findChild(widget, "targetDirectoryGamedata");
    const targetDirectoryPatches = gui.findChild(widget, "targetDirectoryPatches");
    const targetDirectoryProfiles = gui.findChild(widget, "targetDirectoryProfiles");

    widget.targetDirectoryImpacto.textChanged.connect(this, Component.prototype.targetChangedImpacto);
    targetDirectoryGamedata.textChanged.connect(this, Component.prototype.targetChangedGamedata);
    targetDirectoryPatches.textChanged.connect(this, Component.prototype.targetChangedPatches);
    targetDirectoryProfiles.textChanged.connect(this, Component.prototype.targetChangedProfiles);

    widget.targetDirectoryImpacto.text = installer.toNativeSeparators(TargetDirDefault());
    targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
    targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
    targetDirectoryProfiles.text = installer.toNativeSeparators(TargetDirProfilesDefault());

    gui.findChild(widget, "advancedConfig").setVisible(widget.checkBoxAdvanced.checked);
    widget.checkBoxAdvanced.stateChanged.connect(this, (newState) => {
        gui.findChild(widget, "advancedConfig").setVisible(newState == Qt.Checked);
        targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
        targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
        targetDirectoryProfiles.text = installer.toNativeSeparators(TargetDirProfilesDefault());
    })
    installer.setValue("CreateStartMenuShortcut", widget.checkBoxStartMenu.checked ? "1" : "0");
    widget.checkBoxStartMenu.stateChanged.connect(this, (newState) => {
        if (systemInfo.productType === "windows") {
            installer.setDefaultPageVisible(QInstaller.StartMenuSelection, newState == Qt.Checked);
        }
        installer.setValue("CreateStartMenuShortcut", newState == Qt.Checked ? "1" : "0");
    })
    installer.setValue("CreateDesktopShortcut", widget.checkBoxDesktop.checked ? "1" : "0");
    widget.checkBoxDesktop.stateChanged.connect(this, (newState) => {
        installer.setValue("CreateDesktopShortcut", newState == Qt.Checked ? "1" : "0");
    })
}

Component.prototype.chooseTarget = function (widgetName, installerKey) {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (widget != null) {
        const targetDirectory = gui.findChild(widget, widgetName);
        const hintDirectory = installer.toNativeSeparators(installer.value(installerKey));
        const newTarget = QFileDialog.getExistingDirectory("Choose your target directory.", hintDirectory);
        if (newTarget != "")
            targetDirectory.text = installer.toNativeSeparators(newTarget);
    }
}

Component.prototype.targetChanged = function (text, storedKey, validationKey) {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (widget == null) return;

    const errorLabel = gui.findChild(widget, `label${validationKey}Error`);
    if (text != "") {
        let trimmedText = text;
        if (text.endsWith("/") || (systemInfo.productType === "windows" && text.endsWith("\\"))) {
            trimmedText = text.slice(0, -1);
        }
        installer.setValue(storedKey, trimmedText);
        if (!validateTargetDirectories(text)) {
            errorLabel.setVisible(true);
            errorLabel.styleSheet = "color: red;"
            errorLabel.text = `Directory is not empty.`;
            targetDirectoriesValidationState[validationKey] = false;
        } else {
            errorLabel.setVisible(false);
            targetDirectoriesValidationState[validationKey] = true;
        }
    } else {
        targetDirectoriesValidationState[validationKey] = false;
        errorLabel.setVisible(true);
        errorLabel.styleSheet = "color: red;"
        errorLabel.text = `Please select a valid directory.`;
    }
    widget.complete = Object.values(targetDirectoriesValidationState).every((value) => value === true);
}

Component.prototype.validatePage = function () {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");

    if (!widget.complete)
        return false;

    if (!widget.visible)
        return true;

    const directories = [
        installer.value("TargetDir"),
        installer.value("TargetDirGamedata"),
        installer.value("TargetDirPatches"),
        installer.value("TargetDirProfiles"),
    ];

    let hasExistingFiles = false;

    for (let i = 0; i < directories.length; ++i) {
        if (!validateTargetDirectories(directories[i])) {
            hasExistingFiles = true;
            break;
        }
    }

    if (hasExistingFiles) {
        const result = QMessageBox.warning(
            "installerPage.targetDirectoryValidation",
            "Existing files",
            "One or more installation directories are not empty. Continue?",
            QMessageBox.Yes | QMessageBox.No
        );

        if (result !== QMessageBox.Yes)
            return false;
    }

    return true;
};

function validateTargetDirectories(path) {
    const fileCount = installer.folderFileCount(path);
    if (fileCount > 0) {
        return false;
    }
    return true;
}

Component.prototype.targetChangedImpacto = function (text) {
    Component.prototype.targetChanged(text, "TargetDir", "Impacto");
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (targetDirectoriesValidationState.Impacto && !widget.checkBoxAdvanced.checked) {
        const targetDirectoryGamedata = gui.findChild(widget, "targetDirectoryGamedata");
        const targetDirectoryPatches = gui.findChild(widget, "targetDirectoryPatches");
        const targetDirectoryProfiles = gui.findChild(widget, "targetDirectoryProfiles");
        targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
        targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
        targetDirectoryProfiles.text = installer.toNativeSeparators(TargetDirProfilesDefault());
    }
}
Component.prototype.targetChangedGamedata = function (text) {
    Component.prototype.targetChanged(text, "TargetDirGamedata", "Gamedata")
}
Component.prototype.targetChangedPatches = function (text) {
    Component.prototype.targetChanged(text, "TargetDirPatches", "Patches")
}
Component.prototype.targetChangedProfiles = function (text) {
    Component.prototype.targetChanged(text, "TargetDirProfiles", "Profiles")
}