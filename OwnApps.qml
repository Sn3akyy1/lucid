pragma Singleton

import QtQuick
import Quickshell
import qs

// lucid's own apps write their .desktop files in English, and the dock keeps its
// built-in pins under English names; the shell may speak another language, so
// the launcher, the dock and the bar name them from here. only the words lucid
// wrote are swapped: an entry someone edited keeps its own
Singleton {
    id: root

    // by desktop file id or window class, the English as lucid writes it
    // (lucidclock/clock, lucidlumen/lumen, lucidlens/lens, install.sh)
    readonly property var words: ({
        "lucid.clock": {
            "Clock": I18n.tr("Clock"),
            "Alarms, the time around the world, timers, a stopwatch, focus sessions and reminders": I18n.tr("Alarms, the time around the world, timers, a stopwatch, focus sessions and reminders"),
            "Alarms": I18n.tr("Alarms"),
            "Timer": I18n.tr("Timer"),
            "Stopwatch": I18n.tr("Stopwatch"),
            "Reminders": I18n.tr("Reminders")
        },
        "lucid.lumen": {
            "Lumen": I18n.tr("Lumen"),
            "Browse and organise your files": I18n.tr("Browse and organise your files"),
            "New Window": I18n.tr("New Window")
        },
        "lucid.lens": {
            "Lens": I18n.tr("Lens"),
            "View, slide through and edit your pictures and videos": I18n.tr("View, slide through and edit your pictures and videos")
        },
        "org.quickshell": {
            "Lucid Settings": I18n.tr("Lucid Settings"),
            "Change how Lucid looks and works": I18n.tr("Change how Lucid looks and works")
        },
        "files": {
            "Files": I18n.tr("Files")
        },
        "terminal": {
            "Terminal": I18n.tr("Terminal")
        }
    })

    // the text as shown: translated when it is one of lucid's own, else as given
    function shown(id, text) {
        const w = root.words[String(id || "").toLowerCase()];
        return w && text && w[text] ? w[text] : (text || "");
    }

    function isOwn(id) {
        return root.words[String(id || "").toLowerCase()] !== undefined;
    }

}
