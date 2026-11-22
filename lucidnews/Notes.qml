import QtQuick
import qs

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: "1.21.1"
    readonly property string name: I18n.tr("Made yours")
    readonly property string date: I18n.tr("22 November 2026")
    readonly property bool placeholders: false
    readonly property var heroes: [
        {
            "src": "assets/lock-screen.webp",
            "alt": I18n.tr("The lock screen over a blurred evening sky: the weather and status chips along the top, a big two-tone clock and the date in the middle, the song playing and notification icons beneath, then the account and Type to unlock, with the power buttons and Up next in the bottom corners")
        }
    ]
    readonly property string intro: "<b>The lock screen, made yours, and Lucid in your language.</b> The lock screen and the login screen are redesigned together and drawn by the same parts, and you lay them out: six styles to start from, widgets to put where you want them, and an editor that fills the screen to do it in. Whatever the lock wears, the login screen wears too. Lucid now speaks Spanish, Russian, German and Turkish as well as English, and its on-screen keyboard types in your layout. The workspace overview comes down from the top of the screen, and a tap of Ctrl finds the pointer.<br><br>Nine of the pull requests in this one are contributions: eight from <b>Ciro Rivera</b>, who made Lucid translatable, and one from <b>Deniz Gözen</b>, which brought German, Turkish and a good deal more. Their entries end in the pull request's number. Thank you both, and thank you @cwkpete7383, @ArkLmao and @Faoxn, whose reports are fixed here."
    readonly property var sections: [
        {
            "level": 1,
            "icon": "lock",
            "title": I18n.tr("Lock and login screen"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Six styles.</b> <i>Centre</i> keeps a big clock in the middle, <i>Split</i> puts the day on the left and the sign-in on the right, <i>Panel</i> holds the sign-in in a side sheet, <i>Minimal</i> shows only the time until you start typing, <i>Bento</i> sets every widget on a card of its own, and <i>Deck</i> is made for music. Each style has its own places for widgets and remembers what you put in them.",
                    "code": ""
                },
                {
                    "text": "<b>Widgets with options of their own.</b> A clock (stacked, inline, a dial or shapes, in four sizes, two-tone or plain, with seconds if you like), the date, a greeting, the weather, the battery, network, Bluetooth, Do not disturb and keyboard layout as chips or icons, the power buttons as a bar or as round buttons, and a message of your own, such as who to call if this is found. The lock also shows what is playing, your notifications (a list, icons or a count, and <i>Hide what they say</i> keeps the words to yourself) and <i>Up next</i>: your next reminder and the next alarm.",
                    "code": ""
                },
                {
                    "text": "<b>Deck, for music.</b> The cover is cut to a cookie inside a ring of the song's progress that waves while it plays, the title is set in display type, and the play button wears the same shape until a pause rounds it into a circle. The time sits beside it, and takes the middle when nothing plays.",
                    "code": ""
                },
                {
                    "text": "<b>An editor that fills the screen.</b> <i>Settings → Lock screen → Customise</i>, a click on the preview or <code>qs ipc call lockstyle open</code> opens the lock over a frosted wallpaper. The arrows or ‹ › step through the styles, and <i>Edit widgets</i> (or a click on the lock) lets you drag widgets between places, drop them on the bin, add one where a + sits and set each one's options in a side sheet. Preview the login screen or the field being typed into, then <i>Apply</i>; closing with changes asks before dropping them. Print works over the editor too: <i>Window</i> takes the lock preview, cut to its own corners, or the side sheet, and pinned captures, preview cards and the recording controls stay above it.",
                    "code": ""
                },
                {
                    "text": "<b>Backdrop and behaviour.</b> <i>Blur</i>, <i>Dim</i> and <i>Accent wash</i> set the wallpaper beneath. <i>Grow out of the desktop</i> photographs the screen first, so the lock frosts over your windows as the desktop sinks away under it. <i>Back to resting</i> sets how long after you stop typing the day comes back, and <i>Other screens</i> shows them the clock or nothing.",
                    "code": ""
                },
                {
                    "text": "<b>The login screen wears your layout.</b> <i>Wear this layout at login</i> sends it to the login screen for your account only, so each account there wears its own. <i>Weather at login</i> shows the last reading taken here for up to six hours (other accounts see the sky and the temperature, never where you are), and can be turned off.",
                    "code": ""
                },
                {
                    "text": "<b>Accounts and sessions at login.</b> Your name (or your face) and the session chip open Material You menus beside them, above or below wherever there is room, and nothing behind them moves. The arrows, Enter and Escape work them, and a letter jumps to a name. Switching to an account with a different layout no longer pulls the list out from under the pointer.",
                    "code": ""
                },
                {
                    "text": "<b>The password field opens in one motion.</b> <i>Type to unlock</i> grows into the field: the lock stays at its left edge, the words roll over into <i>Password</i> and the button grows in at the right, rather than the field's parts appearing outside the pill as it opened.",
                    "code": ""
                },
                {
                    "text": "<b>The field asks to be used.</b> A moment after the lock settles, and every few seconds after that, the field lights up the way a hover lights it and grows a little, while the lock hops and rocks. The lock answers you too: it springs open on the right password and rattles on a wrong one as the field shakes.",
                    "code": ""
                },
                {
                    "text": "<b>Right and wrong in your colours.</b> The right password lights the field in your accent's own colours rather than green, and a wrong one in a muted rose drawn toward your accent, the way Material You harmonizes its error colour, rather than the stock red. The login screen matches.",
                    "code": ""
                },
                {
                    "text": "<b>The on-screen keyboard, on the lock and at login.</b> The desktop's floating keyboard, with its Letters and Function tabs, its sizes and its grip, comes up when a finger touches the password field, or from the keyboard chip beside the keymap's under it. On the lock it opens at the size and tab you last used on the desktop. It types straight into the field; Esc, Tab, the arrows and Ctrl+A work as on a real keyboard, and the media, volume and brightness keys go to your locked shortcuts. It floats over the screen without moving anything, opens clear of the sign-in and stays wherever you drag it.",
                    "code": ""
                },
                {
                    "text": "<b>No stray keyboard over the login screen.</b> Where SDDM is set to use Qt's virtual keyboard (its own default, which Arch's package turns off), one covered the login screen as soon as the password field took the keys, with or without a touchscreen, and it could flicker or leave the real keyboard dead once closed. The login screen no longer asks for it. Reported by @ArkLmao in #129.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "language",
            "title": I18n.tr("Your language"),
            "intro": "",
            "images": [
                {
                    "src": "assets/language.webp",
                    "alt": I18n.tr("Lucid Settings in German on the Language page, with Deutsch chosen from the menu, and the on-screen keyboard beneath it in the German layout, with ß, ü, ö and ä")
                }
            ],
            "items": [
                {
                    "text": "<b>The shell in your language.</b> <i>Settings → Language</i> picks one from a menu. <i>Automatic</i> follows the system's (<code>LANG</code>), dates and numbers follow the language too, and whatever a translation does not cover stays in English. Spanish and Russian come with it. #117",
                    "code": ""
                },
                {
                    "text": "<b>German and Turkish</b> join them, and more of what the shell says as it works is translated: Wi-Fi, Bluetooth and the updater connecting or checking, the desktop's file menu and Lumen's notices. #131",
                    "code": ""
                },
                {
                    "text": "<b>Add a language, or share one.</b> A language is a single <code>.json</code> file. <i>Export the template</i> saves every string Lucid shows with an empty translation for you to fill in, <i>Import a translation</i> adds yours, and <i>Export the current language</i> saves the one in use to correct or share. #117",
                    "code": ""
                },
                {
                    "text": "<b>Lucid's own apps follow it.</b> Clock, Lumen, Lens and Lucid Settings, with their descriptions and actions, are named in your language in the launcher, the dock and the bar. The launcher finds them, and Settings search finds a setting, by a word in English or in your language.",
                    "code": ""
                },
                {
                    "text": "<b>The on-screen keyboard types in your layout.</b> It was the US board whatever you had set; now it draws the layout in use, QWERTZ and its umlauts on German for instance, with AltGr for the symbols on the third level and dead keys that land on the next letter (´ then e is é). With more than one layout, a key beside the space bar switches between them.",
                    "code": ""
                },
                {
                    "text": "<b>The keyboard layout shows in the bar from the start,</b> and follows layouts added under <i>Settings → Input</i>, even while there is only one to switch to.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "workspaces",
            "title": I18n.tr("Workspaces"),
            "intro": "",
            "images": [
                {
                    "src": "assets/workspaces-overview.webp",
                    "alt": I18n.tr("The workspace overview pulled down from the top of the screen over a red and grey wallpaper: ten workspaces in two rows of five with live pictures of their windows, and the scratchpads in a row beneath")
                }
            ],
            "items": [
                {
                    "text": "<b>The overview comes down from the top.</b> A click on the workspace you are on, a middle click on the workspaces pill or a three-finger swipe down brings it down from the top edge of the screen, and a swipe up, Escape or a click outside sends it back. Your workspaces sit in two rows of five, each a little desktop of your wallpaper with live pictures of its windows and their apps' icons, with your scratchpads in a row beneath. The one you are on stands in the light, rounder at the corners, while the others are shaded back until the pointer passes over them, and the workspaces pill shows their numbers for as long as it is open. Dragging windows between workspaces works as before.",
                    "code": ""
                },
                {
                    "text": "<b>The old overview is still there.</b> <i>Use legacy workspace</i>, in the Workspaces module's settings (right-click it), brings back the overview that grows out of the pill in the middle of the screen.",
                    "code": ""
                },
                {
                    "text": "<b>Every workspace you ask for is there to swipe to.</b> With <i>How many</i> at ten, all ten are kept, so swiping and scrolling go through every one rather than stopping at the sixth until the rest had a window on them.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "mouse",
            "title": I18n.tr("Pointer"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Tap Ctrl to find the pointer.</b> Tap either Ctrl key on its own and the pointer grows for a moment, so it is easy to spot. Only a quick tap counts: a shortcut never sets it off, whichever key you let go of first, and neither does Ctrl with a click, the scroll wheel or in the middle of a drag. Apps still get their Ctrl. It replaces shake to find; <i>Settings → Environment → Find the pointer</i> turns it off and sets how big it grows and for how long.",
                    "code": ""
                },
                {
                    "text": "<b>Lucid's own pointer sets.</b> While Lucid's pointer is on, <i>Cursor theme</i> picks from Lucid's own sets, each shown with its pointers. The first is <i>Nimbus</i>, with Bibata Modern's soft, rounded shapes: its loading ring is drawn like the arrow, in the body colour inside an outline, and <i>not allowed</i> is a plain cross.",
                    "code": ""
                },
                {
                    "text": "<b>The pointer shows on NVIDIA.</b> With the cursor plugin loaded, the pointer could go invisible on an NVIDIA card, and came back only while it was grown to be found or at a large cursor size. On NVIDIA it is now drawn in software, so it is always there and still tilts and grows.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "grid_view",
            "title": I18n.tr("Launcher"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Switching modes is one smooth fade.</b> Tab, a mode's shortcut, a click on the mode bar or a prefix such as <code>&gt;clip</code> fades the old list out before the new one comes in, rather than the new rows appearing, blinking out and coming back, or old rows lingering over them. The panel changes size in that same moment, an empty mode names itself rather than the one you left, and <i>Pictures</i> and <i>Live</i> in the wallpaper picker swap the same way. Reported by @Faoxn in #114.",
                    "code": ""
                },
                {
                    "text": "<b>The mode bar answers at once.</b> One pill slides to the mode you picked, the way the selection slides between rows, and the mode's name appears as it lands.",
                    "code": ""
                },
                {
                    "text": "<b>The selection stays inside the list</b> while the arrow keys scroll it, rather than sliding past the edge and back.",
                    "code": ""
                },
                {
                    "text": "<b>The selection stays on its row</b> after the list scrolls, and when a search drops a row above it. #119, #124",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "toolbar",
            "title": I18n.tr("The bar"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>The System module's settings are in its own sheet.</b> What its pill shows and the game mode commands moved from <i>Settings → Bar</i> to the sheet a right click on the module opens. The Game mode tile opens them there when only one of its commands is set.",
                    "code": ""
                },
                {
                    "text": "<b>A notch's open panel beside a screen side</b> keeps its rounded corner when it stops short of the side: the wall between them stays at the bar's height and curves into the panel, rather than running down beside it. #130",
                    "code": ""
                },
                {
                    "text": "<b>The clock panel's tabs</b> hover as a rounded shape inside the tab rather than a square. #122",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "keyboard",
            "title": I18n.tr("Keys and shortcuts"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>SUPER+F toggles fullscreen.</b> #121",
                    "code": ""
                },
                {
                    "text": "<b>The close bind closes the sheet in front,</b> such as the keybinds sheet, What's new or the session menu, rather than the window behind it. It closes the lock screen's style editor the same way, asking first if there are changes. #123",
                    "code": ""
                },
                {
                    "text": "<b>The media keys play what Lucid shows.</b> Play/pause, next and previous go to the player in the media module rather than whichever one <code>playerctl</code> lists first, so a paused browser no longer takes the key from Spotify. #131",
                    "code": ""
                },
                {
                    "text": "<b>Region capture leaves SUPER+SHIFT+S to the scratchpad.</b> An install still on that old default moves it to Print. #131",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "settings",
            "title": I18n.tr("Settings"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>About system</b>, under About, reads the machine itself: its model, the system and kernel, the processor and every graphics card, memory, storage, uptime, the session and the package count. #131",
                    "code": ""
                },
                {
                    "text": "<b>Animation speed goes the way it says.</b> The slider on the General page, and the bar's own on the Bar page, set how <i>long</i> things took, so dragging right to speed the shell up slowed it down. Right is faster now, from half speed to four times as fast, with <i>Instant</i> at the far end for no animation at all, and a speed you had already set stays as it was. Windows and workspaces are animated by Hyprland rather than the shell, and the slider now says so and where to find them. Reported on Reddit.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "build",
            "title": I18n.tr("Fixes and tweaks"),
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Lumen no longer crashes as you open folders.</b> A double click into a folder could close Lumen out of the blue, most often in big folders outside your home such as <code>/usr</code>, and take an app's open or save dialog with it. The click was still preparing the file's drag picture when its folder was cleared away; the picture is now made only once a drag begins, from a copy that stays put. Reported by @cwkpete7383 in #128.",
                    "code": ""
                },
                {
                    "text": "<b>Places with an apostrophe in their name</b>, such as Xi'an or Coeur d'Alene, are found for the weather. #120",
                    "code": ""
                },
                {
                    "text": "<b>The logo on a tonal plate.</b> The mark, the Settings and Clock icons and the README's badges sit on the brand palette's own deep teal rather than on near-black.",
                    "code": ""
                },
                {
                    "text": "<b>Smaller fixes:</b> the updater's questions no longer leave errors in the log as they come and go, and Lumen's grid cells cancel their own delayed work when they are cleared away. #131",
                    "code": ""
                }
            ]
        }
    ]
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
