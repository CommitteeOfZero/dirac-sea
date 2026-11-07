function Component() { }

Component.prototype.createOperations = function () {
    component.createOperations();
    // Create the target directory for the game data, no undo operation to avoid removing on update
    component.addOperation("Mkdir", "@TargetDirGamedata@", "UNDOOPERATION", "");
    component.registerPathForUninstallation("@TargetDirGamedata@");
};