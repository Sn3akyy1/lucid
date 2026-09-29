import QtQuick
import Quickshell
import Quickshell.Io
import qs

// a template of your own: a file (or a link to one) with matugen's
// {{colors...}} where colours go, the file it writes, and what makes the app
// reload. Try it renders it with the current colours first, so a mistake shows
// here rather than as a toast on the next change
Column {
    id: form

    property string name: ""
    property string input: ""
    property string output: ""
    property string hook: ""
    // idle | trying | tried | adding | added | error
    property string phase: "idle"
    property string message: ""
    property string preview: ""

    readonly property bool ready: form.name.trim() !== "" && form.input.trim() !== "" && form.output.trim() !== ""
    readonly property bool working: form.phase === "trying" || form.phase === "adding"

    function tryIt() {
        if (form.input.trim() === "" || form.working)
            return ;

        form.phase = "trying";
        form.message = "";
        form.preview = "";
        Templates.tryTemplate(form.input.trim(), (r) => {
            if (r.ok) {
                form.phase = "tried";
                form.preview = r.text;
                form.message = r.truncated ? "The first part of what it writes:" : "What it writes with your colours:";
            } else {
                form.phase = "error";
                form.message = r.error;
            }
        });
    }

    function addIt() {
        if (!form.ready || form.working)
            return ;

        form.phase = "adding";
        form.message = "";
        Templates.add(form.name.trim(), form.input.trim(), form.output.trim(), form.hook, (r) => {
            if (r.ok) {
                form.phase = "added";
                form.message = r.name + " is in the list above, coloured with the current palette.";
                form.preview = "";
                nameField.set("");
                inputField.set("");
                outputField.set("");
                hookField.set("");
            } else {
                form.phase = "error";
                form.message = r.error;
            }
        });
    }

    spacing: 12

    Row {
        spacing: 10

        M3TextField {
            id: nameField

            width: 200
            text: form.name
            placeholder: "Name, like myapp"
            onEdited: (v) => {
                return form.name = v;
            }
        }

        M3TextField {
            id: hookField

            width: form.width - nameField.width - 10
            text: form.hook
            placeholder: "Command that reloads the app (optional)"
            onEdited: (v) => {
                return form.hook = v;
            }
        }

    }

    Row {
        spacing: 10

        M3TextField {
            id: inputField

            width: form.width - chooseButton.width - 10
            text: form.input
            placeholder: "Template file, or an https:// link to one"
            onEdited: (v) => {
                return form.input = v;
            }
            onAccepted: (v) => {
                form.input = v;
                form.tryIt();
            }
        }

        M3Button {
            id: chooseButton

            anchors.verticalCenter: parent.verticalCenter
            text: "Choose..."
            onClicked: {
                picker.command = ["sh", "-c", "zenity --file-selection --title='Choose a template' 2>/dev/null || true"];
                picker.running = true;
            }
        }

    }

    M3TextField {
        id: outputField

        width: form.width
        text: form.output
        placeholder: "File it writes, like ~/.config/myapp/colors.css"
        onEdited: (v) => {
            return form.output = v;
        }
    }

    Row {
        spacing: 10

        M3Button {
            text: form.phase === "trying" ? "Trying..." : "Try it"
            enabled: form.input.trim() !== "" && !form.working
            // play
            iconPath: "M8 5v14l11-7z"
            onClicked: form.tryIt()
        }

        M3Button {
            text: form.phase === "adding" ? "Adding..." : "Add"
            variant: "filled"
            enabled: form.ready && !form.working
            iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
            onClicked: form.addIt()
        }

    }

    Rectangle {
        width: form.width
        height: result.implicitHeight + 24
        radius: Theme.radiusSm
        color: Theme.bgSunken
        visible: form.message !== "" || form.preview !== ""

        Column {
            id: result

            x: 14
            y: 12
            width: parent.width - 28
            spacing: 8

            Text {
                width: parent.width
                text: form.message
                visible: form.message !== ""
                color: form.phase === "error" ? Theme.error : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: form.preview
                visible: form.preview !== ""
                color: Theme.text
                font.family: "monospace"
                font.pixelSize: Theme.fontLabel
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 16
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

        }

    }

    Process {
        id: picker

        stdout: StdioCollector {
            onStreamFinished: {
                var chosen = text.trim();
                if (chosen === "")
                    return ;

                inputField.set(chosen);
                // a name to start from: the file's, without its extension
                if (form.name.trim() === "")
                    nameField.set(chosen.split("/").pop().replace(/\.[^.]*$/, "").replace(/[."'\[\]]/g, "-"));

                form.tryIt();
            }
        }

    }

}
