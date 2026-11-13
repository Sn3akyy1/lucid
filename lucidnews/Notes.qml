import QtQuick

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: "1.21"
    readonly property string name: "An ecosystem"
    readonly property string date: "13 November 2026"
    readonly property bool placeholders: false
    readonly property var heroes: [
        {
            "src": "assets/desktop.webp",
            "alt": "The Lucid desktop in blue: a clock, a calendar, the song playing and the weather on the left, battery, system and to-do widgets on the right, and the visualiser along the bottom"
        }
    ]
    readonly property string intro: "<b>Lucid is an ecosystem.</b> It began as a shell around your windows; now it is everything between logging in and logging out, made to belong together. It has apps of its own: Lumen for your files and every app's file dialog, Lens for pictures and videos, and a rebuilt LucidShot. Its own icons and its own pointer are drawn in your palette, and the login screen matches the lock. The desktop is arranged in edit mode right where it stands, the bar can take the bottom edge and open its panels as one shape with it, the control centre is laid out on a grid of your own, whatever plays comes with its lyrics, and everything moves on springs.<br><br>Twenty-three of the pull requests in this one are <b>Ciro Rivera</b>'s, the entries marked with a number below unless someone else is named. Thank you, Ciro, and thank you @SKetU-l and @naevui."
    readonly property var sections: [
        {
            "level": 1,
            "icon": "apps",
            "title": "Apps of Lucid's own",
            "intro": "",
            "images": [
                {
                    "src": "assets/apps.webp",
                    "alt": "Settings, Lumen and Lens open together in a red palette, with the desktop's icons on the right"
                },
                {
                    "src": "assets/lumen.webp",
                    "alt": "Lumen in a green palette over a bamboo wallpaper: places on the left, folders in the middle and the Home folder's details on the right"
                }
            ],
            "items": [
                {
                    "text": "<b>Lumen, a file manager of Lucid's own, and every app's file dialog.</b> SUPER+E opens it, folders open in it, and the <i>Open</i> and <i>Save</i> dialogs of every app are Lumen windows too, filters, overwrite check and all. Tabs with a strip that always shows: pin one and it stays at the front of every new window, give it a colour, drag it out into a window of its own and back. Bookmarks with names and colours (Ctrl+D), Recent, Trash, your drives under <i>Devices</i> with eject, a path bar you can type into, a grid or a list that zooms from 24 to 256 pixels, and a preview pane. Right-click for <i>Open with…</i>, <i>Set as wallpaper</i>, copying the path, compressing and extracting, and more. Copies and moves run in the background, and Lumen does not quit until they are done.",
                    "code": ""
                },
                {
                    "text": "<b>Network drives in Lumen.</b> <i>Connect to server</i> (Ctrl+K, the sidebar's new <i>Network</i> section or the ⋮ menu) opens a shared folder on another computer, a NAS or a server. Type its address (<code>smb://nas.local/media</code>, <code>sftp://you@server</code>, <code>ftp://…</code>, Windows' own <code>\\\\server\\share</code>, or just a name) and sign in if it asks: as a registered user or a guest, with the password kept in your keyring if you tick it. A host Lumen has never seen asks first. Connected shares sit under <i>Network</i> with their free space and a button that disconnects them, and their files open, copy, move, rename and delete like any others; a share has no trash, so deleting says it can't be undone. Apps' open and save dialogs reach them too. Bookmark a folder on a share and a click on it connects again later; the addresses you typed stay in the dialog's <i>Recent</i> list, and <i>Nearby</i> shows the computers sharing folders on your network once Avahi runs.",
                    "code": ""
                },
                {
                    "text": "<b>Lens, a picture viewer of Lucid's own.</b> Open a picture and the rest of its folder comes with it, in the order Lumen shows that folder: the arrow keys, a swipe or a drag slide to the next one, the filmstrip jumps to any, and <i>All pictures</i> (G) lays out the whole folder to search by name. The wheel or a pinch zooms where the pointer is, a double click goes to 100%, and a zoomed picture pans with a map of where you are. <i>Edit</i> (E) crops it (free, its own shape, square, 4:3, 3:2, 16:9 or your screen's), turns, flips and straightens it, adjusts its light and colour, or gives it one of twelve looks; <i>Draw</i> (D) adds pen, highlighter, arrows, lines, boxes, rings, words and boxes that pixelate what is under them. Edits wait for each picture until they are saved, over it or as a copy; a turned JPEG is saved without losing any quality. Saving over a picture keeps its original, for good: <i>Revert to original</i> (right-click, the editor or <i>Details</i>) brings it back whenever you like, and holding \\ shows it in the edited one's place. Right-click for <i>Set as wallpaper</i>, <i>Open with…</i>, <i>Show in Lumen</i>, copying the picture, its path, the text in it or a colour off it, sending it to your phone, renaming it and the trash. <i>Details</i> (I) show the camera's settings, where it was taken, a histogram and the colours it is made of. Slideshow (F5) and full screen (F) too.",
                    "code": ""
                },
                {
                    "text": "<b>Videos in Lens.</b> Videos sit in the folder with the pictures and play where they are, with a time line that waves while they play, volume, speed and play-on-repeat; a click pauses, a double click goes full screen, and J, L, comma and full stop step back and on. A frame can be saved as a picture or copied, a sideways phone video turned upright without encoding it again (its original kept), and <i>Trim</i> (E) cuts a part out as a copy: exactly at the handles, or at once at the nearest keyframe. <code>lens --default-videos</code> makes Lens what opens videos as well.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "edit",
            "title": "Edit mode",
            "intro": "",
            "images": [
                {
                    "src": "assets/edit-mode.webp",
                    "alt": "Edit mode: the widget panel on the left with its clock, calendar and progress galleries, widgets on the shaded desktop, and the edit toolbar above the dock"
                }
            ],
            "items": [
                {
                    "text": "<b>Arrange the desktop where it stands.</b> Pick <i>Edit Desktop</i> from the desktop's right-click menu, or right-click any bar module, and the wallpaper shades over so everything on the desktop can be arranged in place. Drag a bar module along the bar to move it, into another group, or down off the bar to take it out; one that has nothing to show right now keeps a dashed stand-in, so it can be moved too, and the link between two neighbours joins them into one island. Right-click a module, or the dock, for a sheet of its options beside it: its looks, the bar's or the dock's style and sizes. A click still opens a module, so the look just picked can be seen. The dock gets a handle: drag it up to float the dock higher, or down into the bottom edge to make it a notch. <b>Undo</b> takes back the last change and <b>Revert</b> everything since edit mode began; <b>Done</b>, or Escape, leaves it.",
                    "code": ""
                },
                {
                    "text": "<b>The bar and the widgets are set up there now.</b> <i>Settings → Bar</i> loses its arrangement editor and the per-module cards, and <i>Settings → Widgets</i> its layouts and its catalogue: modules are moved and set up in edit mode, and widgets come from the widget panel on the desktop, which has the layouts too. The Bar, Dock and Widgets pages each have a button that opens edit mode.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "toolbar",
            "title": "The bar",
            "intro": "",
            "images": [
                {
                    "src": "assets/bottom-bar.webp",
                    "alt": "The bar as one full strip along the bottom edge, with workspaces, the song playing and the clock on the left, the dock's apps in the middle and the system tray on the right"
                }
            ],
            "items": [
                {
                    "text": "<b>The bottom edge.</b> <i>Position</i> puts the bar on the bottom of the screen, and it slides over to the new edge. Its pop-ups open upwards, one that hides comes out of the bottom edge, and over a fullscreen window the launcher still rises from the edge. With the bar there the dock steps aside, and on a full bar the launcher rises out of the bar itself, one piece of glass with the strip. #100",
                    "code": ""
                },
                {
                    "text": "<b>Panels open as one shape with the bar.</b> On a full bar and with notches, an open panel grows out of the bar with no seam, panels side by side merge into one shape, and a module at either end can meet the screen's side and curve into it. #92, #95",
                    "code": ""
                },
                {
                    "text": "<b>Start and Apps.</b> <i>Start</i> is a button for the launcher, in a circle of its own, drawn as the dock's launcher button by default, or as Lucid's mark, your distro's logo, your picture or the word Start (#88). <i>Apps</i> puts the dock's pinned and running apps on the bar, with their dots, names and right-click menus; drag a pin to reorder it (#99). Joined, the two hover as one row.",
                    "code": ""
                },
                {
                    "text": "<b>The system tray, redesigned.</b> Both looks are rebuilt in Material You. <i>Icons</i> gives each app a slot like <i>Apps</i> does, with a mark that breathes when one wants your attention; <i>Collapsed</i> stacks the first three icons with a count. A click opens the tray: each app is a row with its real name, and its menu opens right in the row, submenus sliding in beside it. A right click on an icon opens that app's menu, a middle click and the wheel go to the app as before, and any app can be hidden from the bar.",
                    "code": ""
                },
                {
                    "text": "<b>The System module shows what you pick</b> of Wi-Fi, Bluetooth, the volume and its level, the microphone and the battery. #97",
                    "code": ""
                },
                {
                    "text": "<b>Content size.</b> <i>Settings → Bar → Content size</i> scales what is in the bar, 80 to 140%, without changing the bar's own height.",
                    "code": ""
                },
                {
                    "text": "<b>Joins hold.</b> A link between two modules carries across one that has emptied out between them, and modules sit on whole pixels, so joined ones leave no seam. #96",
                    "code": ""
                },
                {
                    "text": "<b>Notch edges.</b> A notch's edge blends are frosted like the rest of the bar, light up with it on hover, curve as a quarter ellipse beside a short module instead of stepping, and can reach up to 64 pixels.",
                    "code": ""
                },
                {
                    "text": "<b>Calmer motion.</b> A panel closes on the exit curve, modules leave the bar in order instead of all at once, a module's contents hold still while hover grows its pill, switching a look animates, and a panel too wide for its place clears the bar around it. Over a fullscreen window an open panel stands above it.",
                    "code": ""
                },
                {
                    "text": "<b>Fewer, clearer looks.</b> The clock's day and date are bold, the date in the accent, and the window title is bolder. The Notifications module's <i>Accent</i> look and the window title's <i>Chip</i> look are gone; a bar that used them takes the default.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "music_note",
            "title": "Music",
            "intro": "",
            "images": [
                {
                    "src": "assets/lyrics-widget.webp",
                    "alt": "The Lyrics widget singing along word by word over a red and grey wallpaper, beside a clock, a calendar, a to-do list and a note"
                },
                {
                    "src": "assets/lyrics-panel.webp",
                    "alt": "The media panel's Lyrics page for Skyfall by Adele, the line being sung lit and the ones around it fainter"
                }
            ],
            "items": [
                {
                    "text": "<b>Lyrics.</b> The media panel has a <i>Lyrics</i> button beside <i>Identify</i>: the song scrolls by, the line being sung springs up to full size and fills with colour letter by letter, the word being sung stands up a little, and a pause is three dots that fill through it and let go just before the next line. A click on a line jumps there. <code>qs ipc call media lyrics</code> opens it too, and a switch on the media module's card in edit mode takes the button away. The new <i>Lyrics</i> widget follows the song in three looks: <i>Word by word</i>, captions that tip in and land as they are sung; <i>Karaoke</i>, the line filling letter by letter, the next one zooming up into its place as the last flies off; and <i>Classic</i>, the whole song scrolling by with the sung line lit. The words come from lrclib.net, looked up only while something shows them and kept on disk, so each song is fetched once. #109",
                    "code": ""
                },
                {
                    "text": "<b>The media module and its panel, rebuilt.</b> In the bar, <i>Progress</i> fills the pill as the song goes and <i>Controls</i> puts previous, play and next before the track; the panel comes as <i>Vinyl</i>, a record that turns while it plays, <i>Backdrop</i>, over the cover blurred across the panel, and <i>Mini</i>, besides side by side and the large cover (#89). The wave rests while a song is paused, and a track with no cover shows a crisp note.",
                    "code": ""
                },
                {
                    "text": "<b>Covers that never stall the shell.</b> Covers and GIFs from the internet are fetched into a cache of their own instead of through Qt's network stack, which could take the whole shell down. By @naevui in #86.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "tune",
            "title": "Control centre",
            "intro": "",
            "images": [
                {
                    "src": "assets/control-centre-editor.webp",
                    "alt": "The control centre's editor in edit mode: the blocks to add on the left, the panel being laid out in the middle, and layouts to start from on the right"
                }
            ],
            "items": [
                {
                    "text": "<b>Lay it out your way.</b> The control centre can become a bento grid of blocks in an editor of its own, lifted off the bar to the middle of the display: sliders lying or standing (also <i>Wavy</i>), big tiles and small ones, what is playing, gauges, and four new blocks, the weather, the network, power profiles and what is up next. Each has looks of its own. Add them from a shelf with a search, drag them, undo, start from a ready layout, and make tiles of your own. Untouched, it stays the column it was, and a charging battery's gauge reads plainly. #90",
                    "code": ""
                },
                {
                    "text": "<b>Open it over IPC:</b> <code>qs ipc call controlcentre toggle</code> (or <code>open</code>, <code>close</code>), for a keybind of your own. #108",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "wallpaper",
            "title": "The desktop",
            "intro": "",
            "images": [
                {
                    "src": "assets/desktop-icons.webp",
                    "alt": "Desktop icons down the left of an evening city wallpaper, and on the right a shaped clock, the song playing, today's date and how much of the day has gone"
                }
            ],
            "items": [
                {
                    "text": "<b>A Poster clock.</b> The hour over the minute in huge figures, straight on the wallpaper with no card behind them, in white or a colour from your palette.",
                    "code": ""
                },
                {
                    "text": "<b>The Lyrics widget</b>, in <i>Music</i> above. #109",
                    "code": ""
                },
                {
                    "text": "<b>Widgets stay over fullscreen windows by default</b> on a new install; <i>Hide for fullscreen windows</i> is still in <i>Settings → Widgets</i>, and a choice already saved stays as it is. #111",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "screenshot_region",
            "title": "LucidShot",
            "intro": "",
            "images": [
                {
                    "src": "assets/lucidshot.webp",
                    "alt": "LucidShot over a frozen screen: the hint to drag a region or click a window at the top, crosshairs, and the toolbar above the dock"
                }
            ],
            "items": [
                {
                    "text": "<b>LucidShot, rebuilt.</b> Print freezes the screen under a Material You toolbar with a shutter beside it: <i>Screenshot</i>, <i>Record</i>, <i>Text</i> or <i>Colour</i>, of a region, a window or the whole screen. Drag out a region or click a window; a magnifier shows the pixels under the pointer, edges snap to the windows', Shift keeps it square, Alt grows it from the middle and Space moves it. The capture flies into a card in the corner to open in Lens, mark up, pin to the screen, read the text off, drag into an app, find in its folder or delete. With <i>Mark up before saving</i> (E) the selection stays put instead: pen, highlighter, arrows, boxes, ellipses, text, numbered steps and pixelation, with undo, then save, copy without saving or pin. Text read off the screen pastes the way it was written: lines that only wrapped on screen join up again, while lists, short lines and code keep their breaks. The self-timer takes it 3, 5 or 10 seconds later, live.",
                    "code": ""
                },
                {
                    "text": "<b>Colour and recording.</b> <i>Colour</i> turns the pointer into a lens over the frozen screen: a click copies HEX, RGB or HSL, Shift-click collects a palette. <i>Record</i> takes a region, a window or the screen with what is playing and, if you like, the microphone, mixed without muting anything; a countdown first, a pill with pause, the two sources and stop that tucks into the bar, and a recording carries on through a shell reload. A recording's card makes a GIF of it.",
                    "code": ""
                },
                {
                    "text": "<b>Settings and pins.</b> <i>Settings → Screenshots</i> has the folders, the card, window corners, the magnifier, the languages text is read in and the recorder's countdown, frame rate and encoder. Pinned captures float over your windows: drag them, scroll to size them, Ctrl and scroll to see through them, double-click to let go.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "palette",
            "title": "Look and feel",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Jelly motion.</b> Panels, pills, menus, the dock and its icons, the OSD and widgets settle on a spring, with a little wobble as they open and land. <i>Settings → General → Motion</i> turns it off or sets how much.",
                    "code": ""
                },
                {
                    "text": "<b>A pointer of Lucid's own.</b> The arrow, the hand and every other shape take the colours of your palette, <i>Dark</i>, <i>Light</i> or <i>Accent</i>, and fade along when the palette changes. The shapes are Bibata Modern's: Lucid fetches its source once and draws them on your machine, so nothing of Bibata ships with Lucid. <i>Settings → Environment</i> has it, the cursor tilt (only the arrows and hands lean as they move), and a switch back to any cursor theme you have. While you drag a widget, a pin, a slider or a block, the shell draws the pointer itself, so it stays right on what it holds.",
                    "code": ""
                },
                {
                    "text": "<b>Icons of Lucid's own.</b> Folders, files, places, drives and many apps get one tonal set drawn from your palette, in Lumen, on the desktop, in the dock and in the launcher, folders in the accent. An app the set doesn't know keeps its own icon.",
                    "code": ""
                },
                {
                    "text": "<b>Light or dark, by the wallpaper.</b> The theme can follow each new wallpaper into light or dark mode, whichever suits it (#79). A built-in theme you never use can be taken off the list.",
                    "code": ""
                },
                {
                    "text": "<b>The OSD as a notch.</b> <i>Notch</i> rises the OSD out of the bottom edge, the Caps Lock, Num Lock and microphone cards can be toasts instead, and a keyboard with a backlight gets a card of its own (#22). With the dock a notch as well, the dock itself turns into the OSD and back (<i>Morph the dock</i>).",
                    "code": ""
                },
                {
                    "text": "<b>A Split dock.</b> The launcher in a circle, the pins in a pill and the running apps in a third island, which fuse into one when the launcher opens and spring apart again. A running app dragged onto the pins pushes them aside, and the dock's edge blends are frosted like the dock.",
                    "code": ""
                },
                {
                    "text": "<b>Settings</b> has an icon and a name of its own, Lucid's orbit around a gear, its sidebar highlights the way Lumen's does, and the style tiles draw each module exactly as the bar does. Zen follows the palette live.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "volume_up",
            "title": "Sound",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Several outputs at once.</b> Play through your speakers and headphones together, with a volume slider under each device (#82). The audio panel has a slider for every app playing sound. By @SKetU-l in #84.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "lock",
            "title": "Login and lock screen",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>A live login screen.</b> The login screen plays your live wallpaper behind its blur (#83), takes the lock screen's size, corners and glance chips, and the lock screen plays it too. Fingerprint login tries again with a short wait instead of giving up, and a password typed meanwhile waits its turn. By @SKetU-l in #80 and #81.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "update",
            "title": "Updates",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Update from inside Lucid.</b> When a new release is out, <i>Settings → About</i> (and the notification that announces it) has an <b>Update</b> button. It warns you what is about to happen, asks for your password once, and then installs the release's own source with its own installer, in a pop-up with a progress bar. Anything the installer would ask in a terminal, a yes or no or sudo wanting the password again, is asked in the pop-up. When it is done, <b>Restart now</b>, <b>Remind me later</b> (an hour) or <b>Cancel</b>. The updater runs outside the shell, so it survives a reload, and the pop-up picks up where it was. Only a published release counts as an update, not a push to <code>main</code>. The password goes to <code>sudo</code> once and is never stored.",
                    "code": ""
                },
                {
                    "text": "<b>Beta updates.</b> A switch under <i>Settings → About</i>, with a warning that things may break, offers the newest commit on <code>main</code> before it becomes a release. It installs the same way and needs the password too.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "computer",
            "title": "Displays",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Stop mirroring</b> stops the mirror, and the display gets its own wallpaper and bar back (#87). Each set of displays keeps its own split of workspaces, so plugging a monitor in or out puts them back where they were (#91).",
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
                    "text": "<b>Install from a window.</b> In a Wayland session <code>./install.sh</code> opens a window: pick what to install, watch it work beside a tour of Lucid, and answer its questions with buttons (<code>./install.sh --terminal</code> stays in the terminal). It installs Hyprland itself when it is missing, works with any login manager or offers to make SDDM the one, takes the keyboard layout you already type on, sets up screen sharing, and says so when the window is closed mid-install. #94",
                    "code": ""
                },
                {
                    "text": "<b>A way back.</b> The uninstaller puts back the login screen, the GTK settings and the Hyprland config you had before Lucid. #94",
                    "code": ""
                },
                {
                    "text": "<b>Hyprland, refreshed.</b> The glass has no grain or vibrancy boost now, the tilting cursor turns smoother and further, and SUPER+V floats a window at 1366 by 768, centred (a plain float bind you never changed moves to it). Zen takes Matugen's colours on a fresh install.",
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
                    "text": "<b>Less memory for what is hidden.</b> The visualiser's cava rests while nothing plays. Settings is taken down a minute after it closes and opens again on the page it was left on, and What's new and the on-screen keyboard lay themselves out only while they are up. #98, #101",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "build",
            "title": "Fixed",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>A timer or reminder made just as the one before it was being saved no longer goes missing.</b> The save finished off to one side and then wrote the older list back over the new one.",
                    "code": ""
                },
                {
                    "text": "<b>A Wi-Fi password being typed survives network updates</b>, and the search for networks keeps going while one is open. #93, #106",
                    "code": ""
                },
                {
                    "text": "<b>A panel sliding off its layer no longer frosts the whole layer</b> for a moment, and a long list in the launcher ends on a whole row.",
                    "code": ""
                },
                {
                    "text": "<b>The camera's on and off toasts</b> no longer flicker when an app opens it several times in a row, and the CPU temperature comes from the processor's own sensor before any other. By @naevui in #86.",
                    "code": ""
                }
            ]
        }
    ]
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
