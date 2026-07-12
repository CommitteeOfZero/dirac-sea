#!/usr/bin/env python3
import argparse
import hashlib
import platform
import xml.etree.ElementTree as ET
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path
import json

INSTALLER_REPO = "CommitteeOfZero/dirac-sea"
PACKAGES_DIR = Path("installer/packages")
CONFIG_DIR = Path("installer/config")

INSTALLER_NAME_BY_OS = {
    "windows": "ImpactoInstaller.exe",
    "linux": "ImpactoInstaller.run",
    "mac": "ImpactoInstaller.app",
}

def get_release_asset_url(repo: str, version: str | None, param: str | None) -> tuple[str, str]:
    if version:
        api_url = f"https://api.github.com/repos/{repo}/releases/tags/{version}"
    else:
        api_url = f"https://api.github.com/repos/{repo}/releases?per_page=1"
    print(f"==> Fetching release from {api_url}")
    req = urllib.request.Request(api_url, headers={"Accept": "application/vnd.github+json"})
    with urllib.request.urlopen(req) as resp:
        release = json.loads(resp.read())
    if isinstance(release, list):
        release = release[0]

    if param is None:
        asset = release["assets"][0]
        return asset["browser_download_url"], asset["name"]

    for asset in release["assets"]:
        if param in asset["name"]:
            return asset["browser_download_url"], asset["name"]
    raise RuntimeError(
        f"No asset found for keyword '{param}' in release {release['tag_name']} of {repo}.\n"
        f"Available assets: {[a['name'] for a in release['assets']]}"
    )


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


def load_config(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)


def get_products(config: dict, args) -> dict:
    if hasattr(args, "override_version") and args.override_version:
        for override in args.override_version:
            product, version = override.split("=", 1)
            if product in config:
                config[product]["version"] = version
    return config


def collect_assets(products: dict, os_name: str) -> list[dict]:
    """Returns list of (product, component, asset_url, archive_name) for the given OS."""
    result = []
    for product_name, product in products.items():
        for component in product["components"]:
            result.append({
                "product": product_name,
                "assets_repo": product.get("assets_repo", INSTALLER_REPO),
                "version": product["version"],
                "component": component,
            })
    return result


def generate_repository(bin_dir: Path, repo_dir: Path):
    run([bin_dir / "repogen", "-p", PACKAGES_DIR, repo_dir])


def patch_and_copy_repository(repo_dir: Path, assets: list[dict], dest: Path):
    dest.mkdir(parents=True, exist_ok=True)
    updates_xml = repo_dir / "Updates.xml"
    for asset in assets:
        patch_updates_xml(
            updates_xml,
            asset["component"]["name"],
            asset["asset_url"],
            asset["checksum"],
        )
    if dest != repo_dir:
        shutil.copy(updates_xml, dest / "Updates.xml")
        for meta in repo_dir.glob("*/*meta.7z"):
            shutil.copy(meta, dest / meta.name)


def download_assets(assets: list[dict], dest: Path) -> list[dict]:
    result = []
    for asset in assets:
        data_dir = PACKAGES_DIR / asset["component"]["name"] / "data"
        data_dir.mkdir(parents=True, exist_ok=True)

        # check if any file is already cached in data/
        cached_files = list(data_dir.iterdir())
        if cached_files:
            cached = cached_files[0]
            archive_name = cached.name
            asset_url = None
            print(f"==> Using cached {cached}")
            archive = dest / archive_name
            shutil.copy(cached, archive)
        else:
            asset_url, archive_name = get_release_asset_url(
                asset.get("assets_repo", INSTALLER_REPO),
                asset["version"],
                asset["component"].get("param")
            )
            print(f"==> Found asset: {archive_name}")
            archive = dest / archive_name
            download(asset_url, archive)
            shutil.copy(archive, data_dir / archive_name)

        checksum = sha1(archive)
        print(f"    SHA1: {checksum}")
        result.append({**asset, "asset_url": asset_url, "archive_name": archive_name, "checksum": checksum})
    return result

def patch_updates_xml(path: Path, component_name: str, asset_url: str, asset_sha1: str):
    tree = ET.parse(path)
    root = tree.getroot()
    for pkg in root.findall(".//PackageUpdate"):
        if pkg.findtext("Name") == component_name:
            pkg.find("DownloadableArchives").text = asset_url
            pkg.find("SHA1").text = asset_sha1
    ET.indent(tree)
    path.write_text(ET.tostring(root, encoding="unicode", xml_declaration=True))

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

def build(args, local: bool):
    config = load_config(args.config)
    products = get_products(config, args)
    os_name = args.os
    bin_dir = ifw_bin(args.qt_ifw_dir)

    assets = collect_assets(products, os_name)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        assets = download_assets(assets, tmp)

        if local:
            repo_dir = Path("test-repository")
            if repo_dir.exists():
                shutil.rmtree(repo_dir)
            installer = Path(INSTALLER_NAME_BY_OS[os_name])
            if installer.exists():
                installer.unlink()

            generate_repository(bin_dir, repo_dir)
            patch_and_copy_repository(repo_dir, assets, repo_dir)
            shutil.copytree(CONFIG_DIR, tmp, dirs_exist_ok=True)

            tmp_config = tmp / "config.xml"
            tmp_config.write_text(patch_config_xml_local(CONFIG_DIR/"config.xml", repo_dir))

            run([bin_dir / "binarycreator", "--online-only",
                "-c", tmp_config, "-p", PACKAGES_DIR, installer])
        else:
            repo_dir = tmp / "repository"
            generate_repository(bin_dir, repo_dir)

            dist = Path("dist")
            patch_and_copy_repository(repo_dir, assets, dist)


            run([bin_dir / "binarycreator", "--online-only",
                 "-c", CONFIG_DIR, "-p", PACKAGES_DIR,
                 dist / INSTALLER_NAME_BY_OS[os_name]])

            print(f"\nDone. Output in {dist}/")

def main():
    parser = argparse.ArgumentParser(description="IFW installer build tool")
    parser.add_argument(
        "--config", type=Path, required=True,
        help="Path to Config json file",
    )
    parser.add_argument(
        "--qt-ifw-dir", type=Path, required=True,
        help="Path to Qt Installer Framework root",
    )
    parser.add_argument(
        "--os", choices=["windows", "linux", "mac"], default=None,
        help="Target OS (defaults to current platform)",
    )
    parser.add_argument(
        "--local", action="store_true", default=False,
        help="Build and run a local test installer instead of release artifacts",
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

    build(args, local=args.local)


if __name__ == "__main__":
    main()