function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function() {
    if (systemInfo.productType != "windows") {
        component.setValue("Virtual", "true");
    
        installer?.recalculateAllComponents();

    }
}

Component.prototype.createOperations = function()
{
    component.createOperations();
    prepConfigFilesWin();
};

function prepConfigFilesWin() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    const configDir = QDesktopServices.storageLocation(QDesktopServices.GenericConfigLocation) + `/${publisher}/${productName}`;
    const localAppData = QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation) + `/${publisher}/${productName}`;
    const gameSavesFolder = QDesktopServices.storageLocation(QDesktopServices.DocumentsLocation) + `/My Games/${publisher}/${productName}`;

    const isAppdataSameAsTargetDir = installer.toNativeSeparators(installer.value("TargetDir")) === installer.toNativeSeparators(localAppData);
    const isConfigDirSameAsTargetDir = installer.toNativeSeparators(installer.value("TargetDir")) === installer.toNativeSeparators(configDir);

    if(!isConfigDirSameAsTargetDir) component.addOperation("Mkdir", configDir);
    if(!isAppdataSameAsTargetDir) component.addOperation("Mkdir", localAppData);
    component.addOperation("Mkdir", installer.value("TargetDirGamedata"));
    component.addOperation("Mkdir", installer.value("TargetDirPatches"));
    component.addOperation("Mkdir", gameSavesFolder, "UNDOOPERATION", ""); // Leave saves on uninstall
    
    // Copy profiles to LocalAppData and remove from install dir
    if(!isAppdataSameAsTargetDir) {
        component.addOperation("Mkdir", localAppData + "/profiles");
        component.addOperation("CopyDirectory", 
            "@TargetDir@/impacto/profiles",
            localAppData + "/profiles",
        );
        component.registerPathForUninstallation(localAppData + "/profiles");

        if(installer.value("ElevationRequired") === "1") {
            component.addElevatedOperation(
                "Execute",
                "cmd", 
                "/c",
                "rmdir",
                "/s",
                "/q",
                installer.toNativeSeparators(installer.value("TargetDir") + "\\impacto\\profiles"),
            );
        } else {
            component.addOperation(
                "Execute",
                "cmd", 
                "/c",
                "rmdir",
                "/s",
                "/q",
                installer.toNativeSeparators(installer.value("TargetDir") + "\\impacto\\profiles"),
            );
        }
    }


    if(!isConfigDirSameAsTargetDir) {
        component.addOperation("Copy", "@TargetDir@/impacto/basepaths.lua", configDir + "/basepaths.lua");
        component.addOperation("Copy", "@TargetDir@/impacto/gamedefinitions.lua", configDir + "/gamedefinitions.lua");
        component.addOperation("Copy", "@TargetDir@/impacto/userconfig.lua", configDir + "/userconfig.lua");
    }

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace",  configDir + "/basepaths.lua", "./gamedata",  installer.value("TargetDirGamedata"), "string");
    component.addOperation("Replace",  configDir + "/basepaths.lua", "./profiles",  localAppData + "/profiles", "string");
    component.addOperation("Replace",  configDir + "/basepaths.lua", "./patches",   installer.value("TargetDirPatches"), "string");
    component.addOperation("Replace",  configDir + "/basepaths.lua", "./saves",     gameSavesFolder, "string");
}