function Component() {
    console.log("hooking installer")
    if (installer.isInstaller()) {
        component.loaded.connect(this, Component.prototype.installerLoaded);
    }
}

Component.prototype.isDefault = function() {
    return true; 
}



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

Component.prototype.installerLoaded = function () {
    installer.addWizardPage(component, "SelectionValidationPage", QInstaller.LicenseCheck);
}