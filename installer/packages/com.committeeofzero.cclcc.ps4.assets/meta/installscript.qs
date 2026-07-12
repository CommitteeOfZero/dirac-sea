function Component()
{
    if(installer.addWizardPage(component, "PathPage", QInstaller.ReadyForInstallation)) {
        var widget = gui.pageWidgetByObjectName("DynamicPathPage");
        if (widget != null) {
            widget.complete = false;
            widget.browseButton.clicked.connect(this, Component.prototype.onBrowseButtonClicked);
        }
    }
}

Component.prototype.onBrowseButtonClicked = function()
{
    var page = gui.pageWidgetByObjectName("DynamicPathPage");

    if (page !== null) {
        var selectedPath = QFileDialog.getExistingDirectory(
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
}