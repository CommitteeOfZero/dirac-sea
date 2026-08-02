const targetDirectoriesValidationState = {
    Impacto: false,
    Gamedata: false,
    Patches: false
};

function Component() {
    if (installer.isInstaller()) {
        component.loaded.connect(this, Component.prototype.installerLoaded);
    }
}

Component.prototype.isDefault = function () {
    return true;
}

function validateSelection() {
    const errors = [];

    const impactoGroup = installer.componentByName("com.committeeofzero.impacto");

    if (!impactoGroup.installationRequested()) {
        errors.push(
            "Please select an Impacto component."
        );
    }

    return errors;
}

const TargetDirGamedataDefault = () => installer.value("TargetDir") + "/gamedata";
const TargetDirPatchesDefault = () => installer.value("TargetDir") + "/patches";

function hookupTargetDirectoryPage() {
    if (!installer.addWizardPage(component, "TargetWidget", QInstaller.TargetDirectory)) return;
    console.log("Added DynamicTargetWidget page");
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    const localAppData = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;

    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (widget == null) return; 

    installer.setValidatorForCustomPage(component, "TargetWidget", "validatePage");

    gui.findChild(widget, "labelImpactoError").setVisible(false);
    gui.findChild(widget, "labelGamedataError").setVisible(false);
    gui.findChild(widget, "labelPatchesError").setVisible(false);

    gui.findChild(widget, "targetChooserImpacto").clicked.connect(this, 
        () => Component.prototype.chooseTarget("targetDirectoryImpacto", "TargetDir")
    );
    gui.findChild(widget, "targetChooserGamedata").clicked.connect(this, 
        () => Component.prototype.chooseTarget("targetDirectoryGamedata", "TargetDirGamedata")
    );
    gui.findChild(widget, "targetChooserPatches").clicked.connect(this, 
        () => Component.prototype.chooseTarget("targetDirectoryPatches", "TargetDirPatches")
    );

    const targetDirectoryGamedata = gui.findChild(widget, "targetDirectoryGamedata");
    const targetDirectoryPatches = gui.findChild(widget, "targetDirectoryPatches");

    widget.targetDirectoryImpacto.textChanged.connect(this, Component.prototype.targetChangedImpacto);
    targetDirectoryGamedata.textChanged.connect(this, Component.prototype.targetChangedGamedata);
    targetDirectoryPatches.textChanged.connect(this, Component.prototype.targetChangedPatches);

    widget.targetDirectoryImpacto.text = installer.toNativeSeparators(localAppData);
    targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
    targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());

    gui.findChild(widget, "advancedConfig").setVisible(widget.checkBoxAdvanced.checked);
    widget.checkBoxAdvanced.stateChanged.connect(this, (newState) => {
        gui.findChild(widget, "advancedConfig").setVisible(newState == Qt.Checked);
        targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
        targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
        
    })
    widget.checkBoxStartMenu.stateChanged.connect(this, (newState) => {
        if(systemInfo.productType === "windows") {
            installer.setDefaultPageVisible(QInstaller.StartMenuSelection, newState == Qt.Checked);
        }
    })
    widget.checkBoxDesktop.stateChanged.connect(this, (newState) => {
        installer.setValue("CreateDesktopShortcut", newState == Qt.Checked ? "1" : "0");
    })
}

Component.prototype.installerLoaded = function () {
    installer.setDefaultPageVisible(QInstaller.TargetDirectory, false);
    hookupTargetDirectoryPage();
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

Component.prototype.chooseTargetImpacto = function () {
    Component.prototype.chooseTarget("targetDirectoryImpacto", "TargetDir");
}
Component.prototype.chooseTargetGamedata = function () {
    Component.prototype.chooseTarget("targetDirectoryGamedata", "TargetDirGamedata");
}
Component.prototype.chooseTargetPatches = function () {
    Component.prototype.chooseTarget("targetDirectoryPatches", "TargetDirPatches");
}

Component.prototype.targetChanged = function (text, storedKey, validationKey) {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (widget == null) return;

    const errorLabel = gui.findChild(widget, `label${validationKey}Error`);
    if (text != "") {
        installer.setValue(storedKey, text);
        targetDirectoriesValidationState[validationKey] = true;
        if(!validateTargetDirectories(text)) {
            errorLabel.setVisible(true);
            errorLabel.styleSheet = "color: orange;"
            errorLabel.text = `Directory is not empty. Existing files may be overwritten.`;
        } else {
            errorLabel.setVisible(false);
        }
    } else {
        targetDirectoriesValidationState[validationKey] = false;
        errorLabel.setVisible(true);
        errorLabel.styleSheet = "color: red;"
        errorLabel.text = `Please select a valid directory.`;
        widget.complete = false;
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
        installer.value("TargetDirPatches")
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
    if(targetDirectoriesValidationState.Impacto && !widget.checkBoxAdvanced.checked) {
        const targetDirectoryGamedata = gui.findChild(widget, "targetDirectoryGamedata");
        const targetDirectoryPatches = gui.findChild(widget, "targetDirectoryPatches");
        targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
        targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
    }
}
Component.prototype.targetChangedGamedata = function (text) {
    Component.prototype.targetChanged(text, "TargetDirGamedata", "Gamedata")
}
Component.prototype.targetChangedPatches = function (text) {
    Component.prototype.targetChanged(text, "TargetDirPatches", "Patches")
}