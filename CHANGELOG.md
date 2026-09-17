# Changelog

All notable changes to Lucid are recorded here, newest first.

## v1.1.0 — 2026-09-17

Everything the shell asks you for, it now asks for itself: a lock screen that
checks your password through PAM, the administrator prompt for the whole
machine, the accounts on it, and a login screen wearing the same palette. Around
that, a notification centre that groups and replies, clipboard history in the
launcher, a keyboard you can type with when there is not one, and a light mode
built rather than inverted.

### Lock screen

- **The lock screen is rebuilt from scratch.** The old single 1000x600 card
  packed with weather, disk charts, CPU and RAM graphs and a fastfetch dump is
  gone. In its place the content floats on the wallpaper the way Material You
  lays out a lock screen: an oversized two-line clock in the wallpaper's own
  accent colour on the left, the weather above it, the glanceable chips top
  right, and a right-hand column carrying the sign-in card, what is playing and
  the notifications.
- **It authenticates through PAM.** The old screen shelled out to
  `sudo -S -v`, which only worked for accounts that happen to be sudoers and
  told you nothing when it failed. The lock now opens a real PAM session
  against `/etc/pam.d/login` — the same service a display manager uses — so any
  account can unlock, and PAM's own words are what you read when something goes
  wrong. A second question from PAM (a token, a second factor) reopens the
  field with PAM's prompt on it rather than dead-ending.
- **The refusals say something useful.** "Incorrect password — 2 tries left"
  counting down against faillock's real `deny`, "Too many attempts — try again
  in 8 minutes" with the countdown read from `faillock` itself, "The check
  timed out" when PAM stops answering, and PAM's own sentence when it has one.
- **Caps Lock gets its own badge** next to the field, so the commonest reason a
  password is refused stays visible even while a refusal is on screen. The
  active keyboard layout shows beside it when you are typing.
- **Two faces, one screen.** Resting, the lock is a glance: clock, date,
  greeting, weather, media, notifications. Touch the keyboard and it focuses —
  the wallpaper blurs further, the clock shrinks out of the way, everything
  that is not the field steps back, and the sign-in card is all that is lit.
  **What steps back also goes inert** — while the field has the screen, the
  media card, the notifications, the power bar and the glance chips take
  neither clicks nor hover: no pill opens, no button lights up, and a click out
  there buys the focus back rather than pressing whatever was under the
  pointer. It drifts back to the glance after half a
  minute of quiet.
- **The password field is an M3 outlined field**: a focus ring in the accent,
  beads that pop in per character, a reveal toggle, and a submit button that
  turns into a proper indeterminate spinner while PAM thinks and a tick when it
  opens. The lock glyph turns over on success; the pill and the avatar's ring
  go green, or red and shake.
- **Power actions ask first.** Log out, restart and shut down morph the bar
  into a confirmation instead of going straight through; suspend and hibernate
  still go immediately. The question withdraws itself after seven seconds.
  Hovering one opens it into its own labelled pill inside the bar — the glyph
  stays put, the bar grows around it — rather than floating a tooltip over the
  wallpaper.
- **A caret you can steer.** The beads are not just a count: a caret sits where
  the next character will land, and the arrow keys walk it back through what is
  already typed so a single character can be fixed instead of starting over.
  Each new bead is left behind *by* that caret — it starts as the caret's own
  line and settles into a dot where it stood.
- **Clicking away puts the lock back to rest.** Anywhere off the sign-in card
  drops the focus, forgets what was half-typed and clears any refusal still on
  screen; the card itself counts as inside, so clicking the avatar aims the
  keyboard at the field instead.
- **Notifications on the lock cannot reach past it.** Their action buttons and
  inline reply are hidden, and `Notifs` refuses to invoke an action or send a
  reply while the session is locked, so no card can launch or talk to an
  application from the lock screen.
- **Every other screen gets the clock**, not a second password field.
- **Arriving and leaving are different gestures.** The entrance is a staggered
  wave read off a single number: the wallpaper settles out of a push-in and
  blurs, the clock rises in from the left, and the right-hand cards slide in
  one after another. Leaving is not that run backwards — the whole stage leans
  forward and dissolves at once while the wallpaper comes back into focus.
- **New layout of the code.** `Lockscreen.qml` is a root singleton holding the
  session state, PAM, the attempt ledger and the IPC; `lucidlock/` is eleven
  small views instead of one 3000-line file. `lucidlock/BlurBackdrop.qml`, which
  nothing had used for a long time, is gone.
- `qs ipc call -- lock` keeps `lock`, `unlock` and `isLocked`, and gains
  `status` (the session state as JSON). Nothing bypasses the password: the
  scaffolding used while the screen was being built — a dry-run mode, and
  handles that could force a verdict — is gone, so PAM is the only way in.

### Authentication

- **Lucid is the session's polkit agent.** Anything on the machine that needs
  an administrator — mounting a disk, changing the time zone, installing a
  package, `pkexec`, the Users page — now asks through a Lucid dialog instead
  of the KDE one. Only the dialog is ours: polkitd still decides what needs
  authorising and PAM still checks the password, through polkit's own setuid
  helper. Nothing about the security model changes.
- **The dialog says what is actually being asked.** A badge glyph picked from
  the action itself (a disk for udisks, a power symbol for logind, a terminal
  for `pkexec`, a parcel for package installs), the action's short description
  from `pkaction` as the headline, and polkit's own sentence underneath —
  retyped out of its `like this' quoting into real quotation marks.
- **It shows whose password it wants.** Every identity polkit will accept is
  listed with the name and picture from the Users page, and when there is more
  than one, picking a different administrator re-points the request at them.
- **The field is the lock screen's field** — the same pill, focus ring and
  reveal toggle — so a password prompt looks the same wherever the shell asks
  for one. A refusal tints the pill, shakes it and says what PAM said; a grant
  shows a tick before it leaves.
- Escape, the Cancel button and a click on the dimmer all dismiss the request
  properly, so whatever asked is told it was refused rather than left waiting.
  The dialog holds the keyboard only while a request is actually live.

### Users and accounts

- **The settings app manages the machine's user accounts.** A card at the top of
  the navigation rail shows your picture and name and opens a new *Users and
  Accounts* page, where every account on the machine is listed and picking one
  points the whole page at it.
- **Full name, username, account type, login shell, email and location** are all
  editable, with the guards that matter: the last administrator cannot demote
  themselves, an account that is signed in cannot be renamed, and you cannot
  lock or clear the password of the account you are using.
- **Passwords** are set through a dialog that checks the two entries match and
  rates what you typed, and a password hint can be left alongside. An account
  can instead be told to choose its own password at its next sign-in.
- **Accounts can be added and removed.** Adding asks for a name, guesses the
  username from it, and offers to set the first password now or leave it for
  first sign-in. Removing makes the files a separate, explicit decision from the
  account itself.
- **Account pictures** can be chosen from the machine's stock faces or any image
  on disk; it is centre-cropped and scaled to 256 px, saved to `~/.face` for
  your own account so the lock screen finds it, and can be removed again to fall
  back to initials on a tonal disc.
- **Supplementary groups** — audio, video, libvirt and the like — are shown as
  chips you can toggle, batched into one authorisation rather than one per group.
- Everything privileged goes through AccountsService on the system bus, so the
  session's polkit agent does the asking and the shell never runs as root. A
  refused or cancelled prompt is reported on the page instead of failing
  silently. Requires `accountsservice`, now declared in the installer.
- **Account pictures keep a history.** Changing your picture files the old one
  away rather than losing it, and the picker shows what the account wore
  before, newest first — clicking one puts it back. Removing a picture keeps it
  too, so going back to initials is never a one-way door.
- The shelf holds twelve pictures or 8 MB, whichever runs out first, and the
  oldest drop off as new ones arrive. Pictures are stored by what they look
  like, so re-applying one already there just moves it to the front instead of
  filing a second copy. **Clear** empties the whole shelf.
- The history lives in your own data directory, so reading it never asks for an
  administrator.
- **Passwords now need four characters rather than six**, in the password
  dialog and when adding an account. The strength read-out is unchanged, so a
  short password is allowed but still reads as weak.
- Fixed: a face directory's own hidden fallback silhouette (SDDM ships one as
  `.face.icon`) was being offered as a stock picture, showing up as an empty
  black circle in the picker.

### Notifications

- **The notification centre is rebuilt.** One place now owns every notification
  in the shell — the pill on the bar, the popups and the lock screen are three
  views onto the same list, so dismissing something dismisses it everywhere and
  Do Not Disturb means the same thing wherever you turn it on.
- **Notifications group by application.** Five messages from one chat collapse
  into a single stack with the application's name on it; open it to read them,
  clear it to drop the lot. A heading separates what has just arrived from the
  rest, and each card says how long ago it came.
- **You can answer without leaving what you are doing.** Applications that offer
  an inline reply get a message box on the notification itself.
- **File copies, downloads and transfers report how far along they are**, as a
  bar that fills in place rather than one notification per percent.
- **Popups stack under the bar.** The newest grows out of the pill itself and
  the rest float beneath it; hovering the stack freezes every countdown at once,
  and anything past the limit waits in the list instead of racing past. A swipe
  up sends a popup back to the bar, a swipe sideways clears a card from the list.
- Grouping, timestamps, progress, inline reply and how many popups show at once
  are all switchable on the Notifications page.
- `qs ipc call -- notifs open|close|toggle|clear|toggleDnd|expandAll|count`.

### Control centre

- **The System pill's job is narrower and what is left goes deeper.** The
  notifications preview is gone from it — the Notifications pill owns that list
  — and what remains is device state and quick settings.
- **Audio devices can be switched from it.** A chevron on the volume and
  microphone rows slides in the outputs or the inputs, named the way you would
  name them — "Speaker", "HDMI 1" — rather than by the chipset four of them
  share. A socket with nothing plugged into it says "Not connected" and cannot
  be picked.
- **A Caffeine tile**, so the idle ladder can be held off without opening the
  settings app.
- CPU temperature, uptime, memory in gigabytes, and on a laptop what the battery
  is actually drawing.
- The player card stays, redesigned: album art, title and artist, previous and
  next either side of a filled play button, and a progress bar that moves.

### Clipboard history

- **The launcher remembers what you copy.** `SUPER` + `SHIFT` + `V`, or `>clip`
  in the search field, lists what has been through the clipboard, newest first —
  pick one to put it back.
- **Images are kept too**, and preview on their row.
- `Delete`, or the button on the row, drops one entry; *Clear history* on the
  Dock settings page drops all of them; the switch beside it turns the whole
  thing off.
- `cliphist` is the store, and the shell owns the watchers that feed it — so
  history records for as long as the shell is running, not only while the
  launcher is open.

### On-screen keyboard

- **A keyboard for when there is not one.** `SUPER` + `K`, the desktop's
  right-click menu, the launcher's command list, or `qs ipc call keyboard
  toggle`.
- **It never takes the focus off what you are typing into**, and clicks outside
  the panel reach the application underneath — so the caret stays where you put
  it and you can aim at a field between keystrokes.
- A letters layer and a function layer; modifiers latch on one press and lock on
  two; Caps is kept to the panel so it cannot fall out of step with the real
  keyboard. Chords go out as chords, which is the only form some applications
  accept.
- Drag it anywhere by the strip along its top, and it stays where you left it.

### Light mode

- **The shell has a light mode**, under Theme in the settings app. The palette is
  rebuilt rather than inverted at the last minute: matugen and pywal re-extract
  the wallpaper in the mode you picked, and the themes that only ship a dark
  palette get a light one built from their own colours in tone space — Nord
  lands on its own Snow Storm, Gruvbox on its own cream.
- **The accent is applied to light surfaces.** A generated light palette is
  almost white, and no hue exists at all near tone 100 — so the ramp is first
  walked off white, then mixed toward the accent at each rung's own tone, which
  keeps the elevation ladder exactly as far apart as it was. The tint aims at an
  amount of colour rather than mixing a fixed fraction, so every theme lands in
  the same place: a near-grey Gruvbox and a vivid pywal both come out tinted
  rather than one staying white and the other turning mint. *Accent tint*,
  beside Surface darkness, controls how far.
- **The mode is remembered**, in `~/.cache/current_mode` beside the theme, so
  changing wallpaper keeps the mode instead of dropping back to dark.
- **Applications follow the shell.** Flipping the mode also asks GTK and Qt for
  it and swaps the GTK and icon themes to their light or dark counterpart —
  but only to a counterpart that is actually installed.
- Status colours, dim text, hover and pressed states, and every elevated
  surface now flip direction with the mode, instead of staying at the tone that
  only reads on a dark background.

### Login screen

- **SDDM gets a Lucid theme** — the lock screen ported to the greeter: the same
  two-tone clock, the same palette, the same wallpaper, blurred once in advance
  so the login screen is not running a blur on a cold GPU. The user and session
  pickers take the place of the glance chips, and the weather, media and
  notifications drop out, there being no session yet to read them from. It
  carries the lock's two faces too, including going inert while the field has
  the screen: the pickers and the power bar take neither clicks nor hover until
  a click hands the focus back.
- It is painted from the running shell's own resolved colours, so it follows a
  theme or wallpaper change like everything else does, and repaints without
  asking for a password.
- The installer copies it in when SDDM is present, but **never switches to it** —
  which theme greets you stays your call.

### Volume, brightness and the lock keys

- **The volume, brightness and microphone popups are redrawn** to the same
  anatomy the control centre's sliders use: a badge, a track that answers the
  keypress, and a readout. Mute is cut through the badge as a gap in the glyph
  rather than a line laid over it.
- **Caps Lock and Num Lock get a popup of their own**, showing the letters the
  next keystroke will make — `ABC` against `abc` — rather than the words on and
  off, and rolling from one to the other.
- **Toasts are snackbars**, to the Material 3 metrics, and a colour too dark to
  read against the pill is lifted until it is.

### Workspaces

- **Any installed application can be put on a scratchpad workspace**, not only
  the ones the catalogue knows about: *Add an app* on the Workspaces page lists
  everything on the machine, and works out what to match the window by.
- **The chips say what a stashed window is rather than who made it.** The
  application logos are replaced by a glyph read off the application's own
  categories — a terminal for a terminal, a note for an editor — drawn as
  vectors, so they stay sharp at any scale. Tucked away, only the front one
  shows; opening the chip fans the rest out behind it.

### Environment

- **The pointer's shadow can be turned off.** Hyprland has no switch for this —
  the shade is painted into the cursor theme's own images — so Lucid renders the
  theme again from its vector sources, copying every size, hotspot and frame
  delay exactly, and points GTK, Qt, XCursor and Hyprland at that copy. The
  pointer keeps its shape; only the shade goes.

### Performance

- **Animations run at the screen's refresh rate on NVIDIA.** Qt refuses threaded
  rendering on the proprietary driver — its own workaround for an old resize bug
  — and falls back to a render loop whose animation clock is a fixed 16ms timer,
  which pins every animation in the shell to ~60fps however fast the monitor is.
  Hyprland stays smooth throughout, which is why this looked like the shell
  being slow. Lucid now starts through `~/.config/lucid/launch-shell.sh`, which
  moves those machines to Qt's Vulkan backend, where the restriction does not
  apply.
- It only switches when NVIDIA is the card the compositor actually renders on,
  the driver is 555 or newer, and an NVIDIA Vulkan driver is present — a hybrid
  laptop rendering on Intel is left alone. `launch-shell.sh --explain` prints
  what it decided and why, without starting anything.

### Contributed

- **A KDE Connect widget** for the desktop, in three sizes: the phone's name and
  battery at a glance, a card with signal and charge state, and a remote. Files
  can be sent to the phone from it. Thanks to @k-k-j123.
- **A Sound page** in the settings app — output and input devices with what each
  one is, a volume for every application making or taking sound right now, and
  the choice of whether picking a new output carries what is already playing
  across to it. Thanks to @MrZtone.
- **Installer fixes:** the warning about an old Hyprland actually fires, a
  configuration the installer cannot read is no longer replaced without asking
  first, and `require` lines added to `hyprland.lua` by hand survive a refresh.
  Thanks to @arbelonson-source.

### Fixed

- Do Not Disturb could not be turned on from the System pill or the lock screen.
  Both wrote to a value that refused to be written, so the switch moved and
  nothing happened.
- Airplane mode never gave the radios back. It only ever turned Wi-Fi and
  Bluetooth off, so switching it off again did nothing; it now puts back exactly
  what was on before.
- The CPU reading in the System panel was wrong for a moment after opening it —
  the first sample averaged over the whole time the panel had been closed.
- The widget options menu opened underneath your windows when the cards are set
  to sit below them. It is drawn on its own layer now.
- Hyprland's autostart re-applied the GTK theme, the icon theme and a dark
  colour scheme on every login, overriding whatever the Environment page had
  been told and putting light mode's applications straight back into dark. The
  installer seeds those once when you ask for the Lucid look; the Environment
  page owns them from then on.
- `sync-sddm.sh` never ran and never reported that it had not. A misplaced
  `exit 0` meant it returned success without painting anything, so the login
  screen sat on a months-old palette; it was not installed by the installer
  either, and it exited silently on a machine without `/etc/sddm.conf.d`. All
  three are fixed, and matugen applies it now too.

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
