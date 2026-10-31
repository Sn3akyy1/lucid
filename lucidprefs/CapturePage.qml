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
        "eng": "English",
        "deu": "German",
        "fra": "French",
        "spa": "Spanish",
        "ita": "Italian",
        "por": "Portuguese",
        "nld": "Dutch",
        "rus": "Russian",
        "ukr": "Ukrainian",
        "pol": "Polish",
        "ces": "Czech",
        "swe": "Swedish",
        "nor": "Norwegian",
        "dan": "Danish",
        "fin": "Finnish",
        "tur": "Turkish",
        "ell": "Greek",
        "heb": "Hebrew",
        "ara": "Arabic",
        "hin": "Hindi",
        "jpn": "Japanese",
        "kor": "Korean",
        "chi_sim": "Chinese (Simplified)",
        "chi_tra": "Chinese (Traditional)",
        "vie": "Vietnamese",
        "tha": "Thai",
        "ind": "Indonesian"
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
        title: "SHORTCUTS"

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
            title: page.shotBinds.length > 0 ? "Change them" : "No shortcut reaches LucidShot"
            description: "Print opens the capture overlay out of the box. Anything here can be rebound, and the commands are qs ipc call snap open, region, window, screen, text, color, video or edit, and screenshot full, window or text."
            showDivider: false

            M3Button {
                text: "Keybinds…"
                variant: "tonal"
                onClicked: win.show("keybinds")
            }

        }

    }

    SettingCard {
        title: "SCREENSHOTS"

        SettingRow {
            title: "After a capture"
            resetKey: "shotPreview"
            description: Prefs.shotPreview === "preview" ? "It flies into a card in the corner: open it, mark it up, pin it, read its text, drag it into an app or delete it. Recordings get one too." : (Prefs.shotPreview === "notify" ? "A notification says where it went, with a button to mark it up. Screenshots are on the clipboard either way." : "Nothing shows. Screenshots are still copied to the clipboard.")

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.shotPreview
                options: [{
                    "key": "preview",
                    "label": "Card"
                }, {
                    "key": "notify",
                    "label": "Notification"
                }, {
                    "key": "none",
                    "label": "Nothing"
                }]
                onChosen: (key) => {
                    return Prefs.shotPreview = key;
                }
            }

        }

        SettingRow {
            title: "The card stays for"
            resetKey: "shotPreviewSeconds"
            enabled: Prefs.shotPreview === "preview"
            description: "Resting the pointer on the card holds it for as long as you like. Text read off a capture stays a little longer."
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
            title: "Keep a file"
            resetKey: "shotSaveFile"
            description: Prefs.shotSaveFile ? "Every capture is saved as a PNG and copied to the clipboard." : "Captures are only copied. The card can still save one you want to keep."

            M3Switch {
                checked: Prefs.shotSaveFile
                onToggled: (v) => {
                    Prefs.shotSaveFile = v;
                }
            }

        }

        SettingRow {
            title: "Folder"
            resetKey: "shotFolder"
            enabled: Prefs.shotSaveFile
            description: page.pretty(Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault)

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: "Open"
                    variant: "text"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault])
                }

                M3Button {
                    text: shotPicker.running ? "Choosing…" : "Change…"
                    enabled: !shotPicker.running
                    onClicked: page.pickFolder(shotPicker, "Save screenshots to", Prefs.shotFolder !== "" ? Prefs.shotFolder : page.shotDefault)
                }

            }

        }

        SettingRow {
            title: "Window corners"
            resetKey: "shotRoundWindows"
            description: Prefs.shotRoundWindows ? "A window taken whole keeps its rounded corners, cut out clear." : "A window is taken square, corners and all."

            M3Switch {
                checked: Prefs.shotRoundWindows
                onToggled: (v) => {
                    Prefs.shotRoundWindows = v;
                }
            }

        }

        SettingRow {
            title: "Magnifier"
            resetKey: "shotLoupe"
            description: Prefs.shotLoupe ? "A lens shows the pixels under the pointer while you drag out a region. The colour picker always has one." : "Regions are dragged out without the lens."

            M3Switch {
                checked: Prefs.shotLoupe
                onToggled: (v) => {
                    Prefs.shotLoupe = v;
                }
            }

        }

        SettingRow {
            title: "Reading text in"
            resetKey: "shotOcrLang"
            description: page.ocrLangs.length > 1 ? "Pick every language your screens are in. Each one makes reading a little slower." : "Install more tesseract languages (tesseract-data-*) and they show up here."
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
        title: "RECORDING"

        SettingRow {
            title: "Folder"
            resetKey: "recordFolder"
            description: page.pretty(Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault)

            Row {
                spacing: Theme.dp(8)

                M3Button {
                    text: "Open"
                    variant: "text"
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault])
                }

                M3Button {
                    text: recordPicker.running ? "Choosing…" : "Change…"
                    enabled: !recordPicker.running
                    onClicked: page.pickFolder(recordPicker, "Save recordings to", Prefs.recordFolder !== "" ? Prefs.recordFolder : page.recordDefault)
                }

            }

        }

        SettingRow {
            title: "Count down first"
            resetKey: "recordCountdown"
            description: Prefs.recordCountdown > 0 ? "A count of " + Prefs.recordCountdown + " before it starts, to get your windows ready. A click on it calls the recording off. The overlay's timer button changes it for one recording." : "It starts the moment you press record."

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: String(Prefs.recordCountdown)
                options: [{
                    "key": "0",
                    "label": "Off"
                }, {
                    "key": "3",
                    "label": "3 s"
                }, {
                    "key": "5",
                    "label": "5 s"
                }, {
                    "key": "10",
                    "label": "10 s"
                }]
                onChosen: (key) => {
                    return Prefs.recordCountdown = parseInt(key);
                }
            }

        }

        SettingRow {
            title: "Frame rate"
            resetKey: "recordFps"
            description: Prefs.recordFps > 0 ? "A steady " + Prefs.recordFps + " frames a second, which video editors like best." : "Frames are taken as the screen changes, which keeps files small. Some video editors prefer a steady rate."

            M3Segmented {
                width: Math.max(Theme.dp(260), fitWidth)
                current: String(Prefs.recordFps)
                options: [{
                    "key": "0",
                    "label": "Adaptive"
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
            title: "Encoder"
            resetKey: "recordEncoder"
            description: Prefs.recordEncoder === "software" ? "x264 on the processor: works everywhere, uses more power." : (Prefs.recordEncoder === "hardware" ? "The graphics card's own encoder, and nothing else: if it cannot start, the recording fails." : "The graphics card's own encoder (VA-API), and x264 on the processor if that cannot start.")
            showDivider: false

            M3Segmented {
                width: Math.max(Theme.dp(300), fitWidth)
                current: Prefs.recordEncoder
                options: [{
                    "key": "auto",
                    "label": "Automatic"
                }, {
                    "key": "hardware",
                    "label": "Hardware"
                }, {
                    "key": "software",
                    "label": "Software"
                }]
                onChosen: (key) => {
                    return Prefs.recordEncoder = key;
                }
            }

        }

    }

    SettingCard {
        title: "PINS"

        SettingRow {
            title: "Pinned captures"
            description: "Pin a capture from the editor or its card and it floats over your windows. Drag it about, scroll to size it, Ctrl and scroll to see through it, double-click to let it go."
            showDivider: false

            M3Button {
                text: "Unpin all"
                variant: "tonal"
                onClicked: Quickshell.execDetached(["qs", "ipc", "call", "snap", "unpin"])
            }

        }

    }

}
