import QtQuick

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: "1.20.1"
    readonly property string name: ""
    readonly property string date: "15 October 2026"
    readonly property bool placeholders: false
    readonly property var heroes: []
    readonly property string intro: "A point release on top of Lucid 2: icons on the desktop, bar modules that join into one island, live wallpapers and three new ways to pick a wallpaper, five new widgets, files over Bluetooth, a Startup page, fingerprint unlock, and the fix for Steam opening and closing in a loop. Much of it is once again the work of <b>Ciro Rivera</b>, fifteen pull requests of it."
    readonly property var sections: [
        {
            "level": 1,
            "icon": "build",
            "title": "Fixed",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Steam no longer opens and closes in a loop.</b> <i>Settings → Environment</i> writes the cursor theme into <code>~/.icons/default/index.theme</code>, the file that says what the default cursor theme is, and on first start it takes the name the machine already uses. On a machine where that name was <code>default</code>, the default theme ended up inheriting itself. Steam's window, a Chromium inside, follows that chain with no end and crashed each time it needed a cursor, so it flashed up and vanished over and over (#55, #57). Lucid never writes such a chain now and takes back one it wrote before, so the next start repairs it with nothing to do. Thanks to @xherqs, who found the file.",
                    "code": ""
                },
                {
                    "text": "<b>Steam gets the right graphics driver.</b> The installer left Steam's Vulkan drivers to pacman, which picks NVIDIA's whenever no 32-bit driver is installed yet. On an AMD or Intel machine that left Steam and every 32-bit game without Vulkan. It now installs the drivers for the graphics cards the machine has, and a re-run adds the one an earlier install left out.",
                    "code": ""
                },
                {
                    "text": "<b>A second click on a bar module closes its pop-up</b>, as a click anywhere else already did (#70).",
                    "code": ""
                },
                {
                    "text": "<b>The region screenshot opens after a reboot.</b> On a machine whose built-in screen is switched off just after start-up, it kept asking for that screen and gave up without a word. It now captures the display it is on, a capture that fails says so, and <code>qs ipc call snap status</code> shows what it tried. It also no longer waits for hours when the clock is set back after login.",
                    "code": ""
                },
                {
                    "text": "<b>Live wallpapers keep playing behind your windows.</b> By default they now hold still only under a fullscreen window, instead of under any window, which left them looking like a still picture whenever something was open. <i>Settings → Theme → Pause under windows</i> still offers <i>Any window</i>. A setting saved by an earlier version stays as it was.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "favorite",
            "title": "From Ciro Rivera",
            "intro": "Fifteen pull requests, some reworked on the way in. Thank you, Ciro.",
            "images": [],
            "items": []
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Desktop icons",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20.1/desktop-icons.webp",
                    "alt": "Folders, files and the Trash on the desktop beside the widgets"
                }
            ],
            "items": [
                {
                    "text": "<b>Icons on the desktop.</b> Your <code>~/Desktop</code> folder on the wallpaper of the main display, the way Windows, macOS and GNOME have it, turned on in <i>Settings → General → Desktop icons</i>. Folders, files and apps are drawn by the icon theme picked on the Environment page; pictures, videos, music with cover art and documents show thumbnails; the Trash fills up, and USB sticks and phones appear while they are mounted. Widgets keep their space: an icon under one steps aside, live while the widget is dragged. In #64.",
                    "code": ""
                },
                {
                    "text": "<b>It works like a real desktop.</b> Click, Ctrl- or Shift-click, or draw a box; drag into a folder, onto the Trash or a drive, or out to a file manager or a browser. Space opens a quick look, F2 renames, and the right-click menu cascades into submenus: <i>New Item</i> from <code>~/Templates</code>, <i>Open With</i>, compress and extract, tags, <i>Get Info</i>, undo, and <i>Send to</i> your folders, a phone over KDE Connect or a device over Bluetooth (#66).",
                    "code": ""
                },
                {
                    "text": "<b>Pins make shortcuts.</b> Pull a pinned app up off the dock and drop it on the desktop for a launcher there; the pin stays on the dock.",
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
                    "src": "assets/whatsnew/1.20.1/bar-islands.webp",
                    "alt": "Bar modules joined into islands, one with its panel open"
                }
            ],
            "items": [
                {
                    "text": "<b>Modules that join into one island.</b> In <i>Settings → Bar → Arrangement</i> a link sits between every two neighbours. Tap it and they sit flush as one island, or one notch with its fillets only at the ends, with a faint line where they meet (<i>Lines between joined modules</i>). A module opened in place hangs its panel from its own stretch of the group, its corners curving into the neighbours. In #67.",
                    "code": ""
                },
                {
                    "text": "<b>Notched pop-ups</b>, off by default in <i>Settings → Bar</i>: in pop-up mode the pop-up grows straight down out of its module or group, its corners blending into the bar the way the notch's do.",
                    "code": ""
                },
                {
                    "text": "<b>A full bar.</b> A third shape beside islands and notches: one strip across the whole top edge with every module on it, hanging into the screen's corners (<i>Screen corners</i> sizes them). Hovering a module lifts its own island out of the strip, and an open panel curves into the strip where it meets it. In #16.",
                    "code": ""
                },
                {
                    "text": "<b>Open on hover and auto-hide</b>, both off by default. A module can unfold under the pointer without taking the keyboard from the window you are typing in, and a click makes it an ordinary open panel. Auto-hide slides the bar up out of sight and hands its space to the windows, and it comes back when the pointer touches the top of the screen or a panel is open. In #16.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Wallpapers",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20.1/wallpaper-picker.webp",
                    "alt": "The wallpaper picker in its Tiles style, with the Pictures and Live switch beside it"
                }
            ],
            "items": [
                {
                    "text": "<b>Four picker styles</b>, each with a live thumbnail in <i>Settings → Theme → Wallpaper picker</i>: <i>Strip</i> (the carousel), <i>Pills</i>, <i>Tiles</i> and <i>Bento</i>. <i>Arrow keys</i> on the same page moves the wallpaper with ← → or ↑ ↓, so the arrows can stay with the search field. In #65.",
                    "code": ""
                },
                {
                    "text": "<b>The transition is yours.</b> Presets (Soft, Circle, Sweep, Wave, Instant, Random) or your own, saved and named: the effect, its length, angle and curve, and whether it grows from the centre, the picked card or the cursor. <i>Try transition</i> runs it on the wallpaper you have.",
                    "code": ""
                },
                {
                    "text": "<b>Live wallpapers.</b> Videos in the wallpaper folder (mp4, webm, mkv, mov) get a side of the picker of their own, and <code>&gt;live</code> goes straight to them. A video plays behind the desktop's icons and widgets, the colours come from its first frame, and it holds still under windows, behind the lock screen and, if you like, in game mode. <i>Settings → Theme → Live wallpapers</i> turns it off and picks the decoder; on a hybrid laptop <i>Automatic</i> keeps the graphics card asleep, and the same page lists the videos beside the pictures. In #73.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Bluetooth",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Files, both ways.</b> A phone or laptop sending something brings a notification with Accept and Decline, which then follows the transfer and opens what arrived; <i>Settings → Bluetooth</i> picks the folder and whether paired devices skip the question. <i>Send files</i> on a paired phone or computer, in the control centre and in Settings, sends one file after another, with one notification following it all. In #60.",
                    "code": ""
                },
                {
                    "text": "<b>A pairing agent.</b> Nothing answered Bluetooth's pairing questions before, so AirPods could come up connected with no sound and a phone that confirms a code could not pair. The code now arrives as a notification with Pair and Decline. <i>Answer pairing questions</i> turns it off where another app already does.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Windows and displays",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Pinned windows stand out</b> with a border of their own from the palette and a tab with a pin in a corner, which unpins the window on a click. <b>A window asking for attention</b> gets a tab with a ringing bell once you are on its workspace. Both are on <i>Settings → Windows</i>. In #61.",
                    "code": ""
                },
                {
                    "text": "<b>The display map</b> lands a dragged display against a neighbour when it is let go, never on top of one, and the arrow keys move a picked one. Pointing at a box shows its number on the real screen. Resolution, refresh rate, scale, rotation and mirroring now ask <i>Keep these display settings?</i> and go back by themselves after 15 seconds. In #62.",
                    "code": ""
                },
                {
                    "text": "<b>The launcher and the OSD</b> open on the display you are working on, unless <i>Settings → Displays</i> pins the shell to one. In #63.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Widgets and apps",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>A GitHub widget</b>: your contributions as your profile draws them, as many weeks as you drag it wide, or your streak. It needs only your username, no token. In #69.",
                    "code": ""
                },
                {
                    "text": "<b>The battery widget</b> no longer shows days of time left while plugged in and full, and a battery held below a charge limit reads <i>Plugged in</i>, not <i>Charging</i>. In #74.",
                    "code": ""
                },
                {
                    "text": "<b>Qt and KDE apps follow the theme.</b> Prism Launcher, Dolphin, Kate and the rest came up in light colours whatever the theme. With qt6ct installed, the installer now gives Qt and KDE apps a colour scheme made from the theme; one you picked yourself stays. In #68.",
                    "code": ""
                },
                {
                    "text": "<b>Open GTK4 and libadwaita apps repaint</b> when the theme or the wallpaper changes, instead of on their next start. In #75.",
                    "code": ""
                }
            ]
        },
        {
            "level": 2,
            "icon": "notes",
            "title": "Startup",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>A Startup page.</b> <i>Settings → Startup</i> opens apps at login, sets environment variables, and starts what apps put in <code>~/.config/autostart</code> when the session does not (the plain Hyprland session never did, so an app's own <i>Start at login</i> switch did nothing). It is kept in <code>~/.config/hypr/lucid-startup.lua</code>, which an update never overwrites, unlike lines added by hand to <code>modules/autostart.lua</code> and <code>modules/env.lua</code>. The page lists those lines too and moves them over with one button, and variables that no longer help, such as <code>MOZ_ENABLE_WAYLAND</code>, come with a note saying why. In #77.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "notes",
            "title": "New widgets",
            "intro": "",
            "images": [
                {
                    "src": "assets/whatsnew/1.20.1/widgets.webp",
                    "alt": "The Expressive preset: shaped quick toggles and shortcuts, the sun and the day's progress"
                }
            ],
            "items": [
                {
                    "text": "<b>Five new widgets, in Material You's shapes.</b> <i>Progress</i> shows how much of the day, the week, the month and the year has gone, as a wavy ring, a bar each, or the whole year as dots. <i>Quick toggles</i> puts Wi-Fi, Bluetooth, Do not disturb and more on the desktop, as switches that turn into shapes when they come on, a pill of buttons or Quick Settings tiles. <i>Shortcuts</i> sets your dock's apps on shapes of their own, in a pill that blooms under the pointer, or as a folder like a phone's. <i>Search</i> keeps the launcher's search on the desktop, as a phone's search bar or over the launcher's modes. <i>Sun</i> works out sunrise, sunset and the daylight left where you are.",
                    "code": ""
                },
                {
                    "text": "<b>New faces.</b> The clock gains <i>Oval</i>, the time on a band across a round face, and <i>Dial</i>, bold hands on a scalloped face with the seconds as a dot. The weather gains <i>Details</i>. What is playing gets four that are not square: <i>Pill</i>, <i>Orbit</i>, <i>Capsule</i>, and <i>Shape</i>, the cover cut to a shape of its own that morphs with every track.",
                    "code": ""
                },
                {
                    "text": "<b>An <i>Expressive</i> preset</b> lays the new ones out together.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "notes",
            "title": "Also new",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>A dock that hides only when it is in the way.</b> <i>Settings → Dock → Auto-hide → Dynamic</i> tucks it away while a tiled window is open on the workspace, or a floating one overlaps it, and leaves it up on a clear desktop.",
                    "code": ""
                },
                {
                    "text": "<b>A notched launcher.</b> With the dock hidden or turned off, the launcher opens as a notch from the bottom edge.",
                    "code": ""
                },
                {
                    "text": "<b>The Caps Lock and Num Lock cards can be turned off</b>, in <i>Settings → General → On-screen display</i> (#59).",
                    "code": ""
                },
                {
                    "text": "<b>Metric or imperial</b>, in <i>Settings → Date &amp; Time → Units</i>: the weather in the bar, on the lock screen and in the widgets, and the temperatures of the processor, graphics card and drives, in °C and km/h or °F and mph, all at once. It takes over from the °C or °F the weather widgets each had (#76).",
                    "code": ""
                },
                {
                    "text": "<b>Apps match the shell in light mode.</b> Lucid's light bars and panels are tinted toward the accent rather than plain white, but the apps it themes (VSCodium, GTK and Qt apps, kitty and the rest) were given the raw, near-white palette. They now get the same tinted surfaces. Dark mode is unchanged.",
                    "code": ""
                },
                {
                    "text": "<b>A new prompt and terminal.</b> The starship prompt shows how long the last command took, then the folder and the git branch, with the prompt on a line of its own. kitty draws a block cursor that leaves a short trail as it jumps and stays a block at the prompt.",
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
                    "text": "<b>Fingerprint unlock.</b> With <code>fprintd</code> installed and a finger enrolled, the lock screen takes a fingerprint at the same time as the password, whichever comes first; a machine without a reader behaves as before. By @SKetU-l in #78. The login screen takes one as well: press Enter on an empty field, then touch the sensor.",
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
                    "text": "New packages: <code>bluez-obex</code> (Bluetooth files), and <code>ffmpegthumbnailer</code> with <code>gvfs</code> (the desktop icons' thumbnails, drives and Trash). Installing Steam brings the Vulkan drivers for the machine's own graphics cards.",
                    "code": ""
                },
                {
                    "text": "<b>The new <code>starship.toml</code> and <code>kitty.conf</code></b> replace the copies an earlier release installed, keeping a backup. One you have changed is left alone; the new ones are in <code>support/look/</code>.",
                    "code": ""
                },
                {
                    "text": "Where the desktop icons sit carries over a reinstall.",
                    "code": ""
                },
                {
                    "text": "<b>The login screen's fingerprint</b> is asked about when <code>fprintd</code> is installed, since it adds two marked lines to <code>/etc/pam.d/sddm</code> (backed up first, a typed password still checked before the reader). <code>sudo support/sddm/install-theme.sh --no-fingerprint</code> takes them out.",
                    "code": ""
                },
                {
                    "text": "A Hyprland config of your own gets <code>require(\"modules.startup\")</code> appended, so the Startup page works there too.",
                    "code": ""
                }
            ]
        }
    ]
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
