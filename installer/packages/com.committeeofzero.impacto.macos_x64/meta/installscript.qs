function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function() {
    if (systemInfo.productType != "macos" || systemInfo.currentCpuArchitecture !== "x64") {
        component.setValue("Virtual", "true");
    
        installer?.recalculateAllComponents();
    }
}

Component.prototype.createOperations = function () {
    component.createOperations();
    moveBundle();
    prepConfigFilesMac();
};

function moveBundle() {
    component.addOperation("CopyDirectory", "@TargetDir@/impacto/Impacto.app", "@TargetDir@/destination_folder");
    component.addOperation("Rmdir", "@TargetDir@/impacto/Impacto.app", "FORCE", "UNDOOPERATION", "");
}


function prepConfigFilesMac() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    // ~/Library/Preferences/Committee of Zero/Impacto
    const configDir = `${QDesktopServices.storageLocation(QDesktopServices.ConfigLocation)}/${publisher}/${productName}`;

    // ~/Library/Application Support/Committee of Zero/Impacto
    const dataDir = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;

    const isConfigDirSameAsTargetDir = installer.value("TargetDir") === configDir;
    if (!isConfigDirSameAsTargetDir) component.addOperation("Mkdir", configDir);

    const gameSavesFolder = `${dataDir}/saves`;
    component.addOperation("Mkdir", gameSavesFolder, "UNDOOPERATION", ""); // Leave saves on uninstall

    // Copy profiles to Data Dir and remove from install dir
    component.addOperation("Mkdir", "@TargetDirProfiles@");
    component.addOperation("CopyDirectory",
        "@TargetDir@/impacto/profiles",
        "@TargetDirProfiles@",
        "UNDOOPERATION", "",
    );
    component.addOperation("Rmdir",
        "@TargetDir@/impacto/profiles",
        "FORCE", "UNDOOPERATION", "",
    );
    component.registerPathForUninstallation("@TargetDirProfiles@");

    component.addOperation("Move", "@TargetDir@/impacto/basepaths.lua", configDir + "/basepaths.lua");
    component.addOperation("Move", "@TargetDir@/impacto/gamedefinitions.lua", configDir + "/gamedefinitions.lua");
    component.addOperation("Move", "@TargetDir@/impacto/userconfig.lua", configDir + "/userconfig.lua");
    component.addOperation("Rmdir", "@TargetDir@/impacto","FORCE",);

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", configDir + "/basepaths.lua", "\"./\"", `"${installer.value("TargetDir")}"`, "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./gamedata", installer.value("TargetDirGamedata"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./profiles", installer.value("TargetDirProfiles"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./patches", installer.value("TargetDirPatches"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./saves", gameSavesFolder, "string");
}