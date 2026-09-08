# dotfiles

macOS configuration tracked straight from `~/.config` — the repository root is
the directory itself, so there are no symlinks or a dotfiles manager involved.

## Layout

| Path | What it configures |
| --- | --- |
| `aerospace/` | AeroSpace tiling window manager; `simple-bar-refresh.sh` notifies `simple-bar-server` to update the spaces widget on focus/workspace change |
| `sketchybar/` | SketchyBar status bar written in Lua (widgets, popups, media/artwork, calendar, weather, mic, volume) plus C event providers in `helpers/event_providers/` |
| `simple-bar/`, `simple-bar-server/` | Nested app repos (own Git remotes) that render the AeroSpace spaces widget; not tracked here |
| `colors.sh` | Catppuccin Macchiato palette exported as hex environment variables (`COLOR_*`) |
| `icons.sh` | Nerd Font glyphs exported as environment variables (`ICON_*`) |
| `ghostty/` | Ghostty terminal config and Catppuccin Macchiato theme |
| `zed/` | Zed editor settings, themes, and prompts |
| `micro/` | micro editor settings, bindings, and Catppuccin colorscheme |
| `yazi/` | yazi file manager keymaps, theme, and plugins |
| `btop/` | btop system monitor config and Catppuccin theme |
| `cava/` | cava audio visualizer shaders and themes |
| `karabiner/` | Karabiner-Elements keyboard remapping |
| `iterm2/` | iTerm2 support files |
| `rstudio/` | RStudio preferences |
| `gtk-2.0/` | GTK file chooser settings |
| `xbuild/` | xbuild pkgconfig cache |
| `starship.toml` | starship prompt |
| `cline/skills/` | Cline agent skill definitions |
| `PureRef.ini` | PureRef reference viewer settings |

## Setup

The repo is cloned directly into `~/.config`:

```sh
git clone https://github.com/theryokato/dotfiles.git ~/.config
git -C ~/.config pull   # update
```

App-specific dependencies live next to their config:

- SketchyBar and its dependencies (fonts, helper binaries): `sketchybar/helpers/install.sh`
- `simple-bar-server` (nested repo) is expected at `~/.config/simple-bar-server`

## Not tracked

`.gitignore` excludes machine-specific and credential-bearing paths: `gh/`,
`github-copilot/`, `configstore/`, `gnupg/`, `gpg/`, wallpapers, SketchyBar
helper binaries, and the nested `simple-bar*` app repos.