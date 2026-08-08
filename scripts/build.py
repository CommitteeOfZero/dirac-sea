# build.py
import argparse
from pathlib import Path
import sys
import traceback
import lib.common as common

import lib.vcpkg as vcpkg
import lib.qt as qt
import lib.ifw as ifw
import lib.installer as installer

def main():
  parser = argparse.ArgumentParser(description="Build Qt, IFW, and the installer package")

  # qt/ifw
  parser.add_argument("--rebuild-qt", action="store_true", default=False, help="Rebuild Qt even if it is already built")
  parser.add_argument("--stage", choices=["vcpkg", "qt", "ifw", "installer", "all"], default="all")
  parser.add_argument("--symbols", action="store_true", default=False, help="Builds with debugging symbols")
  parser.add_argument("--qt-ifw-dir", type=Path, default=common.ROOT / "dist" / "qt-static", help="Path to Qt Installer Framework root")

  # installer
  parser.add_argument("--local", action="store_true", default=False, help="Use a local filesystem repository instead of the online repository")
  parser.add_argument("--online-only", action="store_true", default=False, help="Skip bundling archives for a minimal installer")
  parser.add_argument("--skip-download", action="store_true", default=False, help="Skip downloading assets")
  parser.add_argument("--excluded-packages", nargs="*", default=[], help="Space separated list of components to skip")

  args = parser.parse_args()

  qt.set_qt_prefix(args.qt_ifw_dir)
      

  common.run(["git", "submodule", "update", "--init"], cwd=common.ROOT)

  if args.stage in ("vcpkg", "all"):
      vcpkg.init_vcpkg()
      vcpkg.install_dependencies()

  if args.stage in ("qt", "all"):
      qt.init_qt()
      qt.build_qt(rebuild=args.rebuild_qt, symbols=args.symbols)
      print(f"QT will be installed to {qt.qt_prefix()}")


  if args.stage in ("ifw", "all"):
      qt.qmake = qt.qt_prefix() / "bin" / common.exe("qmake")
      ifw.build_ifw(qt.qmake, args.symbols)
      print(f"IFW will be installed to QT install at {qt.qt_prefix()}/bin")

  if args.stage in ("installer", "all"):
      if not installer.installer_base().exists():
          print(f"Missing installerbase at {installer.installer_base(args.qt_ifw_dir)}, run with --stage ifw first", file=sys.stderr)
          return 1
      installer.build_installer(
          local=args.local,
          online_only=args.online_only,
          skip_download=args.skip_download,
          excluded_packages=args.excluded_packages,
      )
      print(f"Installer will be installed to {common.ROOT}/dist")

  print("Finished")

if __name__ == "__main__":
    try:
      main()
    except Exception as e:
      traceback.print_exc()
      print(e)
      exit(1)