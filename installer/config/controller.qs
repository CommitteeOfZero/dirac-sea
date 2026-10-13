function Controller() {
    installer.setDefaultPageVisible(QInstaller.TargetDirectory, false);
}

Controller.prototype.FinishedPageCallback = function () {
    const wasUpdated = installer.containsValue("ExistingMaintenanceTool");
    if (wasUpdated) {
        const finishedPage = gui.currentPageWidget();
        const maintenanceToolStatus = Number(installer.value("MaintenanceToolStatus"));
        if (maintenanceToolStatus == 0) finishedPage.MessageLabel.text = `Operation completed.`;
        if (maintenanceToolStatus == 1) finishedPage.MessageLabel.text = `Operation failed.`;
        if (maintenanceToolStatus == 3) finishedPage.MessageLabel.text = `Operation canceled.`;
    }
}


function componentIsSelected(widget) {
    if (!widget) return false;
    return (widget.isInstalled() || widget.installationRequested()) &&
        !widget.uninstallationRequested();
}


Controller.prototype.onSelectionChange = function () {
    const page = gui.currentPageWidget();
    page.completeChanged.disconnect(this, Controller.prototype.onSelectionChange); // Prevent recursive calls

    // If either CCLCC PS4 patches are selected, automatically select the CCLCC PS4 assets component and don't allow unchecking.
    const cclccPs4Eng = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.eng");
    const cclccPs4Jpn = installer.componentByName("com.committeeofzero.cclcc.ps4.patch.jpn");
    const cclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if (cclccPs4Assets) {
        const cclccPs4Selected = componentIsSelected(cclccPs4Eng) || componentIsSelected(cclccPs4Jpn);
        if (cclccPs4Selected) {
            page.selectComponent("com.committeeofzero.cclcc.ps4.assets");
            cclccPs4Assets.enabled = false;
        } else {
            cclccPs4Assets.enabled = true;
        }
    }

    // If either CHLCC PS3 patches are selected, automatically select the CHLCC PS3 assets component and don't allow unchecking.

    const chlccPs3Eng = installer.componentByName("com.committeeofzero.chlcc.ps3.patch.eng");
    const chlccPs3Jpn = installer.componentByName("com.committeeofzero.chlcc.ps3.patch.jpn");
    const chlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if (chlccPs3Assets) {
        const chlccPs3Selected = componentIsSelected(chlccPs3Eng) || componentIsSelected(chlccPs3Jpn);
        if (chlccPs3Selected) {
            page.selectComponent("com.committeeofzero.chlcc.ps3.assets");
            chlccPs3Assets.enabled = false;
        } else {
            chlccPs3Assets.enabled = true;
        }
    }

    validateSelection();

    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);
};

Controller.prototype.ComponentSelectionPageCallback = function () {
    const page = gui.pageByObjectName("ComponentSelectionPage");
    if (!page || !page.visible) return;
    // Validate selections and hook up signal
    Controller.prototype.onSelectionChange();
};

function addCclccPs4AssetsInstallPage() {
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if (componentCclccPs4Assets) {
        const pageCclccPs4Assets = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");
        if (componentCclccPs4Assets.installationRequested()) {
            if (!pageCclccPs4Assets) {
                installer.addWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4", QInstaller.ReadyForInstallation);
            }
        } else if(pageCclccPs4Assets) {
            installer.removeWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4");
        }
    }
}

function addChlccPs3AssetsInstallPage() {
    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if (componentChlccPs3Assets) {
        const pageChlccPs3Assets = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
        if (componentChlccPs3Assets.installationRequested()) {
            if (!pageChlccPs3Assets) {
                installer.addWizardPage(componentChlccPs3Assets, "PathPage_CHLCC_PS3", QInstaller.ReadyForInstallation);
            }
        } else if(pageChlccPs3Assets) {
            installer.removeWizardPage(componentChlccPs3Assets, "PathPage_CHLCC_PS3");
        }
    }
}

function validateSelection() {
    addCclccPs4AssetsInstallPage();
    addChlccPs3AssetsInstallPage();
}

Controller.prototype.DynamicTargetWidgetMobileCallback = function () {
    console.log("Setting to portable install");
    installer.setPortableInstaller();
}

Controller.prototype.DynamicUpdateWaitingRoomCallback = function () {
    const waitingPage = gui.pageByObjectName("DynamicUpdateWaitingRoom");
    waitingPage.setComplete(false);
    const tempRepo = `${QDesktopServices.storageLocation(QDesktopServices.TempLocation)}/tmpImpactoInstallRepository`;
    const tempCache = `${QDesktopServices.storageLocation(QDesktopServices.TempLocation)}/tmpImpactoInstallCache`;
    installer.performOperation("CreateLocalRepository", ["@InstallerFilePath@", tempRepo]);
    const existingInstall = installer.value("ExistingMaintenanceTool");
    const output =
        (() => {
            if (systemInfo.productType === "windows") {
                return installer.execute(
                    "cmd", ["/c", "start", "", "/wait", existingInstall, "--set-temp-repository", tempRepo, "--cache-path", tempCache]
                );
            } else if (systemInfo.productType === "macos") {
                return installer.execute(
                    "open",
                    ["-W", existingInstall, "--args",
                        "--set-temp-repository", tempRepo,
                        "--cache-path", tempCache]
                );
            } else {
                return installer.execute(
                    existingInstall,
                    ["--set-temp-repository", tempRepo, "--cache-path", tempCache]
                );
            }
        })();
    console.log(`Maintenance Tool Output: ${output[0]}`)
    console.log(`Maintenance Tool Status Code: ${output[1]}`)
    installer.setValue("MaintenanceToolStatus", output[1]);
    installer.performOperation("Rmdir", [tempRepo, "FORCE"]);
    installer.performOperation("Rmdir", [tempCache, "FORCE"]);
    waitingPage.setComplete(true);
    gui.clickButton(buttons.NextButton);
    gui.setVisible(true);
}
