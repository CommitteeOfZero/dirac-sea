function Component() {
}

Component.prototype.createOperationsForArchive = function(archive)
{
    console.log(`Extracting archive ${archive} to ${installer.value("TargetDirPatches")}`);
    component.addOperation("Extract", archive, "@TargetDirPatches@");
}