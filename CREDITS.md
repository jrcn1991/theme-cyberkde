# Credits and licenses

**CyberKDE** — Copyright (C) 2026 Rafael Neves.

## Code — GPL-3.0-or-later

The `cyberkde` script, the installers, the generators (`generator/`, `modules/*/generator/`), the KWin effects, the QML of the login screen and splash, and every theme file they generate are licensed under the GNU General Public License, version 3 or later. See [LICENSE](LICENSE).

## Dolphin and Konsole — GPL

The patches in `dolphin/` and `konsole/` modify [Dolphin](https://invent.kde.org/system/dolphin) and [Konsole](https://invent.kde.org/utilities/konsole), which are © the KDE community and licensed under the GPL. The patches are distributed under the same terms.

The optional animated Dolphin and Konsole (`cyberkde animados`) are binary packages published in this repository's releases (tags `apps-*`). Each one is built by the `.github/workflows/apps.yml` workflow from the unmodified KDE source at the tag matching the version Ubuntu ships, plus the patch in this repository at the release commit. That source, together with `scripts/empacotar-apps.sh`, is the complete corresponding source of the packages.

## Dynamic island — GPL-3.0

The dynamic island (`app/ilha`) is a port to PyQt6 and QML of the island from Halo, a project by the same author, also under the GPL-3.0. Halo's weather icons, which have another license, were not copied.

## Phosphor Icons — MIT

The icons of the dynamic island (`app/ilha/qml/glifos.js`) come from [Phosphor Icons](https://phosphoricons.com), © Phosphor Icons, licensed under the MIT license.

## Latte Dock NG — GPL-2.0-or-later

The dock in the screenshots is [Latte Dock NG](https://github.com/jrcn1991/latte-dock-ng) as maintained in the jrcn1991/latte-dock-ng fork. The lineage is:

- [Latte Dock](https://invent.kde.org/plasma/latte-dock), © Michail Vourlakos, Smith AR and the KDE community;
- [Latte Dock NG](https://github.com/ruizhi-lab/latte-dock-ng), the Plasma 6/Wayland port by Ruizhi Zhong;
- [jrcn1991/latte-dock-ng](https://github.com/jrcn1991/latte-dock-ng), a fork of that port with a security review and hardening, used by this theme.

The theme contains no Latte code. `cyberkde latte` installs the package from that fork's releases, pinned to a reviewed version and checked by SHA-256.

## Cyber Fence widget — GPL-2.0-or-later

The Cyber Fence widget (`modules/widgets/plasmoides/org.cyberkde.cerca`) is derived from KDE Plasma's folder view, `org.kde.desktopcontainment` (plasma-desktop): © Eike Hein, Marco Martin, Sebastian Kügler and the other KDE contributors named in each file's header. The derived files keep their copyright headers and the GPL-2.0-or-later license. The theme colors, the frame and the roll-up logic were added by this project. The roll-up behavior follows the idea of Stardock Fences; no code from it, or from any other fence program, is included.

## Online services

Only the widgets and options you turn on make these requests. None of them needs an account, and no service code is included.

- **Weather**: forecast and city search from [Open-Meteo](https://open-meteo.com).
- **Exchange**: rates from [AwesomeAPI](https://docs.awesomeapi.com.br).
- **Network**: the public IP comes from [ipify](https://www.ipify.org), and only if you turn that option on (it is off by default).
- **Dynamic island**: off by default, synced lyrics come from [LRCLIB](https://lrclib.net) (it receives the title and artist) and weather from Open-Meteo.
- **News**: the feeds you choose. The default list has G1 Tecnologia, Tecnoblog and Ars Technica; headlines belong to their publishers.

## Artwork — CC BY-SA 4.0

The icons (`assets/icons/ai-final`) and the wallpapers (`assets/wallpapers`) were created for this project with the help of AI image generators, then cleaned up, recolored and resized by the project's own scripts. They are licensed under Creative Commons Attribution-ShareAlike 4.0 International. See [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt).

The FUI wallpaper, the FUI dashboard and its modules, the Jukebox and Neon Radio styles and DATASHARD are original code and drawings for this theme (GPL-3.0-or-later), made after the look of the game's interface. No game asset is included in them, apart from the corporation logos described below.

The Dolphin icon is an original cyborg war-veteran dolphin, a nod to Jones from the film *Johnny Mnemonic* (1995). It is not a depiction of the film's character and is not affiliated with the film's rights holders.

## Fonts — SIL Open Font License 1.1

- **Rajdhani** © Indian Type Foundry: `assets/fonts/OFL-Rajdhani.txt`.
- **Orbitron** © The Orbitron Project Authors: `assets/fonts/OFL-Orbitron.txt`.

## Inherited icons

The CyberKDE icon theme inherits **Breeze Dark** (© KDE, LGPL-3.0) for every icon it does not define. Some small sizes are symbolic links to the Breeze files already installed on your system. No Breeze file is copied into this repository.

## Trademarks

The app icons for Konsole, Microsoft Edge and Obsidian are original reinterpretations in the CyberKDE style, made so the panel matches the theme. *Microsoft Edge* is a trademark of Microsoft Corporation and *Obsidian* is a trademark of Dynalist Inc.; they are used only to name the apps these icons stand in for, with no affiliation or endorsement.

*Cyberpunk 2077* is a trademark of CD PROJEKT S.A. This is an independent fan project, not affiliated with or endorsed by CD PROJEKT. KDE and Plasma are trademarks of KDE e.V.

## Corporation logos — trademarks, not licensed

The corporation logos in `assets/corporacoes/` (Arasaka, Biotechnica, Delamain, Dynalar, Kang Tao, Kiroshi, Militech, NetWatch, Night Corp, Petrochem, Segotari, Trauma Team and Zetatech) are trademarks of CD PROJEKT RED (*Cyberpunk 2077*) and/or R. Talsorian Games (*Cyberpunk RED*, *Cyberpunk 2020*). They are included as a non-profit fan tribute, so that `cyberkde corp` can show each corporation's mark, and are **not** covered by the GPL or CC BY-SA licenses of this project. The source of each file and how it was vectorized are listed in [assets/corporacoes/FONTES.md](assets/corporacoes/FONTES.md). Moore Tech has no logo in the theme and uses the theme's own blocks. The older provisional emblems are kept in `assets/corporacoes/genericos/`.

## README media

The animations in `assets/readme/` are recordings of the theme itself: the desktop captures come from a virtual KWin session (`kwin_wayland --virtual`) with the theme applied by `cyberkde corp`, the panel was recorded offscreen with its own QML, and the grids are made from the previews in `assets/previas/`. The transitions between desktop captures are composited in the style of the panel's glitch transition.

The Cyber Fence and DATASHARD animations and captures were recorded in an isolated nested KWin session with fictional folders. In the FUI dashboard picture, some machine data is blurred. The small "previews" of the widgets, fences and wallpapers come from `assets/previas/`.

The dynamic island and Jukebox/Neon Radio animations were recorded the same way, with a fake island object and a fake MPRIS player; the track and artist are fictional.
