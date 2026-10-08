import QtQuick

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: "1.20"
    readonly property string name: "Lucid 2"
    readonly property string date: "7 October 2026"
    readonly property bool placeholders: true
    readonly property var heroes: [
        {
            "src": "assets/desktop.webp",
            "alt": "The Lucid desktop: the bar along the top, calendar and weather widgets on the left, the clock and what is playing on the right, and the dock along the bottom"
        },
        {
            "src": "assets/control-centre.webp",
            "alt": "The control centre open from the bar, beside palette, music and quote widgets, with the volume popup above the dock"
        },
        {
            "src": "assets/settings-storage.webp",
            "alt": "Settings on the Storage page, with the control centre and the on-screen keyboard open beside it"
        }
    ]
    readonly property string intro: "Lucid 2. Every surface is redrawn in Material You Expressive on one shared kit of controls, the clock grows into an app, the launcher learns new modes and the control centre's tiles are yours to arrange. On top of that sits a release's worth of new features, most of them from <b>Ciro Rivera</b>, who wrote twenty-five of the pull requests in this one. Thank you, Ciro."
    readonly property var sections: [
        {
            "level": 1,
            "icon": "auto_awesome",
            "title": "Lucid 2",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20/look.webp",
                    "alt": "The new look across the bar, a panel and the settings"
                },
                {
                    "src": "assets/clock-app.webp",
                    "alt": "The clock app on its Today page, among clock, music, calendar, weather, battery, system and to-do widgets"
                },
                {
                    "src": "assets/widget-panel.webp",
                    "alt": "The widget panel on its Clock gallery, beside a Coming up card and lucidfetch on the desktop"
                },
                {
                    "src": "assets/launcher-wallpapers.webp",
                    "alt": "The launcher in its wallpaper mode, its other modes along the top"
                },
                {
                    "src": "assets/whatsnew/1.20/lock.webp",
                    "alt": "The lock screen sinking out of the desktop"
                }
            ],
            "items": [
                {
                    "text": "<b>What's new, in the shell.</b> The first start after an update opens a sheet with what the new version brings, once; <i>Settings → About → What's new</i> opens it again, and <code>qs ipc call updates whatsnew</code> too. A newer release waiting to be installed still links its notes on GitHub from the same card.",
                    "code": ""
                },
                {
                    "text": "<b>Material You Expressive, everywhere.</b> The bar, dock, launcher, control centre, clock, widgets, OSD, toasts, lock screen and settings now share one kit of controls (<code>lucidui/</code>): buttons, chips, sliders, switches, tabs, text fields, list items, loading indicators and the expressive shapes. Icons are Material Symbols drawn from Google's own paths, multisampled so they stay clean at the smallest sizes, and text is set in Google Sans Flex, bundled under its OFL licence.",
                    "code": ""
                },
                {
                    "text": "<b>Interface size.</b> <i>Settings → General → Size</i> scales the whole shell at once, from 75 to 125 %: the bar, dock, panels, menus, desktop widgets and the text in them. Apps and the monitor's own scale are left as they are. Widgets keep their place against the edge or corner they sit nearest, and the new size applies when the slider is let go.",
                    "code": ""
                },
                {
                    "text": "<b>Progress waves.</b> Timers, the stopwatch, the media disc and the session screen draw their rings the M3 Expressive way: the active arc waves, the track stays still.",
                    "code": ""
                },
                {
                    "text": "<b>A session screen.</b> SUPER+Escape opens lock, suspend, log out, restart and shut down in one full-screen sheet. The three that end the session need a second press within four seconds.",
                    "code": ""
                },
                {
                    "text": "<b>A window switcher.</b> CTRL+ALT+TAB lays out every open window on every workspace, the special ones included, newest first and with live previews. As on Windows it stays up once the keys are let go: Tab or the arrows move, Enter switches, Delete closes the window and Esc backs out. CTRL+ALT+TAB again steps on; with SHIFT it steps back.",
                    "code": ""
                },
                {
                    "text": "<b>Password beads.</b> On the lock screen, in the polkit prompt and on the login screen, each character typed drops a Material Expressive shape that melts into a dot. A selection gathers its beads into one band, and Ctrl+A sweeps it across from the left. The shapes are androidx's own MaterialShapes, worked out from the same numbers rather than drawn by eye.",
                    "code": ""
                },
                {
                    "text": "<b>The lock screen grows out of your desktop.</b> Locking takes a picture of each display first, so the lock starts as exactly what was on screen, which frosts, sinks into a card and gives way to the wallpaper. Unlocking runs it back: the cards fall away, the desktop rises through the frost, and the last moments fade straight onto your live windows.",
                    "code": ""
                },
                {
                    "text": "<b>Workspaces as shapes.</b> The workspace pill's resting look: an empty workspace is a dot, one with windows a square, the one you are on a new Material shape on each visit, and neighbouring busy workspaces join into one run. The pill stretches from one to the next, and the marks under it take its ink exactly. Hovering still brings the numbers.",
                    "code": ""
                },
                {
                    "text": "<b>The clock is an app.</b> Behind the pill: Today, with the weather and what is next; a month calendar with reminders; countdown timers and a pomodoro; a stopwatch with laps; and world clocks. Whatever is counting shows on the pill as a chip with a ring, and the timers are shared with the Timer widget and the control centre's Timer tile.",
                    "code": ""
                },
                {
                    "text": "<b>The pomodoro has options of its own.</b> The tune button on its card opens them in place: four presets (25 / 5, 50 / 10, 15 / 3, 90 / 20), a stepper for each length and for the rounds, and a daily goal the card counts toward. Breaks and focus sessions can each start by themselves or wait for you, a set can stop after its long break instead of repeating, and do-not-disturb can be held for as long as a focus session runs. A phase in hand takes another minute from the card, or any number over IPC (<code>timer pomodoroAdd</code>, beside <code>pomodoroSkip</code> and <code>pomodoroStop</code>). The same options sit under <i>Pomodoro</i> on Settings' Date &amp; Time page.",
                    "code": ""
                },
                {
                    "text": "<b>Every widget is rebuilt</b>, and four new ones join them: Timer, At a Glance, Photo and Fetch. A widget's right-click menu is a new sheet with live previews of its looks.",
                    "code": ""
                },
                {
                    "text": "<b>A widget panel.</b> Right-click the desktop and choose <i>Widget Panel</i>, or pick Widgets in the launcher's mode bar: a sheet slides in with every widget drawn live. Drag one straight out to where it should sit — it snaps like any card — or click it into the first free spot. It searches by name or by what a widget does, lists what is already out (hover to find a card, click for its sheet, lock or remove it) and switches layouts. While it is open the cards come up over your windows with a − on each, and a card dragged onto the sheet is taken off. <code>qs ipc call widgets panel</code> toggles it.",
                    "code": ""
                },
                {
                    "text": "<b>The launcher</b> gains a head band with its modes, the calculator's answer as a card at the top of the results, and prefixes: <code>?</code> for the web, <code>$</code> to run a command in your terminal and <code>:</code> for emoji. Apps can be hidden from it, and it has a page of its own in Settings.",
                    "code": ""
                },
                {
                    "text": "<b>Control centre tiles are yours to arrange.</b> <i>Edit tiles</i> lets you drag them into any order and add or remove them from a shelf of spares; the sliders ease as they move.",
                    "code": ""
                },
                {
                    "text": "<b>Switching wallpaper no longer stalls the desktop.</b> The colours are worked out at low priority, one run at a time with the newest request winning, and the shell crossfades its own palette alongside the picture. Browsing the wallpaper strip works out colours only for the picture you stop on, and kitty, VSCodium, Discord, Spotify, Steam, GTK and the login screen follow once, a few seconds later. The strip opens from small cached copies rather than decoding every original, 8K ones included, each time.",
                    "code": ""
                },
                {
                    "text": "<b>Window borders follow the palette</b>, and the starship prompt takes the palette's colours without its format being replaced.",
                    "code": ""
                },
                {
                    "text": "<b>A Storage page.</b> <i>Settings → Storage</i> shows what fills each drive, by kind and as a map you can zoom through from your home folder or the whole disk, what could go (package caches, old trash, duplicates and large files in your own folders) with a confirm for each, and the drives themselves with their health. It warns when space runs low and can empty trash after a number of days. The bar's disk card and the System widget now count free space as <code>df</code> does, leaving the root reserve out.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "graphic_eq",
            "title": "Sounds",
            "intro": "",
            "images": [
                {
                    "src": "assets/settings-sound.webp",
                    "alt": "Settings on the Sound page: the system sounds, each with a switch and a play button"
                }
            ],
            "items": [
                {
                    "text": "<b>Lucid has sounds of its own.</b> The freedesktop bells and drops are gone; every sound is synthesised — FM bells, plucks, blips and sweeps, nothing recorded — by <code>support/sounds/build-sounds.py</code>, all in one key and levelled to one loudness, so a volume you set means the same thing for each.",
                    "code": ""
                },
                {
                    "text": "<b>Eight notification sounds</b>: Glint, Pulse, Chime, Tap, Orbit, Halo, Beacon and Alert, picked from chips that play as you choose. A saved freedesktop choice carries over to its nearest match.",
                    "code": ""
                },
                {
                    "text": "<b>System sounds</b> for a USB or Bluetooth device connecting and leaving, the charger going in and out, a full charge, low and critical battery, the camera turning on and off, and a screenshot. <i>Settings → Sound → System sounds</i> has a switch and a play button for each, and one volume for all of them. They keep quiet while you are silenced, apart from the battery warnings. The timer and pomodoro alarm is new as well, and <b>reminders ring out loud</b> now — they used to arrive in silence — with a switch and a play button for each under <i>Settings → Date &amp; Time → Timers</i>.",
                    "code": ""
                },
                {
                    "text": "<b>Tiny ticks for your own keys</b>: volume and brightness tick at the level just set — where a drag or a held key starts and where it stops, not at every step — and Caps Lock and the microphone answer on and off. Dimming while you are away stays quiet. They start from <a href=\"https://kenney.nl\">Kenney</a>'s Interface Sounds (CC0).",
                    "code": ""
                },
                {
                    "text": "<b>A toast for USB devices</b>, named and drawn as what they are — a phone, a mouse, a drive. The laptop's own built-in parts stay quiet, a hub full of devices is one toast, and a device that drops and comes straight back is not news.",
                    "code": ""
                },
                {
                    "text": "<b>Camera on and camera off</b>, with the app using it, the way Windows 11 says so. Nothing polls for it: the camera's device is watched for being opened and closed. With the Privacy module on the bar, its own camera toast folds into the same pill.",
                    "code": ""
                },
                {
                    "text": "<code>qs ipc call -- sounds play &lt;name&gt;</code> plays any of them; <code>sounds list</code> names them all.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "favorite",
            "title": "From Ciro Rivera",
            "intro": "Ciro wrote everything in this section, and a good deal of 1.10.5 besides. The pull requests arrived tested, explained and ready, and the shell is better in places nobody had asked about yet. A huge thank you, @ciroenrique4-eng.",
            "images": [],
            "items": []
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Settings",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20/settings.webp",
                    "alt": "The Windows and Input pages"
                }
            ],
            "items": [
                {
                    "text": "<b>Search every setting.</b> A field at the head of the settings rail searches every row on every page, not just the page names: the results say which card a row sits in, and opening one scrolls to the row and flashes it. <code>Ctrl+F</code> focuses the field, typing anywhere starts a search, and <code>qs ipc call -- settings search &lt;words&gt;</code> opens Settings with the search typed. It replaces the rail's filter. By Ciro Rivera in #34.",
                    "code": ""
                },
                {
                    "text": "<b>A Windows page for Hyprland.</b> Gaps, border width and colour (none, the accent, or a gradient through the palette, which follows the theme), corners and their shape, shadow, dimming; the tiling layout with each layout's own options and a live preview; and focus, the cursor, resizing, snapping and animations. Only what you change belongs to Lucid, it applies without a reload, each row's reset hands the option back to your own config, and a file of yours required after Lucid's still wins, with the row saying so. By Ciro Rivera in #46.",
                    "code": ""
                },
                {
                    "text": "<b>An Input page for Hyprland.</b> Keyboard layouts in order, picked from every layout and variant the system knows; the key that switches them; what Caps Lock does; key repeat and Num Lock. Mouse speed, acceleration, scrolling and left-handed buttons; the touchpad's tapping, scrolling and palm rejection; and how the workspace swipe feels. By Ciro Rivera in #47.",
                    "code": ""
                },
                {
                    "text": "<b>Corner rounding.</b> One dial under <i>Settings → General → Shape</i>, from square to half as round again as shipped, live: cards, panels, menus, the bar's and the dock's pills, buttons, chips, switches and the search fields all follow it, while avatars, dots and the like stay round. By Ciro Rivera in #18.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Colours and palettes",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Templates follow every palette.</b> The matugen templates that carry the palette into other applications (Hyprland, Zen, rofi, waybar, pywalfox and your own) used to follow only the wallpaper; the fixed themes and pywal reach them too now. They render one at a time, so one broken template no longer breaks the others, and what happened to each is recorded, with a toast naming any that failed. By Ciro Rivera in #36.",
                    "code": ""
                },
                {
                    "text": "<b>A Colours page.</b> Matugen's scheme style (nine of them, from Tonal to Monochrome), its contrast, and which of the wallpaper's dominant colours the palette starts from. <b>Your colour</b> is a new theme built from a single colour, typed as hex, picked off the screen or chosen from a few. Below that, every app template with how its last render went, a switch for each, the apps that are installed but not wired up yet, and a form for a template of your own that you can try before adding. By Ciro Rivera in #38.",
                    "code": ""
                },
                {
                    "text": "<b>A Palettes page.</b> A gallery of the 560 base16 and base24 schemes tinted-theming collects, drawn in their own colours, searchable and filtered by dark or light, one click to add or use. Themes import from a repo or a file, light schemes are finally kept light (with a dark side worked out for them), and the palette on screen can be edited live and exported as a Lucid palette or base16 YAML. By Ciro Rivera in #40.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Bar",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20/bar.webp",
                    "alt": "A module's card on the Bar page, with its looks"
                }
            ],
            "items": [
                {
                    "text": "<b>Arrange the bar from Settings.</b> <i>Settings → Bar → Modules</i> shows the bar's three groups as lanes: drag a module along its lane or into another one, or use the arrow keys. Each module has a card with its switch, the group it sits in and a way to the rest of its settings, and a right click on a module in the bar opens its card. By Ciro Rivera in #44 and #50.",
                    "code": ""
                },
                {
                    "text": "<b>Three new modules</b>, all off until you switch them on. <b>Privacy</b> appears only while something uses the microphone, the camera or the screen, says which app, and can raise a toast as it starts. <b>Power</b> holds lock, suspend, hibernate, log out, restart and shut down, in the order you pick, under the machine's uptime. <b>Active window</b> shows the focused window and, opened, floats, pins, fullscreens, moves or closes it, or switches to another window on the workspace. By Ciro Rivera in #50.",
                    "code": ""
                },
                {
                    "text": "<b>Looks and options for the bar's own modules</b>, each on its card, every one starting from how the module already looks. The clock: one line or two lines beside the accent chip, and four ways to write the date. Media: a still cover or just the bars and the play button, a large-cover panel, and switches to hide it while nothing plays, drop the artist, cap the title's width, hide the play button and turn the volume wheel off. Workspaces: numbers instead of dots, how many always show, and the wheel on or off — the wheel switches workspaces now, which it never did. Notifications: a dot, or bell and count on an accent chip. The tray: every app's icon in the bar, the icons in the palette's colours, and a switch per app to keep it out. By Ciro Rivera in #50.",
                    "code": ""
                },
                {
                    "text": "<b>A bar on every display.</b> <i>Settings → Displays → The bar on its own → Every display</i> (or <code>qs ipc call -- displays bar all</code>) gives each screen a bar of its own, with that screen's workspaces. Notification popups, the privacy toast and the bar's ipc still come from one of them: the shell's display, or the one you are on. By Ciro Rivera in #14.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Launcher",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20/launcher.webp",
                    "alt": "A typed search finding a window, an app's actions and a power action"
                }
            ],
            "items": [
                {
                    "text": "<b>One search for everything open and everything to do.</b> Typed text now finds open windows by their app or their title (Return switches to it), apps' own actions like <i>New Private Window</i> (listed under the app when you type its name), and lock, suspend, log out, restart and shut down from three letters, ranked together with the apps and the commands. Restart, shut down and log out ask for a second Return. A typed address gets a row of its own at the top when nothing matches it better. Each has a switch under <i>Settings → Launcher</i>, beside a line under each app from its desktop entry (off to begin with). By Ciro Rivera in #17.",
                    "code": ""
                },
                {
                    "text": "<b>Power buttons by the search field</b>, off to begin with: pick which of lock, suspend, log out, restart and shut down show while nothing is typed. The ones that end the session turn red on the first press and act on the second. By Ciro Rivera in #17.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Sound and the phone",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>The Sound page shows what a device is doing.</b> A live level meter under the output and the microphone volume (so a dead microphone reads apart from a quiet one), balance for a stereo output with a way back to the centre, a Left/Right test, an app put back on the default device, and a Behaviour card for WirePlumber's own settings: remembering each app's volume and device, following the default, pausing when a device goes away, headset call mode and mono audio. The meters have a switch of their own. By Ciro Rivera in #11.",
                    "code": ""
                },
                {
                    "text": "<b>The phone widget</b> browses the phone's files (with a switch for the button), greys out what the phone has switched off and says why when tapped, says what an action just did, and with more than one phone paired steps to the next and remembers it. By Ciro Rivera in #15.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Control centre",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Night light.</b> hyprsunset warms the screen, fading in and out, by hand, from sunset to sunrise where you are (worked out locally, with no network) or between hours you set. Switching it while a schedule runs holds until the schedule next changes. Add the <i>Night light</i> tile with <i>Edit tiles</i>; right-click it for the warmth and the schedule. Settings → Displays and <code>qs ipc call nightlight</code> reach it too. By Ciro Rivera in #53.",
                    "code": ""
                },
                {
                    "text": "<b>The disk card counts LVM and LUKS volumes.</b> A root on LVM read as <i>0 / 477 GB</i>; volumes now count toward the disk they live on, and a btrfs partition with several subvolumes mounted is counted once rather than once per subvolume. By Ciro Rivera in #27.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Screenshots and recording",
            "intro": "",
            "images": [
                {
                    "src": "assets/screenshot-toolbar.webp",
                    "alt": "The screenshot toolbar over the dimmed desktop: photo, video, text and colour, then a region or the whole display"
                },
                {
                    "src": "assets/whatsnew/1.20/preview.webp",
                    "alt": "The preview card after a capture"
                }
            ],
            "items": [
                {
                    "text": "<b>A preview card after each capture</b>, in the corner of the display you captured: click to open, drag it into any app that takes files, or copy, mark up, show in its folder or delete (twice) from its buttons. Recordings get one too, with their length. Settings → General → Screenshots picks the card, the old notification or nothing. Screenshots also save about three times faster. By Ciro Rivera in #52.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Network, workspaces and the clipboard",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Share a Wi-Fi network as a QR code</b>, from its row in Settings → Network or the bar's Wi-Fi panel, the way phones do it. The password shows on request and copies without landing in the clipboard history. By Ciro Rivera in #51.",
                    "code": ""
                },
                {
                    "text": "<b>Special workspaces</b> can blur what is behind them, keep a margin from the screen's edges so they sit like a card, and be made by you: a name, a mark, the apps it brings up and a key of its own. By Ciro Rivera in #45.",
                    "code": ""
                },
                {
                    "text": "<b>The clipboard history has a preview pane</b>: an image at full size, text in full, a colour as a large swatch. Entries are sorted into images, colours, links, addresses and text, and <code>Ctrl+Shift+Del</code> twice clears the lot. By Ciro Rivera in #10.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "build",
            "title": "Fixed",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>The charger and low-battery toasts never fired</b>, and the <i>Preview</i> button under Notifications → System events did nothing. By Ciro Rivera in #25.",
                    "code": ""
                },
                {
                    "text": "<b>Log out did nothing on a Lua config</b>, from the session screen, the lock screen or SUPER+M: <code>hyprctl dispatch exit</code> is not a dispatcher there. It tries <code>hl.dsp.exit()</code> first now. By Ciro Rivera in #30.",
                    "code": ""
                },
                {
                    "text": "<b>The bar clock's AM/PM</b> is the locale's own now (\"P.M.\", \"午後\"). Ciro found it doubled outside English locales in #29.",
                    "code": ""
                },
                {
                    "text": "<b>Bluetooth devices that drop two seconds after connecting</b>, over and over: an adapter that is not pairable lets the pairing through but throws its key away. Pairing now holds pairable on until it is done. By Ciro Rivera in #9.",
                    "code": ""
                },
                {
                    "text": "<b>A region or a recording on a second display</b> came from the wrong place, or recorded both displays. By Ciro Rivera in #8.",
                    "code": ""
                },
                {
                    "text": "<b>The installer offered to restart a shell that was not running</b>, and did, with plain <code>qs</code>. By Ciro Rivera in #7.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "group",
            "title": "Contributed",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Workspaces that say which display they are on.</b> With two or more displays the bar's dots fall into one run per display, each led by the display's number on hover, the accent follows the display you are on, and the overview lays out one block per display. <i>Settings → Displays → Workspaces → Group by display</i> turns it off; one display looks as it always did. By @MrZtone in #54.",
                    "code": ""
                },
                {
                    "text": "<b>The installer names what a replaced <code>hyprland.conf</code> sourced</b>, since a Lua config cannot read those files, and the README gives the xray layer rule in Lua. By @arbelonson-source in #5.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "speed",
            "title": "Performance",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>About 150 MB less memory at rest</b> (790 to 639 MB resident on an Iris Xe laptop). The bundled font keeps only the three axes the shell varies, 4.15 MB down to 569 KB; the launcher, the settings window and the emoji picker are built the first time they are used rather than at start-up; and an unused NVIDIA driver is no longer loaded on a machine without an NVIDIA card.",
                    "code": ""
                },
                {
                    "text": "<b>The bar no longer redraws at 60 fps on an idle desktop.</b> Every looping animation in it now stops while it cannot be seen. Thanks to @theheavenlyhacker, whose measurements in #43 showed what it was costing.",
                    "code": ""
                },
                {
                    "text": "<b>Hyprland no longer freezes for five seconds while a window resizes.</b> The OSD asked Hyprland for the lock keys; it reads the keyboard's own LEDs now.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "download",
            "title": "Installer",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "New packages: <code>hyprsunset</code> (night light), <code>qrencode</code> (Wi-Fi codes), <code>xdg-terminal-exec</code> (the launcher's <code>$</code> mode), <code>inotify-tools</code> (the camera on/off toast), <code>sshfs</code> (browsing a phone's files), <code>pipewire-audio</code> with <code>sound-theme-freedesktop</code> (the Sound page's Left/Right test), and <code>smartmontools</code> and <code>udisks2</code> (drive health and mounting on the Storage page).",
                    "code": ""
                },
                {
                    "text": "<b>Google Sans Flex</b> is installed to <code>~/.local/share/fonts/lucid</code> for the apps the Environment page dresses, and beside the SDDM theme, which now draws in it the way the lock screen does.",
                    "code": ""
                },
                {
                    "text": "<b>Hyprland:</b> <code>modules/settings.lua</code> applies what the Windows and Input pages set, and <code>modules/plugins.lua</code> holds plugin settings, each applying only while its plugin is loaded. It ships with the tilting cursor of <a href=\"https://github.com/virtcode/hypr-dynamic-cursors\">hypr-dynamic-cursors</a>; the installer offers to build it (<code>--no-plugins</code> skips that) with <code>scripts/cursor-plugin.sh</code>, against the headers the hyprland package installs and without root. <code>modules/autostart.lua</code> runs the same script on every login, so the cursor is still there after a restart, and is rebuilt by itself after a Hyprland update.",
                    "code": ""
                },
                {
                    "text": "The theme scripts behind the Colours and Palettes pages go into <code>~/.config/lucid</code> with the rest.",
                    "code": ""
                },
                {
                    "text": "<b>The login screen wears whoever is picked.</b> Each account paints its own wallpaper and palette into the SDDM theme, and choosing another account in the user picker crossfades the greeter to theirs. Before, the installer handed the whole theme to whichever account ran it last, and every other account's wallpaper changes were dropped without a word. The theme now stays root's, with one sticky <code>users/</code> directory each account writes only its own part of, and an account the greeter has nothing for yet is painted at its next login.",
                    "code": ""
                },
                {
                    "text": "<b>Settings' file choosers no longer need zenity.</b> Picking an account picture, a wallpaper, a template or a palette did nothing at all without it. They now open the desktop's own chooser through the XDG portal, with zenity and kdialog as fallbacks and a notification when none is there, and they float instead of tiling.",
                    "code": ""
                },
                {
                    "text": "Restarting the shell at the end of an install goes through <code>launch-shell.sh</code>, as a login does, so it comes up on the same render backend.",
                    "code": ""
                },
                {
                    "text": "<b>SUPER+R restarts the shell as well</b>, as its keybind always said: Hyprland reloads, the shell stops cleanly and comes back through <code>launch-shell.sh</code>. The calculator (F12) opens as a small floating window rather than tiling, and with more than one keyboard layout Alt+Shift switches between them (<i>Settings → Input</i> picks another key).",
                    "code": ""
                }
            ]
        }
    ]
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
