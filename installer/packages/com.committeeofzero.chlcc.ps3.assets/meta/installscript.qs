
let copyFiles = {};

const fileEntries = {
    "BG.CPK": "87C8C7C2EBBF5AB2F216383064AFED22B10D4421C443F14FE38232A38607E85F",
    "BGM.CPK": "2D6B112E2E83447D8595DB783B6C359565151571E8EC1F5C00038E92F838E139",
    "CHARA.CPK": "7DD171AC789C09DF080A4DCD3217076D8631DF4A126A2C8224A59BE04A68B0DA",
    "MASK.CPK": "87CF4CD2430C7BF5DE128AA58D34018CB506F320DC3C4157D1BB19A823B49CCD",
    "MOVIE.CPK": "0F32745D07F6FDFA47446DE8D2A232E9D1562052FE9F4AFC6A5DB8DF50E444EA",
    "SCRIPT.CPK": "3798A005E44A43AEC78295EBAE3B57763D50CF44EA61840080EB9DB16133B154",
    "SE.CPK": "5FE43B0F74EBEF4B4D67AC0EA690221BD9436774C3A3E2E7EC54C033843336B9",
    "SHADER.CPK": "E714F7AE10B05614F5E8F982F79F0EC4A2F4FACE96512DD1E74F5FE727177AC8",
    "SYSTEM.CPK": "90A41E9F884FF036597ADB251F499218F54B58B57CDD0E8FD602B30A4B1C2D8E",
    "VOICE.CPK": "9051E51A1EEDAE405D38E328DD8A6700A0AC9512A6C1BF4C25A86400307D434C",
}

function Component() {
    installer.wizardPageInsertionRequested.connect(this, Component.prototype.onWizardPageInsertionRequested);
    installer.wizardPageRemovalRequested.connect(this, Component.prototype.onWizardPageRemovalRequested);
}

Component.prototype.onWizardPageInsertionRequested = function (widget, page) {
    if (widget.objectName !== "PathPage_CHLCC_PS3") return;
    console.log("Setting up Path Selection Page for CHLCC PS3");
    widget.complete = false;
    widget.validateResult.setVisible(false);
    widget.errorLabel.setVisible(false);
    widget.validateButton.setEnabled(false);
    widget.browseButton.clicked.connect(this, Component.prototype.onBrowseButtonClicked);
    widget.pathLineEdit.textChanged.connect(this, Component.prototype.onPathChanged);
    widget.pathLineEdit.editingFinished.connect(this, Component.prototype.onPathEditingFinished);
    widget.validateButton.clicked.connect(this, Component.prototype.onValidate);
}

Component.prototype.onWizardPageRemovalRequested = function (widget) {
    if (widget.objectName !== "PathPage_CHLCC_PS3") return;
    console.log("Removing Path Selection Page for CHLCC PS3");
    widget.browseButton.clicked.disconnect(this, Component.prototype.onBrowseButtonClicked);
    widget.pathLineEdit.textChanged.disconnect(this, Component.prototype.onPathChanged);
    widget.pathLineEdit.editingFinished.disconnect(this, Component.prototype.onPathEditingFinished);
    widget.validateButton.clicked.disconnect(this, Component.prototype.onValidate);
}

function lineEditDirExists() {
    // this installer value is always up-to-date since it's set in `onPathChanged`
    // (so don't break that)
    const dirPath = installer.value("CHLCC-PS3-Assets-Path");
    return dirPath !== "" && installer.fileExists(dirPath);
}

// get rid of all the happy stuff that might be there from a previous verification/validation
function clearSuccessWindow() {
    console.log("clearing results ...");
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    page.complete = false;
    page.validateButton.setEnabled(false);
    page.validateResult.setVisible(false);
    page.validateLog.setPlainText("");
}

Component.prototype.onPathChanged = function (newPath) {
    clearSuccessWindow();
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    page.pathLineEdit.text = installer.toNativeSeparators(newPath);
    installer.setValue("CHLCC-PS3-Assets-Path", page.pathLineEdit.text);
    if (!lineEditDirExists()) {
        page.errorLabel.setVisible(true);
        page.errorLabel.text = "Please select a valid directory.";
        copyFiles = {};
        return;
    }
    page.errorLabel.setVisible(false);
    copyFiles = {};
}

function getWindowsHash(filePath) {
    const output = installer.execute("certutil", ["-hashfile", filePath, "SHA256"]);
    if (!output || output[1] !== 0) return null;

    return output[0].split("\n")[1].trim();
}

function getLinuxHash(filePath) {
    const output = installer.execute("sha256sum", [filePath]);
    if (!output || output[1] !== 0) return null;
    return output[0].split(" ")[0].trim();
}

function getMacHash(filePath) {
    const output = installer.execute("shasum", ["-a", "256", filePath]);
    if (!output || output[1] !== 0) return null;
    return output[0].split(" ")[0].trim();
}

// returns whether the hashing finished with a valid value
function hashFile(filePath) {
    if (systemInfo.productType === "windows") {
        return getWindowsHash(filePath);
    } else if (systemInfo.kernelType === "linux") {
        return getLinuxHash(filePath);
    } else if (systemInfo.productType === "macos") {
        return getMacHash(filePath);
    } else {
        return null;
    }
}

// one fell swoop
function logAndAppend(logWidget, msg) {
    console.log(msg);
    logWidget.append(msg);
    logWidget.repaint();
}

function validateFileHash(assetPath, expectedHash, logWidget) {
    const actualHash = hashFile(assetPath);

    if (actualHash === null) {
        logAndAppend(logWidget, `Failed to compute hash for file: ${assetPath}\n`);
        return false;
    }

    if (actualHash.toUpperCase() !== expectedHash.toUpperCase()) {
        logAndAppend(logWidget, `Hash mismatch for file: ${assetPath}`);
        logAndAppend(logWidget, `\tExpected: ${expectedHash}`);
        logAndAppend(logWidget, `\tActual: ${actualHash}\n`);
        return false;
    }

    logAndAppend(logWidget, `Hash for file ${assetPath} matches.\n`);
    return true;
}

// check if the selected directory has all files in `fileEntries`.
// does NOT perform hashing validation.
function validateSelectedDirectory() {
    clearSuccessWindow();
    const selectedPath = installer.value("CHLCC-PS3-Assets-Path");
    console.log(`validating selected path ${selectedPath} ...`);
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    copyFiles = {};

    const findAssetFile = (entryPath) => {
        const subdirs = ["", "/USRDIR", "/PS3_GAME/USRDIR"];

        for (const subdir of subdirs) {
            const resultPath = `${selectedPath}${subdir}/${entryPath}`;
            console.log(`Checking for "${resultPath}"...`);
            if (installer.fileExists(resultPath)) return resultPath;
        }
        return null;
    }

    logAndAppend(page.validateLog, "Checking for CHLCC PS3 Assets in directory: " + selectedPath + "\n");

    let hasErrors = false;
    const notFoundFiles = new Set(Object.keys(fileEntries));
    let fileSize = 0;
    for (const [assetFile, expectedHash] of Object.entries(fileEntries)) {
        const foundFile = findAssetFile(assetFile);
        if (!foundFile) continue;
        const actualAssetPath = installer.toNativeSeparators(foundFile);
        notFoundFiles.delete(assetFile);
        logAndAppend(page.validateLog, `Found file ${assetFile} at ${actualAssetPath}.`);

        copyFiles[assetFile] = installer.fromNativeSeparators(actualAssetPath);
        fileSize += installer.fileSize(actualAssetPath);
    }
    if (notFoundFiles.size > 0) {
        hasErrors = true;
        for (const missingFile of notFoundFiles) {
            logAndAppend(page.validateLog, `Missing file ${missingFile}.`);
        }
    } else {
        logAndAppend(page.validateLog, `Found all asset files.`);
    }


    page.validateResult.setVisible(true);
    if (hasErrors) {
        page.validateResult.text = "Some files are missing.";
        page.validateResult.styleSheet = "color: red;"
        page.complete = false;
    } else {
        page.validateResult.text = "All files accounted for!";
        page.validateResult.styleSheet = ""
        page.validateButton.setEnabled(true);
        page.complete = true;

        console.log(`Successfully found all ${Object.keys(copyFiles).length} files.`);
        console.log(`Uncompressed file size: ${fileSize}`);
        component.setValue("UncompressedSize", fileSize);
    }
}

Component.prototype.onValidate = function () {
    clearSuccessWindow();
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    page.validateResult.setVisible(true);
    page.validateResult.text = "Validating file hashes, this may take a while...";
    page.validateResult.styleSheet = "";
    // need to repaint here, otherwise the cleared results are queued until after the function
    // completes, which is pointless
    page.repaint();

    let hasErrors = false;
    let invalidFiles = [];

    for (const [assetFile, rawPath] of Object.entries(copyFiles)) {
        const filePath = installer.toNativeSeparators(rawPath);
        logAndAppend(page.validateLog, `Validating hash for file ${assetFile} ...`)
        if (!validateFileHash(filePath, fileEntries[assetFile], page.validateLog)) {
            hasErrors = true;
            invalidFiles.push(assetFile);
        }
    }

    if (hasErrors) {
        page.validateResult.text = "Validation failed.";
        page.validateResult.styleSheet = "color: red;"
        page.complete = false;
        logAndAppend(page.validateLog, `The following files failed validation: ${invalidFiles.join(', ')}`)
    } else {
        page.validateResult.text = "Validation successful!";
        page.validateResult.styleSheet = ""
        page.complete = true;
        logAndAppend(page.validateLog, "All file hashes successfully validated!");
    }
}

Component.prototype.onPathEditingFinished = function () {
    if (lineEditDirExists()) {
        validateSelectedDirectory();
    }
}

Component.prototype.onBrowseButtonClicked = function () {
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    if (page === null) return;

    const targetDirectory = page.pathLineEdit;
    const newTarget = QFileDialog.getExistingDirectory("Pick directory containing CHAOS;HEAD Love Chu☆Chu! PS3 Assets.", "", "AssetsDir_CHLCC_PS3");
    if (newTarget != "") {
        const selectedDirectory = installer.toNativeSeparators(newTarget);
        targetDirectory.text = selectedDirectory;
        console.log(`selected directory from file browser dialogue: ${selectedDirectory}`);
        installer.setValue("CHLCC-PS3-Assets-Path", selectedDirectory);
        validateSelectedDirectory();
    }

}

Component.prototype.createOperations = function () {
    const assetsPath = installer.value("CHLCC-PS3-Assets-Path");
    if (!assetsPath || assetsPath === "") {
        throw new Error("CHLCC PS3 Assets path is not set. Please select a valid directory.");
    }

    component.addOperation("Mkdir", "@TargetDirGamedata@/chlcc");
    for (const [outFile, srcFile] of Object.entries(copyFiles)) {
        const slash = outFile.lastIndexOf("/");
        if (slash !== -1) {
            const parentDir = outFile.slice(0, slash);
            component.addOperation("Mkdir", `@TargetDirGamedata@/chlcc/${parentDir}`);
        }
        component.addOperation("Copy", srcFile, `@TargetDirGamedata@/chlcc/${outFile}`);
    }
}
