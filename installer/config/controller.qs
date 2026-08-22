let existingMaintenanceTool = "";
let maintenanceToolStatus = 0;

function Controller() {
    installer.setDefaultPageVisible(QInstaller.TargetDirectory, false);

    const existingInstall = getExistingInstall();
    if (existingInstall && installer.isInstaller()) {
        existingMaintenanceTool = existingInstall;

        installer.setDefaultPageVisible(QInstaller.TargetDirectory, false);
        installer.setDefaultPageVisible(QInstaller.ReadyForInstallation, false);
        installer.setDefaultPageVisible(QInstaller.ComponentSelection, false);
        installer.setDefaultPageVisible(QInstaller.StartMenuSelection, false);
        installer.setDefaultPageVisible(QInstaller.PerformInstallation, false);
        installer.setDefaultPageVisible(QInstaller.LicenseCheck, false);
    }
}

Controller.prototype.IntroductionPageCallback = function () {
    if (existingMaintenanceTool) {
        const introPage = gui.currentPageWidget();
        introPage.setComplete(false);
        introPage.MessageLabel.text = "Waiting for Maintenance Tool to Complete";
        const tempRepo = `${QDesktopServices.storageLocation(QDesktopServices.TempLocation)}/tmpImpactoInstallRepository`;
        const tempCache = `${QDesktopServices.storageLocation(QDesktopServices.TempLocation)}/tmpImpactoInstallCache`;
        installer.performOperation("CreateLocalRepository", ["@InstallerFilePath@", tempRepo]);
        const output =
            (() => {
                if (systemInfo.productType === "windows") {
                    return installer.execute(
                        "cmd", ["/c", "start", "", "/wait", existingMaintenanceTool, "--set-temp-repository", tempRepo, "--cache-path", tempCache]
                    );
                } else if (systemInfo.productType === "macos") {
                    return installer.execute(
                        "open",
                        ["-W", existingMaintenanceTool, "--args",
                            "--set-temp-repository", tempRepo,
                            "--cache-path", tempCache]
                    );
                } else {
                    return installer.execute(
                        existingMaintenanceTool,
                        ["--set-temp-repository", tempRepo, "--cache-path", tempCache]
                    );
                }
            })();
        console.log(`Maintenance Tool Output: ${output[0]}`)
        console.log(`Maintenance Tool Status Code: ${output[1]}`)
        maintenanceToolStatus = Number(output[1]);
        installer.performOperation("Rmdir", [tempRepo, "FORCE"]);
        installer.performOperation("Rmdir", [tempCache, "FORCE"]);
        introPage.setComplete(true);
        gui.clickButton(buttons.NextButton);
    }
}

Controller.prototype.FinishedPageCallback = function () {
    if (existingMaintenanceTool) {
        const finishedPage = gui.currentPageWidget();
        if (maintenanceToolStatus == 0) finishedPage.MessageLabel.text = `Operation completed.`;
        if (maintenanceToolStatus == 1) finishedPage.MessageLabel.text = `Operation failed.`;
        if (maintenanceToolStatus == 3) finishedPage.MessageLabel.text = `Operation canceled.`;
    }
}

function getConfigDir() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");
    if (systemInfo.productType === "windows") {
        const roaming = installer.fromNativeSeparators(QDesktopServices.storageLocation(QDesktopServices.AppDataLocation));
        const roamingSlash = roaming.lastIndexOf("/");
        const configDir = roaming.slice(0, roamingSlash) + `/${publisher}/${productName}`;
        return installer.toNativeSeparators(configDir);
    }

    if (systemInfo.productType === "macos") {
        const configDir = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;
        return configDir;
    }

    const configDir = `${QDesktopServices.storageLocation(QDesktopServices.ConfigLocation)}/${publisher}/${productName}`;
    return configDir;
}

function getExistingInstall() {
    const configDir = getConfigDir();
    console.log(configDir);
    const basePathsFilePath = installer.toNativeSeparators(`${configDir}/basepaths.lua`);
    console.log(basePathsFilePath);
    const basePaths = installer.readFile(basePathsFilePath, "UTF-8");
    console.log(basePaths);

    if (basePaths.length === 0) return null;
    // 1. Strip out Lua block comments --[[ ... ]] so we do not match dead code
    let cleanContent = basePaths.replace(/--\[\[[\s\S]*?\]\]/g, "");

    // 2. Strip out single line comments -- ...
    cleanContent = basePaths.replace(/--.*$/gm, "");

    // 3. Regex matching the Lua standard for strings:
    // Pattern 1: "..." or '...' using (["'])(.*?)\1
    // Pattern 2: [[...]] using \[\[([\s\S]*?)\]\]
    let regex = /RootInstallDir\s*=\s*(?:(["'])(.*?)\1|\[\[([\s\S]*?)\]\])/g;
    let match;


    // Loop through all matches in the file string
    while ((match = regex.exec(cleanContent)) !== null) {
        // If it matched a quoted string, the path is in match[2]
        // If it matched a Lua long bracket [[ ]], the path is in match[3]
        let extractedPath = match[2] || match[3];

        console.log("Extracted Lua RootInstallDir: " + extractedPath);
        if (extractedPath.length > 0) {
            let maintenanceToolName = installer.value("MaintenanceToolName");
            if (systemInfo.productType === "windows") maintenanceToolName += ".exe";
            if (systemInfo.productType === "macos") maintenanceToolName += ".dmg";
            const maintenanceTool = installer.findPath(maintenanceToolName, [extractedPath]);
            if (maintenanceTool.length > 0) {
                console.log(`Found Maintenance Tool at ${maintenanceTool}`);
                return maintenanceTool;
            }
        }
    }
    return null;
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

function checkImpactoDesktopInstall() {
    const componentInstaller = installer.componentByName("com.committeeofzero.installer");

    if (componentInstaller) {
        const errors = [];

        const impactoGroup = installer.componentByName("com.committeeofzero.impacto");

        if (!componentIsSelected(impactoGroup)) {
            errors.push(
                "Please select an Impacto component."
            );
        }
        const pageTargetDesktop = gui.pageWidgetByObjectName("DynamicTargetWidget");
        const componentImpactoWin = installer.componentByName("com.committeeofzero.impacto.windows");
        const componentImpactoLin = installer.componentByName("com.committeeofzero.impacto.linux");
        const componentImpactoMacArm = installer.componentByName("com.committeeofzero.impacto.macos_arm64");
        const componentImpactoMacX64 = installer.componentByName("com.committeeofzero.impacto.macos_x64");

        const requestDesktopInstall =
            componentImpactoWin?.installationRequested() ||
            componentImpactoLin?.installationRequested() ||
            componentImpactoMacArm?.installationRequested() ||
            componentImpactoMacX64?.installationRequested();
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
    }
}

function addCclccPs4AssetsInstallPage() {
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if (componentCclccPs4Assets) {
        const pageCclccPs4Assets = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");
        if (componentCclccPs4Assets.installationRequested()) {
            if (!pageCclccPs4Assets) {
                installer.addWizardPage(componentCclccPs4Assets, "PathPage_CCLCC_PS4", QInstaller.ReadyForInstallation);
            }
        } else {
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
        } else {
            installer.removeWizardPage(componentChlccPs3Assets, "PathPage_CHLCC_PS3");
        }
    }
}

function validateSelection() {

    // Desktop path selection page
    checkImpactoDesktopInstall();

    addCclccPs4AssetsInstallPage();
    addChlccPs3AssetsInstallPage();
}
