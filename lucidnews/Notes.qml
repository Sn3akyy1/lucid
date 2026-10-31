import QtQuick

// what the What's new sheet says about this release: the version's own section
// of CHANGELOG.md, written out by support/whatsnew/build-notes.py so the two
// never disagree. edit the changelog, then run that again, rather than this file.
// pictures are paths under assets/; one that is not there yet keeps its place
// while `placeholders` is on, and folds away once it is off
QtObject {
    // the sheet opens by itself once, on the first start of a shell whose
    // VERSION file says this
    readonly property string version: "1.20.5.5"
    readonly property string name: ""
    readonly property string date: "31 October 2026"
    readonly property bool placeholders: false
    readonly property var heroes: []
    readonly property string intro: "A beta on the way to the next release: Lumen, a file manager of Lucid's own that is also every app's file dialog, Lens for pictures and video, LucidShot rebuilt, edit mode on the desktop, and updates from inside Lucid. It's what I use daily, but rough edges are likely."
    readonly property var sections: [
        {
            "level": 1,
            "icon": "notes",
            "title": "New",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>Lumen, a file manager of Lucid's own.</b> It replaces Nautilus: SUPER+E opens it, folders open in it, and every app's open and save dialog is a Lumen window. Tabs can be pinned, coloured and dragged out into a window of their own and back. Ctrl+D keeps a folder in the bookmarks, and Alt+P shows pictures, PDFs, text, video and sound in a preview beside the folder. The sidebar lists your drives with the room left on them, and Enter in the location bar searches the whole disk.",
                    "code": ""
                },
                {
                    "text": "<b>Lucid's own icons.</b> Folders, files and apps are drawn in one tonal set across Lumen, the desktop, the dock and the launcher, and they move when you hover them. <i>Settings → Environment</i> goes back to your icon theme.",
                    "code": ""
                },
                {
                    "text": "<b>Jelly motion.</b> Panels, pills and dock icons give a slight wobble on a spring as they open and move. <i>Settings → General</i> turns it off or sets how much.",
                    "code": ""
                },
                {
                    "text": "<b>LucidShot, rebuilt.</b> Print freezes the screen under a Material You toolbar with a shutter beside it: <i>Screenshot</i>, <i>Record</i>, <i>Text</i> or <i>Colour</i>, of a region, a window or the whole screen. Drag out a region or click a window; a magnifier shows the pixels under the pointer, edges snap to the windows', Shift keeps it square, Alt grows it from the middle and Space moves it. The capture flies into a card in the corner to open in Lens, mark up, pin to the screen, read the text off, drag into an app, find in its folder or delete. With <i>Mark up before saving</i> (E) the selection stays put instead: pen, highlighter, arrows, boxes, ellipses, text, numbered steps and pixelation, with undo, then save, copy without saving or pin. Text read off the screen pastes the way it was written: lines that only wrapped on screen join up again, while lists, short lines and code keep their breaks. The self-timer takes it 3, 5 or 10 seconds later, live. <i>Colour</i> turns the pointer into a lens over the frozen screen: a click copies HEX, RGB or HSL, Shift-click collects a palette. <i>Record</i> takes a region, a window or the screen with what is playing and, if you like, the microphone, mixed without muting anything; a countdown first, a pill with pause, the two sources and stop that tucks into the bar, and a recording now carries on through a shell reload. A recording's card makes a GIF of it. <i>Settings → Screenshots</i> has the folders, the card, window corners, the magnifier, the languages text is read in and the recorder's countdown, frame rate and encoder. Pinned captures float over your windows: drag them, scroll to size them, Ctrl and scroll to see through them, double-click to let go.",
                    "code": ""
                },
                {
                    "text": "<b>Lens, a picture viewer of Lucid's own.</b> Open a picture and the rest of its folder comes with it, in the order Lumen shows that folder: the arrow keys, a swipe or a drag slide to the next one, the filmstrip jumps to any, and <i>All pictures</i> (G) lays out the whole folder to search by name. The wheel or a pinch zooms where the pointer is, a double click goes to 100%, and a zoomed picture pans with a map of where you are. <i>Edit</i> (E) crops it (free, its own shape, square, 4:3, 3:2, 16:9 or your screen's), turns, flips and straightens it, adjusts its light and colour, or gives it one of twelve looks; <i>Draw</i> (D) adds pen, highlighter, arrows, lines, boxes, rings, words and boxes that pixelate what is under them. Edits wait for each picture until they are saved, over it or as a copy; a turned JPEG is saved without losing any quality. Saving over a picture keeps its original, for good: <i>Revert to original</i> (right-click, the editor or <i>Details</i>) brings it back whenever you like, and holding \\ shows it in the edited one's place. Right-click for <i>Set as wallpaper</i>, <i>Open with…</i>, <i>Show in Lumen</i>, copying the picture, its path, the text in it or a colour off it, sending it to your phone, renaming it and the trash. <i>Details</i> (I) show the camera's settings, where it was taken, a histogram and the colours it is made of. Slideshow (F5) and full screen (F) too. Videos sit in the folder with the pictures and play where they are, with a time line that waves while they play, volume, speed and play-on-repeat; a click pauses, a double click goes full screen, and J, L, comma and full stop step back and on. A frame can be saved as a picture or copied, a sideways phone video turned upright without encoding it again (its original kept), and <i>Trim</i> (E) cuts a part out as a copy: exactly at the handles, or at once at the nearest keyframe. <code>lens --default-videos</code> makes Lens what opens videos as well.",
                    "code": ""
                },
                {
                    "text": "<b>Network drives in Lumen.</b> <i>Connect to server</i> (Ctrl+K, the sidebar's new <i>Network</i> section or the ⋮ menu) opens a shared folder on another computer, a NAS or a server. Type its address (<code>smb://nas.local/media</code>, <code>sftp://you@server</code>, <code>ftp://…</code>, Windows' own <code>\\\\server\\share</code>, or just a name) and sign in if it asks: as a registered user or a guest, with the password kept in your keyring if you tick it. A host Lumen has never seen asks first. Connected shares sit under <i>Network</i> with their free space and a button that disconnects them, and their files open, copy, move, rename and delete like any others; a share has no trash, so deleting says it can't be undone. Apps' open and save dialogs reach them too. Bookmark a folder on a share and a click on it connects again later; the addresses you typed stay in the dialog's <i>Recent</i> list, and <i>Nearby</i> shows the computers sharing folders on your network once Avahi runs. Windows shares and most NAS drives need <code>gvfs-smb</code>, which the installer now adds with NFS, WebDAV and finding computers nearby.",
                    "code": ""
                },
                {
                    "text": "<b>Update from inside Lucid.</b> When a new release is out, <i>Settings → About</i> (and the notification that announces it) has an <b>Update</b> button. It warns you what is about to happen, asks for your password once, and then installs the release's own source with its own installer, in a pop-up with a progress bar. Anything the installer would ask in a terminal, a yes or no or sudo wanting the password again, is asked in the pop-up. When it is done, <b>Restart now</b>, <b>Remind me later</b> (an hour) or <b>Cancel</b>. The updater runs outside the shell, so it survives a reload, and the pop-up picks up where it was. Only a published release counts as an update, not a push to <code>main</code>. The password goes to <code>sudo</code> once and is never stored.",
                    "code": ""
                },
                {
                    "text": "<b>Beta updates.</b> A switch under <i>Settings → About</i>, with a warning that things may break, offers the newest commit on <code>main</code> before it becomes a release. It installs the same way and needs the password too.",
                    "code": ""
                },
                {
                    "text": "<b>Edit mode.</b> Pick <i>Edit Desktop</i> from the desktop's right-click menu, or right-click any bar module, and the wallpaper shades over so everything on the desktop can be arranged where it stands. Drag a bar module along the bar to move it, into another group, or down off the bar to take it out; one that has nothing to show right now keeps a dashed stand-in, so it can be moved too, and the link between two neighbours joins them into one island. Right-click a module, or the dock, for a sheet of its options beside it: its looks, the bar's or the dock's style and sizes. A click still opens a module, so the look just picked can be seen. The dock gets a handle: drag it up to float the dock higher, or down into the bottom edge to make it a notch. <b>Undo</b> takes back the last change and <b>Revert</b> everything since edit mode began; <b>Done</b>, or Escape, leaves it.",
                    "code": ""
                },
                {
                    "text": "<b>A Poster clock.</b> The hour over the minute in huge figures, straight on the wallpaper with no card behind them, in white or a colour from your palette.",
                    "code": ""
                }
            ]
        },
        {
            "level": 1,
            "icon": "notes",
            "title": "Changed",
            "intro": "",
            "images": [],
            "items": [
                {
                    "text": "<b>The bar is arranged on the desktop now.</b> <i>Settings → Bar</i> loses its arrangement editor and the per-module cards, and <i>Settings → Widgets</i> its layouts and its catalogue of widgets to add: modules are moved and set up in edit mode, and widgets come from the Widget Panel on the desktop, which has the layouts too. The Bar, Dock and Widgets pages each have a button that opens edit mode.",
                    "code": ""
                },
                {
                    "text": "<b>The Settings sidebar highlights the way Lumen's does.</b> One pill travels between the rows, stretching as it goes, and a row lights up as it arrives.",
                    "code": ""
                },
                {
                    "text": "<b>The installer asks for more.</b> <code>qt6-webengine</code>, a large download, because Lumen's preview needs its PDF module to open at all, and <code>qt6-imageformats</code>, <code>kimageformats</code>, <code>libjpeg-turbo</code> and <code>exiv2</code> for pictures in Lens. <code>swappy</code> is gone, as nothing uses it now. Running timers and the stopwatch survive an update.",
                    "code": ""
                }
            ]
        }
    ]
    // the whole history, every version
    readonly property string fullUrl: "https://github.com/Sn3akyy1/lucid/blob/main/CHANGELOG.md"
}
