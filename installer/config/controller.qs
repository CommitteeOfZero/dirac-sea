function Controller() {
    installer.setDefaultPageVisible(QInstaller.TargetDirectory, false);

}

function componentIsSelected(widget) {
    return (widget.isInstalled() || widget.installationRequested()) &&
        !widget.uninstallationRequested();
}


Controller.prototype.onSelectionChange = function () {
    const page = gui.currentPageWidget();
    page.completeChanged.disconnect(this, Controller.prototype.onSelectionChange); // Prevent recursive calls

    const cclccPs4Eng = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.eng");
    const cclccPs4Jpn = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.jpn");
    const cclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");

    const chlccPs3Eng = installer.componentByName("com.committeeofzero.chlcc.ps3.patch.eng");
    const chlccPs3Jpn = installer.componentByName("com.committeeofzero.chlcc.ps3.patch.jpn");
    const chlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");


    const cclccPs4Selected = componentIsSelected(cclccPs4Eng) || componentIsSelected(cclccPs4Jpn);
    const chlccPs3Selected = componentIsSelected(chlccPs3Eng) || componentIsSelected(chlccPs3Jpn);

    // If either CCLCC PS4 patches are selected, automatically select the CCLCC PS4 assets component and don't allow unchecking.
    if (cclccPs4Selected) {
        page.selectComponent("com.committeeofzero.cclcc.ps4.assets");
        cclccPs4Assets.enabled = false;
    } else {
        cclccPs4Assets.enabled = true;
    }

    // If either CHLCC PS3 patches are selected, automatically select the CHLCC PS3 assets component and don't allow unchecking.
    if (chlccPs3Selected) {
        page.selectComponent("com.committeeofzero.chlcc.ps3.assets");
        chlccPs3Assets.enabled = false;
    } else {
        chlccPs3Assets.enabled = true;
    }

    validateSelection();

    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);
};

Controller.prototype.ComponentSelectionPageCallback = function () {
    const page = gui.pageByObjectName("ComponentSelectionPage");
    if (!page) return;

    // Validate selections and hook up signal
    Controller.prototype.onSelectionChange();
};


function validateSelection() {
    const errors = [];

    const impactoGroup = installer.componentByName("com.committeeofzero.impacto");

    if (!componentIsSelected(impactoGroup)) {
        errors.push(
            "Please select an Impacto component."
        );
    }

    // Desktop path selection page
    const componentInstaller = installer.componentByName("com.committeeofzero.installer");
    const componentImpactoWin = installer.componentByName("com.committeeofzero.impacto.windows");
    const componentImpactoLin = installer.componentByName("com.committeeofzero.impacto.linux");
    const componentImpactoMacArm = installer.componentByName("com.committeeofzero.impacto.macos_arm64");
    const componentImpactoMacX64 = installer.componentByName("com.committeeofzero.impacto.macos_x64");

    const requestDesktopInstall =
        componentImpactoWin?.installationRequested() ||
        componentImpactoLin?.installationRequested() ||
        componentImpactoMacArm?.installationRequested() ||
        componentImpactoMacX64?.installationRequested();

    const pageTargetDesktop = gui.pageWidgetByObjectName("DynamicTargetWidget");
    if (installer.isInstaller() && requestDesktopInstall && !pageTargetDesktop) {
        installer.addWizardPage(componentInstaller, "TargetWidget", QInstaller.ReadyForInstallation);
    }

    // Add block continue page w/ error if impacto is not selected
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

    // Add the asset-selection wizard page when either the PS4 or PS3 patch component is selected.
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    const pageCclccPs4Assets = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");
    if (componentCclccPs4Assets.installationRequested()) {
        if (!pageCclccPs4Assets) {
            installer.addWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4", QInstaller.ReadyForInstallation);
        }
    } else {
        installer.removeWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4");
    }

    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    const pageChlccPs3Assets = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    if (componentChlccPs3Assets.installationRequested()) {
        if (!pageChlccPs3Assets) {
            installer.addWizardPage(componentChlccPs3Assets, "PathPage_CHLCC_PS3", QInstaller.ReadyForInstallation);
        }
    } else {
        installer.removeWizardPage(componentChlccPs3Assets, "PathPage_CHLCC_PS3");
    }
}



