// CyberKDE Popups — popups do Plasma, menus, dicas e notificações (UI kit CyberKDE, A07, A11 e A12).
// Faz o papel dos efeitos "fadingpopups" e "slidingpopups" do sistema: a fase "plasma" desliga os
// dois e liga este. Estrutura baseada no fadingpopups do KWin (GPL-2.0-or-later) e no cyberkde_scan.
//
// Um só shader serve a todas as janelas, por isso o que muda por janela (tipo, lado de origem,
// abrir ou fechar) vai codificado no próprio valor animado de uProgress:
//     uProgress = código * 2 + t   (t de 0 a 1)
//     código    = fechando * 16 + tipo * 4 + lado
// Assim duas animações simultâneas (um menu e uma dica, por exemplo) não disputam uniforms.

"use strict";

// @tokens-begin (regravado por modules/plasma/generator/gen_plasma.py a partir de tokens/cyberkde.json)
const TOKENS = {
    "micro": 80,
    "fast": 140,
    "standard": 220,
    "close": 160,
    "red": "#F75049",
    "cyan": "#5EF6FF",
    "surface": "#12121C"
};
// @tokens-end

const SIDE = { top: 0, bottom: 1, left: 2, right: 3 };
const KIND = { popup: 0, notification: 1, menu: 2, fade: 3 };

const blacklist = [
    // Fundo da tela de bloqueio, tela de sair e splash têm animações próprias.
    "ksmserver ksmserver",
    "ksmserver-logout-greeter ksmserver-logout-greeter",
    "kscreenlocker_greet kscreenlocker_greet",
    "ksplashqml ksplashqml",
];

function hexToVec3(hex) {
    const v = parseInt(String(hex).replace("#", ""), 16);
    return [((v >> 16) & 255) / 255, ((v >> 8) & 255) / 255, (v & 255) / 255];
}

function isShellPopup(window) {
    const cls = String(window.windowClass || "");
    return cls.indexOf("plasmashell") === 0 || cls.indexOf("latte-dock") !== -1;
}

// Perfil de animação da janela; null = fica fora deste efeito (como no fadingpopups).
function profileOf(window) {
    if (blacklist.indexOf(window.windowClass) !== -1) {
        return null;
    }
    if (window.notification || window.criticalNotification) {
        return "notification";
    }
    if (window.appletPopup) {          // menu iniciar, calendário, bandeja (plasmashell e Latte)
        return "popup";
    }
    if (window.tooltip) {
        return "tooltip";
    }
    if (window.popupMenu || window.dropdownMenu || window.comboBox) {
        return "menu";
    }
    if (window.popupWindow) {
        return isShellPopup(window) ? "popup" : "menu";
    }
    if (window.outline) {
        return "fade";
    }
    if (!window.managed) {
        // Janelas utilitárias sem gerenciamento (ex.: sugestões da barra de endereço) não animam.
        return window.utility ? null : "fade";
    }
    if (window.splash || window.toolbar || window.onScreenDisplay) {
        return "fade";
    }
    return null;
}

function screenOf(window) {
    try {
        const g = window.screen && window.screen.geometry;
        if (g && g.width > 0) {
            return g;
        }
    } catch (e) {
        // Versões sem Output.geometry exposto ao JS: usa a área total.
    }
    return effects.virtualScreenGeometry;
}

// Lado de onde a janela "nasce" (o acionador).
function sideOf(window, how) {
    const g = window.geometry;
    if (how === "edge" || how === "hedge") {
        const s = screenOf(window);
        const d = [
            g.y - s.y,                                  // topo
            (s.y + s.height) - (g.y + g.height),        // base
            g.x - s.x,                                  // esquerda
            (s.x + s.width) - (g.x + g.width),          // direita
        ];
        if (how === "hedge") {                          // notificações: só bordas laterais
            return d[2] < d[3] ? SIDE.left : SIDE.right;
        }
        let best = 0;
        for (let i = 1; i < 4; ++i) {
            if (d[i] < d[best]) {
                best = i;
            }
        }
        return best;
    }
    if (how === "cursor") {                             // menus e dicas: abrem para longe do ponteiro
        try {
            const c = effects.cursorPos;
            return c.y <= g.y + g.height / 2 ? SIDE.top : SIDE.bottom;
        } catch (e) {
            return SIDE.top;
        }
    }
    return SIDE.top;
}

// Deslocamento inicial: a janela começa encostada no acionador e se afasta dele.
function offset(side, amount) {
    switch (side) {
    case SIDE.top: return { value1: 0.0, value2: -amount };
    case SIDE.bottom: return { value1: 0.0, value2: amount };
    case SIDE.left: return { value1: -amount, value2: 0.0 };
    default: return { value1: amount, value2: 0.0 };
    }
}

class CyberPopupsEffect {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effects.windowAdded.connect(this.slotWindowAdded.bind(this));
        effects.windowClosed.connect(this.slotWindowClosed.bind(this));
        effects.windowDataChanged.connect(this.slotWindowDataChanged.bind(this));
        this.shader = effect.addFragmentShader(Effect.MapTexture, "popup.frag");
        this.loadConfig();
    }

    loadConfig() {
        const rc = (key, fallback) => effect.readConfig(key, fallback);
        // Durações em ms antes do AnimationDurationFactor (aplicado em animationTime na hora de animar).
        this.profiles = {
            popup: {          // A07: revelação a partir do acionador, 140 ms, 4–6 px
                kind: KIND.popup, side: "edge",
                open: rc("PopupDuration", TOKENS.fast), close: rc("PopupCloseDuration", 120),
                slide: rc("PopupSlide", 5),
            },
            notification: {   // A12: entra 12 px pela borda, 220 ms
                kind: KIND.notification, side: "hedge",
                open: rc("NotificationDuration", TOKENS.standard), close: rc("NotificationCloseDuration", TOKENS.close),
                slide: rc("NotificationSlide", 12),
            },
            menu: {           // menus e listas suspensas: revelação curta, 4 px
                kind: KIND.menu, side: "cursor",
                open: rc("MenuDuration", 120), close: rc("MenuCloseDuration", 100),
                slide: rc("MenuSlide", 4),
            },
            tooltip: {        // A11: opacidade com deslocamento de 4 px, 120 ms
                kind: KIND.fade, side: "cursor",
                open: rc("TooltipDuration", 120), close: rc("TooltipCloseDuration", TOKENS.micro),
                slide: rc("TooltipSlide", 4),
            },
            fade: {           // o restante do antigo fadingpopups: só opacidade
                kind: KIND.fade, side: "none", open: 150, close: 150, slide: 0,
            },
        };
        this.red = hexToVec3(rc("FrameColor", TOKENS.red));
        this.cyan = hexToVec3(rc("ScanColor", TOKENS.cyan));
        this.applyColors();
    }

    applyColors() {
        effect.setUniform(this.shader, "uRed", this.red);
        // Só uniforms usados no shader: um uniform não usado é descartado na compilação e o
        // setUniform falha, abortando o script inteiro.
        effect.setUniform(this.shader, "uCyan", this.cyan);
    }

    run(window, profile, closing) {
        const duration = animationTime(closing ? profile.close : profile.open);
        if (duration < 2) {
            return null;  // AnimationDurationFactor = 0: sem animação
        }
        const side = sideOf(window, profile.side);
        const code = (closing ? 16 : 0) + profile.kind * 4 + side;
        const animations = [{
            type: Effect.ShaderUniform,
            fragmentShader: this.shader,
            uniform: "uProgress",
            curve: QEasingCurve.Linear,   // a curva fica no shader
            from: code * 2.0,
            to: code * 2.0 + 1.0,
        }];
        if (profile.slide > 0) {
            const shift = offset(side, closing ? profile.slide * 0.6 : profile.slide);
            animations.push({
                type: Effect.Translation,
                curve: closing ? QEasingCurve.InCubic : QEasingCurve.OutCubic,
                from: closing ? { value1: 0.0, value2: 0.0 } : shift,
                to: closing ? shift : { value1: 0.0, value2: 0.0 },
            });
        }
        this.applyColors();
        return animate({ window: window, duration: duration, animations: animations });
    }

    slotWindowAdded(window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        const name = profileOf(window);
        if (!name || !window.visible) {
            return;
        }
        if (animationTime(this.profiles[name].open) < 2) {
            return;
        }
        if (!effect.grab(window, Effect.WindowAddedGrabRole)) {
            return;
        }
        window.cyberPopupIn = this.run(window, this.profiles[name], false);
    }

    slotWindowClosed(window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        const name = profileOf(window);
        if (!name || !window.visible || window.skipsCloseAnimation) {
            return;
        }
        if (animationTime(this.profiles[name].close) < 2) {
            return;
        }
        if (!effect.grab(window, Effect.WindowClosedGrabRole)) {
            return;
        }
        if (window.cyberPopupIn) {
            cancel(window.cyberPopupIn);
            delete window.cyberPopupIn;
        }
        window.cyberPopupOut = this.run(window, this.profiles[name], true);
    }

    // Outro efeito tomou a janela: desiste da nossa animação.
    slotWindowDataChanged(window, role) {
        if (role == Effect.WindowAddedGrabRole) {
            if (window.cyberPopupIn && effect.isGrabbed(window, role)) {
                cancel(window.cyberPopupIn);
                delete window.cyberPopupIn;
            }
        } else if (role == Effect.WindowClosedGrabRole) {
            if (window.cyberPopupOut && effect.isGrabbed(window, role)) {
                cancel(window.cyberPopupOut);
                delete window.cyberPopupOut;
            }
        }
    }
}

new CyberPopupsEffect();
