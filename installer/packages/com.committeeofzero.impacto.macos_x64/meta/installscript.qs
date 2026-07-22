function Component() {
    component.loaded.connect(this, Component.prototype.setComponentVirtual);
}

Component.prototype.setComponentVirtual = function() {
    if (systemInfo.productType != "osx" || systemInfo.currentCpuArchitecture !== "x64") {
        component.setValue("Virtual", "true");
    
        installer?.recalculateAllComponents();
    }
}
Component.prototype.createOperations = function()
{
    component.createOperations();
    component.registerPathForUninstallation("@TargetDir@", true);
};

Component.prototype.createOperationsForArchive = function(archive) {
    component.addOperation("Extract", archive, "@TargetDir@");
}
