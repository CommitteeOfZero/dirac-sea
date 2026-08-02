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

function installStartMenuShortcuts() {
    console.log("Installing Start Menu Shortcuts...");
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");

    if(componentCclccPs4Assets.installationRequested()) {
        console.log(`Installing Start Menu Shortcut for CCLCC PS4 Assets to ${installer.value("StartMenuDir")}`);
        component.addOperation("CreateShortcut", 
            "@TargetDir@/impacto/impacto.exe", 
            "@StartMenuDir@/Chaos;Child Love Chu Chu (PS4).lnk",
            "-g cclcc",
            "workingDirectory=@TargetDir@/impacto", 
            "iconPath=@TargetDir@/impacto/games/cclcc/icondata/icon.ico",
            "description=Launch Chaos;Child Love Chu Chu (PS4)");
    }

    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if(componentChlccPs3Assets.installationRequested()) {
        console.log(`Installing Start Menu Shortcut for CHLCC PS3 Assets to ${installer.value("StartMenuDir")}`);
        component.addOperation("CreateShortcut", 
            "@TargetDir@/impacto/impacto.exe", 
            "@StartMenuDir@/Chaos;Head Love Chu Chu (PS3).lnk",
            "-g chlcc",
            "workingDirectory=@TargetDir@/impacto",
            "iconPath=@TargetDir@/impacto/games/chlcc/icondata/icon.ico",
            "description=Launch Chaos;Head Love Chu Chu (PS3)");
    }

    component.addOperation("CreateShortcut", "@TargetDir@/@MaintenanceToolName@.exe", "@StartMenuDir@/Uninstaller Impacto.lnk",
        "workingDirectory=@TargetDir@", "description=Launch the Impacto Updater/Uninstaller");
}

function installDesktopShortcuts() {
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");

    if(componentCclccPs4Assets.installationRequested()) {
        console.log(`Installing Desktop Shortcut for CCLCC PS4 Assets to ${installer.value("DesktopDir")}`);
        component.addOperation("CreateShortcut", "@TargetDir@/impacto/impacto.exe -g cclcc", "@DesktopDir@/Chaos;Child Love Chu Chu (PS4).lnk",
            "workingDirectory=@TargetDir@/impacto", "iconPath=%SystemRoot%/system32/SHELL32.dll",
            "iconId=2", "description=Launch Chaos;Child Love Chu Chu (PS4)");
    }

    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if(componentChlccPs3Assets.installationRequested()) {
        console.log(`Installing Desktop Shortcut for CHLCC PS3 Assets to ${installer.value("DesktopDir")}`);
        component.addOperation("CreateShortcut", "@TargetDir@/impacto/impacto.exe -g chlcc", "@DesktopDir@/Chaos;Head Love Chu Chu (PS3).lnk",
            "workingDirectory=@TargetDir@/impacto", "iconPath=%SystemRoot%/system32/SHELL32.dll",
            "iconId=2", "description=Launch Chaos;Head Love Chu Chu (PS3)");
    }
}


function prepConfigFilesWin() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");


    const roaming = installer.fromNativeSeparators(QDesktopServices.storageLocation(QDesktopServices.AppDataLocation));
    const roamingSlash = roaming.lastIndexOf("/");
    
    const configDir = roaming.slice(0, roamingSlash) + `/${publisher}/${productName}`;
    const localAppData = QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation) + `/${publisher}/${productName}`;
    const gameSavesFolder = QDesktopServices.storageLocation(QDesktopServices.DocumentsLocation) + `/My Games/${publisher}/${productName}`;

    const isAppdataSameAsTargetDir = installer.toNativeSeparators(installer.value("TargetDir")) === installer.toNativeSeparators(localAppData);
    const isConfigDirSameAsTargetDir = installer.toNativeSeparators(installer.value("TargetDir")) === installer.toNativeSeparators(configDir);

    if (!isConfigDirSameAsTargetDir) component.addOperation("Mkdir", configDir);
    if (!isAppdataSameAsTargetDir) component.addOperation("Mkdir", localAppData);
    component.addOperation("Mkdir", installer.value("TargetDirGamedata"));
    component.addOperation("Mkdir", installer.value("TargetDirPatches"));
    component.addOperation("Mkdir", gameSavesFolder, "UNDOOPERATION", ""); // Leave saves on uninstall

    // Copy profiles to LocalAppData and remove from install dir
    component.addOperation("Mkdir", localAppData + "/profiles");
    component.addOperation("CopyDirectory",
        "@TargetDir@/impacto/profiles",
        localAppData + "/profiles",
        "UNDOOPERATION", "",
    );
    component.registerPathForUninstallation(localAppData + "/profiles");
    component.addOperation(
        "Execute",
        "cmd",
        "/c",
        "rmdir",
        "/s",
        "/q",
        installer.toNativeSeparators(installer.value("TargetDir") + "\\impacto\\profiles"),
    );

    component.addOperation("Copy", "@TargetDir@/impacto/basepaths.lua", configDir + "/basepaths.lua");
    component.addOperation("Copy", "@TargetDir@/impacto/gamedefinitions.lua", configDir + "/gamedefinitions.lua");
    component.addOperation("Copy", "@TargetDir@/impacto/userconfig.lua", configDir + "/userconfig.lua");

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", configDir + "/basepaths.lua", "./gamedata", installer.fromNativeSeparators(installer.value("TargetDirGamedata")), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./profiles", installer.fromNativeSeparators(localAppData + "/profiles"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./patches", installer.fromNativeSeparators(installer.value("TargetDirPatches")), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./saves", installer.fromNativeSeparators(gameSavesFolder), "string");
}