import os
from pathlib import Path
import platform
import subprocess

ROOT = Path(__file__).resolve().parents[2]

QT = ROOT / "qt"
IFW = ROOT / "installer-framework"

BUILD = ROOT / "build"

def run(cmd, cwd=None, env=None):
    print("> " + " ".join(map(str, cmd)))
    subprocess.run(cmd, cwd=cwd, env=env, check=True)


def exe(name):
    return name + ".exe" if platform.system() == "Windows" else name

def build_command():
    if platform.system() == "Windows":
        return ["nmake"]

    return [
        "make",
        f"-j{os.cpu_count()}"
    ]