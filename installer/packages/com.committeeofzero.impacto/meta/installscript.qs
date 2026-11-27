function Component() { }

Component.prototype.createOperations = function () {
    component.createOperations();
    component.addOperation("Mkdir", "@TargetDirGamedata@", "UNDOOPERATION", "");
    component.registerPathForUninstallation("@TargetDirGamedata@");
  
    component.addOperation("Mkdir", "@TargetDirPatches@", "UNDOOPERATION", "");
    component.registerPathForUninstallation("@TargetDirPatches@");
};