const cclccName = "CHAOS;CHILD Love Chu☆Chu!!";
const chlccName = "CHAOS;HEAD Love Chu☆Chu!";

function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function() {
    if (systemInfo.productType != "macos" || systemInfo.currentCpuArchitecture !== "x86_64") {
        component.setValue("Virtual", "true");

        installer?.recalculateAllComponents();
    }
}

Component.prototype.createOperations = function () {
  component.createOperations();
    moveBundle();
    prepConfigFilesMac();

    if(installer.value("CreateDesktopShortcut") === "1") installDesktopShortcuts();
};

function installDesktopShortcuts() {
    console.log("Installing Desktop Shortcuts...");
    const homeDir = installer.value("HomeDir");
    createShortcuts(`${homeDir}/Desktop`, false)
}

function createShortcuts(destFolder, uninstallerShortcut) {
    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if(componentChlccPs3Assets.installationRequested()) {
      const name = `${chlccName} (PS3)`;
      console.log(`Installing Shortcut for CHLCC PS3 to ${destFolder}`);
      createAppBundleShortcut(destFolder, name, "chlcc.ps3", "chlcc");
    }

    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if(componentCclccPs4Assets.installationRequested()) {
      const name = `${cclccName} (PS4)`;
      console.log(`Installing Shortcut for CCLCC PS4 to ${destFolder}`);
      createAppBundleShortcut(destFolder, name, "cclcc.ps4", "cclcc");
    }

    if(uninstallerShortcut) {
        // component.addOperation("CreateShortcut",
        //     "@TargetDir@/@MaintenanceToolName@.exe",
        //     `${destFolder}/Uninstall Impacto.lnk`,
        //     "workingDirectory=@TargetDir@",
        //     "description=Launch the Impacto Updater/Uninstaller"
        // );
    }
}

function removeQuarantine(path) {
  component.addOperation("Execute", "xattr", "-rd", "com.apple.quarantine", path);
}

function createAppBundleShortcut(destFolder, name, shortAppName, shortName) {
    const launcherApp = `${destFolder}/${name}.app`;
    const launcherBin = launcherApp + "/Contents/MacOS";
    const launcherRes = launcherApp + "/Contents/Resources";

    component.addOperation("Mkdir", launcherApp);
    component.addOperation("Mkdir", launcherBin);
    component.addOperation("Mkdir", launcherRes);

    const iconPath = `${installer.value("TargetDir")}/Impacto.app/Contents/Resources/games/${shortName}/icondata/icon.png`;
    const iconsetPath = `${launcherRes}/AppIcon.iconset`;
    const icnsPath = `${launcherRes}/AppIcon.icns`;

    const infoPlist =
              '<?xml version="1.0" encoding="UTF-8"?>\n' +
              '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n' +
              '<plist version="1.0">\n<dict>\n' +
              `  <key>CFBundleExecutable</key><string>${name}</string>\n` +
              `  <key>CFBundleIdentifier</key><string>com.committeeofzero.${shortAppName}</string>\n` +
              `  <key>CFBundleName</key><string>${name}</string>\n` +
              '  <key>CFBundlePackageType</key><string>APPL</string>\n' +
              '  <key>CFBundleShortVersionString</key><string>1.0</string>\n' +
              '  <key>CFBundleIconFile</key><string>AppIcon</string>\n' +
              '</dict>\n</plist>\n';

    component.addOperation("AppendFile", launcherApp + "/Contents/Info.plist", infoPlist);

    const script = '#!/bin/bash\n' +
      `exec "@TargetDir@/Impacto.app/Contents/MacOS/Impacto" -g ${shortName}\n`;

    component.addOperation("AppendFile", launcherBin + `/${name}`, script);
    component.addOperation("Execute", "chmod", "+x", launcherBin + `/${name}`);

    component.addOperation("Mkdir", iconsetPath);

    const iconGenScript = `
    export TMPDIR=/tmp
    sips -z 16 16 "${iconPath}" --out "${iconsetPath}/icon_16x16.png"
    sips -z 32 32 "${iconPath}" --out "${iconsetPath}/icon_16x16@2x.png"
    sips -z 32 32 "${iconPath}" --out "${iconsetPath}/icon_32x32.png"
    sips -z 64 64 "${iconPath}" --out "${iconsetPath}/icon_32x32@2x.png"
    sips -z 128 128 "${iconPath}" --out "${iconsetPath}/icon_128x128.png"
    sips -z 256 256 "${iconPath}" --out "${iconsetPath}/icon_128x128@2x.png"
    sips -z 256 256 "${iconPath}" --out "${iconsetPath}/icon_256x256.png"
    sips -z 512 512 "${iconPath}" --out "${iconsetPath}/icon_256x256@2x.png"
    sips -z 512 512 "${iconPath}" --out "${iconsetPath}/icon_512x512.png"
    sips -z 1024 1024 "${iconPath}" --out "${iconsetPath}/icon_512x512@2x.png"
    iconutil -c icns "${iconsetPath}" -o "${icnsPath}"
    `;
    component.addOperation("Execute", "sh", "-c", iconGenScript);
    component.addOperation("Rmdir", iconsetPath, "FORCE");
    component.addOperation("Execute", "touch", launcherApp);

    removeQuarantine(launcherApp);
}


function moveBundle() {
    component.addOperation("Mkdir", "@TargetDir@/Impacto.app");
    component.addOperation("CopyDirectory", "@TargetDir@/impacto/Impacto.app", "@TargetDir@/Impacto.app");
    component.addOperation("Rmdir", "@TargetDir@/impacto/Impacto.app", "FORCE", "UNDOOPERATION", "");
}


function prepConfigFilesMac() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    // ~/Library/Application Support/Committee of Zero/Impacto
    const dataDir = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;
    const configDir = dataDir;

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
