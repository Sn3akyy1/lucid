import QtQuick
import qs
import qs.lucidui

// one modal card for everything lumen asks: confirm, name a thing, pick an app,
// show a file's details. ask(opts, cb) calls back cb(accepted, value)
Item {
    id: dlg

    property bool shown: false
    property string mode: "confirm"
    property string title: ""
    property string text: ""
    property string confirmLabel: "OK"
    property string cancelLabel: "Cancel"
    property bool danger: false
    property var taken: []
    property var apps: []
    property int appPick: -1
    property bool always: false
    property var rows: []
    property var glyph: null
    property var callback: null
    readonly property string problem: {
        if (dlg.mode !== "input")
            return "";

        var t = field.text.trim();
        if (t === "")
            return " ";

        if (t.indexOf("/") !== -1)
            return "A name can't contain “/”";

        if (t === "." || t === "..")
            return "That name is reserved";

        if (dlg.taken.indexOf(t) !== -1)
            return "Something here already has that name";

        return "";
    }

    function ask(opts, cb) {
        dlg.mode = opts.mode || "confirm";
        dlg.title = opts.title || "";
        dlg.text = opts.text || "";
        dlg.confirmLabel = opts.confirm || "OK";
        dlg.cancelLabel = opts.cancel || "Cancel";
        dlg.danger = opts.danger === true;
        dlg.taken = opts.taken || [];
        dlg.apps = opts.apps || [];
        dlg.appPick = dlg.apps.length > 0 ? 0 : -1;
        dlg.always = false;
        dlg.rows = opts.rows || [];
        dlg.glyph = opts.glyph || null;
        dlg.callback = cb || null;
        dlg.shown = true;
        if (dlg.mode === "input") {
            field.text = opts.input || "";
            var end = opts.selectEnd !== undefined ? opts.selectEnd : field.text.length;
            Qt.callLater(function() {
                field.input.forceActiveFocus();
                field.input.select(0, end);
            });
        } else {
            Qt.callLater(function() {
                card.forceActiveFocus();
            });
        }
    }

    function setRow(key, value) {
        var r = dlg.rows.slice();
        for (var i = 0; i < r.length; i++) {
            if (r[i].key === key) {
                r[i] = Object.assign({}, r[i], {
                    "value": value
                });
                dlg.rows = r;
                return ;
            }
        }
    }

    function finish(ok) {
        if (ok && dlg.problem !== "")
            return ;

        var cb = dlg.callback;
        var value = dlg.mode === "input" ? field.text.trim() : dlg.mode === "apps" ? {
            "app": dlg.appPick >= 0 ? dlg.apps[dlg.appPick] : null,
            "always": dlg.always
        } : null;
        dlg.shown = false;
        dlg.callback = null;
        if (cb)
            cb(ok, value);

    }

    anchors.fill: parent
    visible: dlg.shown || scrim.opacity > 0

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Theme.scrim
        opacity: dlg.shown ? 0.55 : 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: dlg.finish(false)
            onWheel: (wheel) => {
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.dp(48), dlg.mode === "info" ? Theme.dp(460) : Theme.dp(420))
        height: body.implicitHeight + Theme.dp(48)
        radius: Theme.shapeXl
        color: Theme.bgHigh
        opacity: dlg.shown ? 1 : 0
        scale: dlg.shown ? 1 : 0.94
        focus: dlg.shown && dlg.mode !== "input"
        Keys.onEscapePressed: dlg.finish(false)
        Keys.onReturnPressed: dlg.finish(true)
        Keys.onEnterPressed: dlg.finish(true)

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body

            x: Theme.dp(24)
            y: Theme.dp(24)
            width: card.width - Theme.dp(48)
            spacing: Theme.dp(16)

            Row {
                width: parent.width
                spacing: Theme.dp(16)

                FileGlyph {
                    id: hero

                    visible: dlg.glyph !== null
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(56)
                    slot: dlg.glyph ? dlg.glyph.slot || "file" : "file"
                    thumb: dlg.glyph ? dlg.glyph.thumb || "" : ""
                    icon: dlg.glyph ? dlg.glyph.icon || "" : ""
                    kind: dlg.glyph ? dlg.glyph.kind || "file" : "file"
                    legacy: dlg.glyph ? dlg.glyph.legacy === true : false
                }

                LText {
                    width: parent.width - (hero.visible ? hero.width + parent.spacing : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "headlineSmall"
                    text: dlg.title
                    color: Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

            }

            LText {
                width: parent.width
                visible: dlg.text !== ""
                role: "bodyMedium"
                text: dlg.text
                color: Theme.subtext
                wrapMode: Text.Wrap
            }

            TextField {
                id: field

                width: parent.width
                visible: dlg.mode === "input"
                variant: "filled"
                error: dlg.problem !== "" && dlg.problem !== " "
                supporting: dlg.problem === " " ? "" : dlg.problem
                onAccepted: dlg.finish(true)
                onEscaped: dlg.finish(false)
            }

            // open with: the apps that take this kind of file
            Column {
                width: parent.width
                visible: dlg.mode === "apps"
                spacing: Theme.dp(2)

                Repeater {
                    model: dlg.mode === "apps" ? dlg.apps : []

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: dlg.appPick === index

                        width: parent.width
                        height: Theme.dp(48)
                        radius: index === 0 ? Theme.dp(20) : Theme.dp(6)
                        color: on ? Theme.accentContainer : Theme.surfaceHigh

                        Image {
                            id: appIcon

                            x: Theme.dp(14)
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(28)
                            height: Theme.dp(28)
                            source: modelData.icon ? "file://" + modelData.icon : ""
                            sourceSize: Qt.size(Theme.dp(56), Theme.dp(56))
                            asynchronous: true
                        }

                        LText {
                            anchors.left: appIcon.right
                            anchors.leftMargin: Theme.dp(12)
                            anchors.right: tag.left
                            anchors.rightMargin: Theme.dp(8)
                            anchors.verticalCenter: parent.verticalCenter
                            role: "bodyLarge"
                            text: modelData.name
                            color: on ? Theme.fgAccentContainer : Theme.text
                            elide: Text.ElideRight
                        }

                        LText {
                            id: tag

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(16)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.default === true
                            role: "labelSmall"
                            text: "Default"
                            color: on ? Theme.fgAccentContainer : Theme.subtext
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: dlg.appPick = index
                            onDoubleClicked: {
                                dlg.appPick = index;
                                dlg.finish(true);
                            }
                        }

                    }

                }

                // a check of its own: lucid's switch belongs to the shell's sounds
                Item {
                    width: parent.width
                    height: Theme.dp(44)

                    Rectangle {
                        id: box

                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.dp(4)
                        width: Theme.dp(20)
                        height: Theme.dp(20)
                        radius: Theme.dp(6)
                        color: dlg.always ? Theme.accent : "transparent"
                        border.width: dlg.always ? 0 : Theme.dp(2)
                        border.color: Theme.subtext

                        Icon {
                            anchors.centerIn: parent
                            visible: dlg.always
                            name: "check"
                            size: Theme.dp(16)
                            color: Theme.fgAccent
                        }

                    }

                    LText {
                        anchors.left: box.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        text: "Always use it for this kind of file"
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: dlg.always = !dlg.always
                    }

                }

            }

            // properties: one row per fact
            Column {
                width: parent.width
                visible: dlg.mode === "info"
                spacing: Theme.dp(10)

                Repeater {
                    model: dlg.mode === "info" ? dlg.rows : []

                    delegate: Row {
                        required property var modelData

                        width: parent.width
                        spacing: Theme.dp(16)

                        LText {
                            width: Theme.dp(110)
                            role: "labelLarge"
                            text: modelData.label
                            color: Theme.subtext
                        }

                        LText {
                            width: parent.width - Theme.dp(126)
                            role: "bodyMedium"
                            text: modelData.value
                            color: Theme.text
                            wrapMode: Text.WrapAnywhere
                            maximumLineCount: 4
                            elide: Text.ElideRight
                        }

                    }

                }

            }

            Row {
                anchors.right: parent.right
                spacing: Theme.dp(8)

                Button {
                    visible: dlg.mode !== "info"
                    variant: "text"
                    text: dlg.cancelLabel
                    onClicked: dlg.finish(false)
                }

                Button {
                    variant: dlg.mode === "info" ? "tonal" : "filled"
                    danger: dlg.danger
                    disabled: dlg.problem !== "" || (dlg.mode === "apps" && dlg.appPick < 0)
                    text: dlg.mode === "info" ? "Close" : dlg.confirmLabel
                    onClicked: dlg.finish(dlg.mode !== "info")
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
