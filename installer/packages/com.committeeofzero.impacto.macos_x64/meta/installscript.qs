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

  const organization = installer.value("Publisher");
  const application = installer.value("Name");
  const isUpdater = installer.isUpdater();
  let createStartMenuShortcut;
  let createDesktopShortcut;

  if (isUpdater) {
    const startMenuState = installer.readGlobalConfig(organization,application,"CreateStartMenuShortcut","");
    const desktopState = installer.readGlobalConfig(organization,application,"CreateDesktopShortcut","");
    createStartMenuShortcut =
      startMenuState === ""
        ? hasMacShortcut(installer.value("TargetDir"))
        : startMenuState === "1";
    createDesktopShortcut =
      desktopState === "" ? hasMacDesktopItem() : desktopState === "1";
  } else {
    createStartMenuShortcut =
      installer.value("CreateStartMenuShortcut") === "1";
    createDesktopShortcut = installer.value("CreateDesktopShortcut") === "1";
  }

  component.addOperation( "GlobalConfig",organization,application,"CreateStartMenuShortcut",createStartMenuShortcut ? "1" : "0","UNDOOPERATION","");
  component.addOperation("GlobalConfig", organization, application, "CreateDesktopShortcut", createDesktopShortcut ? "1" : "0", "UNDOOPERATION", "");

  if (createStartMenuShortcut) installStartMenuShortcuts();
  if (createDesktopShortcut) installDesktopShortcuts(createStartMenuShortcut);
};

function hasMacShortcut(destFolder) {
  return (
    installer.fileExists(`${destFolder}/${chlccName} (PS3).app`) ||
    installer.fileExists(`${destFolder}/${cclccName} (PS4).app`)
  );
}

function hasMacDesktopItem() {
  const destFolder = installer.environmentVariable("HOME") + "/Desktop";
  return (
    installer.fileExists(`${destFolder}/${chlccName} (PS3)`) ||
    installer.fileExists(`${destFolder}/${cclccName} (PS4)`) ||
    hasMacShortcut(destFolder)
  );
}

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
  const originalFolder = installer.value("TargetDir");

  if (componentIsSelectedForInstallation(componentChlccPs3Assets, "chlcc")) {
    const name = `${chlccName} (PS3)`;
    const originalPath = installer.toNativeSeparators(`${originalFolder}/${name}.app`);
    const targetPath = `${destFolder}/${name}`;
    console.log(`Creating alias for CHLCC PS3 from ${originalPath} to ${targetPath}`);
    createAppBundleAlias(originalPath, targetPath);
  }

  const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
  if (componentIsSelectedForInstallation(componentCclccPs4Assets, "cclcc")) {
    const name = `${cclccName} (PS4)`;
    const originalPath = installer.toNativeSeparators(`${originalFolder}/${name}.app`);
    const targetPath = `${destFolder}/${name}`;
    console.log(`Creating alias for CCLCC PS4 from "${originalPath}" to "${targetPath}"`);
    createAppBundleAlias(originalPath, targetPath);
  }
}

function createAppBundleAlias(originalPath, targetPath) {
  component.addOperation("Execute", "ln", "-sfn", originalPath, targetPath);
  component.registerPathForUninstallation(targetPath);
}

function componentIsSelectedForInstallation(assetComponent, gameDataDirectory) {
  const gameDataPath = installer.toNativeSeparators(
    `${installer.value("TargetDirGamedata")}/${gameDataDirectory}`,
  );

  if (installer.isUpdater()) {
    return installer.fileExists(gameDataPath);
  }
  if (!assetComponent) return false;
  if (assetComponent.uninstallationRequested()) return false;

  return (
    assetComponent.isInstalled() ||
    assetComponent.installationRequested() ||
    (installer.isPackageManager() && installer.fileExists(gameDataPath))
  );
}

function createShortcuts(destFolder) {
    const componentChlccPs3Assets = installer.componentByName("com.committeeofzero.chlcc.ps3.assets");
    if(componentIsSelectedForInstallation(componentChlccPs3Assets, "chlcc")) {
      const name = `${chlccName} (PS3)`;
      console.log(`Installing Shortcut for CHLCC PS3 to ${destFolder}`);
      createAppBundleShortcut(destFolder, name, "chlcc.ps3", "chlcc");
    }

    const componentCclccPs4Assets = installer.componentByName("com.committeeofzero.cclcc.ps4.assets");
    if(componentIsSelectedForInstallation(componentCclccPs4Assets, "cclcc")) {
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

    component.addOperation("Mkdir", launcherApp, "UNDOOPERATION", "");
    component.addOperation("Mkdir", launcherBin, "UNDOOPERATION", "");
    component.addOperation("Mkdir", launcherRes, "UNDOOPERATION", "");
    component.registerPathForUninstallation(launcherApp, true);

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
              '  <key>LSApplicationCategoryType</key><string>public.app-category.games</string>\n' +
              '  <key>CFBundleShortVersionString</key><string>1.0</string>\n' +
              '  <key>CFBundleIconFile</key><string>AppIcon</string>\n' +
              '</dict>\n</plist>\n';

    component.addOperation("AppendFile", launcherApp + "/Contents/Info.plist", infoPlist, "UNDOOPERATION", "");

    const script = '#!/bin/bash\n' +
      `exec /usr/bin/open "@TargetDir@/Impacto.app" --args -g ${shortName}\n`;

    const launcherExecutable = launcherBin + `/${name}`;
    if (installer.fileExists(launcherExecutable)) {
        component.addOperation("Delete", launcherExecutable, "UNDOOPERATION", "");
    }
    component.addOperation("AppendFile", launcherExecutable, script, "UNDOOPERATION", "");
    component.addOperation("Execute", "chmod", "+x", launcherBin + `/${name}`);
    component.addOperation("Copy", iconPath, icnsPath, "UNDOOPERATION", "");
    // "final touch" to update icon
    component.addOperation("Execute", "touch", launcherApp);

    removeQuarantine(launcherApp);
}


function moveBundle() {
    component.addOperation("Mkdir", "@TargetDir@/Impacto.app");
    component.addOperation("CopyDirectory",
        "@TargetDir@/impacto/Impacto.app",
        "@TargetDir@/Impacto.app",
        "UNDOOPERATION", "",
    );
    component.registerPathForUninstallation("@TargetDir@/Impacto.app", true);
    removeQuarantine("@TargetDir@/Impacto.app");
    component.addOperation("Rmdir", "@TargetDir@/impacto/Impacto.app", "FORCE", "UNDOOPERATION", "");
}


function prepConfigFilesMac() {
    const productName = installer.value("Name");
    const publisher = installer.value("Publisher");

    // ~/Library/Application Support/Committee of Zero/Impacto
    const impactoDir = `${QDesktopServices.storageLocation(QDesktopServices.GenericDataLocation)}/${publisher}/${productName}`;

    const isConfigDirSameAsTargetDir = installer.value("TargetDir") === impactoDir;
    if (!isConfigDirSameAsTargetDir) component.addOperation("Mkdir", impactoDir);

    const gameSavesFolder = `${impactoDir}/saves`;
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

    component.addOperation("Move", "@TargetDir@/impacto/basepaths.lua", impactoDir + "/basepaths.lua", "UNDOOPERATION", "");
    component.addOperation("Move", "@TargetDir@/impacto/gamedefinitions.lua", impactoDir + "/gamedefinitions.lua", "UNDOOPERATION", "");
    component.addOperation("Rmdir", "@TargetDir@/impacto","FORCE",);

    // Update basepaths.lua with the platform/user provided paths
    component.addOperation("Replace", impactoDir + "/basepaths.lua", "\"./\"", `"${installer.value("TargetDir")}"`, "string");
    component.addOperation("Replace", impactoDir + "/basepaths.lua", "./gamedata", installer.value("TargetDirGamedata"), "string");
    component.addOperation("Replace", impactoDir + "/basepaths.lua", "./profiles", installer.value("TargetDirProfiles"), "string");
    component.addOperation("Replace", impactoDir + "/basepaths.lua", "./patches", installer.value("TargetDirPatches"), "string");
    component.addOperation("Replace", impactoDir + "/basepaths.lua", "./saves", gameSavesFolder, "string");
}
