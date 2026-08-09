const cclccName = "CHAOS;CHILD Love Chu☆Chu!!"
const chlccName = "CHAOS;HEAD Love Chu☆Chu!"

function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function () {
    if (systemInfo.productType != "windows") {
        component.setValue("Virtual", "true");

        installer?.recalculateAllComponents();

    }
}

Component.prototype.createOperations = function () {
    component.createOperations();
    prepConfigFilesWin();
    if(installer.value("CreateStartMenuShortcut") === "1") installStartMenuShortcuts();
    if(installer.value("CreateDesktopShortcut") === "1") installDesktopShortcuts();
};

function createShortcuts(destFolder, uninstallerShortcut) {
     const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if(componentChlccPs3Assets.installationRequested()) {
        const name = `${chlccName} (PS3)`;
        console.log(`Installing Shortcut for CHLCC PS3 to ${destFolder}`);
        component.addOperation("CreateShortcut", 
            "@TargetDir@/impacto/impacto.exe", 
            `${destFolder}/${name}.lnk`,
            "-g chlcc",
            "workingDirectory=@TargetDir@/impacto",
            "iconPath=@TargetDir@/impacto/games/chlcc/icondata/icon.ico",
            `description=Launch ${name}`);
    }

    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if(componentCclccPs4Assets.installationRequested()) {
        console.log(`Installing Shortcut for CCLCC PS4 to ${destFolder}`);
        const name = `${cclccName} (PS4)`;
        component.addOperation("CreateShortcut", 
            "@TargetDir@/impacto/impacto.exe", 
            `${destFolder}/${name}.lnk`,
            "-g cclcc",
            "workingDirectory=@TargetDir@/impacto", 
            "iconPath=@TargetDir@/impacto/games/cclcc/icondata/icon.ico",
            `description=Launch ${name}`);
    }

    if(uninstallerShortcut) {
        component.addOperation("CreateShortcut", 
            "@TargetDir@/@MaintenanceToolName@.exe", 
            `${destFolder}/Uninstall Impacto.lnk`,
            "workingDirectory=@TargetDir@", 
            "description=Launch the Impacto Updater/Uninstaller"
        );
    }
}

function installStartMenuShortcuts() {
    console.log("Installing Start Menu Shortcuts...");
    createShortcuts("@StartMenuDir@", true)
}

function installDesktopShortcuts() {
    console.log("Installing Desktop Shortcuts...");
    createShortcuts("@DesktopDir@", false)
}


function prepConfigFilesWin() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");


    const roaming = installer.fromNativeSeparators(QDesktopServices.storageLocation(QDesktopServices.AppDataLocation));
    const roamingSlash = roaming.lastIndexOf("/");
    
    const configDir = roaming.slice(0, roamingSlash) + `/${publisher}/${productName}`;
    const gameSavesFolder = QDesktopServices.storageLocation(QDesktopServices.DocumentsLocation) + `/My Games/${publisher}/${productName}`;

    const isConfigDirSameAsTargetDir = installer.toNativeSeparators(installer.value("TargetDir")) === installer.toNativeSeparators(configDir);

    if (!isConfigDirSameAsTargetDir) component.addOperation("Mkdir", configDir);

    component.addOperation("Mkdir", gameSavesFolder, "UNDOOPERATION", ""); // Leave saves on uninstall

    // Copy profiles to LocalAppData and remove from install dir
    component.addOperation("Mkdir", "@TargetDirProfiles@");
    component.addOperation("CopyDirectory",
        "@TargetDir@/impacto/profiles",
        "@TargetDirProfiles@",
        "UNDOOPERATION", "",
    );
    component.registerPathForUninstallation(installer.fromNativeSeparators(installer.value("TargetDirProfiles")));
    component.addOperation(
        "Execute",
        "cmd",
        "/c",
        "rmdir",
        "/s",
        "/q",
        installer.toNativeSeparators(installer.value("TargetDir") + "\\impacto\\profiles"),
    );

    component.addOperation("Move", "@TargetDir@/impacto/basepaths.lua", configDir + "/basepaths.lua");
    component.addOperation("Move", "@TargetDir@/impacto/gamedefinitions.lua", configDir + "/gamedefinitions.lua");
    component.addOperation("Move", "@TargetDir@/impacto/userconfig.lua", configDir + "/userconfig.lua");

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", configDir + "/basepaths.lua", "\"./\"", `"${installer.fromNativeSeparators(installer.value("TargetDir"))}"`, "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./gamedata", installer.fromNativeSeparators(installer.value("TargetDirGamedata")), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./profiles", installer.fromNativeSeparators(installer.value("TargetDirProfiles"), "string"));
    component.addOperation("Replace", configDir + "/basepaths.lua", "./patches", installer.fromNativeSeparators(installer.value("TargetDirPatches")), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./saves", installer.fromNativeSeparators(gameSavesFolder), "string");
}