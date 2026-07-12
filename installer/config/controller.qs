function Controller() {
    this.hookSelection = false;
}

Controller.prototype.onSelectionChange = function() {
    var page = gui.currentPageWidget();
    page.completeChanged.disconnect(this, Controller.prototype.onSelectionChange);
    var eng = installer.componentByName(
        "com.committeeofzero.cclcc.ps4.patch.eng"
    );
    if (eng.installationRequested()) {
        page.selectComponent("com.committeeofzero.cclcc.ps4.assets");
    }

    var jpn = installer.componentByName(
        "com.committeeofzero.cclcc.ps4.patch.jpn"
    );
    if (jpn.installationRequested()) {
        page.selectComponent("com.committeeofzero.cclcc.ps4.assets");
    };

    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);
};

Controller.prototype.ComponentSelectionPageCallback = function() {
    var page = gui.pageByObjectName("ComponentSelectionPage");
    if (!page) return;

    var impactoGroup = installer.componentByName(
        "com.committeeofzero.impacto"
    );

    page.completeChanged.connect(this, Controller.prototype.onSelectionChange);

    var impactoGroup = installer.componentByName("com.committeeofzero.impacto");
};


function validateSelection()
{
    var errors = [];

    var impactoGroup = installer.componentByName("com.committeeofzero.impacto");

    if (!impactoGroup.installationRequested()) {
        errors.push(
            "Please select an Impacto component."
        );
    }

    return errors;
}

Controller.prototype.DynamicSelectionValidationPageCallback = function()
{
    var errors = validateSelection();
    console.log(errors)
    const hasErr = errors.length !== 0;
    gui.currentPageWidget().complete = !hasErr;
    var page = gui.pageWidgetByObjectName("DynamicSelectionValidationPage");
    if(hasErr) {
        page.label.text = errors.join("\n");
        page.label.styleSheet = "color: red; font-weight: bold;";
    } else {
        page.label.text = "Component selection validated successfully.";
        page.label.styleSheet = "";
    }
}



