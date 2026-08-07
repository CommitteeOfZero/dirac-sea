#!/usr/bin/env python3

import argparse
from pathlib import Path
import os
import platform
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]

QT = ROOT / "qt"
IFW = ROOT / "installer-framework"

BUILD = ROOT / "build"

VCPKG = ROOT / "vcpkg"

VCPKG_DEPS = [
    "openssl",
    "bzip2",
    "liblzma",
    "zlib",
]

def qt_prefix():
    return ROOT / "dist" / "qt-static"

def qt_build_dir():
    return BUILD / "qt"

def ifw_build_dir():
    return BUILD / "ifw"

def vcpkg_exe():
    return VCPKG / ("vcpkg.exe" if platform.system() == "Windows" else "vcpkg")


def run(cmd, cwd=None, env=None):
    print("> " + " ".join(map(str, cmd)))
    subprocess.run(cmd, cwd=cwd, env=env, check=True)


def exe(name):
    return name + ".exe" if platform.system() == "Windows" else name

def qt_script(name):
    print(QT / f"{name}.bat")
    if platform.system() == "Windows":
        return QT / f"{name}.bat"
    return QT / name

def vcpkg_arch():
    machine = platform.machine().lower()

    if machine in ("amd64", "x86_64", "x64"):
        return "x64"
    if machine in ("arm64", "aarch64"):
        return "arm64"
    if machine in ("x86", "i386", "i686"):
        return "x86"

    raise RuntimeError(f"Unsupported architecture: {machine}")


def vcpkg_triplet():
    arch = vcpkg_arch()
    system = platform.system()

    if system == "Windows":
        return f"{arch}-windows-static"
    if system == "Linux":
        return f"{arch}-linux"
    if system == "Darwin":
        return f"{arch}-osx"

    raise RuntimeError(f"Unsupported platform: {system}")

def init_vcpkg():
    bootstrap = VCPKG / (
        "bootstrap-vcpkg.bat"
        if platform.system() == "Windows"
        else "bootstrap-vcpkg.sh"
    )
    env = os.environ.copy()
    env["VCPKG_ROOT"] = str(VCPKG)

    vcpkg = VCPKG / exe("vcpkg")
    if not vcpkg.exists():
        print("Bootstrapping VCPKG")
        run([str(bootstrap)], cwd=VCPKG, env=env)

def init_qt():

    run(
        [
            str(qt_script("init-repository")),
            "--module-subset=qtbase,qtdeclarative,qttools,qttranslations,qt5compat",
        ],
        cwd=QT,
    )

def build_command():
    if platform.system() == "Windows":
        return ["nmake"]

    return [
        "make",
        f"-j{os.cpu_count()}"
    ]

def patch_qt_mac_arm(qt_src_dir: Path) -> None:
  # Workaround for QTBUG-145239: qyieldcpu.h fails to compile with
  # macOS 26.4 SDK on Apple Silicon.
  # https://qt-project.atlassian.net/browse/QTBUG-145239
  # https://codereview.qt-project.org/c/qt/qtbase/+/724619
  qyieldcpu_h = qt_src_dir.joinpath('qtbase', 'src', 'corelib', 'thread', 'qyieldcpu.h')
  content = qyieldcpu_h.read_text(encoding='utf-8')
  content = content.replace(
      '#if __has_builtin(__yield)\n',
      '#if __has_builtin(__builtin_arm_yield)\n'
      '    __builtin_arm_yield();\n'
      '#elif __has_builtin(__yield)\n',
  )
  qyieldcpu_h.write_text(content, encoding='utf-8')

def build_qt(rebuild=False, symbols = False):
    qmake = qt_prefix() / "bin" / exe("qmake")

    vcpkg_prefix = VCPKG / "installed" / vcpkg_triplet()

    if qmake.exists() and not rebuild:
        return
    extra_configure_args = []

    if(platform.system() == "Darwin" and platform.machine() == "arm64"):
        patch_qt_mac_arm(QT)

    qt_build_dir().mkdir(parents=True, exist_ok=True)
        
    if(platform.system() == "Windows"):
        extra_configure_args=[
            "-static-runtime",
            "-no-icu",
        ]
    elif(platform.system() == "Linux"):
        extra_configure_args=[
            "-qt-libpng",
            "-qt-libjpeg",
            "-qt-pcre",
            "-no-glib",
            "-no-cups",
            "-no-feature-gssapi",
            "-no-qml-debug",
            "-no-opengl",
            "-no-egl",
            "-no-sm",
            "-no-icu",
            "-no-libudev",
            "-bundled-xcb-xinput",
            "-qt-harfbuzz",
            "-qt-doubleconversion",
        ]
    elif(platform.system() == "Darwin"):
        extra_configure_args=[
            "-qt-libpng",
            "-no-cups",
            "-no-freetype",
        ]

    if(symbols):
        extra_configure_args.append("-force-debug-info")

    args = [
        str(qt_script("configure")),

        "-prefix",
        str(qt_prefix()),

        "-static",
        "-release",

        "-accessibility",

        "-opensource",
        "-confirm-license",

        "-nomake",
        "examples",

        "-nomake",
        "tests",

        "-no-sql-sqlite", 
        "-no-qml-debug"
    ]
    args.extend(extra_configure_args)
    args.extend([
        "--",
        f"-DOPENSSL_ROOT_DIR={vcpkg_prefix}",
    ])

    run(args,cwd=qt_build_dir())

    run(["cmake", "--build", ".", "--parallel"], cwd=qt_build_dir())
    run(["cmake", "--install", "."], cwd=qt_build_dir())

def build_ifw(qmake, symbols):
    ifw_build_dir().mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["PATH"] = (
        str(qmake.parent)
        + os.pathsep
        + env.get("PATH", "")
    )
    vcpkg_prefix = VCPKG / "installed" / vcpkg_triplet()

    def static_library(name):
        if platform.system() == "Windows":
            return f"{name}.lib"
        return f"lib{name}.a"


    qmake_args = [
        str(qmake),
        "-r",
        str(IFW / "installerfw.pro"),
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


    run(qmake_args,
        cwd=ifw_build_dir(),
        env=env,
    )

    run(build_command(), cwd=ifw_build_dir())
    run(build_command() + ["install"], cwd=ifw_build_dir())

    install_dir = qt_prefix() / "bin"
    if(platform.system() == "Linux"):
        run(["objcopy", "--only-keep-debug", install_dir / "installerbase", install_dir / "installerbase.debug"])
        run(["strip", "--strip-debug", install_dir / "installerbase"])
        run(["objcopy", "--add-gnu-debuglink=installerbase.debug", "installerbase"], cwd=install_dir)


def install_dependencies():
    triplet = vcpkg_triplet()

    args = [
        str(vcpkg_exe()),
        "install",
    ]

    env = os.environ.copy()
    env["VCPKG_ROOT"] = str(VCPKG)

    for dep in VCPKG_DEPS:
        args.append(f"{dep}:{triplet}")
    run(args, cwd=VCPKG, env=env)

def main():
    parser = argparse.ArgumentParser(description="Build Qt and IFW")
    parser.add_argument("--rebuild-qt", default=False, action="store_true", help="Rebuild Qt even if it is already built")
    parser.add_argument("--stage", choices=["vcpkg", "qt", "ifw", "all"], default="all")
    parser.add_argument("--symbols", action="store_true", default=False, help="Builds with debugging symbols")
    args = parser.parse_args()

    run(
        [
            "git",
            "submodule",
            "update",
            "--init",
        ],
        cwd=ROOT,
    )

    init_qt()
    if args.stage in ("vcpkg", "all"):
        init_vcpkg()
        install_dependencies()
    if args.stage in ("qt", "all"):
        build_qt(rebuild=args.rebuild_qt,symbols=args.symbols)
    if args.stage in ("ifw", "all"):
        qmake = qt_prefix() / "bin" / exe("qmake")
        build_ifw(qmake,args.symbols)    

    print("Finished:")
    print(f"IFW will be installed to QT install at {qt_prefix()}/bin")


if __name__ == "__main__":
    main()