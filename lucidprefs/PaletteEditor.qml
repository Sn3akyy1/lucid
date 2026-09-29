import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs

// the palette on screen, edited in place. six key colours rebuild the whole
// palette (palette-edit.py build, the importer's own builder); every other role
// can be set by hand after that. while a draft differs, the shell wears it:
// the draft is written where the shell reads its palette, and Discard, closing
// Settings or saving puts things right again
Column {
    id: editor

    readonly property string home: Quickshell.env("HOME")
    readonly property string palettePath: editor.home + "/.cache/quickshell/matugen.json"
    readonly property var keys: [{
        "role": "surface",
        "label": "Background"
    }, {
        "role": "on_surface",
        "label": "Text"
    }, {
        "role": "primary",
        "label": "Primary"
    }, {
        "role": "secondary",
        "label": "Secondary"
    }, {
        "role": "tertiary",
        "label": "Tertiary"
    }, {
        "role": "error",
        "label": "Error"
    }]
    // the palette on screen, as read, and the file's text, to put it back
    property var onScreen: ({})
    property string originalText: ""
    // every text the editor wrote there while editing. the watcher can read the
    // file back late, and one of these coming back is not a theme change
    property var written: ({})
    // the last of them, or the original put back
    property string lastWrite: ""
    // the palette being edited; empty until something changes
    property var draft: ({})
    property bool editing: false
    property string selected: "primary"
    property bool allRoles: false
    // idle | building | saving | saved | error
    property string phase: "idle"
    property string message: ""
    readonly property var shown: editor.editing ? editor.draft : editor.onScreen
    readonly property var roles: Object.keys(editor.shown).filter((k) => {
        return typeof editor.shown[k] === "string" && editor.shown[k].charAt(0) === "#";
    }).sort()

    // the name a saved theme starts from, and the one typed over it
    property string baseName: ""
    property string themeName: editor.baseName !== "" ? editor.baseName + " (edited)" : "My palette"

    function begin() {
        if (editor.editing)
            return ;

        editor.originalText = paletteFile.text();
        editor.written = {};
        editor.phase = "idle";
        editor.message = "";
        editor.draft = Object.assign({}, editor.onScreen);
        editor.editing = true;
    }

    // a key colour: the rest of the palette follows it
    function setKey(role, hex) {
        editor.begin();
        var d = Object.assign({}, editor.draft);
        d[role] = hex;
        editor.draft = d;
        editor.phase = "building";
        builder.running = false;
        builder.command = ["python3", editor.home + "/.config/lucid/palette-edit.py", "build", d.surface, d.on_surface, d.primary, d.secondary, d.tertiary, d.error, Prefs.colorMode];
        builder.running = true;
    }

    // any other role, just that one
    function setRole(role, hex) {
        editor.begin();
        var d = Object.assign({}, editor.draft);
        d[role] = hex;
        editor.draft = d;
        editor.preview();
    }

    function set(hex) {
        var isKey = editor.keys.some((k) => {
            return k.role === editor.selected;
        });
        if (isKey)
            editor.setKey(editor.selected, hex);
        else
            editor.setRole(editor.selected, hex);
    }

    function preview() {
        var t = JSON.stringify(editor.draft, null, 2);
        editor.written[t] = true;
        editor.lastWrite = t;
        paletteFile.setText(t);
    }

    function discard() {
        if (!editor.editing)
            return ;

        editor.editing = false;
        editor.phase = "idle";
        editor.message = "";
        if (editor.originalText !== "") {
            editor.lastWrite = editor.originalText;
            paletteFile.setText(editor.originalText);
            editor.read(editor.originalText);
        }

    }

    function read(t) {
        try {
            editor.onScreen = JSON.parse(t);
        } catch (e) {
        }
    }

    function save(name) {
        if (!editor.editing || name.trim() === "")
            return ;

        editor.phase = "saving";
        saver.running = false;
        saver.command = ["python3", editor.home + "/.config/lucid/palette-edit.py", "save", name.trim(), JSON.stringify(editor.draft), Prefs.colorMode];
        saver.running = true;
    }

    spacing: 14

    // closing Settings with a draft on the shell would leave it there
    Connections {
        function onVisibleChanged() {
            if (editor.Window.window && !editor.Window.window.visible)
                editor.discard();

        }

        target: editor.Window.window
        ignoreUnknownSignals: true
    }

    FileView {
        id: paletteFile

        path: editor.palettePath
        watchChanges: true
        printErrors: false
        onFileChanged: paletteFile.reload()
        onLoaded: {
            var t = paletteFile.text();
            if (editor.editing) {
                // its own write, read back
                if (t === "" || editor.written[t] || t === editor.originalText)
                    return ;

                // a theme or wallpaper change wrote over the draft: that palette
                // is the one to keep now, so the draft goes without putting anything back
                editor.editing = false;
                editor.phase = "idle";
                editor.message = "The theme changed underneath, so the draft was dropped.";
            } else if (editor.written[t] && t !== editor.lastWrite) {
                // a draft read back after it was discarded
                return ;
            }
            editor.read(t);
        }
    }

    Process {
        id: builder

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text);
                } catch (e) {
                }
                if (!r || !r.ok) {
                    editor.phase = "error";
                    editor.message = r ? r.error : "The palette could not be built.";
                    return ;
                }
                editor.phase = "idle";
                editor.message = "";
                editor.draft = r.palette;
                editor.preview();
            }
        }

    }

    Process {
        id: saver

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text);
                } catch (e) {
                }
                if (!r || !r.ok) {
                    editor.phase = "error";
                    editor.message = r ? r.error : "The theme could not be saved.";
                    return ;
                }
                // the new theme takes over the palette file from the draft
                editor.onScreen = editor.draft;
                editor.editing = false;
                editor.phase = "saved";
                editor.message = r.name + " is one of your themes now, and the one on screen.";
                Prefs.rescanThemes();
                Prefs.themeChangeRequested(r.id);
            }
        }

    }

    // the six key colours
    Flow {
        width: editor.width
        spacing: 10

        Repeater {
            model: editor.keys

            delegate: Rectangle {
                id: key

                required property var modelData
                readonly property string hex: editor.shown[key.modelData.role] || "#000000"
                readonly property bool current: editor.selected === key.modelData.role

                width: 112
                height: 70
                radius: Theme.radiusMd
                color: key.hex
                border.width: key.current ? 3 : (keyArea.containsMouse ? 2 : 1)
                border.color: key.current ? Theme.text : Theme.alpha(Theme.text, 0.2)

                Column {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 9
                    spacing: 1

                    Text {
                        text: key.modelData.label
                        color: Theme.toneOf(Qt.color(key.hex)) > 60 ? "#000000" : "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.bold: true
                    }

                    Text {
                        text: key.hex
                        color: Theme.toneOf(Qt.color(key.hex)) > 60 ? "#333333" : "#dddddd"
                        font.family: "monospace"
                        font.pixelSize: Theme.fontLabel - 2
                    }

                }

                MouseArea {
                    id: keyArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editor.selected = key.modelData.role
                }

            }

        }

    }

    Text {
        width: editor.width
        text: editor.keys.some((k) => {
            return k.role === editor.selected;
        }) ? "Editing " + editor.selected.replace(/_/g, " ") + ". Changing a key colour builds the rest of the palette again from all six." : "Editing " + editor.selected.replace(/_/g, " ") + " by itself."
        color: Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

    ThemeColourPicker {
        width: editor.width
        colour: editor.shown[editor.selected] || "#000000"
        inUse: true
        onPicked: (hex) => {
            return editor.set(hex);
        }
    }

    M3Button {
        text: editor.allRoles ? "Hide the other roles" : "Every role (" + editor.roles.length + ")"
        variant: "text"
        onClicked: editor.allRoles = !editor.allRoles
    }

    Flow {
        width: editor.width
        spacing: 6
        visible: editor.allRoles

        Repeater {
            model: editor.allRoles ? editor.roles : []

            delegate: Rectangle {
                id: chip

                required property string modelData

                width: chipRow.implicitWidth + 20
                height: 32
                radius: height / 2
                color: editor.selected === chip.modelData ? Theme.bgHigh : (chipArea.containsMouse ? Theme.bgHigh : Theme.bgSunken)
                border.width: editor.selected === chip.modelData ? 2 : 0
                border.color: Theme.accent

                Row {
                    id: chipRow

                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        color: editor.shown[chip.modelData] || "#000000"
                        border.width: 1
                        border.color: Theme.alpha(Theme.text, 0.2)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: chip.modelData
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                    }

                }

                MouseArea {
                    id: chipArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: editor.selected = chip.modelData
                }

            }

        }

    }

    Row {
        spacing: 10
        visible: editor.editing

        M3TextField {
            id: nameField

            width: 260
            text: editor.themeName
            placeholder: "Name for the theme"
            onEdited: (v) => {
                return editor.themeName = v;
            }
            onAccepted: (v) => {
                return editor.save(v);
            }
        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            text: editor.phase === "saving" ? "Saving..." : "Save as theme"
            variant: "filled"
            enabled: editor.phase !== "saving" && editor.phase !== "building" && editor.themeName.trim() !== ""
            onClicked: editor.save(editor.themeName)
        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Discard"
            onClicked: editor.discard()
        }

    }

    Text {
        width: editor.width
        visible: editor.editing || editor.message !== ""
        text: editor.message !== "" ? editor.message : "The shell is showing the draft. Save it as a theme to keep it, which also carries it to your applications, or discard it."
        color: editor.phase === "error" ? Theme.error : Theme.subtext
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        wrapMode: Text.WordWrap
    }

}
