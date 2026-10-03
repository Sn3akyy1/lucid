import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.lucidui

// the card that floats in the corner after a screenshot or a recording is
// saved: the capture itself, and what to do with it next. it slides away on
// its own unless the pointer is resting on it
PanelWindow {
    id: preview

    property bool shown: false
    property string file: ""
    // "image" | "video"
    property string kind: "image"
    // what the card shows: the capture for an image, a frame for a video
    property string thumb: ""
    property int imgW: 0
    property int imgH: 0
    property bool armedDelete: false
    // seconds, for a recording
    property real duration: 0
    // skips the slide, so a capture taken right after never has the card in it
    property bool instant: false
    // the card drawn empty for a capture. the window stays mapped meanwhile:
    // unmapping it sets off the compositor's own fade, which the capture sees
    property bool cleared: false
    // the button under the pointer names itself on the caption line
    property string hint: ""
    property string done: ""

    readonly property int cardWidth: 320
    readonly property int pad: 8
    readonly property int thumbWidth: preview.cardWidth - preview.pad * 2
    readonly property int thumbHeight: {
        if (preview.imgW <= 0 || preview.imgH <= 0)
            return 180;

        return Math.round(Math.max(110, Math.min(220, preview.thumbWidth * preview.imgH / preview.imgW)));
    }
    // every control names itself in hint while under the pointer, and a
    // hovering MouseArea hides the pointer from the card's HoverHandler
    readonly property bool hovered: cardHover.hovered || preview.hint !== ""
    readonly property bool dragging: shotArea.drag.active
    readonly property bool onScreen: preview.visible && !preview.cleared
    readonly property string fileName: preview.file.substring(preview.file.lastIndexOf("/") + 1)
    readonly property string fileUrl: "file://" + preview.file.split("/").map((p) => {
        return encodeURIComponent(p);
    }).join("/")
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lucid-shot"

    // material symbol names, by action
    readonly property var icons: ({
        "copy": "content_copy",
        "edit": "edit",
        "folder": "folder_open",
        "delete": "delete",
        "close": "close",
        "play": "play_arrow"
    })

    function show(path, what, where) {
        if (!path)
            return ;

        if (where)
            preview.screen = where;

        preview.file = path;
        preview.kind = what === "video" ? "video" : "image";
        preview.armedDelete = false;
        preview.done = "";
        preview.hint = "";
        preview.imgW = 0;
        preview.imgH = 0;
        preview.duration = 0;
        preview.instant = false;
        preview.cleared = false;
        unmapTimer.stop();
        // the real size (and length): the thumbnail is decoded smaller
        probeProc.running = false;
        probeProc.command = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height:format=duration", "-of", "csv=p=0", path];
        probeProc.running = true;
        if (preview.kind === "image") {
            preview.thumb = "";
            preview.thumb = preview.fileUrl;
        } else {
            // a frame from half a second in, the first is often black
            preview.thumb = "";
            frameProc.target = preview.thumbDir + "/frame-" + Date.now() + ".jpg";
            frameProc.command = ["sh", "-c", "mkdir -p \"$1\" && chmod 700 \"$1\" && rm -f \"$1\"/frame-*.jpg; ffmpeg -v error -y -ss 0.5 -i \"$2\" -frames:v 1 -vf scale=640:-2 \"$3\" || ffmpeg -v error -y -i \"$2\" -frames:v 1 -vf scale=640:-2 \"$3\"", "sh", preview.thumbDir, path, frameProc.target];
            frameProc.running = true;
        }
        preview.shown = true;
        lifeAnim.restart();
    }

    // gone this frame, no slide: a live capture is about to be taken
    function hideNow() {
        preview.instant = true;
        preview.cleared = true;
        preview.dismiss();
        unmapTimer.restart();
    }

    // a control under the pointer as the card goes would otherwise keep its
    // hint, and with it hold the next card up for good
    function dismiss() {
        lifeAnim.stop();
        preview.shown = false;
        preview.armedDelete = false;
        preview.hint = "";
    }

    // the next control's enter can land before this one's exit
    function leave(label) {
        if (preview.hint === label)
            preview.hint = "";

    }

    function run(argv) {
        Quickshell.execDetached(argv);
    }

    function act(what) {
        const f = preview.file;
        if (what === "copy") {
            // an image goes on as itself; a video as a file other apps can paste
            if (preview.kind === "image")
                preview.run(["sh", "-c", "wl-copy --type image/png < \"$1\"", "sh", f]);
            else
                preview.run(["wl-copy", "--type", "text/uri-list", preview.fileUrl]);
            preview.done = "Copied";
            doneTimer.restart();
            return ;
        }
        if (what === "edit") {
            preview.run(["swappy", "-f", f]);
        } else if (what === "open") {
            preview.run(["xdg-open", f]);
        } else if (what === "folder") {
            // a file manager that speaks FileManager1 opens the folder with the
            // file already picked out; anything else just gets the folder
            preview.run(["sh", "-c", "gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems \"['$1']\" '' >/dev/null 2>&1 || xdg-open \"$2\"", "sh", preview.fileUrl, f.substring(0, f.lastIndexOf("/"))]);
        } else if (what === "delete") {
            if (!preview.armedDelete) {
                preview.armedDelete = true;
                disarmTimer.restart();
                return ;
            }
            // the trash first, so a slip can be undone from the file manager
            preview.run(["sh", "-c", "gio trash \"$1\" 2>/dev/null || rm -f \"$1\"", "sh", f]);
        }
        preview.dismiss();
    }

    color: "transparent"
    exclusiveZone: 0
    visible: (card.opacity > 0.01 || preview.cleared) && Monitors.surfacesUp
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucid-shot-preview"
    implicitWidth: preview.cardWidth + 36
    implicitHeight: card.height + 36
    BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && preview.visible && !preview.cleared) ? cardBlur : null
    mask: preview.shown ? cardRegion : emptyRegion

    anchors {
        bottom: true
        right: true
    }

    Region {
        id: emptyRegion
    }

    Region {
        id: cardRegion

        item: card
    }

    Region {
        id: cardBlur

        x: Math.round(card.x + slide.x)
        y: Math.round(card.y)
        width: card.width
        height: card.height
        radius: card.radius
    }

    // the time left, run as an animation so hovering can pause it in place
    NumberAnimation {
        id: lifeAnim

        target: lifeBar
        property: "progress"
        from: 1
        to: 0
        duration: Math.max(2, Prefs.shotPreviewSeconds) * 1000
        paused: running && (preview.hovered || preview.dragging)
        onFinished: preview.dismiss()
    }

    // long after any capture that asked for the clear has been taken
    Timer {
        id: unmapTimer

        interval: 1500
        onTriggered: preview.cleared = false
    }

    Timer {
        id: disarmTimer

        interval: 3000
        onTriggered: preview.armedDelete = false
    }

    Timer {
        id: doneTimer

        interval: 1400
        onTriggered: preview.done = ""
    }

    Process {
        id: probeProc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const wh = (lines[0] || "").split(",");
                const w = parseInt(wh[0]);
                const h = parseInt(wh[1]);
                if (w > 0 && h > 0) {
                    preview.imgW = w;
                    preview.imgH = h;
                }
                const d = parseFloat(lines[1]);
                preview.duration = isNaN(d) ? 0 : d;
            }
        }

    }

    Process {
        id: frameProc

        property string target: ""

        onExited: (code) => {
            if (code === 0)
                preview.thumb = "file://" + frameProc.target;

        }
    }

    Rectangle {
        id: card

        // hidden outright while cleared: a fade still running would keep
        // painting it even with its Behavior switched off
        visible: !preview.cleared
        x: 18
        y: 18
        width: preview.cardWidth
        height: body.implicitHeight + preview.pad * 2
        radius: Theme.radiusLg
        color: Theme.bg
        opacity: preview.shown ? 1 : 0
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.06)

        transform: Translate {
            id: slide

            x: preview.shown ? 0 : 60

            Behavior on x {
                enabled: !preview.instant

                NumberAnimation {
                    duration: preview.shown ? Theme.durEnter : Theme.durExit
                    easing.type: Easing.Bezier
                    easing.bezierCurve: preview.shown ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
                }

            }

        }

        HoverHandler {
            id: cardHover
        }

        Column {
            id: body

            x: preview.pad
            y: preview.pad
            width: preview.thumbWidth
            spacing: 8

            ClippingRectangle {
                id: shot

                width: preview.thumbWidth
                height: preview.thumbHeight
                // concentric with the card
                radius: Math.max(4, card.radius - preview.pad)
                color: Theme.alpha(Theme.text, 0.06)

                Image {
                    id: shotImage

                    anchors.fill: parent
                    source: preview.thumb
                    sourceSize.width: preview.thumbWidth * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 46
                    height: 46
                    radius: 23
                    visible: preview.kind === "video"
                    color: Theme.alpha("#000000", 0.45)

                    Glyph {
                        anchors.centerIn: parent
                        name: preview.icons.play
                        size: 28
                        tint: "#ffffff"
                    }

                }

                // dragged out, the capture lands in any app that takes files
                Item {
                    id: dragProxy

                    width: shot.width
                    height: shot.height
                    Drag.active: preview.dragging
                    Drag.dragType: Drag.Automatic
                    Drag.supportedActions: Qt.CopyAction
                    Drag.mimeData: ({
                        "text/uri-list": preview.fileUrl + "\r\n"
                    })
                    Drag.hotSpot.x: dragProxy.imageWidth / 2
                    Drag.hotSpot.y: dragProxy.imageHeight / 2
                    // the card stays: a drop another app took comes back here as
                    // IgnoreAction under Wayland, same as one that missed
                    Drag.onDragFinished: (action) => {
                        dragProxy.x = 0;
                        dragProxy.y = 0;
                    }

                    // the picture that rides under the pointer, half the thumbnail
                    readonly property int imageWidth: Math.round(shot.width / 2)
                    readonly property int imageHeight: Math.round(shot.height / 2)
                }

                MouseArea {
                    id: shotArea

                    readonly property string label: preview.kind === "image" ? "Open it, or drag it out" : "Play it, or drag it out"

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: preview.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    drag.target: dragProxy
                    drag.threshold: 8
                    onEntered: preview.hint = shotArea.label
                    onExited: preview.leave(shotArea.label)
                    onClicked: preview.act("open")
                    // grabbed on press, so it is ready by the time the drag starts
                    onPressed: shot.grabToImage((r) => {
                        dragProxy.Drag.imageSource = r.url;
                    }, Qt.size(dragProxy.imageWidth, dragProxy.imageHeight))
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: 26
                    height: 26
                    radius: 13
                    opacity: preview.hovered ? 1 : 0
                    color: closeArea.containsMouse ? Theme.alpha("#000000", 0.7) : Theme.alpha("#000000", 0.5)

                    Glyph {
                        anchors.centerIn: parent
                        name: preview.icons.close
                        size: 16
                        tint: "#ffffff"
                    }

                    MouseArea {
                        id: closeArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: preview.hint = "Dismiss"
                        onExited: preview.leave("Dismiss")
                        onClicked: preview.dismiss()
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

            Item {
                width: parent.width
                height: 34

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.right: actions.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: {
                            if (preview.armedDelete)
                                return "Click again to delete";

                            if (preview.done !== "")
                                return preview.done;

                            if (preview.hint !== "")
                                return preview.hint;

                            return preview.kind === "video" ? "Recording saved" : "Screenshot copied";
                        }
                        color: preview.armedDelete ? Theme.error : Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: {
                            if (preview.imgW <= 0)
                                return preview.fileName;

                            const size = preview.imgW + " × " + preview.imgH;
                            if (preview.duration <= 0)
                                return size;

                            const secs = Math.round(preview.duration);
                            return size + "  ·  " + Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0");
                        }
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        elide: Text.ElideMiddle
                    }

                }

                Row {
                    id: actions

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    ActionButton {
                        action: "copy"
                        label: preview.kind === "image" ? "Copy the image" : "Copy the file"
                    }

                    ActionButton {
                        action: "edit"
                        label: "Mark it up"
                        visible: preview.kind === "image"
                    }

                    ActionButton {
                        action: "folder"
                        label: "Show in folder"
                    }

                    ActionButton {
                        action: "delete"
                        label: "Delete"
                        danger: true
                    }

                }

            }

        }

        Rectangle {
            id: lifeBar

            property real progress: 1

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            x: card.radius
            width: Math.max(0, (card.width - card.radius * 2) * lifeBar.progress)
            height: 2
            radius: 1
            color: Theme.alpha(Theme.accent, preview.hovered ? 0.35 : 0.7)
        }

        Behavior on opacity {
            enabled: !preview.instant

            NumberAnimation {
                duration: preview.shown ? Theme.durEnter : Theme.durExit
                easing.type: Easing.Bezier
                easing.bezierCurve: preview.shown ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

    }

    component Glyph: Item {
        id: glyph

        property string name: ""
        property int size: 18
        property color tint: Theme.text

        width: 24
        height: 24

        Icon {
            anchors.centerIn: parent
            name: glyph.name
            size: Math.round(glyph.size * 1.1)
            fill: 1
            color: glyph.tint
        }

    }

    component ActionButton: Rectangle {
        id: btn

        property string action: ""
        property string label: ""
        property bool danger: false
        readonly property bool armed: btn.danger && preview.armedDelete

        width: 34
        height: 34
        radius: 17
        color: btn.armed ? Theme.alpha(Theme.error, 0.18) : (btnArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent")

        Glyph {
            anchors.centerIn: parent
            name: preview.icons[btn.action] || ""
            size: 18
            tint: btn.danger && (btn.armed || btnArea.containsMouse) ? Theme.error : Theme.subtext
        }

        MouseArea {
            id: btnArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: preview.hint = btn.label
            onExited: preview.leave(btn.label)
            onClicked: preview.act(btn.action)
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
