from pathlib import Path
import platform

from . import common
from . import vcpkg

QT_PREFIX = Path()

def set_qt_prefix(new_prefix: str):
    global QT_PREFIX
    QT_PREFIX = Path(new_prefix)

def qt_prefix():
    return QT_PREFIX

def qt_build_dir():
    return common.BUILD / "qt"

def qt_script(name):
    print(common.QT / f"{name}.bat")
    if platform.system() == "Windows":
        return common.QT / f"{name}.bat"
    return common.QT / name

def init_qt():

    common.run(
        [
            str(qt_script("init-repository")),
            "--module-subset=qtbase,qtdeclarative,qttools,qttranslations,qt5compat",
        ],
        cwd=common.QT,
    )

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
    qmake = qt_prefix() / "bin" / common.exe("qmake")

    vcpkg_prefix = vcpkg.VCPKG / "installed" / vcpkg.vcpkg_triplet()

    if qmake.exists() and not rebuild:
        return
    extra_configure_args = []

    if(platform.system() == "Darwin" and platform.machine() == "arm64"):
        patch_qt_mac_arm(common.QT)

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

    common.run(args,cwd=qt_build_dir())

    common.run(["cmake", "--build", ".", "--parallel"], cwd=qt_build_dir())
    common.run(["cmake", "--install", "."], cwd=qt_build_dir())
