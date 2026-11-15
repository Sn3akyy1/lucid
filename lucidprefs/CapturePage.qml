import QtQuick
import Quickshell
import Quickshell.Io
import qs

// LucidShot's own page: the shortcuts that reach it, what a capture leaves
// behind, the recorder, and the pins
Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property string shotDefault: page.home + "/Pictures/screenshots"
    readonly property string recordDefault: page.home + "/Videos"
    // every bind whose command reaches lucidshot, in the order they are listed
    readonly property var shotBinds: Keybinds.binds.filter((b) => {
        return b.enabled !== false && /ipc call (snap|screenshot|recorder)\b/.test(String(b.cmd || ""));
    })
    // tesseract's installed languages, osd left out: it reads layout, not words
    property var ocrLangs: ["eng"]
    readonly property var ocrPicked: String(Prefs.shotOcrLang || "eng").split("+").filter((l) => {
        return l !== "";
    })
    readonly property var langNames: ({
        "eng": I18n.tr("English"),
        "deu": I18n.tr("German"),
        "fra": I18n.tr("French"),
        "spa": I18n.tr("Spanish"),
        "ita": I18n.tr("Italian"),
        "por": I18n.tr("Portuguese"),
        "nld": I18n.tr("Dutch"),
        "rus": I18n.tr("Russian"),
        "ukr": I18n.tr("Ukrainian"),
        "pol": I18n.tr("Polish"),
        "ces": I18n.tr("Czech"),
        "swe": I18n.tr("Swedish"),
        "nor": I18n.tr("Norwegian"),
        "dan": I18n.tr("Danish"),
        "fin": I18n.tr("Finnish"),
        "tur": I18n.tr("Turkish"),
        "ell": I18n.tr("Greek"),
        "heb": I18n.tr("Hebrew"),
        "ara": I18n.tr("Arabic"),
        "hin": I18n.tr("Hindi"),
        "jpn": I18n.tr("Japanese"),
        "kor": I18n.tr("Korean"),
        "chi_sim": I18n.tr("Chinese (Simplified)"),
        "chi_tra": I18n.tr("Chinese (Traditional)"),
        "vie": I18n.tr("Vietnamese"),
        "tha": I18n.tr("Thai"),
        "ind": I18n.tr("Indonesian")
    })

    function pretty(path) {
        return String(path).replace(page.home, "~");
    }

    function pickFolder(proc, title, current) {
        proc.command = ["python3", Qt.resolvedUrl("pickfile.py").toString().replace("file://", ""), "--directory", "--title", title, "--file", current];
        proc.running = true;
    }

    // a language joins or leaves the set tesseract reads with; one always stays
    function toggleLang(key) {
        const now = page.ocrPicked.slice();
        const at = now.indexOf(key);
        if (at === -1)
            now.push(key);
        else if (now.length > 1)
            now.splice(at, 1);
        Prefs.shotOcrLang = now.join("+");
    }

    spacing: Theme.dp(26)

    Process {
        running: true
        command: ["sh", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"]

        stdout: StdioCollector {
            onStreamFinished: {
                const langs = this.text.split("\n").map((l) => {
                    return l.trim();
                }).filter((l) => {
                    return l !== "" && l !== "osd" && l !== "equ";
                });
                if (langs.length > 0)
                    page.ocrLangs = langs;

            }
        }

    }

    Process {
        id: shotPicker

        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir !== "")
                    Prefs.shotFolder = dir === page.shotDefault ? "" : dir;

            }
        }

    }

    Process {
        id: recordPicker

        stdout: StdioCollector {
            onStreamFinished: {
                const dir = this.text.trim();
                if (dir !== "")
                    Prefs.recordFolder = dir === page.recordDefault ? "" : dir;

            }
        }

    }

    SettingCard {
        title: I18n.tr("SHORTCUTS")

        Repeater {
            model: page.shotBinds

            SettingRow {
                required property var modelData
                required property int index

                title: Keybinds.displayDesc(modelData)
                description: Keybinds.summary(modelData)
                showDivider: index < page.shotBinds.length - 1

                KeyCombo {
                    keys: modelData.keys
                }

            }

        }

        SettingRow {
            title: page.shotBinds.length > 0 ? I18n.tr("Change them") : I18n.tr("No shortcut reaches LucidShot")
            description: I18n.tr("Print opens the capture overlay out of the box. Anything here can be rebound, and the commands are qs ipc call snap open, region, window, screen, text, color, video or edit, and screenshot full, window or text.")
            showDivider: false

            M3Button {
                text: I18n.tr("Keybinds…")
                variant: "tonal"
                onClicked: win.show("keybinds")
            }

        }

    }

    SettingCard {
        title: I18n.tr("SCREENSHOTS")

        SettingRow {
            title: I18n.tr("After a capture")
            resetKey: "shotPreview"
            description: Prefs.shotPreview === "preview" ? I18n.tr("It flies into a card in the corner: open it, mark it up, pin it, read its text, drag it into an app or delete it. Recordings get one too.") : (Prefs.shotPreview === "notify" ? I18n.tr("A notification says where it went, with a button to mark it up. Screenshots are on the clipboard either way.") : I18n.tr("Nothing shows. Screenshots are still copied to the clipboard."))

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.shotPreview
                options: [{
                    "key": "preview",
                    "label": I18n.tr("Card")
                }, {
                    "key": "notify",
                    "label": I18n.tr("Notification")
                }, {
                    "key": "none",
                    "label": I18n.tr("Nothing")
                }]
                onChosen: (key) => {
                    return Prefs.shotPreview = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("The card stays for")
            resetKey: "shotPreviewSeconds"
            enabled: Prefs.shotPreview === "preview"
            description: I18n.tr("Resting the pointer on the card holds it for as long as you like. Text read off a capture stays a little longer.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.shotPreview === "preview"
                from: 3
                to: 20
                stepSize: 1
                suffix: " s"
                value: Prefs.shotPreviewSeconds
                onMoved: (v) => {
                    return Prefs.shotPreviewSeconds = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Keep a file")
            resetKey: "shotSaveFile"
            description: Prefs.shotSaveFile ? I18n.tr("Every capture is saved as a PNG and copied to the clipboard.") : I18n.tr("Captures are only copied. The card can still save one you want to keep.")

            M3Switch {
                checked: Prefs.shotSaveFile
                onToggled: (v) => {
                    Prefs.shotSaveFile = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Folder")
            resetKey: "shotFolder"
            enabled: Prefs.shotSaveFile
            description: page.pretty(Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault)

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: I18n.tr("Open")
                    variant: "text"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault])
                }

                M3Button {
                    text: shotPicker.running ? I18n.tr("Choosing…") : I18n.tr("Change…")
                    enabled: !shotPicker.running
                    onClicked: page.pickFolder(shotPicker, I18n.tr("Save screenshots to"), Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault)
                }

            }

        }

        SettingRow {
            title: I18n.tr("Window corners")
            resetKey: "shotRoundWindows"
            description: Prefs.shotRoundWindows ? I18n.tr("A window taken whole keeps its rounded corners, cut out clear.") : I18n.tr("A window is taken square, corners and all.")

            M3Switch {
                checked: Prefs.shotRoundWindows
                onToggled: (v) => {
                    Prefs.shotRoundWindows = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Magnifier")
            resetKey: "shotLoupe"
            description: Prefs.shotLoupe ? I18n.tr("A lens shows the pixels under the pointer while you drag out a region. The colour picker always has one.") : I18n.tr("Regions are dragged out without the lens.")

            M3Switch {
                checked: Prefs.shotLoupe
                onToggled: (v) => {
                    Prefs.shotLoupe = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Reading text in")
            resetKey: "shotOcrLang"
            description: page.ocrLangs.length > 1 ? I18n.tr("Pick every language your screens are in. Each one makes reading a little slower.") : I18n.tr("Install more tesseract languages (tesseract-data-*) and they show up here.")
            stacked: true
            showDivider: false

            M3Chips {
                width: parent.width
                multi: true
                selectedKeys: page.ocrPicked
                options: page.ocrLangs.map((l) => {
                    return {
                        "key": l,
                        "label": page.langNames[l] || l
                    };
                })
                onChosen: (key) => {
                    return page.toggleLang(key);
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("RECORDING")

        SettingRow {
            title: I18n.tr("Folder")
            resetKey: "recordFolder"
            description: page.pretty(Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault)

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: I18n.tr("Open")
                    variant: "text"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault])
                }

                M3Button {
                    text: recordPicker.running ? I18n.tr("Choosing…") : I18n.tr("Change…")
                    enabled: !recordPicker.running
                    onClicked: page.pickFolder(recordPicker, I18n.tr("Save recordings to"), Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault)
                }

            }

        }

        SettingRow {
            title: I18n.tr("Count down first")
            resetKey: "recordCountdown"
            description: Prefs.recordCountdown > 0 ? I18n.tr("A count of %1 before it starts, to get your windows ready. A click on it calls the recording off. The overlay's timer button changes it for one recording.", Prefs.recordCountdown) : I18n.tr("It starts the moment you press record.")

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: String(Prefs.recordCountdown)
                options: [{
                    "key": "0",
                    "label": I18n.tr("Off")
                }, {
                    "key": "3",
                    "label": I18n.tr("3 s")
                }, {
                    "key": "5",
                    "label": I18n.tr("5 s")
                }, {
                    "key": "10",
                    "label": I18n.tr("10 s")
                }]
                onChosen: (key) => {
                    return Prefs.recordCountdown = parseInt(key);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Frame rate")
            resetKey: "recordFps"
            description: Prefs.recordFps > 0 ? I18n.tr("A steady %1 frames a second, which video editors like best.", Prefs.recordFps) : I18n.tr("Frames are taken as the screen changes, which keeps files small. Some video editors prefer a steady rate.")

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: String(Prefs.recordFps)
                options: [{
                    "key": "0",
                    "label": I18n.tr("Adaptive")
                }, {
                    "key": "30",
                    "label": "30"
                }, {
                    "key": "60",
                    "label": "60"
                }]
                onChosen: (key) => {
                    return Prefs.recordFps = parseInt(key);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Encoder")
            resetKey: "recordEncoder"
            description: Prefs.recordEncoder === "software" ? I18n.tr("x264 on the processor: works everywhere, uses more power.") : (Prefs.recordEncoder === "hardware" ? I18n.tr("The graphics card's own encoder, and nothing else: if it cannot start, the recording fails.") : I18n.tr("The graphics card's own encoder (VA-API), and x264 on the processor if that cannot start."))
            showDivider: false

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.recordEncoder
                options: [{
                    "key": "auto",
                    "label": I18n.tr("Automatic")
                }, {
                    "key": "hardware",
                    "label": I18n.tr("Hardware")
                }, {
                    "key": "software",
                    "label": I18n.tr("Software")
                }]
                onChosen: (key) => {
                    return Prefs.recordEncoder = key;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("PINS")

        SettingRow {
            title: I18n.tr("Pinned captures")
            description: I18n.tr("Pin a capture from the editor or its card and it floats over your windows. Drag it about, scroll to size it, Ctrl and scroll to see through it, double-click to let it go.")
            showDivider: false

            M3Button {
                text: I18n.tr("Unpin all")
                variant: "tonal"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "snap", "unpin"])
            }

        }

    }

}
