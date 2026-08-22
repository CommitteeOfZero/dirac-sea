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

    const createStartMenuShortcut = installer.value("CreateStartMenuShortcut") === "1";
    const createDesktopShortcut = installer.value("CreateDesktopShortcut") === "1";

    if (createStartMenuShortcut) installStartMenuShortcuts();
    if (createDesktopShortcut) installDesktopShortcuts(createStartMenuShortcut);
};

function installStartMenuShortcuts() {
  const targetDir = installer.value("TargetDir");
  createShortcuts(targetDir)
}

function installDesktopShortcuts(createdStartupMenuShortcut) {
    console.log("Installing Desktop Shortcuts...");
    const destFolder = installer.environmentVariable("HOME") + "/Desktop";
    if (createdStartupMenuShortcut) {
      createAliases(destFolder)
    } else {
      createShortcuts(destFolder);
    }
}

function createAliases(destFolder) {
  const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
  const originalFolder = "@TargetDir@";

  if (componentChlccPs3Assets.installationRequested()) {
    const name = `${chlccName} (PS3)`;
    const originalPath = `${originalFolder}/${name}.app`;
    const targetPath = `${destFolder}/${name}`;
    console.log(`Creating alias for CHLCC PS3 from ${originalPath} to ${targetPath}`);
    creteAppBundleAlias(originalPath, targetPath);
  }

  const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
  if (componentCclccPs4Assets.installationRequested()) {
    const name = `${chlccName} (PS4)`;
    const originalPath = `${originalFolder}/${name}.app`;
    const targetPath = `${destFolder}/${name}`;
    console.log(`Creating alias for CCLCC PS4 from "${originalPath}" to "${targetPath}"`);
    creteAppBundleAlias(originalPath, targetPath);
  }
}


function creteAppBundleAlias(originalPath, targetPath) {
  component.addOperation("Execute", "ln", "-s", originalPath, targetPath);
}

function createShortcuts(destFolder) {
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

    const iconPath = `${installer.value("TargetDir")}/Impacto.app/Contents/Resources/resources/${shortName}/icondata/icon.icns`;
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
    component.addOperation("Copy", iconPath, icnsPath);
    // "final touch" to update icon
    component.addOperation("Execute", "touch", launcherApp);

    removeQuarantine(launcherApp);
}


function moveBundle() {
    component.addOperation("Mkdir", "@TargetDir@/Impacto.app");
    component.addOperation("CopyDirectory", "@TargetDir@/impacto/Impacto.app", "@TargetDir@/Impacto.app");
    removeQuarantine("@TargetDir@/Impacto.app");
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
    component.addOperation("Rmdir", "@TargetDir@/impacto","FORCE",);

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", configDir + "/basepaths.lua", "\"./\"", `"${installer.value("TargetDir")}"`, "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./gamedata", installer.value("TargetDirGamedata"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./profiles", installer.value("TargetDirProfiles"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./patches", installer.value("TargetDirPatches"), "string");
    component.addOperation("Replace", configDir + "/basepaths.lua", "./saves", gameSavesFolder, "string");
}
