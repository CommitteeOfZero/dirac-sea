function Component() {
}

Component.prototype.createOperationsForArchive = function (archive) {
  console.log(`Extracting archive ${archive} to ${installer.value("TargetDirPatches")}`);
  if(!installer.fileExists(installer.toNativeSeparators(installer.value("TargetDirPatches")))) {
      component.addOperation("Mkdir", "@TargetDirPatches@");
  }
  component.addOperation("Extract", archive, "@TargetDirPatches@");
}