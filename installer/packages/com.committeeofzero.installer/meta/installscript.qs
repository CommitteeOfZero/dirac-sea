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

    gui.findChild(widget, "labelImpactoError").setVisible(false);
    gui.findChild(widget, "labelGamedataError").setVisible(false);
    gui.findChild(widget, "labelPatchesError").setVisible(false);

    gui.findChild(widget, "targetChooserGamedata").clicked.connect(this, Component.prototype.chooseTargetGamedata);
    gui.findChild(widget, "targetChooserPatches").clicked.connect(this, Component.prototype.chooseTargetPatches);

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

Component.prototype.chooseTargetGamedata = function () {
    Component.prototype.chooseTarget("targetDirectoryGamedata", "TargetDirGamedata");
}
Component.prototype.chooseTargetPatches = function () {
    Component.prototype.chooseTarget("targetDirectoryPatches", "TargetDirPatches");
}

Component.prototype.targetChanged = function (text, storedKey, validationKey, validateCallBack) {
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (widget != null) {
        if (text != "") {
            const errorLabel = gui.findChild(widget, `label${validationKey}Error`);
            if (validateCallBack(text)) {
                installer.setValue(storedKey, text);
                targetDirectoriesValidationState[validationKey] = true;
                errorLabel.setVisible(false);
            } else {
                targetDirectoriesValidationState[validationKey] = false;
                errorLabel.setVisible(true);
                errorLabel.setText(`The selected path is invalid or already exists. Please choose a different path.`)
            }
            console.log(`Impacto Validation state: ${targetDirectoriesValidationState.Impacto}`)
            console.log(`Gamedata Validation state: ${targetDirectoriesValidationState.Gamedata}`)
            console.log(`Patches Validation state: ${targetDirectoriesValidationState.Patches}`)
            widget.complete = Object.values(targetDirectoriesValidationState).every((value) => value === true);
        }
    }
}

Component.prototype.targetChangedImpacto = function (text) {
    Component.prototype.targetChanged(text, "TargetDir", "Impacto", (path) => !installer.fileExists(path))
    const widget = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if(targetDirectoriesValidationState.Impacto && !widget.checkBoxAdvanced.checked) {
        targetDirectoryGamedata.text = installer.toNativeSeparators(TargetDirGamedataDefault());
        targetDirectoryPatches.text = installer.toNativeSeparators(TargetDirPatchesDefault());
    }
}
Component.prototype.targetChangedGamedata = function (text) {
    Component.prototype.targetChanged(text, "TargetDirGamedata", "Gamedata", (path) => true)
}
Component.prototype.targetChangedPatches = function (text) {
    Component.prototype.targetChanged(text, "TargetDirPatches", "Patches", (path) => true)
}