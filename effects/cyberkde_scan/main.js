// CyberKDE Scan — abertura e fechamento de janelas (UI kit CyberKDE, seções 12.2 e 13).
// Estrutura baseada no efeito "scale" do KWin e no Burn My Windows (GPL-3.0-or-later).
// O shader desenha região de destino, moldura e varredura; aqui só se controla o tempo.

"use strict";

const blacklist = [
    // Tela de sair e splash têm animações próprias.
    "ksmserver ksmserver",
    "ksmserver-logout-greeter ksmserver-logout-greeter",
    "ksplashqml ksplashqml",
];

function hexToVec3(hex) {
    const v = parseInt(hex.replace("#", ""), 16);
    return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255];
}

class CyberScanEffect {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.cleanupForcedRoles.bind(this));
        effects.windowAdded.connect(this.slotWindowAdded.bind(this));
        effects.windowClosed.connect(this.slotWindowClosed.bind(this));
        effects.windowDataChanged.connect(this.slotWindowDataChanged.bind(this));

        this.shader = effect.addFragmentShader(Effect.MapTexture, "scan.frag");
        this.loadConfig();
    }

    loadConfig() {
        this.openDuration = animationTime(effect.readConfig("OpenDuration", 320));
        this.closeDuration = animationTime(effect.readConfig("CloseDuration", 200));
        this.slide = effect.readConfig("Slide", 8);
        this.frameColor = hexToVec3(effect.readConfig("FrameColor", "#F75049"));
        this.scanColor = hexToVec3(effect.readConfig("ScanColor", "#5EF6FF"));
        this.surface = hexToVec3(effect.readConfig("Surface", "#12121C"));
    }

    // O shader é um só para todas as janelas: os uniforms são renovados a cada animação.
    applyUniforms(opening) {
        effect.setUniform(this.shader, "uForOpening", opening ? 1.0 : 0.0);
        effect.setUniform(this.shader, "uFrameColor", this.frameColor);
        effect.setUniform(this.shader, "uScanColor", this.scanColor);
        effect.setUniform(this.shader, "uSurface", this.surface);
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
        if (effects.hasActiveFullScreenEffect || this.openDuration === 0) {
            return;
        }
        if (!CyberScanEffect.shouldAnimate(window) || !window.visible) {
            return;
        }
        if (effect.isGrabbed(window, Effect.WindowAddedGrabRole)) {
            return;
        }
        this.setupForcedRoles(window);
        this.applyUniforms(true);
        window.cyberScanIn = animate({
            window: window,
            duration: this.openDuration,
            animations: [
                {
                    type: Effect.ShaderUniform,
                    fragmentShader: this.shader,
                    uniform: "uProgress",
                    curve: QEasingCurve.Linear,
                    from: 0.0,
                    to: 1.0
                },
                {
                    type: Effect.Translation,
                    curve: QEasingCurve.OutCubic,
                    from: { value1: 0.0, value2: this.slide },
                    to: { value1: 0.0, value2: 0.0 }
                }
            ]
        });
    }

    slotWindowClosed(window) {
        if (effects.hasActiveFullScreenEffect || this.closeDuration === 0) {
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
        this.applyUniforms(false);
        window.cyberScanOut = animate({
            window: window,
            duration: this.closeDuration,
            animations: [
                {
                    type: Effect.ShaderUniform,
                    fragmentShader: this.shader,
                    uniform: "uProgress",
                    curve: QEasingCurve.Linear,
                    from: 0.0,
                    to: 1.0
                },
                {
                    type: Effect.Translation,
                    curve: QEasingCurve.InCubic,
                    from: { value1: 0.0, value2: 0.0 },
                    to: { value1: 0.0, value2: this.slide * 0.75 }
                }
            ]
        });
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
