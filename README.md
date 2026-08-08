Terminal to realboot impacto

To build, ensure you have required dependencies:

Windows:
MSVC Compiler
Python 3.12

Linux:

Python 3.12
Any packages you need to compile C++,  such as
GCC (tested with 13)
build-essential

QT Development Dependencies as mentioned here
https://doc.qt.io/qt-6/linux-requirements.html

Ubuntu Dependencies Install:
```
sudo apt install \
    libfontconfig1-dev \
    libfreetype-dev \
    libgtk-3-dev \
    libx11-dev \
    libx11-xcb-dev \
    libxcb-cursor-dev \
    libxcb-glx0-dev \
    libxcb-icccm4-dev \
    libxcb-image0-dev \
    libxcb-keysyms1-dev \
    libxcb-randr0-dev \
    libxcb-render-util0-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-sync-dev \
    libxcb-util-dev \
    libxcb-xfixes0-dev \
    libxcb-xkb-dev \
    libxcb1-dev \
    libxext-dev \
    libxfixes-dev \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxrender-dev \
    build-essential \
    ninja-build \
    cmake
```

Build instructions:

Open a terminal 
(Windows will require a VS Developer Command Prompt or an IDE terminal configured wth MSVC build tools)

run `python3 scripts/build.py` to build QT, IFW, and the Installer for your platform
  - You can check --help flags for additional options


Updating a Package:
Edit the package.xml within a package inside `installer/packages/<package_name>/meta`, with the new url, version number, dates, etc.
Run `python3 scripts/build.py --stage installer` to build a new installer and update the repository files
Update repository should be pushed to the updates branch (git worktrees is useful for this).
This can also be done through GitHub Actions.
