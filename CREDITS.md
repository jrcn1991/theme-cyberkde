# Credits and licenses

**CyberKDE** — Copyright (C) 2026 Rafael Neves.

## Code — GPL-3.0-or-later

The `cyberkde` script, the installers, the generators (`generator/`, `modules/*/generator/`), the KWin effects, the QML of the login screen and splash, and every theme file they generate are licensed under the GNU General Public License, version 3 or later. See [LICENSE](LICENSE).

## Dolphin and Konsole — GPL

The patches in `dolphin/` and `konsole/` modify [Dolphin](https://invent.kde.org/system/dolphin) and [Konsole](https://invent.kde.org/utilities/konsole), which are © the KDE community and licensed under the GPL. The patches are distributed under the same terms.

The optional animated Dolphin and Konsole (`cyberkde animados`) are binary packages published in this repository's releases (tags `apps-*`). Each one is built by the `.github/workflows/apps.yml` workflow from the unmodified KDE source at the tag matching the version Ubuntu ships, plus the patch in this repository at the release commit. That source, together with `scripts/empacotar-apps.sh`, is the complete corresponding source of the packages.

## Latte Dock NG — GPL-2.0-or-later

The dock in the screenshots is [Latte Dock NG](https://github.com/jrcn1991/latte-dock-ng) as maintained in the jrcn1991/latte-dock-ng fork. The lineage is:

- [Latte Dock](https://invent.kde.org/plasma/latte-dock), © Michail Vourlakos, Smith AR and the KDE community;
- [Latte Dock NG](https://github.com/ruizhi-lab/latte-dock-ng), the Plasma 6/Wayland port by Ruizhi Zhong;
- [jrcn1991/latte-dock-ng](https://github.com/jrcn1991/latte-dock-ng), a fork of that port with a security review and hardening, used by this theme.

The theme contains no Latte code. `cyberkde latte` installs the package from that fork's releases, pinned to a reviewed version and checked by SHA-256.

## Artwork — CC BY-SA 4.0

The icons (`assets/icons/ai-final`) and the wallpapers (`assets/wallpapers`) were created for this project with the help of AI image generators, then cleaned up, recolored and resized by the project's own scripts. They are licensed under Creative Commons Attribution-ShareAlike 4.0 International. See [LICENSES/CC-BY-SA-4.0.txt](LICENSES/CC-BY-SA-4.0.txt).

The Dolphin icon is an original cyborg war-veteran dolphin, a nod to Jones from the film *Johnny Mnemonic* (1995). It is not a depiction of the film's character and is not affiliated with the film's rights holders.

## Fonts — SIL Open Font License 1.1

- **Rajdhani** © Indian Type Foundry: `assets/fonts/OFL-Rajdhani.txt`.
- **Orbitron** © The Orbitron Project Authors: `assets/fonts/OFL-Orbitron.txt`.

## Inherited icons

The CyberKDE icon theme inherits **Breeze Dark** (© KDE, LGPL-3.0) for every icon it does not define. Some small sizes are symbolic links to the Breeze files already installed on your system. No Breeze file is copied into this repository.

## Trademarks

The app icons for Konsole, Microsoft Edge and Obsidian are original reinterpretations in the CyberKDE style, made so the panel matches the theme. *Microsoft Edge* is a trademark of Microsoft Corporation and *Obsidian* is a trademark of Dynalist Inc.; they are used only to name the apps these icons stand in for, with no affiliation or endorsement.

*Cyberpunk 2077* is a trademark of CD PROJEKT S.A. This is an independent fan project, not affiliated with or endorsed by CD PROJEKT. KDE and Plasma are trademarks of KDE e.V.
