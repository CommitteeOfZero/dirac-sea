function Component()
{
    const widget = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");
    if (widget != null) {
        widget.complete = false;
        widget.browseButton.clicked.connect(this, Component.prototype.onBrowseButtonClicked);
    }
}

Component.prototype.onBrowseButtonClicked = function()
{
    const page = gui.pageWidgetByObjectName("DynamicPathPage_CCLCC_PS4");

    if (page === null) return;

    const selectedPath = QFileDialog.getExistingDirectory(
        "Select CCLCC PS4 Assets Directory",
        page.pathLineEdit.text,
        "CCLCCAssetsDirectory"
    );

    if (selectedPath !== "") {
        page.pathLineEdit.text = selectedPath;
        if (selectedPath === "" || !installer.fileExists(selectedPath)) {
            console.log(selectedPath)
            console.log(installer.fileExists(selectedPath))
            page.complete = false;
        } else {
            installer.setValue("CCLCC-PS4-Assets-Path", selectedPath);
            page.complete = true;
        }
    }
}