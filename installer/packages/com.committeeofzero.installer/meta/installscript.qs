const targetDirectoriesValidationState = {
    Impacto: false,
    Gamedata: false,
    Patches: false,
    Profiles: false,
};

const targetChooserImpactoCallback = () => Component.prototype.chooseTarget("targetDirectoryImpacto", "TargetDir", "DynamicTargetWidget");
const targetChooserGamedataCallback = () => Component.prototype.chooseTarget("targetDirectoryGamedata", "TargetDirGamedata", "DynamicTargetWidget");
const targetChooserPatchesCallback = () => Component.prototype.chooseTarget("targetDirectoryPatches", "TargetDirPatches", "DynamicTargetWidget");
const targetChooserProfilesCallback = () => Component.prototype.chooseTarget("targetDirectoryProfiles", "TargetDirProfiles", "DynamicTargetWidget");

const targetChooserImpactoMobileCallback = () => Component.prototype.chooseTarget("targetDirectoryImpacto", "TargetDir", "DynamicTargetWidgetMobile");

function Component() {
    installer.wizardPageInsertionRequested.connect(this, Component.prototype.onWizardPageInsertionRequested);
    installer.wizardPageRemovalRequested.connect(this, Component.prototype.onWizardPageRemovalRequested);
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
        return installer.value("TargetDir") + "/patches";
    }
    return `${GetAppDataDir()}/patches`
}
function TargetDirProfilesDefault() {
    return `${GetAppDataDir()}/profiles`;
}

function TargetDirectoriesDesktopPageInserted(widget, page) {
    console.log("Setting up Target Directories Page for Desktop Install");
    installer.setValidatorForCustomPage(component, "TargetWidget", "validatePage");

    gui.findChild(widget, "labelImpactoError").setVisible(false);
    gui.findChild(widget, "labelGamedataError").setVisible(false);
    gui.findChild(widget, "labelPatchesError").setVisible(false);
    gui.findChild(widget, "labelProfilesError").setVisible(false);

    gui.findChild(widget, "targetChooserImpacto").clicked.connect(this, targetChooserImpactoCallback);
    gui.findChild(widget, "targetChooserGamedata").clicked.connect(this, targetChooserGamedataCallback);
    gui.findChild(widget, "targetChooserPatches").clicked.connect(this, targetChooserPatchesCallback);
    gui.findChild(widget, "targetChooserProfiles").clicked.connect(this, targetChooserProfilesCallback);

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
    widget.checkBoxAdvanced.stateChanged.connect(this, CheckboxAdvancedChanged);
    installer.setValue("CreateStartMenuShortcut", widget.checkBoxStartMenu.checked ? "1" : "0");
    widget.checkBoxStartMenu.stateChanged.connect(this, CheckboxStartMenuChanged);
    installer.setValue("CreateDesktopShortcut", widget.checkBoxDesktop.checked ? "1" : "0");
    widget.checkBoxDesktop.stateChanged.connect(this, CheckboxDesktopChanged);
}

function CheckboxAdvancedChanged(newState) {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    gui.findChild(widget, "advancedConfig").setVisible(newState == Qt.Checked);
    gui.findChild(widget, "targetDirectoryGamedata").text = installer.toNativeSeparators(TargetDirGamedataDefault());
    gui.findChild(widget, "targetDirectoryPatches").text = installer.toNativeSeparators(TargetDirPatchesDefault());
    gui.findChild(widget, "targetDirectoryProfiles").text = installer.toNativeSeparators(TargetDirProfilesDefault());
}

function CheckboxStartMenuChanged(newState) {
    installer.setValue("CreateStartMenuShortcut", newState == Qt.Checked ? "1" : "0");
}

function CheckboxDesktopChanged(newState) {
    installer.setValue("CreateDesktopShortcut", newState == Qt.Checked ? "1" : "0");
}

function TargetDirectoriesMobilePageInserted(widget) {
    console.log("Setting up Target Directories Page for Mobile Install");
    installer.setValidatorForCustomPage(component, "TargetWidgetMobile", "validatePageMobile");

    gui.findChild(widget, "labelImpactoError").setVisible(false);
    widget.targetChooserImpacto.clicked.connect(this, targetChooserImpactoMobileCallback);

    widget.targetDirectoryImpacto.textChanged.connect(this, Component.prototype.targetChangedImpactoMobile);
    widget.targetDirectoryImpacto.text = installer.toNativeSeparators("");
}

Component.prototype.onWizardPageInsertionRequested = (widget, page) => {
    if (widget.objectName == "TargetWidget") {
        TargetDirectoriesDesktopPageInserted(widget, page);
    } else if (widget.objectName == "TargetWidgetMobile") {
        TargetDirectoriesMobilePageInserted(widget, page);
    }
}


Component.prototype.onWizardPageRemovalRequested = (widget) => {
    if (widget.objectName == "TargetWidget") {
        console.log("Removing Target Directories Page");
        gui.findChild(widget, "targetChooserImpacto").clicked.disconnect(this, targetChooserImpactoMobileCallback);
        gui.findChild(widget, "targetChooserGamedata").clicked.disconnect(this, targetChooserGamedataCallback);
        gui.findChild(widget, "targetChooserPatches").clicked.disconnect(this, targetChooserPatchesCallback);
        gui.findChild(widget, "targetChooserProfiles").clicked.disconnect(this, targetChooserProfilesCallback);

        widget.targetDirectoryImpacto.textChanged.disconnect(this, Component.prototype.targetChangedImpacto);
        gui.findChild(widget, "targetDirectoryGamedata").textChanged.disconnect(this, Component.prototype.targetChangedGamedata);
        gui.findChild(widget, "targetDirectoryPatches").textChanged.disconnect(this, Component.prototype.targetChangedPatches);
        gui.findChild(widget, "targetDirectoryProfiles").textChanged.disconnect(this, Component.prototype.targetChangedProfiles);
        widget.checkBoxAdvanced.stateChanged.disconnect(this, CheckboxAdvancedChanged);
        widget.checkBoxStartMenu.stateChanged.disconnect(this, CheckboxStartMenuChanged);
        widget.checkBoxDesktop.stateChanged.disconnect(this, CheckboxDesktopChanged);        
    } else if (widget.objectName == "TargetWidgetMobile") {
        console.log("Removing Target Directories Page for Mobile Install");
        widget.targetChooserImpacto.clicked.disconnect(this, targetChooserImpactoMobileCallback);
        widget.targetDirectoryImpacto.textChanged.disconnect(this, Component.prototype.targetChangedImpactoMobile);
    }
}


Component.prototype.chooseTarget = function (widgetName, installerKey, pageName) {
    const widget = gui.pageWidgetByObjectName(pageName);
    if (widget != null) {
        const targetDirectory = gui.findChild(widget, widgetName);
        const hintDirectory = installer.toNativeSeparators(installer.value(installerKey));
        const newTarget = QFileDialog.getExistingDirectory("Choose your target directory.", hintDirectory);
        if (newTarget != "")
            targetDirectory.text = installer.toNativeSeparators(newTarget);
    }
}

Component.prototype.targetChanged = function (text, storedKey, validationKey, pageName = "DynamicTargetWidget") {
    const widget = gui.pageWidgetByObjectName(pageName);
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

Component.prototype.validatePageMobile = function () {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidgetMobile");

    if (!widget.complete)
        return false;

    if (!widget.visible)
        return true;
    
    const hasExistingFiles = !validateTargetDirectories(installer.value("TargetDir"));
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
Component.prototype.targetChangedImpactoMobile = function (text) {
    Component.prototype.targetChanged(text, "TargetDir", "Impacto", "DynamicTargetWidgetMobile");
    if (!targetDirectoriesValidationState.Impacto) return;

    installer.setValue("TargetDirGamedata", installer.toNativeSeparators(text + "/impacto/gamedata"));
    installer.setValue("TargetDirPatches", installer.toNativeSeparators(text + "/impacto/patches"));
    installer.setValue("TargetDirProfiles", installer.toNativeSeparators(text + "/impacto/profiles"));

    targetDirectoriesValidationState.Gamedata = true;
    targetDirectoriesValidationState.Patches = true;
    targetDirectoriesValidationState.Profiles = true;
    
}