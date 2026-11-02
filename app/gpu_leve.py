"""Só o driver OpenGL em uso. O libglvnd carrega TODOS os fornecedores de EGL ao abrir a tela; numa máquina só com
NVIDIA, o Mesa inteiro (libgallium + libLLVM) entra à toa em cada app: ~50 MB de RSS e ~16 MB de PSS por processo,
medidos. O desenho é o mesmo: quem desenha já era o driver da NVIDIA.

Só age com certeza: sessão Wayland, toda placa DRM no driver nvidia, nada forçado pelo ambiente. Híbrido (Intel + NVIDIA)
ou nouveau: não muda nada. CYBERKDE_EGL_TODOS=1 desliga. A variável só existe durante a escolha do fornecedor, antes do
Qt e de qualquer processo filho: o libglvnd a lê uma vez, na primeira chamada de EGL, e nenhum app aberto por aqui a herda."""

import ctypes
import glob
import os

VAR = "__EGL_VENDOR_LIBRARY_FILENAMES"
JSONS = ("/usr/share/glvnd/egl_vendor.d/10_nvidia.json", "/etc/glvnd/egl_vendor.d/10_nvidia.json")


def so_nvidia():
    placas = glob.glob("/sys/class/drm/card[0-9]*/device/driver")
    try:
        return bool(placas) and all(os.path.basename(os.readlink(p)) == "nvidia" for p in placas)
    except OSError:
        return False


def preparar():
    """Antes do QGuiApplication."""
    e = os.environ
    livre = not any(k in e for k in (VAR, "__EGL_VENDOR_LIBRARY_DIRS", "LIBGL_ALWAYS_SOFTWARE", "CYBERKDE_EGL_TODOS"))
    if not (livre and e.get("XDG_SESSION_TYPE") == "wayland" and e.get("QT_QPA_PLATFORM", "wayland") == "wayland"
            and e.get("QT_QUICK_BACKEND", "") != "software" and so_nvidia()):
        return
    alvo = next((j for j in JSONS if os.path.exists(j)), None)
    if not alvo:
        return
    e[VAR] = alvo
    try:
        egl = ctypes.CDLL("libEGL.so.1")
        egl.eglQueryString.restype = ctypes.c_char_p
        egl.eglQueryString.argtypes = (ctypes.c_void_p, ctypes.c_int)
        egl.eglQueryString(None, 0x3055)   # EGL_EXTENSIONS sem tela: faz o libglvnd escolher os fornecedores agora
    except (OSError, AttributeError):
        pass
    finally:
        del e[VAR]
