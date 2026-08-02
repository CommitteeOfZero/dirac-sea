#!/usr/bin/env python3
import argparse
import hashlib
import platform
import sys
import xml.etree.ElementTree as ET
import shutil
import subprocess
import tempfile
from pathlib import Path
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[1]

PACKAGES_DIR = ROOT/"installer/packages"
CONFIG_DIR = ROOT/"installer/config"

INSTALLER_NAME_BY_OS = {
    "windows": "ImpactoInstaller.exe",
    "linux": "ImpactoInstaller.run",
    "mac": "ImpactoInstaller.app",
}


def detect_os() -> str:
    system = platform.system().lower()
    if system == "windows":
        return "windows"
    elif system == "darwin":
        return "mac"
    elif system == "linux":
        return "linux"
    else:
        raise RuntimeError(f"Unsupported platform: {system}")


def ifw_bin(qt_ifw_dir: Path) -> Path:
    return qt_ifw_dir / "bin"

def installer_base(qt_ifw_dir: Path) -> Path:
    installer_base_name = "installerbase.exe" if platform.system() == "Windows" else "installerbase"
    return ifw_bin(qt_ifw_dir) / installer_base_name


def run(cmd, **kwargs):
    print(f"==> {' '.join(str(c) for c in cmd)}")
    subprocess.run(cmd, check=True, **kwargs)


def sha1(path: Path) -> str:
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path):
    print(f"==> Downloading {url}")
    urllib.request.urlretrieve(url, dest)


def get_components() -> list[str]:
    result = []
    for package_dir in PACKAGES_DIR.iterdir():
        if package_dir.is_dir() and (package_dir / "meta" / "package.xml").exists():
            result.append(package_dir.name)
    return result


def parse_component(component_name: str) -> dict[str, list[tuple[str, str]]]:
    package_xml = PACKAGES_DIR / component_name / "meta" / "package.xml"
    if not package_xml.exists():
        raise RuntimeError(f"No package.xml found for component '{component_name}' at {package_xml}")

    tree = ET.parse(package_xml)
    root = tree.getroot()

    downloadable = root.find("DownloadableArchives")
    version = root.find("Version")

    result = {
        "version": version.text.strip() if version is not None and version.text else "",
        "archives": [],
    }

    if downloadable is None:
        return result

    """
        <DownloadableArchives>
            <Archive>
                <Path>archive_name.7z</Path>
                <URL>https://.../</URL>
            </Archive>
        </DownloadableArchives>
    """
    for archive in downloadable.findall("Archive"):
        path_el = archive.find("Path")
        url_el = archive.find("Url")
        if path_el is not None and url_el is not None and path_el.text and url_el.text:
            result["archives"].append((path_el.text.strip(), url_el.text.strip()))

    return result


def generate_repository(bin_dir: Path, repo_dir: Path):
    run([bin_dir / "repogen", "-p", PACKAGES_DIR, repo_dir])


def copy_repository(repo_dir: Path, dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    if dest == repo_dir:
        return
    shutil.copy(repo_dir / "Updates.xml", dest / "Updates.xml")
    for meta in repo_dir.glob("*/*meta.7z"):
        shutil.copy(meta, dest / meta.name)


def download_assets(dest: Path) -> list[dict]:
    """For each component, reads its package.xml DownloadableArchives entries
    (if any) and downloads each declared archive, caching a copy in the
    component's data/ directory so subsequent builds can reuse it."""
    result = []
    for component_name in get_components():
        data_dir = PACKAGES_DIR / component_name / "data"

        component_data = parse_component(component_name)
        archives = component_data["archives"]
        version = component_data["version"]
        if not archives:
            print(f"==> No downloadable archives declared for {component_name}, skipping")
            continue

        data_dir.mkdir(parents=True, exist_ok=True)

        # Delete any existing archives in the component's data/ directory that are not declared in package.xml
        for existing in data_dir.glob("*"):
            if existing.is_file() and not any(existing.name == archive_name for archive_name, _ in archives) and not existing.name == f"{version}meta.7z":
                print(f"==> Removing undeclared cached archive {existing}")
                existing.unlink()
        
        for archive_name, asset_url in archives:
            print(f"==> Found archive: {archive_name}")
            archive = dest / archive_name
            cached = data_dir / archive_name
            if cached.exists():
                print(f"==> Using cached {cached}")
                shutil.copy(cached, archive)
            else:
                download(asset_url, archive)
                shutil.copy(archive, cached)

            checksum = sha1(archive)
            print(f"    SHA1: {checksum}")
            result.append({"name": component_name, "asset_url": asset_url, "archive_name": archive_name, "checksum": checksum})
    return result


def patch_config_xml_local(config_path: Path, repo_dir: Path) -> str:
    tree = ET.parse(config_path)
    root = tree.getroot()
    for repo in root.findall(".//RemoteRepositories/Repository"):
        url = repo.find("Url")
        if url is not None:
            url.text = repo_dir.resolve().as_uri() + "/"
            print(f"==> Local repo URL: {url.text}")
        enabled = repo.find("Enabled")
        if enabled is not None:
            enabled.text = "1"
    ET.indent(tree)
    return ET.tostring(root, encoding="unicode", xml_declaration=True)

def build(args):
    os_name = args.os
    bin_dir = ifw_bin(args.qt_ifw_dir)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        if(not args.online_only):
            assets = download_assets(tmp)
        installer_mode = "--online-only" if args.online_only else "--hybrid" 

        excluded_packages = []
        if(platform.system() != "Windows"):
            excluded_packages.append("com.committeeofzero.impacto.windows")
        if(platform.system() != "Linux"):
            excluded_packages.append("com.committeeofzero.impacto.linux")
        if(platform.system() != "Darwin" and (platform.machine() != "arm64")):
            excluded_packages.append("com.committeeofzero.impacto.macos_arm64")
        if(platform.system() != "Darwin" and (platform.machine() != "x86_64")):
            excluded_packages.append("com.committeeofzero.impacto.macos_x64")
        excluded_packages = ",".join(excluded_packages)
        if args.local:
            repo_dir = Path(ROOT/"test-repository")
            if repo_dir.exists():
                shutil.rmtree(repo_dir)
            dist = Path(ROOT/"dist")
            dist.mkdir(parents=True, exist_ok=True)
            installer = dist/INSTALLER_NAME_BY_OS[os_name]
            if installer.exists():
                installer.unlink()

            generate_repository(bin_dir, repo_dir)
            copy_repository(repo_dir, repo_dir)
            shutil.copytree(CONFIG_DIR, tmp, dirs_exist_ok=True)

            tmp_config = tmp / "config.xml"
            tmp_config.write_text(patch_config_xml_local(CONFIG_DIR/"config.xml", repo_dir))

            run_args = [
                bin_dir / "binarycreator", installer_mode,
                "-c", tmp_config, 
                "-p", PACKAGES_DIR,  
                "-t", installer_base(args.qt_ifw_dir),
                "-v",
            ]

            if(not args.online_only):
                run_args.append("-e")
                run_args.append(excluded_packages),

            run_args.append(installer)
            run(run_args)
        else:
            repo_dir = tmp / "repository"
            generate_repository(bin_dir, repo_dir)

            dist = Path(ROOT/"dist")
            copy_repository(repo_dir, dist)

            run_args =[
                bin_dir / "binarycreator", installer_mode,
                "-c", CONFIG_DIR, 
                "-p", PACKAGES_DIR,
                "-t", installer_base(args.qt_ifw_dir),
                "-e", excluded_packages,
                "-v",
                dist / INSTALLER_NAME_BY_OS[os_name]
            ]

            if(not args.online_only):
                run_args.append("-e")
                run_args.append(excluded_packages),

            run_args.append(installer)
            run(run_args)

            print(f"\nDone. Output in {dist}/")

def main():
        

    parser = argparse.ArgumentParser(description="IFW installer build tool")
    parser.add_argument(
        "--qt-ifw-dir", type=Path, 
        default=ROOT/"dist"/"qt-static",
        help="Path to Qt Installer Framework root",
    )
    parser.add_argument(
        "--os", choices=["windows", "linux", "mac"], default=None,
        help="Target OS (defaults to current platform)",
    )
    parser.add_argument(
        "--local", action="store_true", default=False,
        help="Build a test installer instead of release artifacts",
    )
    parser.add_argument(
        "--online-only", action="store_true", default=False,
        help="Build a minimal online installer without bundling release artifacts",
    )
    parser.add_argument(
        "--override-version",
        nargs="+",
        metavar="PRODUCT=VERSION",
        help="Override version for specific products, e.g. impacto=0.9.9.300",
    )

    args = parser.parse_args()
    if args.os is None:
        args.os = detect_os()
        print(f"==> Detected OS: {args.os}")

    if not (installer_base(args.qt_ifw_dir)).exists():
        print(sys.stderr, f"Missing installerbase at {installer_base(args.qt_ifw_dir)}, run build_ifw.py first")
        return 1

    build(args)


if __name__ == "__main__":
    main()