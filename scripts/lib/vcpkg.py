import os
import platform
from . import common


VCPKG = common.ROOT / "vcpkg"

VCPKG_DEPS = [
    "openssl",
    "bzip2",
    "liblzma",
    "zlib",
]

def vcpkg_exe():
    return VCPKG / ("vcpkg.exe" if platform.system() == "Windows" else "vcpkg")

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

    vcpkg = VCPKG / common.exe("vcpkg")
    print(vcpkg)
    if not vcpkg.exists():
        print("Bootstrapping VCPKG")
        common.run([str(bootstrap)], cwd=VCPKG, env=env)

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
    common.run(args, cwd=VCPKG, env=env)
