# Changelog

All notable changes to Lucid are recorded here, newest first.

## v1.0.5 — 2026-09-12

Multiple displays, properly: the shell sits where you put it, every screen is
configurable from the settings app, and a display coming and going no longer
takes the bar with it. Plus scratchpad workspaces on their own keys, glass you
can aim at one app at a time, widget arrangements you can save, and Lucid
telling you when there is a new version.

### Displays

- **A Displays page**, under Environment in the sidebar, for every screen the
  machine has: resolution, refresh rate, scale, orientation and adaptive sync,
  one card per output. Each card names the panel, its size and what it is doing
  right now, and only offers modes the display actually reports — so there is no
  way to pick one it cannot show.
- **Scale says what you get.** Each option is labelled with the room it leaves
  for windows, a scale that does not divide the panel evenly is called out as
  such, and scales that would leave less than 960px of width are not offered at
  all.
- **Displays are arranged by dragging them.** With more than one screen the page
  draws the layout the way Hyprland sees it; drag one and its edges snap to its
  neighbours, so there are no gaps for the pointer to fall into. *Arrange
  automatically* hands the placement back to Hyprland. Moving one display pins
  them all where they already are, so Hyprland cannot shuffle the rest around
  the one you moved.
- **A display can mirror another, or be switched off** — except the last one
  left on, which the page will not let go. The Hyprland module refuses it too,
  so a hand-edited config cannot black out every screen either.
- **The shell can be pinned to one display.** The bar, the dock, the volume and
  brightness popup and the toasts are one of each, and they all move together;
  widgets with no display of their own follow too. *Automatic* leaves the choice
  to Hyprland as before. The wallpaper, the desktop menu and the lock screen are
  drawn on every display either way. `qs ipc call -- displays shell <name>` does
  it from a keybind, and takes `here`, `next`, `prev` or `auto` as well;
  `qs ipc call displays list` says where it is.
- **Unplugging the display the shell was pinned to no longer takes the shell
  with it.** It moves to a display that is left, keeping the pick, so plugging
  back in puts it back where you had it.
- **The bar and the dock can each be sent to a display of their own**, for a
  setup that wants them apart — *The bar on its own* and *The dock on its own*
  on the same page, both *With the shell* by default. `qs ipc call -- displays
  bar left` and `displays dock middle` do it from a keybind.
- **A display can be named by where it sits**: `left`, `middle` and `right`
  work anywhere an output name does, as do `here` for the display in use and
  `next`/`prev`. `qs ipc call displays list` prints the outputs left to right
  and marks what is sitting on each.
- **Screenshots are taken of one display**, the one in use, rather than every
  display stitched into a single image — which also means a region crop lands
  where you drew it, and the capture flash is on the screen you captured.
- Settings become Hyprland monitor rules in `~/.config/hypr/lucid-monitors.lua`,
  read by `modules/monitors.lua` on every change, so nothing reloads. A display
  is keyed by its description rather than its port, so unplugging it and putting
  it back in a different socket keeps what you set. A display dropped from the
  page goes back to its preferred mode the same way. Scriptable with
  `qs ipc call settings displays`.

### Wallpaper

- **Wallpapers ship with Lucid.** A set for each theme lives in the repo under
  `wallpapers/`, and the installer copies them into `~/Pictures/wallpapers/<theme>`
  — the folder the strip reads while you are on that theme — so the picker has
  something in it the first time you open it. A file you already have is never
  overwritten, nothing is ever removed, and `--no-wallpapers` skips the step.
- **One display can be given its own wallpaper, or its own fit.** Rules go in
  `~/.config/lucid/wallpaper-outputs.conf`, one output a line — an image path,
  arguments for `awww`/`swww`, or both — so a portrait screen can letterbox
  instead of crop, or show a different picture entirely. Outputs with no rule
  keep the wallpaper you picked, in the same pass, so nothing fades twice, and
  colours are still generated from the wallpaper itself. The installer drops a
  commented example in place the first time, and never touches it again.

### Glass

- **Glass is its own page now**, above Theme in the sidebar. The slider moved
  off Settings → General (which keeps a button through to it), and `>blur` in
  the launcher opens it.
- **One slider, three surfaces, each let through as far as it can take.** The
  page shows where it lands: the shell's own panels go furthest, kitty goes all
  the way — its `background_opacity` only touches the background, so the text
  stays readable at *Full* — and app windows go a quarter as far, because
  Hyprland fades a window's text along with it.
- **Kitty follows the slider.** Lucid writes `~/.config/kitty/lucid-glass.conf`
  and signals kitty to reload, so open terminals follow without restarting. The
  exception is the very first window after installing: `dynamic_background_opacity`
  only takes effect in a kitty that started with it set, so reopen it once. Your
  `kitty.conf` gains a single `include ./lucid-glass.conf` line with a
  `kitty.conf.pre-lucid-glass` copy beside it; take the line back out and it
  stays out.
- **Apps can be frosted one at a time.** Tick the ones you want from what you
  have installed — editors, browsers, file managers, chat, Spotify — and each
  gets a row that follows the master slider until you give it a value of its
  own. Anything else that is open can be added by its window class, and it stays
  on the page after the window closes.
- Per-app values become Hyprland window rules in `~/.config/hypr/lucid-glass.lua`,
  read by `modules/glass.lua` on every change, so nothing reloads. Windows
  already open are set directly rather than waiting for a restart, and an app
  taken off the list goes back to opaque the same way. VSCodium's old hardcoded
  `opacity 0.90` rule left `modules/windowrules.lua` and ships as this page's
  default instead.

### Update check

- **Lucid says when a new version is out.** Once a day it asks GitHub's public
  API for the newest release, compares it with the `VERSION` file the installer
  puts beside `shell.qml`, and posts one notification per version with a
  **What's new** button onto the release notes. It never repeats itself for a
  version you have already been told about.
- **Settings → About** gained an *Updates* card: what the last check found, a
  *Check now* button, and the switch that turns the daily check off. The request
  carries nothing about you or your machine, and `qs ipc call updates status`
  reports the same thing from a terminal.

### Special workspaces

- **Music, comms, to-do and system monitor workspaces**, each on its own key:
  `Super+Shift+M`, `Super+Shift+D`, `Super+Shift+R` and `Ctrl+Shift+Esc`. One
  press slides the workspace over whatever you are on, the next puts it away.
  The key starts the app if it is not running and pulls it back in if you moved
  it out, and apps opened from the launcher or the dock land in their workspace
  too.
- **The scratchpad is `special` now, not `magic`.** `Super+Shift+S` also puts
  away whichever workspace is up, and `Super+Alt+S` stashes the focused window —
  pressed inside a special workspace, it sends the window back instead.
- **Settings → Workspaces** picks each workspace's apps from what is installed
  (eleven music players, twelve chat and mail apps, seven to-do apps and six
  system monitors are recognised), turns any of them off, and sets the dimming
  and whether a workspace change puts them away. Changes apply live: Hyprland
  reads `~/.config/hypr/lucid-specials.lua` on every key press.
- In the bar, special workspaces sit beside the dots as a stack of the apps in
  them, and opening one lifts it into the accent with its name — Music, Comms,
  To-do, System — in key order.
- Special workspaces pop in with a short vertical slide and fade instead of
  sliding across like a workspace change.

## v1.0.0 — 2026-09-10

The first stable release. Lucid stops being a bar and a dock and becomes a whole
desktop: cards you place on the wallpaper, a settings app that owns your network,
Bluetooth, phone, idle ladder and desktop environment, and a theming layer that
reaches well past the shell.

### Desktop widgets

- **Ten kinds of card, thirty looks between them** — Clock, Calendar, System,
  Battery, Media, Visualiser, Weather, Notes, To-do and Palette. Every category
  ships several variants of the same data: the clock is digital, stacked, analog,
  bare or a three-city world clock; the system card is arc gauges, meters, a
  two-minute graph or a plain row of numbers.
- Placed from **Settings → Widgets**, dragged anywhere on the screen — including
  the strips the bar and dock reserve — and back where you left them after a
  reboot. Dragging snaps to screen edges, centre lines and the other widgets,
  with guides while you move.
- Widgets sit **below your windows** by default so they behave like a desktop,
  and step aside for fullscreen; both are switches.
- Every card has its own menu — right-click, or the gear on hover — for style,
  size and its own options: 12 or 24 hour, which metrics to show, °C or °F, a
  note's tint.
- The **visualiser** is free-resize instead of fixed sizes: hover it, grab any
  edge or corner, and stretch it as wide as the screen. All the visualisers on
  screen share **one** cava process, run at the finest band count any card asks
  for.

### Settings, reimagined

Rebuilt around grouped-list cards, a collapsing app bar and a collapsible
navigation rail, with a live preview of whatever you are adjusting and a reset
arrow on every control that differs from its default.

New pages:

- **Theme** — wallpaper and palette moved out of General into their own section.
- **Widgets** — the tile board that places cards, plus the layering switches.
- **Network** — everything NetworkManager can do: Wi-Fi radio, a live list
  grouped into connected/saved/nearby with a filter and a stoppable scan, join
  with password, forget, hidden networks, wired link speed, VPN and WireGuard, a
  hotspot, per-device addressing, and a DHCP-or-static **IP configuration**
  editor.
- **Bluetooth** — a real manager: radio, discoverability, pairing policy, the
  name other devices see, and per device connect/pair/forget/rename/
  auto-reconnect/allow-wake/block with battery where reported. Connected
  headphones get an **audio mode** switch (high quality vs headset), so reaching
  the mic no longer means opening `pavucontrol`.
- **Phone (KDE Connect)** — a real client over D-Bus, not a launcher for someone
  else's. Pairs and answers pairing requests with the verification key, then:
  send files through the desktop file chooser, send text or a link, ring, lock,
  mount and browse storage, push the clipboard, run remote commands, read and
  reply to notifications inline, a media remote with seek and volume, the phone's
  system volume, and a touchpad and keyboard that drive it from this machine.
- **Idle and sleep** — owns hypridle for you. Writes `~/.config/hypr/hypridle.conf`
  and restarts the daemon on change, so dim → lock → screen off → suspend is set
  with sliders. A rail shows the sequence in firing order and warns when two steps
  are out of turn. Keep-awake, never-interrupt-playback, battery-only suspend,
  lock-before-sleep, wake-on-resume. Your existing config is read in once and kept
  as `hypridle.conf.pre-lucid`.
- **Environment** — cursor theme and size, icon theme, GTK theme, light or dark,
  Qt style and four font roles, each written everywhere it needs to go: GTK 2/3/4,
  `gsettings`, the XCursor fallback, qt5ct and qt6ct, and Hyprland's env module,
  with `hyprctl setcursor` so the pointer changes under your hand. Only the keys
  Lucid owns are touched; unused toolkits are skipped, not conjured.
- **Notifications** — how they behave, in one place: whether popups appear, how
  long one stays and whether an application may set its own timeout, how much of
  the message and how many buttons show, do-not-disturb with quiet hours and a
  fullscreen rule, a notification sound with its own volume, how many the list
  keeps, and per-application muting.
- **Date & Time** — auto-detect location (or name a town), and a time zone that is
  set on the **machine** via `timedatectl`, so the whole box moves together instead
  of Lucid drifting from it. One Open-Meteo forecast is fetched and shared by the
  bar clock, the lock screen and the weather widget, so the three cannot disagree.

Every page is scriptable: `qs ipc call network status | list | rescan`,
`qs ipc call -- kdeconnect ring <id>`, `qs ipc call idle keepawake`,
`qs ipc call settings environment`.

### Theming

- **Import a theme straight from a GitHub repo.** Paste a colour-scheme repo's
  URL and Lucid clones it, reads it and builds a full Material 3 palette from it.
  Detection is tiered: base16/base24 YAML and name-keyed JSON (Catppuccin and
  friends) are read exactly; anything else falls back to harvesting hex codes and
  sorting them by tone and chroma. Repos with several variants are listed so you
  can pick one, wallpapers in the repo come along, and nothing from it is ever
  executed — only text is parsed and only images are copied.
- **Full config dots.** The palette no longer stops at the shell: kitty, starship,
  VSCodium, Vesktop/Discord, GTK 3 and 4, Steam, rofi, Firefox and Zen, Spotify via
  spicetify, pywalfox and ags all repaint from the active theme, each one only if
  it is actually installed. Running kitty and open shells recolour in place rather
  than at the next launch.
- **SDDM** — `support/lucid/sync-sddm.sh` paints the login theme from the same
  palette, since SDDM runs before login and cannot read a per-user one. It is not
  installed or run by default: `/usr/share/sddm/themes` is root-owned, and the
  script refuses rather than escalating. Copy it to `~/.config/lucid/` and make
  the theme writable if you want it.
- The installer now ships a full **Hyprland config layer** (`hyprland.lua` plus
  modules for binds, window and layer rules, decorations, animations, gestures,
  input and autostart) and a **look layer** for kitty, fish and starship.
  `--no-hypr` and `--no-look` opt out; an existing config is backed up and you are
  asked first.

### Screenshots — LucidShot

- **Text copy.** Drag a box over anything on screen — an image, a video still, a
  PDF, an error dialog, a window that will not let you select its text — and the
  words land on your clipboard. The crop goes through tesseract twice, once
  inverted, keeping the better read, so light-on-dark UI text works as well as a
  scan. Emoji come across too: tesseract has none in its character set, so anything
  colourful and square is matched against the glyphs of your installed emoji fonts
  instead — one flat colour means text, many means emoji, and a shape it cannot
  name is left out rather than guessed. The overlay stays up with a beam sweeping
  the selection until the text is on the clipboard.
- **Colour picker.** Hands off to `hyprpicker` with the shade and the freeze
  dropped, so you are picking off a live desktop with the toolbar floating over it.
  HEX, RGB or HSL, with the lens, the clipboard and the toast all reading the same
  valid CSS.

### Bar, dock and desktop

- **Tooltips on the System module** — hover any icon in the compact strip (Wi-Fi,
  Bluetooth, volume, mic, battery) and it names itself, with its own slab per icon
  so the gaps between them stay dead.
- **Improved dock physics** — the gap opening and the icon landing in it now share
  one timing, entrance animations no longer replay on a delegate rebuild, and
  reorder and pin drags settle more cleanly.
- **Icon themes follow without a restart.** Qt reads the icon theme once at process
  start, so the dock now resolves names against the theme directories itself,
  inheritance chain and all.
- **Right-click the desktop** for wallpaper, theme, add-a-widget, show/hide widgets,
  screenshot and settings. Drag across empty desktop and a translucent accent box
  follows the cursor, the way it does on Windows and macOS.
- **Toasts** — a compact pill under the bar for things that just need saying,
  raisable from any script: `qs ipc call -- toast show game "Game Mode On"`.

### Fixed

- **Album art rendered as one huge blob** (or blank) in the media pill on machines
  without a real GPU — the shader mask is gone, the art is clipped instead.
- The media visualiser stretched a single bar across the whole strip when cava was
  not emitting raw frames, and a wide bar could drag its own height past the top of
  the strip.
- Every `Theme.on*` colour silently resolved to **black** shell-wide, because an
  `onFoo` property beside `foo` drops its binding in QML; the roles are now `fg*`.
- `install.sh` stops on an unsynced pacman database instead of failing halfway, and
  recognises Lucid's own Hyprland config on a re-run rather than offering to back it
  up over and over.
- `uninstall.sh` now tells you exactly what it left behind — the matugen template
  blocks, `~/.config/hypr`, `starship.toml` and its rc init lines, kitty's include —
  each with a timestamped backup beside it.

---

Earlier releases are on the
[tags page](https://github.com/Sn3akyy1/lucid/releases).
