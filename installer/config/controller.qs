function Controller() {
    this.hookSelection = false;
}

Controller.prototype.onSelectionChange = function () {
    const page = gui.currentPageWidget();
    page.completeChanged.disconnect(this, Controller.prototype.onSelectionChange); // Prevent recursive calls
    const eng = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.eng");
    const jpn = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.jpn");
    const assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");

    // If either CCLCC PS4 Patches are selected, automatically select the CCLCC PS4 Assets component and don't allow unchecking
    if (eng.installationRequested() || jpn.installationRequested()) {
        page.selectComponent("com.committeeofzero.cclcc.ps4.assets");
        assets.enabled = false; // disable unchecking
    } else {
        assets.enabled = true;
    }

    validateSelection();

    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);
};

Controller.prototype.ComponentSelectionPageCallback = function () {
    const page = gui.pageByObjectName("ComponentSelectionPage");
    if (!page) return;

    // Trigger on component selection changes
    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);
};


function validateSelection() {
    const errors = [];

    const impactoGroup = installer.componentByName("com.committeeofzero.impacto");

    if (!impactoGroup.installationRequested()) {
        errors.push(
            "Please select an Impacto component."
        );
    }

    // Add block continue page w/ error if impacto is not selected
    const componentInstaller = installer.componentByName("com.committeeofzero.installer");
    if (errors.length > 0) {
        let page = gui.pageWidgetByObjectName("DynamicSelectionValidationPage");
        if (!page) {
            installer.addWizardPage(componentInstaller, "SelectionValidationPage", QInstaller.LicenseCheck);
            page = gui.pageWidgetByObjectName("DynamicSelectionValidationPage");
        }
        if (page) {
            page.label.text = errors.join("\n");
            page.complete = false;
        }
    } else {
        installer.removeWizardPage(componentInstaller, "SelectionValidationPage");
    }

    // Add CCLCC PS4 Assets page if CCLCC PS4 Patch is selected
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    const pageCclccPs4Assets = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");
    if (componentCclccPs4Assets.installationRequested()) {
        if (!pageCclccPs4Assets)
            installer.addWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4", QInstaller.ReadyForInstallation);
    } else {
        installer.removeWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4");
    }
}



