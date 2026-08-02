
let copyFiles = {};

const fileEntries = {
    "BG.CPK": "87C8C7C2EBBF5AB2F216383064AFED22B10D4421C443F14FE38232A38607E85F",
    "BGM.CPK": "2D6B112E2E83447D8595DB783B6C359565151571E8EC1F5C00038E92F838E139",
    "CHARA.CPK": "7DD171AC789C09DF080A4DCD3217076D8631DF4A126A2C8224A59BE04A68B0DA",
    "EBOOT.BIN": "8F55F4027F75BA11FEC64532C026B4AEAED4320154027BC970EDC3C44E1BAF77",
    "MASK.CPK": "87CF4CD2430C7BF5DE128AA58D34018CB506F320DC3C4157D1BB19A823B49CCD",
    "MOVIE.CPK": "0F32745D07F6FDFA47446DE8D2A232E9D1562052FE9F4AFC6A5DB8DF50E444EA",
    "SCRIPT.CPK": "3798A005E44A43AEC78295EBAE3B57763D50CF44EA61840080EB9DB16133B154",
    "SE.CPK": "5FE43B0F74EBEF4B4D67AC0EA690221BD9436774C3A3E2E7EC54C033843336B9",
    "SHADER.CPK": "E714F7AE10B05614F5E8F982F79F0EC4A2F4FACE96512DD1E74F5FE727177AC8",
    "SYSTEM.CPK": "90A41E9F884FF036597ADB251F499218F54B58B57CDD0E8FD602B30A4B1C2D8E",
    "VOICE.CPK": "9051E51A1EEDAE405D38E328DD8A6700A0AC9512A6C1BF4C25A86400307D434C",
}

function Component() {
    const widget = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    if (widget != null) {
        widget.complete = false;
        widget.validateResult.setVisible(false);
        widget.errorLabel.setVisible(false);
        widget.validateButton.setEnabled(false);
        widget.browseButton.clicked.connect(this, Component.prototype.onBrowseButtonClicked);
        widget.pathLineEdit.textChanged.connect(this, Component.prototype.onPathChanged);
        widget.validateButton.clicked.connect(this, Component.prototype.onValidate);
    }
}

Component.prototype.onPathChanged = function (newPath) {
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    page.pathLineEdit.text = installer.toNativeSeparators(newPath);
    installer.setValue("CHLCC-PS3-Assets-Path", page.pathLineEdit.text);
    if (newPath === "" || !installer.fileExists(newPath)) {
        page.complete = false;
        page.errorLabel.setVisible(true);
        page.errorLabel.text = "Please select a valid directory.";
        copyFiles = {};
        page.validateButton.setEnabled(false);
        return;
    }
    page.errorLabel.setVisible(false);
    copyFiles = {};
    page.validateResult.setVisible(false);
    page.validateLog.setPlainText("");
    page.validateButton.setEnabled(true);
}

Component.prototype.onValidate = function () {
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    const selectedPath = installer.value("CHLCC-PS3-Assets-Path");
    copyFiles = {};
    component.setValue("UncompressedSize", 0);
    const lookupBySuffix = (path) => {
        let slicePath = path;
        while (true) {
            const foundEntry = fileEntries[slicePath];
            if (foundEntry) return [slicePath, foundEntry];
            var slash = slicePath.indexOf("/");
            if (slash === -1) return null;
            slicePath = slicePath.slice(slash + 1);
        }
    }

    const getWindowsHash = (filePath) => {
        const output = installer.execute("certutil", ["-hashfile", filePath, "SHA256"]);
        if (!output || output[1] !== 0) return null;

        return output[0].split("\n")[1].trim();
    }

    const getUnixHash = (filePath) => {
        const output = installer.execute("sha256sum", [filePath]);
        if (!output || output[1] !== 0) return null;
        return output[0].split(" ")[0].trim();
    }


    let validationLog = "Validating CHLCC PS3 Assets in directory: " + selectedPath + "\n";
    console.log(validationLog);
    const providedFiles = QDesktopServices.findFiles(selectedPath, "*");
    validationLog += `Found ${providedFiles.length} files in selected path.\n`
    console.log(`Found ${providedFiles.length} files in selected path.`);
    let hasErrors = false;
    const notFoundFiles = new Set(Object.keys(fileEntries));
    let fileSize = 0;
    for (const file of providedFiles) {
        const fixedFile = installer.fromNativeSeparators(file);
        const foundEntry = lookupBySuffix(fixedFile);
        if (!foundEntry) continue;
        const [foundFile, expectedHash] = foundEntry;
        notFoundFiles.delete(foundFile);
        validationLog += `Found file ${foundFile} at ${fixedFile}.\n`

        if (page.checkBoxHash.checked) {
            const actualHash = systemInfo.productType === "windows"
                ? getWindowsHash(fixedFile)
                : getUnixHash(fixedFile);

            if (actualHash === null) {
                validationLog += `Failed to compute hash for file: ${fixedFile}\n`;
                hasErrors = true;
                continue;
            }

            if (actualHash.toUpperCase() !== expectedHash.toUpperCase()) {
                validationLog += `Hash mismatch for file: ${fixedFile}\n`
                validationLog += `\tExpected: ${expectedHash}\n`;
                validationLog += `\tActual: ${actualHash}\n`;
                hasErrors = true;
                continue;
            }
            validationLog += `Hash for file ${foundFile} matches.\n`
        }
        copyFiles[foundFile] = fixedFile;
        fileSize += installer.fileSize(fixedFile);
    }
    if (notFoundFiles.size > 0) {
        hasErrors = true;
        for (const missingFile of notFoundFiles) {
            validationLog += `Missing file ${missingFile}.\n`;
        }
    }

    page.validateResult.setVisible(true);
    console.log(validationLog)
    page.validateLog.setPlainText(validationLog);
    if (hasErrors) {
        page.validateResult.text = "Validation Failed";
        page.validateResult.styleSheet = "color: red;"
        page.complete = false;
    } else {
        page.validateResult.text = "Validation Successful";
        page.validateResult.styleSheet = ""
        page.complete = true;
    }
    component.setValue("UncompressedSize", fileSize);
}

Component.prototype.onBrowseButtonClicked = function () {
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CHLCC_PS3");
    if (page === null) return;

    const targetDirectory = page.pathLineEdit;
    const newTarget = QFileDialog.getExistingDirectory("Pick directory containing CHLCC PS3 Assets.", "", "AssetsDir_CHLCC_PS3");
    if (newTarget != "")
        targetDirectory.text = installer.toNativeSeparators(newTarget);

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
