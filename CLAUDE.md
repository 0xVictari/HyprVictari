# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

GNU Stow farm of dotfiles plus suckless builds, shared by two machines:

- **Desktop (CachyOS, Wayland; Cinnamon/Xorg as fallback session):** Hyprland + Waybar + Wofi + dunst. Stowed there: `zsh hyprland waybar wofi dunst kitty ohmyposh fastfetch zed`. Most `.config` dirs are folded symlinks into the repo, but `~/.config/hypr` and `~/.config/kitty` are real dirs with per-entry links: after adding a new top-level file/dir to a package, re-run `stow -R <package>` (a missing `themes` link once broke the Hyprland config).
- **Work laptop (Linux Mint 22, X11):** dwm (`victariwm`) + slstatus + sxhkd. `ohmyposh/`, `sxhkd/`, `dwm/`, `zsh/` and `clipboard/` are stowed here; `~/.config/zed/` is a local copy that has diverged from the repo on purpose.

zsh is shared by both machines and never keyed on hostname (it changes): `zsh/.zshrc` holds the common setup, Arch-only bits (`in`, pacman/AUR aliases) sit behind `$+commands[pacman]`, and `~/.config/zsh/conf.d/*.zsh` modules self-activate when their tools exist. `conf.d/dev.zsh` is the work dev environment: it only runs if mise is installed (the desktop has none), activates mise and sources `~/.config/zsh/cloud.zsh` (tf/tg/aws aliases, `asp`, `tfplan`). The toolchain is the `mise/` stow package (`~/.config/mise/config.toml`); new machine: `curl https://mise.run | sh && stow zsh mise && mise install`. The old `~/projects/.devcontainer` is abandoned (Zed native instead). Unversioned per-machine bits go in `~/.zshrc.local`. When stowing `zsh` on a machine without `~/.config/zsh`, `mkdir -p` it first so stow doesn't fold the whole dir into the repo.

Shell environment: zsh with Zap plugin manager, Oh-My-Posh prompt, kitty/ghostty terminals.

Oh-My-Posh (`ohmyposh/.config/oh-my-posh/config.toml`, shared by both machines): left = OS, user@host only over SSH, folder, git, root, status; right = node/go/python icons (venv name when active), terraform workspace (hidden when `default`), AWS profile pill (`display_default = false`; red when the profile matches `prod|prd|live`, same for the workspace), `took` for commands over 3 s, clock. Keep segment settings under `properties`: newer versions call them `options` but still read `properties`, and the laptop may run an older version. The terraform segment runs `terraform workspace show` (needs the binary and a `.terraform` dir). To test a change: `env -u POSH_SESSION_ID -u POSH_CONFIG oh-my-posh print right --config <file> --shell zsh --plain` (with the session vars set it renders the cached config); running shells pick it up after `exec zsh`.

The user writes in Spanish (rioplatense). **Confirm before structural changes** (rewriting scripts, moving files, changing workflows); small, requested edits can go ahead.

## Build Commands

The only compiled components are under `suckless/`. Always build as the user and only `install` with sudo (`sudo make clean install` leaves root-owned files in the repo).

### dwm (victariwm)

Generated from the dwm-flexipatch submodule with flexipatch-finalizer:

```bash
cd suckless
./build-victariwm.sh            # regenerate victariwm/ (review with git diff)
./build-victariwm.sh --install  # regenerate, build as user, install to /usr/local/bin/dwm with sudo
```

Restart dwm afterwards with `Super+Ctrl+Shift+q` (seamless restart keeps windows).

Sources of truth:

- `suckless/victariwm-src/patches.h` — which patches are enabled (`#define X_PATCH 1`). Based on flexipatch's `patches.def.h`.
- `suckless/victariwm/config.h` — runtime settings (keys, rules, fonts, colors, scratchpads). The script never overwrites it. For config-only changes: `make -C suckless/victariwm && sudo make -C suckless/victariwm install`.
- `suckless/victariwm-src/local/*.diff` — own code changes on the finalized output, applied by the script after the finalizer (`patch --no-backup-if-mismatch`). Currently only `freetag.diff`.
- `suckless/victariwm/config.def.h` — the finalizer's generated config, kept as reference: after enabling a patch, diff it against `config.h` and port new options by hand.

How the script works: `git archive` of the pinned flexipatch commit (independent of the submodule's working tree) → copy `patches.h` → finalizer → rename generated `config.h` to `config.def.h` → apply local diffs → `rsync --delete` into `victariwm/` excluding `config.h`. `OUT=/some/dir ./build-victariwm.sh` writes elsewhere (useful to test that regeneration reproduces `victariwm/` exactly).

### slstatus

Upstream submodule (`git.suckless.org/slstatus`) with the config kept outside it:

```bash
cd suckless
./build-slstatus.sh             # copy slstatus-src/config.h in, build; test with ./slstatus/slstatus -s
./build-slstatus.sh --install   # build, install with sudo, clean submodule, restart slstatus
```

Edit `suckless/slstatus-src/config.h`, never the copy inside the submodule.

### Updating upstreams

- **flexipatch:** `git -C suckless/dwm-flexipatch fetch && git -C suckless/dwm-flexipatch checkout origin/master`, then rebase `victariwm-src/patches.h` on the new `patches.def.h` keeping current values (new patches default to 0), run `./build-victariwm.sh`, port any new required options from `config.def.h` to `config.h` (e.g. 6.8 required `refreshrate`), and regenerate a local diff if it no longer applies cleanly. Test the build before committing the new submodule pointer.
- **slstatus:** checkout the new commit in `suckless/slstatus`, check `config.def.h` for structural changes, rebuild.

All other directories are pure configuration files with no build step.

## Architecture & Layout

```
hyprland/.config/hypr/     # Wayland WM (desktop, stowed; ~/.config/hypr is a real dir with per-entry links: restow after adding entries): hyprland.lua + style.lua, hypr{idle,paper,sunset}.conf, Scripts/
  themes/<theme>/           # One dir per theme (tokyonight, chicago95): see "Themes" below
waybar/.config/waybar/      # Status bar: config.jsonc + style.css are symlinks to themes/current
wofi/.config/wofi/          # Launcher: config (shared) + style.css (symlink to themes/current)
dunst/.config/dunst/        # Notifications (desktop): dunstrc is a symlink to themes/current (only overrides of /etc/dunst/dunstrc)
check.sh                    # Post-update checks (Hyprland/Waybar/hyprlock/hypridle/scripts); not a stow package

suckless/
  README.md                 # Keybinding cheat sheet (dwm + sxhkd), rules, rebuild steps — keep in sync with config.h/sxhkdrc
  victariwm/                # ACTIVE dwm build (finalized flexipatch output + local diffs)
  victariwm-src/patches.h   # Enabled patches
  victariwm-src/local/      # Own diffs applied after the finalizer (freetag.diff)
  build-victariwm.sh
  dwm-flexipatch/           # Submodule bakkeby/dwm-flexipatch (pinned; currently dwm 6.8, 1dc782b)
  flexipatch-finalizer/     # Submodule bakkeby/flexipatch-finalizer
  slstatus/                 # Submodule git.suckless.org/slstatus (pinned 675c839, 1.1 + 2026 fixes)
  slstatus-src/config.h     # slstatus config
  build-slstatus.sh
  # Old builds (dwm-current, vanilla dwm, vendored slstatus 1.0) live in git history; tag `suckless-pre-cleanup`

dwm/.dwm/autostart.sh       # X11 session startup (run by dwm's autostart patch; stowed to ~/.dwm). Must stay distro-agnostic (e.g. polkit agent path differs Debian/Arch)
dwm/.dwm/monitor-setup.sh   # Dual (HDMI-1 above eDP-1) / single layout + feh wallpaper refresh; used by sxhkd
sxhkd/.config/sxhkd/sxhkdrc # X11 app keybindings
clipboard/                  # clip-normalize script + systemd user unit (laptop only, X11)
install/                    # CachyOS installer checklist (README.md) + cachyos-post-install.sh (run with sudo: --core/--cinnamon/--hyprland/--apps/--dotfiles)
                            # + suckless-setup.sh (run as user, Debian or Arch family: --deps/--fonts/--build/--system/--dotfiles). Package lists live in the scripts; PACKAGES.md mirrors them. Artix scripts are in git history.
PACKAGES.md                 # Package inventory per machine
zsh/.zshrc                  # Shared shell config (Zap plugins, aliases, Arch-only `in` behind a pacman check)
zsh/.config/zsh/conf.d/     # Self-activating modules (dev.zsh: mise + cloud.zsh, only where mise exists)
zsh/.config/zsh/cloud.zsh   # AWS/Terraform/Terragrunt aliases and helpers
mise/.config/mise/config.toml # Dev toolchain (terraform, aws-cli, python, node, TUIs...)
ohmyposh/.config/oh-my-posh/config.toml   # Active prompt theme (stowed on both machines)
kitty/, ghostty/            # Terminal configs
fastfetch/.config/fastfetch/ # System info display
zed/.config/zed/            # Zed editor settings (stowed on desktop only)
```

Do not put loose files (READMEs, notes) inside stow packages like `dwm/` or `sxhkd/`: stow would link them into `$HOME`.

## Hyprland (desktop) — current state

Lua config (`hyprland.lua` + `style.lua`), Hyprland 0.57. The session stack (waybar, hypridle, hyprpaper, hyprsunset, wallpaper.sh, polkit, flameshot) is launched from `hl.on("hyprland.start")`, not systemd/uwsm (user preference: Hyprland owns its stack). Gotchas:

- Every `hl.bind` carries `{ description = "..." }`: `Super+F1` (`Scripts/keybinds.sh`) lists them in wofi from `hyprctl binds -j`, and `check.sh` warns on binds without one.
- With a Lua config, `hyprctl dispatch` takes Lua: `hyprctl dispatch 'hl.dsp.dpms({action = "on"})'`; the old `hyprctl dispatch dpms on` errors out (hypridle uses it).
- hyprpaper 0.8 IPC has no `preload`/`unload`; `hyprctl hyprpaper wallpaper "MON,PATH,contain"` loads by itself (exit 1 on failure). `wallpaper.sh` retries because it starts alongside hyprpaper.
- hyprsunset: schedule in `hyprsunset.conf` profiles; `Super+B` toggles 4000K/6500K over IPC. Avoid `identity`: hyprsunset doesn't reflect it in `temperature`.
- Waybar: temperatures use `hwmon-path-abs` (PCI path), since `hwmonN` numbering changes between boots. `custom/cava` is centered, so right-side modules must not have `max-length` (GTK ellipsizes them instead of shifting the center). `killall waybar` doesn't kill module children: continuous `exec` scripts must clean up (cava ignores SIGPIPE, so `cava.sh` kills it from an EXIT/TERM trap; no per-line subshells). `check.sh` runs test instances with `setsid` and kills the whole session: `$(timeout 4 waybar ...)` hung waiting on children holding the pipe. GTK CSS rejects `0%, 100%` in one keyframe block (Waybar won't start).
- Themes (`Super+T`, `Scripts/theme-switch.sh`): each `hyprland/.config/hypr/themes/<theme>/` holds `hypr.lua` (borders, gaps, rounding, blur, shadow, animations, `XCURSOR_*`), `theme.sh` (GTK/icon/cursor/font for gsettings; empty = value saved before the first switch in `~/.local/state/theme-switch/gtk-default`), `waybar.jsonc`/`waybar.css`, `wofi.css`, `dunstrc`, `hyprlock.conf`, `kitty.conf`. The active one is the gitignored symlink `themes/current`; the live files (waybar `config.jsonc`/`style.css`, wofi `style.css`, `dunstrc`, `hypr/hyprlock.conf`) are tracked relative symlinks to it, so edit the theme files, not those. `style.lua` keeps the theme-agnostic settings and `require`s `themes.current.hypr` (falls back to tokyonight). Every `hypr.lua` must set the same keys so nothing leaks after a switch. Waybar is started by `theme-switch.sh --init` from `hyprland.start` (creates `current` if missing). kitty: `kitty.conf` includes the tracked `themes/theme.conf` and then `globinclude current-theme.conf`; the switcher points `~/.config/kitty/current-theme.conf` (outside the repo, never inside the stowed `themes/`) at the theme and sends SIGUSR1. Wallpaper is not per theme (wallpaper.sh keeps rotating). New theme = copy a dir; `check.sh` checks every theme has all files. GTK4 and libadwaita apps follow `~/.config/gtk-4.0/{gtk.css,gtk-dark.css,assets}`, since the user CSS beats any theme (nwg-look had pinned it to Qogir-Dark, so pavucontrol stayed dark in Chicago95). The switcher links them from `GTK4_DIR` in theme.sh (relative to the theme) or, if it is empty, from `<GTK_THEME>/gtk-4.0`; GTK4 apps that are already open need a restart.
- Chicago95 theme: tiling with borders only (no hyprbars: the plugin breaks on Hyprland updates), navy active border, no rounding/blur/shadow/animations; Waybar is a bottom Win95 taskbar (Start = wofi, right click = theme picker, `wlr/taskbar`, sunken `group/notify`, `Apagar` button at the far right). Bevels are 4-color borders + inset box-shadow in GTK CSS. Bar height is 32: a `custom/*` module inside `group/notify` needs it (with 30 Waybar warns, `check.sh` fails, and it draws 32 anyway). Lists in `wofi.css` need `#scroll viewport, #inner-box` painted white, or they take the GTK theme's gray. The package has no GTK4 theme, so `themes/chicago95/gtk-4.0/gtk.css` (own CSS, layered over GTK4's Default or Adwaita) styles pavucontrol 6 and file-roller. GTK4 CSS has no `repeating-conic-gradient`; the checked-button dither is a `conic-gradient` tiled at 2px.
- Power menu (`Scripts/power-menu.sh`, `Super+Escape`, and the taskbar's `Apagar` button): `wofi --dmenu` styled by the active theme's `wofi.css` (power off, reboot, suspend, log out via `hl.dsp.exit()`, lock). Tokyonight's ⏻ button still opens wlogout. Needs `chicago95-theme` (AUR: GTK `Chicago95`, icons `Chicago95`, cursors `Chicago95 Standard Cursors Black`); missing pieces are skipped with a notification.
- Cursor themes: `CURSOR_THEME` (theme.sh) must equal `XCURSOR_THEME` (hypr.lua) and name a dir with `cursors/` that has the Wayland cursor-shape names (`default`, `pointer`, `text`); `check.sh` checks all three. If the name doesn't exist, the switcher skips `hyprctl setcursor` and the previous theme's cursor stays. That is how `Qogir-dark-cursors` (never installed; tokyonight uses `Qogir-Dark`) broke the cursor. `Chicago95_Cursor_*` only ship X11 names (`left_ptr`, `hand2`). Tokyonight sets GTK/icons explicitly (`Qogir-Dark`, `Papirus-Dark`; the GTK theme lives in `~/.themes`).
- Gaming mode detects Steam games via `reaper SteamLaunch AppId=`; the Steam client itself is not a game.

## dwm (victariwm) — current state

Enabled patches (besides bar modules, autostart, pertag, vanitygaps, restartsig, seamless_restart, movestack): statuscmd, scratchpads, fakefullscreen_client, shiftview_clients, sticky, focusdir, tagallmon, sendmon_center, alwayscenter, movecenter. Layouts: tile, monocle, fibonacci dwindle. Full key list in `suckless/README.md`.

Rules (`config.h`): Slack → tag 2 on monitor 0 (eDP-1); Telegram → tag 3; Gimp → tag 5; scratchpads `spterm` (kitty), `spbtop`, `spdocker` (lazydocker via the mise shim at `$HOME/.local/share/mise/shims`, run through `sh -c` so no username is hardcoded; dwm lacks the zsh PATH).

`freetag.diff` + `freetagclasses[] = { "Wfica" }` in `config.h`: Citrix's main window (non-floating) goes to the first empty tag of the largest monitor (HDMI), skipping tag 1 when there are 2+ monitors; with only the laptop, the first empty tag. It does not switch the view (user preference).

Monitors (Xinerama order): 0 = eDP-1 (1280x720, below), 1 = HDMI-1 (1920x1080, above).

Keybinding gotchas:

- `Super+Shift+x` (sxhkd) kills Citrix (`killall wfica`) — avoid binding `Super+x`-adjacent actions; movecenter uses `Super+g` for that reason.
- `Super+Shift+s` is flameshot (sxhkd), `Super+Shift+b` kills Brave, `Super+Shift+m` runs `monitor-setup.sh`.
- `MODKEY` is `Mod4` (Super), so flexipatch defaults written as `MODKEY|Mod4Mask` collapse to plain Super and can clash.
- Brave profiles cannot be targeted by rules: all windows share WM_CLASS/role and titles don't include the profile.

## slstatus — current bar

`[mic, only when open] | volume (mute icon) | clock | SSID (5 chars) + band 2G/5G/6G + signal | CPU % + package temp | RAM % | battery state + %`, colored with status2d `^c#...^`, `|` dividers. Gotchas:

- `awk` needs `LC_ALL=C` (Spanish locale parses `0.55` as 0).
- Temperature reads `/sys/class/thermal/thermal_zone16/temp` (`x86_pkg_temp`); if it shows `n/a` after a kernel update, find the zone again.
- Nerd Font "md" glyphs (U+F0000+) render wider and eat the following space; flexipatch 6.8 removed status2d padding, so the status needs a leading space.
- Clickable blocks (statuscmd, no dwmblocks): each block's format starts with an octal marker `\001`…`\006` (CPU and RAM share `\005`); dwm runs `statuscmds[]` in `victariwm/config.h` under `/bin/sh` (dash) with `$BUTTON`. Write markers in octal: `\x01` followed by a hex digit swallows it. Adding a block = new marker + new `statuscmds[]` entry.
- Band comes from `iwgetid wlp1s0 -f -r` (Hz). Interval is 1 s for everything; keep `run_command`s cheap (no `docker`, no network calls).

## Clipboard fix (Zed -> Citrix, laptop only)

Zed on X11 only offers `UTF8_STRING` / `text/plain;charset=utf-8`; the Citrix Workspace client (`wfica`) asks for `STRING`/`TEXT`/`COMPOUND_TEXT`, so pasting from Zed into the VDI (and some local X11 apps) fails. CopyQ does not fix it (it only records history, it does not re-own the clipboard).

- `clipboard/.local/bin/clip-normalize` (Python + ctypes, no deps beyond `xclip`): listens to XFixes selection events (no polling, ~17 MB); when the CLIPBOARD owner advertises `text/plain;charset=utf-8` but not `STRING` (Zed's signature), it re-publishes the text with `xclip`, which serves every text target. It does not loop because xclip doesn't advertise that signature. Side effect: copied text survives closing Zed.
- `clipboard/.config/systemd/user/clip-normalize.service`: `Restart=on-failure`, `DISPLAY=:0`. It is `WantedBy=graphical-session.target`, but **dwm never activates that target**, so `dwm/.dwm/autostart.sh` runs `systemctl --user start clip-normalize`. The service exits when the X session ends (XIO error) — expected.
- Install on a fresh machine: `stow clipboard && systemctl --user daemon-reload && systemctl --user enable clip-normalize`. Not needed on the Hyprland desktop (Wayland).
- Diagnose: `xclip -selection clipboard -t TARGETS -o` right after copying in Zed should show `STRING` once normalized; `journalctl --user -u clip-normalize`.

## Key Conventions

- **Keyboard layout:** LATAM (Latin American) — there is no `` ` `` key left of `1`; relevant when picking keybindings
- **Modifier key:** Super (Windows key) for both Hyprland and dwm bindings
- **Font:** GoMono Nerd Font — Nerd Font icons are used throughout configs
- **Color scheme:** Tokyo Night / Catppuccin-inspired palette (e.g., `#7aa2f7` active borders)
- **Package manager:** pacman + AUR helpers (yay/paru) on the desktop; apt on the Mint laptop
- **Git:** commits go directly to `master`; `user.email` on the laptop is a placeholder (`you@you.you`)

## Deploying Config Changes

Configs are organized by `<app>/.config/<app>/` structure and deployed with stow (`stow <package>` from the repo root). The zsh config lives at `zsh/.zshrc` (maps to `~/.zshrc`).

After modifying Hyprland configs, changes are picked up automatically or via `hyprctl reload`. Waybar requires restarting (`killall waybar && waybar &`). dunst: `killall dunst` (D-Bus restarts it on the next notification). sxhkd: `pkill -USR1 -x sxhkd` reloads. Suckless components require the build scripts above.

On the desktop, run `./check.sh` after `pacman -Syu` or config changes (`--quick` skips the throwaway Waybar/hypridle instances). It exits 1 on failures.

## Pending / ideas

- `install/cachyos-post-install.sh` is untested on real hardware; `install/README.md` lists what to verify on the first install (No Desktop option, paru in repos, ly after Plymouth, AUR names).

