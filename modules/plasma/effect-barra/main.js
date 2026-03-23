// CyberKDE Barra — barra superior do Plasma no estilo "filete neon" (escolhido em 14/09/2026).
// Um shader fica aplicado o tempo todo sobre a janela da barra e desenha:
// - o filete na cor de destaque na borda de baixo;
// - o brilho sob o menu iniciar;
// - o quadro chanfrado em volta do ícone.
// A barra, os widgets e o ícone do menu não mudam.

"use strict";

// @tokens-begin (gerado por modules/plasma/generator/gen_plasma.py; não editar à mão)
const TOKENS = {
    "accent": "#F75049"
};
// @tokens-end

function hexToVec3(hex) {
    const v = parseInt(hex.replace("#", ""), 16);
    return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255];
}

class CyberBarEffect {
    constructor() {
        this.shader = effect.addFragmentShader(Effect.MapTexture, "barra.frag");
        effect.setUniform(this.shader, "uAccent", hexToVec3(TOKENS.accent));
        effects.windowAdded.connect(this.manage.bind(this));
        for (const window of effects.stackingOrder) {
            this.manage(window);
        }
    }

    // Barras horizontais finas do plasmashell. Docks de outros programas (Latte etc.) também são
    // "dock", mas de outras classes, e ficam de fora.
    static isBar(window) {
        if (!window.dock || String(window.windowClass).indexOf("plasmashell") === -1) {
            return false;
        }
        const g = window.geometry;
        return g.height > 0 && g.height <= 64 && g.width >= g.height * 8;
    }

    // A textura que o shader recebe inclui a sombra da barra (expandedGeometry). O shader precisa
    // saber onde a barra fica dentro dela e o tamanho real, para medir em pixels da barra.
    // As duas barras (uma por tela) têm a mesma sombra, então um único valor serve para ambas.
    applyFrame(window) {
        const g = window.geometry;
        const e = window.expandedGeometry;
        if (e.width <= 0 || e.height <= 0) {
            return;
        }
        effect.setUniform(this.shader, "uFrameUV",
            [(g.x - e.x) / e.width, (g.y - e.y) / e.height, g.width / e.width, g.height / e.height]);
        effect.setUniform(this.shader, "uFrameSize", [g.width, g.height]);
    }

    manage(window) {
        if (!CyberBarEffect.isBar(window) || window.cyberBar) {
            return;
        }
        this.applyFrame(window);
        window.windowFrameGeometryChanged.connect(() => this.applyFrame(window));
        // set(): diferente do animate, fica aplicado até ser cancelado (ou a janela sumir).
        window.cyberBar = set({
            window: window,
            duration: 1,
            keepAlive: false,
            animations: [{
                type: Effect.ShaderUniform,
                fragmentShader: this.shader,
                uniform: "uOn",
                from: 1.0,
                to: 1.0
            }]
        });
    }
}

new CyberBarEffect();
