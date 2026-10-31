import QtQuick
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidui

// one capture's card: the picture (or the text read off it), what it is, and
// what to do with it next. the stack around it decides where it goes and how long
Item {
    id: card

    // the stack, which owns the entries, the engine and the timing
    property var stack: null
    property var entry: null
    // 0..1 of the time left, drawn round the close button
    property real life: 1
    property bool armed: false
    property string done: ""
    readonly property string kind: card.entry ? card.entry.kind : "image"
    readonly property string file: card.entry ? (card.entry.file || "") : ""
    readonly property bool ready: card.file !== ""
    readonly property bool temp: card.entry ? card.entry.temp === true : false
    readonly property bool hovered: hover.hovered
    readonly property bool dragging: thumbArea.drag.active
    readonly property var lay: card.stack ? card.stack.layout(card.entry) : ({
        "thumbH": 0,
        "cardH": 0,
        "textH": 0
    })
    readonly property string link: {
        const all = card.entry ? (card.entry.codes || []).concat([card.entry.text || ""]) : [];
        for (const t of all) {
            const m = String(t).match(/https?:\/\/[^\s<>"']+/);
            if (m)
                return m[0];

        }
        return "";
    }
    readonly property string title: {
        if (card.armed)
            return "Click again to delete";

        if (card.done !== "")
            return card.done;

        switch (card.kind) {
        case "video":
            return "Recording saved";
        case "gif":
            return "GIF made";
        case "text":
            return card.entry && card.entry.text ? "Text copied" : "Code copied";
        }
        if (card.temp)
            return "Copied, not saved";

        return card.entry && card.entry.edited ? "Edited copy saved" : "Screenshot copied";
    }
    readonly property string meta: {
        const e = card.entry;
        if (!e)
            return "";

        if (card.kind === "text") {
            const words = (e.text || "").split(/\s+/).filter((w) => {
                return w !== "";
            }).length;
            const parts = [];
            if (words > 0)
                parts.push(words === 1 ? "1 word" : words + " words");

            if ((e.codes || []).length > 0)
                parts.push(e.codes.length === 1 ? "1 code" : e.codes.length + " codes");

            return parts.join("  ·  ");
        }
        const parts = [];
        if (e.w > 0 && e.h > 0)
            parts.push(e.w + " × " + e.h);

        if (e.duration > 0)
            parts.push(Capture.clock(Math.round(e.duration)));

        if (e.bytes > 0)
            parts.push(card.sizeText(e.bytes));

        if (parts.length === 0 && card.file !== "")
            parts.push(card.file.substring(card.file.lastIndexOf("/") + 1));

        return parts.join("  ·  ");
    }

    function sizeText(b) {
        if (b < 1024 * 1024)
            return Math.max(1, Math.round(b / 1024)) + " KB";

        return (b / 1024 / 1024).toFixed(b < 10 * 1024 * 1024 ? 1 : 0) + " MB";
    }

    function say(text) {
        card.done = text;
        doneTimer.restart();
    }

    function act(what) {
        const s = card.stack;
        const f = card.file;
        if (!s || !card.entry)
            return ;

        switch (what) {
        case "copy":
            if (card.kind === "text")
                s.engine.copyText(card.entry.text || (card.entry.codes || [])[0] || "");
            else if (card.kind === "image")
                s.engine.copyImage(f);
            else
                s.engine.copyFile(f);
            card.say("Copied");
            return ;
        case "open":
            s.engine.view(f);
            s.dismiss(card.entry.id);
            return ;
        case "markup":
            s.markup(card.entry);
            return ;
        case "pin":
            s.pin(card.entry, card);
            return ;
        case "text":
            s.readText(card.entry);
            card.say("Reading the text…");
            return ;
        case "folder":
            s.engine.reveal(f);
            return ;
        case "save":
            s.keep(card.entry);
            card.say("Saved");
            return ;
        case "gif":
            s.makeGif(card.entry);
            return ;
        case "search":
            s.engine.search(card.entry.text || (card.entry.codes || [])[0] || "");
            s.dismiss(card.entry.id);
            return ;
        case "link":
            s.engine.open(card.link);
            s.dismiss(card.entry.id);
            return ;
        case "delete":
            if (!card.armed) {
                card.armed = true;
                disarm.restart();
                return ;
            }
            card.armed = false;
            s.engine.trash(f);
            s.dismiss(card.entry.id);
            return ;
        }
    }

    width: card.stack ? card.stack.cardW : Theme.dp(344)
    height: card.lay.cardH
    // faded as one picture, or the face shows through the thumbnail and buttons
    layer.enabled: card.opacity < 0.999
    onEntryChanged: {
        card.armed = false;
        card.done = "";
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: card.armed = false
    }

    Timer {
        id: doneTimer

        interval: 1600
        onTriggered: card.done = ""
    }

    Rectangle {
        id: face

        anchors.fill: parent
        radius: card.stack ? card.stack.cardRadius : Theme.rad(24)
        color: Theme.bg
        border.width: 1
        border.color: Theme.alpha(Theme.text, 0.06)
    }

    HoverHandler {
        id: hover
    }

    // the rest of the card opens it too, down to the row of actions: a slip off
    // one of those must not take the card away
    MouseArea {
        width: card.width
        height: actions.y
        enabled: thumbArea.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: card.act("open")
    }

    ClippingRectangle {
        id: thumb

        readonly property bool moving: card.kind === "video" || card.kind === "gif"

        x: card.stack ? card.stack.pad : Theme.dp(8)
        y: x
        width: card.width - x * 2
        height: card.lay.thumbH
        visible: height > 0
        radius: card.stack ? card.stack.thumbRadius : Theme.rad(16)
        color: Theme.surfaceHighest

        // a still: the capture's own thumbnail, the file once it is there
        Image {
            id: still

            anchors.fill: parent
            visible: card.kind !== "gif"
            source: card.entry ? (card.entry.thumb ? "file://" + card.entry.thumb : (card.kind === "image" && card.ready ? card.stack.engine.fileUrl(card.file) : "")) : ""
            sourceSize.width: thumb.width * 2
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        AnimatedImage {
            anchors.fill: parent
            visible: card.kind === "gif"
            source: card.kind === "gif" && card.ready ? card.stack.engine.fileUrl(card.file) : ""
            fillMode: Image.PreserveAspectCrop
            playing: card.visible && card.kind === "gif"
            cache: false
        }

        Rectangle {
            anchors.centerIn: parent
            visible: card.kind === "video"
            width: Theme.dp(48)
            height: width
            radius: width / 2
            color: Theme.alpha("#000000", 0.5)

            Icon {
                anchors.centerIn: parent
                name: "play_arrow"
                size: Theme.dp(30)
                fill: 1
                color: "#ffffff"
            }

        }

        LoadingIndicator {
            anchors.centerIn: parent
            width: Theme.dp(40)
            height: width
            visible: card.kind === "image" && !card.ready && still.status !== Image.Ready
            running: visible
        }

        // dragged out, the capture lands in any app that takes files
        Item {
            id: dragProxy

            width: Math.round(thumb.width / 2)
            height: Math.round(thumb.height / 2)
            Drag.active: card.dragging
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({
                "text/uri-list": card.ready && card.stack ? card.stack.engine.fileUrl(card.file) + "\r\n" : ""
            })
            Drag.hotSpot.x: dragProxy.width / 2
            Drag.hotSpot.y: dragProxy.height / 2
            // the card stays: under wayland a drop another app took comes back
            // as IgnoreAction, the same as one that missed
            Drag.onDragFinished: {
                dragProxy.x = 0;
                dragProxy.y = 0;
            }
        }

        MouseArea {
            id: thumbArea

            anchors.fill: parent
            enabled: card.ready && card.kind !== "text"
            hoverEnabled: true
            cursorShape: card.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: dragProxy
            drag.threshold: 8
            onClicked: card.act("open")
            // grabbed on press, so it is ready by the time a drag starts
            onPressed: thumb.grabToImage((r) => {
                dragProxy.Drag.imageSource = r.url;
            }, Qt.size(dragProxy.width, dragProxy.height))
        }

    }

    // outside the thumbnail's clip, or it would be cut away
    Item {
        x: thumb.x
        y: thumb.y
        width: thumb.width
        height: thumb.height

        ShotTip {
            text: card.kind === "image" ? "Open it in Lens, or drag it into an app" : (card.kind === "text" ? "" : "Play it in Lens, or drag it into an app")
            hovered: thumbArea.containsMouse && !thumbArea.pressed
            above: true
        }

    }

    Item {
        id: info

        x: thumb.x + Theme.dp(8)
        y: thumb.y + thumb.height + Theme.dp(10)
        width: thumb.width - Theme.dp(8)
        height: Theme.dp(44)

        Column {
            anchors.left: parent.left
            anchors.right: closer.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            LText {
                width: parent.width
                role: "titleSmall"
                color: card.armed ? Theme.error : Theme.text
                elide: Text.ElideRight
                text: card.title
            }

            LText {
                width: parent.width
                role: "bodySmall"
                tabular: true
                color: Theme.subtext
                elide: Text.ElideMiddle
                text: card.meta
            }

        }

        // the time left runs round the close button
        Item {
            id: closer

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(40)
            height: Theme.dp(40)

            CircularProgress {
                anchors.fill: parent
                value: card.life
                thickness: Theme.dp(3)
                wavy: false
                animated: false
                showTrack: false
                color: Theme.alpha(Theme.primary, card.hovered ? 0.35 : 0.85)
            }

            ShotButton {
                anchors.centerIn: parent
                size: Theme.dp(32)
                icon: "close"
                tip: "Dismiss"
                onClicked: card.stack.dismiss(card.entry.id)
            }

        }

    }

    Rectangle {
        id: textBox

        visible: card.kind === "text"
        x: thumb.x
        y: info.y + info.height + Theme.dp(4)
        width: thumb.width
        height: card.lay.textH
        radius: Theme.rad(16)
        color: Theme.surfaceHigh

        LText {
            anchors.fill: parent
            anchors.margins: Theme.dp(12)
            role: "bodyMedium"
            color: Theme.text
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: 4
            text: card.entry ? (card.entry.text || (card.entry.codes || []).join("\n")) : ""
        }

    }

    Row {
        id: actions

        x: thumb.x
        y: card.height - height - Theme.dp(10)
        width: thumb.width
        spacing: Theme.dp(2)

        Button {
            anchors.verticalCenter: parent.verticalCenter
            variant: "tonal"
            size: "s"
            disabled: !card.ready && card.kind !== "text"
            icon: card.kind === "image" ? "edit" : (card.kind === "video" ? "play_arrow" : (card.kind === "gif" ? "open_in_new" : "content_copy"))
            text: card.kind === "image" ? "Mark up" : (card.kind === "video" ? "Play" : (card.kind === "gif" ? "Open" : "Copy"))
            onClicked: card.act(card.kind === "image" ? "markup" : (card.kind === "text" ? "copy" : "open"))
        }

        Item {
            width: Theme.dp(6)
            height: 1
        }

        ShotButton {
            visible: card.kind !== "text"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "content_copy"
            tip: card.kind === "image" ? "Copy the picture" : "Copy the file"
            disabled: !card.ready
            onClicked: card.act("copy")
        }

        ShotButton {
            visible: card.kind === "image"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "keep"
            tip: "Pin it to the screen"
            disabled: !card.ready
            onClicked: card.act("pin")
        }

        ShotButton {
            visible: card.kind === "image"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "document_scanner"
            tip: "Copy the text in it"
            disabled: !card.ready
            onClicked: card.act("text")
        }

        ShotButton {
            visible: card.kind === "video"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "gif"
            tip: card.entry && card.entry.busy ? "Making a GIF…" : "Make a GIF of it"
            disabled: !card.ready || (card.entry && card.entry.busy === true)
            onClicked: card.act("gif")
        }

        ShotButton {
            visible: card.kind === "text"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "search"
            tip: "Search the web for it"
            onClicked: card.act("search")
        }

        ShotButton {
            visible: card.link !== ""
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: "open_in_new"
            tip: "Open " + card.link
            onClicked: card.act("link")
        }

        ShotButton {
            visible: card.kind !== "text"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: card.temp ? "save" : "folder_open"
            tip: card.temp ? "Save it to the screenshots folder" : "Show it in its folder"
            disabled: !card.ready
            onClicked: card.act(card.temp ? "save" : "folder")
        }

        ShotButton {
            visible: card.kind !== "text"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            icon: card.armed ? "delete_forever" : "delete"
            tip: card.armed ? "Click again to delete" : "Delete"
            checked: card.armed
            onFill: Theme.errorContainer
            onInk: Theme.fgErrorContainer
            disabled: !card.ready
            onClicked: card.act("delete")
        }

    }

}
