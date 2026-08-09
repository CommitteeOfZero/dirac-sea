function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function () {
    if (systemInfo.kernelType != "linux") {
        component.setValue("Virtual", "true");

        installer?.recalculateAllComponents();

    }
}

Component.prototype.createOperations = function () {
    component.createOperations();
    prepConfigFilesLin();
    if (installer.value("CreateStartMenuShortcut") === "1") installStartMenuShortcuts();
    if (installer.value("CreateDesktopShortcut") === "1") installDesktopShortcuts();
};

function createShortcuts(destinationFolder, uninstallerShortcut) {
    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    const baseDir = destinationFolder.length === 0? "": `${destinationFolder}/`;
    if (componentCclccPs4Assets.installationRequested()) {
        const desktopEntryContents = [
            "Type=Application",
            "Terminal=false",
            `Exec="${installer.value("TargetDir")}/impacto/impacto" -g cclcc`,
            `Path=${installer.value("TargetDir")}/impacto`,
            `Name=CHAOS\;CHILD Love Chu☆Chu!! (PS4)`,
            "Comment=Launch CHAOS\;CHILD Love Chu☆Chu!! (PS4)",
            `Icon=${installer.value("TargetDir")}/impacto/games/cclcc/icondata/icon.png`,
            "Categories=Game;",
        ].join("\n")
        const name = "CHAOS;CHILD Love Chu☆Chu!! (PS4)";
        component.addOperation("CreateDesktopEntry",
            baseDir + `${name}.desktop`,
            desktopEntryContents);
    }

    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if (componentChlccPs3Assets.installationRequested()) {
        const name = "CHAOS;HEAD Love Chu☆Chu! (PS3)";
        const desktopEntryContents = [
            "Type=Application",
            "Terminal=false",
            `Exec="${installer.value("TargetDir")}/impacto/impacto" -g chlcc`,
            `Path=${installer.value("TargetDir")}/impacto`,
            `Name=CHAOS\;HEAD Love Chu☆Chu! (PS3)`,
            "Comment=Launch CHAOS\;HEAD Love Chu☆Chu! (PS3)",
            `Icon=${installer.value("TargetDir")}/impacto/games/chlcc/icondata/icon.png`,
            "Categories=Game;",
        ].join("\n")
        component.addOperation("CreateDesktopEntry",
            baseDir + `${name}.desktop`,
            desktopEntryContents);
    }

    if (uninstallerShortcut) {
        const uninstallerName = "Uninstall Impacto";
        const uninstallerDesktopEntryContents = [
            "Type=Application",
            "Terminal=false",
            `Exec="${installer.value("TargetDir")}/${installer.value("MaintenanceToolName")}"`,
            `Path=${installer.value("TargetDir")}`,
            `Name=${uninstallerName}`,
            "Comment=Uninstall Impacto",
            "NotShowIn=GNOME;KDE;XFCE;MATE;X-Cinnamon;Unity;Pantheon;LXDE;LXQt;",
            "Categories=Settings;PackageManager;"
        ].join("\n")
        component.addOperation("CreateDesktopEntry",
            baseDir + `${uninstallerName}.desktop`,
            uninstallerDesktopEntryContents);
    }
}

function installStartMenuShortcuts() {
    console.log("Installing Start Menu Shortcuts...");
    // Defaults to $XDG_DATA_HOME/applications, which generally shows in start menus
    createShortcuts("", true);

}

function installDesktopShortcuts() {
    console.log("Installing Desktop Shortcuts...");
    const dest = `${installer.value("HomeDir")}/Desktop`;
    if (installer.fileExists(dest)) {
        createShortcuts(dest, false);
    }
}


function prepConfigFilesLin() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    // ~/.config/Committee of Zero/Impacto
    const configDir = `${QDesktopServices.storageLocation(QDesktopServices.ConfigLocation)}/${publisher}/${productName}`;

    // ~/.local/share/Committee of Zero/Impacto
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
    component.registerPathForUninstallation("@TargetDirProfiles@");
    component.addOperation(
        "Execute",
        "rm",
        "-rf",
        installer.value("TargetDir") + "/impacto/profiles",
    );

    component.addOperation("Move", "@TargetDir@/impacto/basepaths.lua", configDir + "/basepaths.lua");
    component.addOperation("Move", "@TargetDir@/impacto/gamedefinitions.lua", configDir + "/gamedefinitions.lua");
    component.addOperation("Move", "@TargetDir@/impacto/userconfig.lua", configDir + "/userconfig.lua");

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", configDir + "/basepaths.lua", "\"./\"", `"${installer.value("TargetDir")}"`, "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./gamedata", installer.value("TargetDirGamedata"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./profiles", installer.value("TargetDirProfiles"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./patches", installer.value("TargetDirPatches"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./saves", gameSavesFolder, "string");
}