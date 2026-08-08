import os
from pathlib import Path
import platform

from . import common
from . import vcpkg
from . import qt

def ifw_bin() -> Path:
    return qt.qt_prefix() / "bin"

def ifw_build_dir():
    return common.BUILD / "ifw"

def build_ifw(qmake, symbols):
    ifw_build_dir().mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["PATH"] = (
        str(qmake.parent)
        + os.pathsep
        + env.get("PATH", "")
    )
    vcpkg_prefix = vcpkg.VCPKG / "installed" / vcpkg.vcpkg_triplet()

    def static_library(name):
        if platform.system() == "Windows":
            return f"{name}.lib"
        return f"lib{name}.a"


    qmake_args = [
        str(qmake),
        "-r",
        str(common.IFW / "installerfw.pro"),
        "CONFIG+=release",
        f"INCLUDEPATH+={vcpkg_prefix / 'include'}",
        f"IFW_BZIP2_LIBRARY={vcpkg_prefix/'lib'/static_library('bz2')}", 
        f"IFW_LZMA_LIBRARY={vcpkg_prefix/'lib'/static_library('lzma')}",
    ]
    if(platform.system() == "Windows"):
        qmake_args.append(f"IFW_ZLIB_LIBRARY={vcpkg_prefix/'lib'/static_library('zs')}"), 
    else:
        qmake_args.append(f"IFW_ZLIB_LIBRARY={vcpkg_prefix/'lib'/static_library('z')}"), 

    if(symbols):
        qmake_args.append("CONFIG+=force_debug_info")


    common.run(qmake_args,
        cwd=ifw_build_dir(),
        env=env,
    )

    common.run(common.build_command(), cwd=ifw_build_dir())
    common.run(common.build_command() + ["install"], cwd=ifw_build_dir())

    install_dir = qt.qt_prefix() / "bin"
    if(platform.system() == "Linux"):
        common.run(["objcopy", "--only-keep-debug", install_dir / "installerbase", install_dir / "installerbase.debug"])
        common.run(["strip", "--strip-debug", install_dir / "installerbase"])
        common.run(["objcopy", "--add-gnu-debuglink=installerbase.debug", "installerbase"], cwd=install_dir)
