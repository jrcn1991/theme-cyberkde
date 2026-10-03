# CyberKDE

A cyberpunk theme for KDE Plasma 6, inspired by the menus of Cyberpunk 2077. I made it for my own desktop and decided to share it.

It changes the colors, the windows, the icons, the terminal and the login screen, and adds a few animations. Turn it on with `cyberkde on`; `cyberkde off` puts everything back the way it was.

*[Leia em português](README.pt-BR.md)*

![CyberKDE in motion: windows opening with the scan effect, the Dolphin cascade, Konsole, the menu and an accent-color change](assets/readme/cyberkde.gif)

![CyberKDE desktop](assets/loja/desktop.png)

| | |
|---|---|
| ![Dolphin with the CyberKDE icons](assets/loja/dolphin.png) | ![Konsole with the CyberKDE palette](assets/loja/konsole.png) |
| ![Application menu](assets/loja/menu.png) | ![SDDM login screen](assets/loja/login.png) |

The screenshots show what a fresh install with `./instalar.sh --ligar` gives you: the bar on top and a [Latte Dock NG](https://github.com/jrcn1991/latte-dock-ng) dock, which the installer offers to install on Ubuntu 26.04.

> Fan project, not affiliated with CD PROJEKT. Nothing here comes from the game: every image was made for this theme.

## What it themes

| Part | What changes |
|---|---|
| Colors + Kvantum | color scheme and a chamfered Kvantum style for all Qt/KDE apps |
| Layout | bar on top and a dock at the bottom, as in the screenshots (fresh installs; `cyberkde layout`) |
| Windows | Aurorae decoration and a KWin open/close "scan" animation |
| Plasma | Plasma style (panel, menus, popups, notifications) and a popup animation effect |
| Icons | folders, places, file types and a cyborg-dolphin Dolphin icon; everything else inherits Breeze Dark |
| Konsole | color scheme and profile |
| Login | SDDM login screen, splash and lock-screen background |
| Wallpaper | desktop and lock screen |
| Accent color | `cyberkde color`-style regeneration of the whole theme in any color |
| Optional | Dolphin with a cascading folder reveal and Konsole with animated text/cursor, both built from source with a small patch |

## Install (full version, recommended)

Requirements: KDE Plasma 6, `python3`, ImageMagick, `qdbus6`, Breeze icons and Kvantum for Qt 6.

```bash
# Ubuntu / Debian / Kubuntu
sudo apt install git python3 imagemagick qdbus-qt6 kf6-breeze-icon-theme qt-style-kvantum
# other distributions: install the equivalent packages (the installer lists anything missing)

git clone https://github.com/jrcn1991/theme-cyberkde.git
cd theme-cyberkde
./instalar.sh --ligar    # install and switch it on (./instalar.sh only installs)
```

Before copying anything, the installer checks the requirements and the known problems below, and prints the fix for each one. Items marked `✗` stop it; items marked `!` should be fixed first (`--continuar` goes ahead anyway). You can run the same check at any time with `cyberkde checar`.

On Ubuntu 26.04 it also offers to install [Latte Dock NG](https://github.com/jrcn1991/latte-dock-ng), the dock in the screenshots (`--sem-latte` skips it): the package built from a security-reviewed commit of the [jrcn1991/latte-dock-ng](https://github.com/jrcn1991/latte-dock-ng) fork of [Latte Dock NG](https://github.com/ruizhi-lab/latte-dock-ng) (itself a Plasma 6 port of KDE's [Latte Dock](https://invent.kde.org/plasma/latte-dock)), checked against a SHA-256 fixed in the theme. Latte is only offered where it has been validated end to end (for now, Ubuntu 26.04); elsewhere the dock is a floating Plasma panel. Nothing is compiled on your machine. If you already use Latte, the theme uses yours.

The install is per user; root is only needed for the Latte package and the login screen, and it asks. The program goes to `~/.local/opt/cyberkde` and the command to `~/.local/bin/cyberkde`, so the cloned folder can be deleted afterwards. To update, pull a new version and run `./instalar.sh` again.

### Known problems

| Problem | Fix |
|---|---|
| `cyberkde: command not found` right after installing | `~/.local/bin` only joins the `PATH` at login, when the folder already exists. Log out and back in; until then use `~/.local/bin/cyberkde` or `export PATH="$HOME/.local/bin:$PATH"`. `./instalar.sh --ligar` does not need it. |
| Black login screen after reboot (Ubuntu with SDDM, no Xorg) | SDDM must run on Wayland. `cyberkde checar` prints the `/etc/sddm.conf.d` file to create. Not caused by the theme. |
| No animations in a virtual machine | With software rendering (llvmpipe), KWin turns off every animation. Enable 3D acceleration in the VM. `cyberkde status` says whether the animations are loaded. |

## Use

The command-line interface is in Portuguese:

```
cyberkde on              # switch everything on
cyberkde off             # switch off and restore every original value
cyberkde status          # what is on (and whether the animations are loaded)
cyberkde checar          # requirements and known problems, with the fix for each
cyberkde layout tema     # bar on top + dock, as in the screenshots ('manter' keeps your panels)
cyberkde latte           # install the reviewed Latte Dock NG package (Ubuntu 26.04)
cyberkde cor '#5EF6FF'   # change the accent color ('cyberkde cor padrao' = back to red)
cyberkde papel ~/Pictures/mine.jpg   # use your own wallpaper ('cyberkde papel padrao' = theme's)
cyberkde on <part>       # a single part: dolphin, apps, janelas, icones, icones-sistema, konsole,
                         # plasma, barra-e-dock, papeis-de-parede, login
```

- **Reversible by design.** Every configuration key the theme changes is recorded with its original value the first time it is written, and every file it replaces is backed up. `cyberkde off` walks that record backwards.
- **Your panels come back too.** The bar and dock arrangement saves your Plasma panels first, and `cyberkde off` puts them back.
- **Root only for the login screen.** It lives in `/usr` and `/etc`, so `cyberkde` asks for your sudo password for that part only.
- **One theme at a time.** Switch off any other global theme tool before `cyberkde on`, and run `cyberkde off` before applying another one. The theme records as "original" whatever it finds when it switches on.

### Optional: animated Dolphin and Konsole

A cascading reveal when a folder loads (Dolphin) and decoding text with a cursor halo and trail (Konsole). They are Dolphin and Konsole with a small patch, shipped as ready-made packages built on Ubuntu 26.04 from the same version Ubuntu ships, and checked against a SHA-256 fixed in the theme. Nothing is compiled on your machine. They install next to the system apps (in `/opt`); the theme only points the launcher at them, and `cyberkde off` points it back.

```
cyberkde animados        # the installer offers this on Ubuntu 26.04
```

They are offered only on Ubuntu 26.04 and only while its Dolphin/Konsole version matches the package; after Ubuntu updates them, the system apps are used until new packages are published. `cyberkde on` simply skips them when they are not installed.

### Alongside AppleKDE

CyberKDE and [AppleKDE](https://github.com/jrcn1991/theme_apple_kde) never run mixed. If AppleKDE is on, `cyberkde on` first runs `applekde off`, checks that it really turned off, and only then applies; if it can't confirm (AppleKDE busy, a step needing root without a terminal), nothing is applied and it tells you what to run. `applekde on` does the same in the other direction. Without AppleKDE installed, nothing changes.

## Uninstall

```bash
cyberkde uninstall       # or ./desinstalar.sh
```

It switches the theme off, restores every original value and removes the theme files, your CyberKDE preferences and the program itself.

## KDE Store version

The pieces are also published on the [KDE Store](https://store.kde.org) (Global Theme, Plasma style, window decoration, Kvantum, icons, SDDM, color schemes, KWin effects, wallpaper), in the default red. That version installs from *System Settings → Get New…*. It has no accent-color regeneration, no Dolphin/Konsole animations and no one-command on/off, but it needs nothing beyond Plasma. `scripts/empacotar-loja.sh` builds those packages.

## Tested on

Kubuntu 26.04 and Ubuntu 26.04 (with Plasma added), Plasma 6.6, Wayland; also a clean Ubuntu VM with 4 GB of RAM. Other distributions with Plasma 6 should work. Reports are welcome in the issues.

## License

- Code, generators, patches and generated theme files: **GPL-3.0-or-later** (see [LICENSE](LICENSE)).
- Artwork (icons in `assets/icons`, wallpapers in `assets/wallpapers`): **CC BY-SA 4.0** (see [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt)).
- Fonts Rajdhani and Orbitron: **SIL Open Font License 1.1** (see `assets/fonts/`).

See [CREDITS.md](CREDITS.md) for details.
