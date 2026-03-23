#!/usr/bin/env python3
"""Compila o shader do efeito cyberkde_popups fora da tela (sem abrir janela), nas duas variantes
que o KWin usa: popup_core.frag (GLSL 1.40, perfil core) e popup.frag (legado).

O include "colormanagement.glsl" é interno do KWin; aqui ele vira funções-identidade com as mesmas
assinaturas. Uso: QT_QPA_PLATFORM=offscreen python3 check_shader.py
"""
import os
import pathlib
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
from PyQt6.QtGui import QGuiApplication, QOffscreenSurface, QOpenGLContext, QSurfaceFormat  # noqa: E402
from PyQt6.QtOpenGL import QOpenGLShader  # noqa: E402

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from gen_plasma import EFFECT_SRC, FRAG_CORE, FRAG_LEGACY  # noqa: E402

STUB = ("vec4 sourceEncodingToNitsInDestinationColorspace(vec4 c) { return c; }\n"
        "vec4 nitsToDestinationEncoding(vec4 c) { return c; }\n")


def compile_variant(name, header, core):
    fmt = QSurfaceFormat()
    if core:
        fmt.setVersion(3, 2)
        fmt.setProfile(QSurfaceFormat.OpenGLContextProfile.CoreProfile)
    ctx = QOpenGLContext()
    ctx.setFormat(fmt)
    if not ctx.create():
        print(f"{name}: sem contexto OpenGL {'core' if core else 'legado'}")
        return False
    surface = QOffscreenSurface()
    surface.setFormat(ctx.format())
    surface.create()
    ctx.makeCurrent(surface)
    source = (header + (EFFECT_SRC / "shader.glsl").read_text()).replace('#include "colormanagement.glsl"\n', STUB)
    shader = QOpenGLShader(QOpenGLShader.ShaderTypeBit.Fragment)
    ok = shader.compileSourceCode(source)
    v = ctx.format().version()
    print(f"{name}: {'ok' if ok else 'ERRO'} (OpenGL {v[0]}.{v[1]})")
    if shader.log().strip():
        print(shader.log().strip())
    ctx.doneCurrent()
    return ok


def main():
    app = QGuiApplication(sys.argv)  # noqa: F841 — precisa viver enquanto os contextos existem
    results =[compile_variant("popup_core.frag", FRAG_CORE, True),
               compile_variant("popup.frag", FRAG_LEGACY, False)]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
