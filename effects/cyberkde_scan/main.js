// CyberKDE Scan — abertura e fechamento de janelas (UI kit CyberKDE, seções 12.2 e 13), com um
// catálogo de variantes escolhidas em kwinrc [Effect-cyberkde_scan] (chaves em contents/config/main.xml).
// Estrutura baseada no efeito "scale" do KWin e no Burn My Windows (GPL-3.0-or-later).
// O shader desenha cada variante; aqui só se escolhe a variante e se controla o tempo.
// Só abrir e fechar: minimizar e maximizar ficam sem animação deste efeito, de propósito.
// "Primeira vez" (PrimeiraVezVariante): a primeira janela de cada app (windowClass) desde que o efeito
// foi carregado (a cada sessão) abre com uma montagem mais longa; as seguintes, com a variante normal.

"use strict";

const blacklist = [
    // Tela de sair e splash têm animações próprias.
    "ksmserver ksmserver",
    "ksmserver-logout-greeter ksmserver-logout-greeter",
    "ksplashqml ksplashqml",
];

// id → [número no shader, abrir (ms), fechar (ms), desliza 8 px].
// Mesma ordem e mesmos tempos de variantes.json (conferir.py confere).
const VARIANTES = {
    scan: [0, 320, 200, true],
    moldura: [1, 420, 260, true],
    glitch: [2, 300, 200, false],
    dados: [3, 420, 300, false],
    holograma: [4, 380, 240, true],
    crt: [5, 360, 240, false],
    decodificar: [6, 420, 260, true],
    chanfro: [7, 320, 200, false],
    braindance: [8, 380, 240, false],
    cacos: [9, 420, 280, false],
    convergir: [10, 420, 260, false],
    desintegrar: [11, 400, 300, false],
    terminal: [12, 450, 280, true],
    neon: [13, 420, 260, true],
    modal: [14, 440, 280, true],
    pulso: [15, 400, 240, true],
    pixel: [16, 360, 220, false],
    persiana: [17, 340, 220, false],
    portas: [18, 340, 220, false],
    radar: [19, 380, 240, false],
    fade: [20, 150, 120, false],
};

// Cores da paleta: o "cyberkde install" troca estes valores pelos da paleta atual.
const COR_DESTAQUE = "#F75049";
const COR_SECUNDARIA = "#5EF6FF";
const COR_SUPERFICIE = "#12121C";
const DESLIZE = 8; // px, deslocamento máximo de entrada (UI kit, A04)

function hexToVec3(hex) {
    const v = parseInt(hex.replace("#", ""), 16);
    return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255];
}

// Variante pelo id: "nenhuma" (ou vazio no fechar, tratado antes) desliga; id desconhecido vira scan.
function variante(id) {
    id = String(id === undefined || id === null ? "" : id).trim();
    if (id === "nenhuma") {
        return null;
    }
    const v = VARIANTES[id] || VARIANTES.scan;
    return { numero: v[0], abrir: v[1], fechar: v[2], desliza: v[3] };
}

function numero(valor, padrao) {
    const n = Number(valor);
    return isFinite(n) ? n : padrao;
}

class CyberScanEffect {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.cleanupForcedRoles.bind(this));
        effects.windowAdded.connect(this.slotWindowAdded.bind(this));
        effects.windowClosed.connect(this.slotWindowClosed.bind(this));
        effects.windowDataChanged.connect(this.slotWindowDataChanged.bind(this));

        this.shader = effect.addFragmentShader(Effect.MapTexture, "scan.frag");
        // Apps que já abriram uma janela nesta sessão (windowClass → true). Não zera no reconfigure.
        this.vistos = {};
        this.loadConfig();
    }

    loadConfig() {
        const abrirId = effect.readConfig("AbrirVariante", "scan");
        let fecharId = effect.readConfig("FecharVariante", "");
        if (fecharId === undefined || fecharId === null || String(fecharId).trim() === "") {
            fecharId = abrirId;
        }
        this.abrir = variante(abrirId);
        this.fechar = variante(fecharId);
        // Duração escolhida (ms) ou, sem escolha (-1), a da variante no catálogo.
        const od = numero(effect.readConfig("OpenDuration", -1), -1);
        const cd = numero(effect.readConfig("CloseDuration", -1), -1);
        this.openMs = this.abrir ? (od >= 0 ? od : this.abrir.abrir) : 0;
        this.closeMs = this.fechar ? (cd >= 0 ? cd : this.fechar.fechar) : 0;
        this.openDuration = animationTime(this.openMs);
        this.closeDuration = animationTime(this.closeMs);
        // Primeira vez: id ou "nenhuma" (padrão); duração escolhida ou 1,6 × a da variante (até 700 ms).
        this.primeira = variante(effect.readConfig("PrimeiraVezVariante", "nenhuma") || "nenhuma");
        const pd = numero(effect.readConfig("PrimeiraVezDuration", -1), -1);
        this.primeiraMs = this.primeira ? (pd >= 0 ? pd : Math.min(700, Math.round(this.primeira.abrir * 1.6))) : 0;
        this.primeiraDuration = animationTime(this.primeiraMs);
        const intensidade = Math.min(100, Math.max(0, numero(effect.readConfig("Intensidade", 60), 60)));
        // Iguais para todas as janelas; a variante e o sentido vão por janela (ver animar).
        effect.setUniform(this.shader, "uIntensidade", intensidade / 100);
        effect.setUniform(this.shader, "uFrameColor", hexToVec3(COR_DESTAQUE));
        effect.setUniform(this.shader, "uScanColor", hexToVec3(COR_SECUNDARIA));
        effect.setUniform(this.shader, "uSurface", hexToVec3(COR_SUPERFICIE));
    }

    // Um uniform que fica constante durante a animação: assim cada janela leva a sua variante,
    // mesmo com uma abrindo e outra fechando ao mesmo tempo (o shader é um só).
    constante(uniform, valor) {
        return {
            type: Effect.ShaderUniform,
            fragmentShader: this.shader,
            uniform: uniform,
            curve: QEasingCurve.Linear,
            from: valor,
            to: valor
        };
    }

    animar(window, v, abrindo, duracao) {
        const animations = [
            {
                type: Effect.ShaderUniform,
                fragmentShader: this.shader,
                uniform: "uProgress",
                curve: QEasingCurve.Linear,
                from: 0.0,
                to: 1.0
            },
            this.constante("uVariante", v.numero),
            this.constante("uAbrir", abrindo ? 1.0 : 0.0),
            this.constante("uDuracao", duracao)
        ];
        if (v.desliza) {
            animations.push(abrindo ? {
                type: Effect.Translation,
                curve: QEasingCurve.OutCubic,
                from: { value1: 0.0, value2: DESLIZE },
                to: { value1: 0.0, value2: 0.0 }
            } : {
                type: Effect.Translation,
                curve: QEasingCurve.InCubic,
                from: { value1: 0.0, value2: 0.0 },
                to: { value1: 0.0, value2: DESLIZE * 0.75 }
            });
        }
        return animate({ window: window, duration: duracao, animations: animations });
    }

    static shouldAnimate(window) {
        // Janelas do plasmashell só quando têm decoração (diálogos de configuração).
        if (window.windowClass == "plasmashell plasmashell"
                || window.windowClass == "plasmashell org.kde.plasmashell") {
            return window.hasDecoration;
        }
        // Evita o seletor Alt+Tab e afins.
        if (!window.hasDecoration && window.onAllDesktops) {
            return false;
        }
        if (blacklist.indexOf(window.windowClass) != -1) {
            return false;
        }
        if (window.hasDecoration) {
            return true;
        }
        // Menus, dicas e popups ficam com o efeito de popups do sistema.
        if (window.popupWindow || window.lockScreen || window.outline || !window.managed) {
            return false;
        }
        return window.normalWindow || window.dialog;
    }

    setupForcedRoles(window) {
        window.setData(Effect.WindowForceBackgroundContrastRole, true);
        window.setData(Effect.WindowForceBlurRole, true);
    }

    cleanupForcedRoles(window) {
        window.setData(Effect.WindowForceBackgroundContrastRole, null);
        window.setData(Effect.WindowForceBlurRole, null);
    }

    slotWindowAdded(window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!CyberScanEffect.shouldAnimate(window) || !window.visible) {
            return;
        }
        if (effect.isGrabbed(window, Effect.WindowAddedGrabRole)) {
            return;
        }
        // Primeira janela deste app na sessão: a montagem da "primeira vez", se escolhida.
        const classe = String(window.windowClass || "");
        const primeira = classe !== "" && !this.vistos[classe];
        if (classe !== "") {
            this.vistos[classe] = true;
        }
        let v = this.abrir;
        let duracao = this.openDuration;
        if (primeira && this.primeira && this.primeiraDuration > 0) {
            v = this.primeira;
            duracao = this.primeiraDuration;
        }
        if (!v || duracao === 0) {
            return;
        }
        this.setupForcedRoles(window);
        window.cyberScanIn = this.animar(window, v, true, duracao);
    }

    slotWindowClosed(window) {
        if (effects.hasActiveFullScreenEffect || !this.fechar || this.closeDuration === 0) {
            return;
        }
        if (!CyberScanEffect.shouldAnimate(window) || !window.visible || window.skipsCloseAnimation) {
            return;
        }
        if (effect.isGrabbed(window, Effect.WindowClosedGrabRole)) {
            return;
        }
        if (window.cyberScanIn) {
            cancel(window.cyberScanIn);
            delete window.cyberScanIn;
        }
        this.setupForcedRoles(window);
        window.cyberScanOut = this.animar(window, this.fechar, false, this.closeDuration);
    }

    slotWindowDataChanged(window, role) {
        if (role == Effect.WindowAddedGrabRole) {
            if (window.cyberScanIn && effect.isGrabbed(window, role)) {
                cancel(window.cyberScanIn);
                delete window.cyberScanIn;
                this.cleanupForcedRoles(window);
            }
        } else if (role == Effect.WindowClosedGrabRole) {
            if (window.cyberScanOut && effect.isGrabbed(window, role)) {
                cancel(window.cyberScanOut);
                delete window.cyberScanOut;
                this.cleanupForcedRoles(window);
            }
        }
    }
}

new CyberScanEffect();
