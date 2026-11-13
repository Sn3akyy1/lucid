import QtMultimedia
import QtQuick
import QtQuick.Pdf
import qs
import qs.lucidicons
import qs.lucidui

// the preview pane, right of the folder: what is picked out, big, and what there
// is to know about it. nothing picked shows the folder itself, several a stack.
// pictures, gifs, pdfs and text show what is in them; videos and sound play here
Item {
    id: prev

    required property var app
    required property var win
    // the pane's own width: it slides out at it rather than being squeezed
    readonly property real fullW: Theme.dp(300)
    readonly property var tab: prev.win.tab
    readonly property var items: {
        var t = prev.tab;
        if (!t || t.rev < 0 || t.selCount <= 0)
            return [];

        return t.selectedItems();
    }
    readonly property var one: prev.items.length === 1 ? prev.items[0] : null
    // nothing picked in a real folder: the folder is what is shown
    readonly property bool folderSelf: prev.items.length === 0 && prev.tab !== null && !prev.tab.isSpecial && !prev.tab.searching && prev.tab.path !== ""
    readonly property string subject: prev.one ? prev.one.uri : prev.folderSelf ? prev.app.uriOf(prev.tab.path) : ""
    // what the daemon said about the subject (peek), once it has
    property var info: null
    readonly property bool infoFits: prev.info !== null && prev.info.forUri === prev.subject
    readonly property string mime: prev.one ? prev.one.mime : ""
    // what the views load: someone else's file, through admin://, from the copy the daemon fetched
    readonly property string media: !prev.one ? "" : prev.one.uri.indexOf("admin:") !== 0 ? prev.one.uri : prev.infoFits && prev.info.local ? prev.info.local : ""
    readonly property string kind: {
        if (prev.items.length > 1)
            return "many";

        if (prev.folderSelf || (prev.one && prev.one.kind === "dir"))
            return "folder";

        if (!prev.one)
            return "none";

        var m = prev.mime;
        if (m === "image/gif")
            return "gif";

        if (m.indexOf("image/") === 0)
            return "image";

        if (m.indexOf("video/") === 0)
            return "video";

        if (m.indexOf("audio/") === 0)
            return "audio";

        if (m === "application/pdf")
            return "pdf";

        if (prev.infoFits && prev.info.text !== undefined)
            return "text";

        return "file";
    }
    // filled in by whichever view is showing
    property int pages: 0
    property real duration: 0

    function when(t) {
        return t > 0 ? new Date(t * 1000).toLocaleString(Qt.locale(), "d MMMM yyyy, hh:mm") : "";
    }

    function rows() {
        var out = [];
        var i = prev.infoFits ? prev.info : null;
        if (prev.kind === "many") {
            var bytes = 0, files = 0, dirs = 0;
            for (var k = 0; k < prev.items.length; k++) {
                if (prev.items[k].kind === "dir") {
                    dirs++;
                } else {
                    files++;
                    bytes += prev.items[k].size;
                }
            }
            out.push(["Items", (files > 0 ? files + (files === 1 ? " file" : " files") : "") + (files > 0 && dirs > 0 ? ", " : "") + (dirs > 0 ? dirs + (dirs === 1 ? " folder" : " folders") : "")]);
            if (files > 0)
                out.push(["Size", prev.app.sizeText(bytes)]);

            return out;
        }
        if (prev.kind === "folder") {
            if (i && i.files !== undefined)
                out.push(["Contains", (i.files + i.dirs === 0 ? "Nothing" : (i.dirs > 0 ? i.dirs + (i.dirs === 1 ? " folder" : " folders") : "") + (i.dirs > 0 && i.files > 0 ? ", " : "") + (i.files > 0 ? i.files + (i.files === 1 ? " file" : " files") : "")) + (i.more ? " or more" : "")]);

            if (i)
                out.push(["Modified", prev.when(i.mtime)]);

            return out;
        }
        if (!prev.one)
            return out;

        out.push(["Kind", (i && i.desc) || prev.one.desc || prev.one.mime]);
        out.push(["Size", prev.app.sizeText(prev.one.size)]);
        if (i && i.width)
            out.push(["Dimensions", i.width + " × " + i.height]);

        if (prev.kind === "pdf" && prev.pages > 0)
            out.push(["Pages", String(prev.pages)]);

        if ((prev.kind === "video" || prev.kind === "audio") && prev.duration > 0) {
            var s = Math.round(prev.duration / 1000);
            out.push(["Length", (s >= 3600 ? Math.floor(s / 3600) + ":" + ("0" + Math.floor(s % 3600 / 60)).slice(-2) : Math.floor(s / 60)) + ":" + ("0" + s % 60).slice(-2)]);
        }
        out.push(["Modified", prev.when(prev.one.mtime)]);
        if (i && i.ctime > 0 && i.ctime !== prev.one.mtime)
            out.push(["Created", prev.when(i.ctime)]);

        if (prev.tab && (prev.tab.searching || prev.tab.isRecent) && i)
            out.push(["Where", i.where]);

        return out;
    }

    onSubjectChanged: {
        prev.pages = 0;
        prev.duration = 0;
        ask.restart();
    }
    Component.onCompleted: ask.restart()

    // a moment's wait, so running through a folder with the keys asks once
    Timer {
        id: ask

        interval: 110
        onTriggered: {
            var want = prev.subject;
            if (want === "" || !prev.visible)
                return ;

            prev.app.call("peek", {
                "uri": want
            }, function(r) {
                if (r && r.ok && want === prev.subject) {
                    r.forUri = want;
                    prev.info = r;
                }
            });
        }
    }

    // the pane, at its own width, tied to its left edge: as the room for it
    // closes it slides out to the right instead of being cut
    Rectangle {
        id: sheet

        width: prev.fullW
        height: parent.height
        color: Theme.withBlur(Theme.bgSunken)
        radius: Theme.shapeXl
        opacity: Math.max(0, Math.min(1, prev.width / prev.fullW * 1.3 - 0.3))

        Flickable {
            id: scroll

            anchors.fill: parent
            anchors.margins: Theme.dp(14)
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: body

                width: scroll.width
                spacing: Theme.dp(14)

                // the thing itself
                Rectangle {
                    id: hero

                    width: parent.width
                    height: prev.kind === "text" ? Math.round(width * 1.15) : Math.round(width * 0.78)
                    radius: Theme.shapeLg
                    color: Theme.surfaceHigh
                    clip: true
                    visible: prev.kind !== "none" || prev.tab !== null

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.durMedium
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveStandard
                        }

                    }

                    Loader {
                        id: view

                        anchors.fill: parent
                        // a new subject eases in rather than snapping over the last
                        opacity: 0
                        sourceComponent: {
                            switch (prev.kind) {
                            case "image":
                                return imageView;
                            case "gif":
                                return gifView;
                            case "video":
                                return videoView;
                            case "audio":
                                return audioView;
                            case "pdf":
                                return pdfView;
                            case "text":
                                return textView;
                            case "many":
                                return manyView;
                            case "none":
                                return emptyView;
                            default:
                                return glyphView;
                            }
                        }
                        onLoaded: {
                            view.opacity = 0;
                            fadeIn.restart();
                        }

                        NumberAnimation {
                            id: fadeIn

                            target: view
                            property: "opacity"
                            to: 1
                            duration: Theme.durShort
                            easing.type: Easing.OutCubic
                        }

                    }

                    // the same view for another subject (one picture after another)
                    // still eases in
                    Connections {
                        function onSubjectChanged() {
                            view.opacity = 0.35;
                            fadeIn.restart();
                        }

                        target: prev
                    }

                }

                // its name, and what it is
                Column {
                    width: parent.width
                    spacing: Theme.dp(2)

                    LText {
                        width: parent.width
                        role: "titleMedium"
                        text: prev.kind === "many" ? prev.items.length + " items" : prev.one ? prev.one.label : prev.folderSelf ? prev.tab.title : "Nothing to preview"
                        color: Theme.text
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }

                    LText {
                        width: parent.width
                        visible: text !== ""
                        role: "bodyMedium"
                        text: prev.kind === "none" ? "Pick something to see it here" : prev.kind === "many" ? "Selected" : prev.folderSelf ? "This folder" : ""
                        color: Theme.subtext
                    }

                }

                // what there is to know
                Column {
                    width: parent.width
                    spacing: Theme.dp(8)

                    Repeater {
                        model: prev.infoFits || prev.kind === "many" || prev.one ? prev.rows() : []

                        delegate: Column {
                            required property var modelData

                            width: parent.width
                            spacing: Theme.dp(1)

                            LText {
                                role: "labelMedium"
                                text: modelData[0]
                                color: Theme.subtext
                            }

                            LText {
                                width: parent.width
                                role: "bodyMedium"
                                text: modelData[1]
                                color: Theme.text
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                        }

                    }

                }

                // what to do with it
                Row {
                    visible: prev.one !== null || prev.kind === "many"
                    spacing: Theme.dp(6)

                    Button {
                        variant: "tonal"
                        text: "Open"
                        icon: "open_in_new"
                        onClicked: prev.win.openSelection(false)
                    }

                    IconButton {
                        visible: prev.one !== null && prev.one.kind !== "dir"
                        icon: "apps"
                        tooltip: "Open with…"
                        onClicked: prev.win.runItem("openWith", prev.one, prev.items)

                        Tip {
                        }

                    }

                    IconButton {
                        icon: "info"
                        tooltip: "Properties"
                        onClicked: prev.win.runItem("properties", prev.one, prev.items)

                        Tip {
                        }

                    }

                }

            }

        }

    }

    // ---- the views

    Component {
        id: glyphView

        Item {
            FileGlyph {
                anchors.centerIn: parent
                size: Math.round(parent.height * 0.62)
                slot: prev.one ? prev.one.slot : prev.app.slotForPath(prev.tab ? prev.tab.path : "")
                icon: prev.one ? prev.one.icon : ""
                thumb: prev.one ? prev.one.thumb : ""
                kind: prev.one ? prev.one.kind : "dir"
                legacy: prev.app.legacyIcons
            }

        }

    }

    Component {
        id: emptyView

        Item {
            Icon {
                anchors.centerIn: parent
                name: "preview"
                size: Theme.dp(40)
                color: Theme.subtext
            }

        }

    }

    // a picture: its small copy at once, the full one over it when decoded
    Component {
        id: imageView

        Item {
            Image {
                id: low

                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                source: prev.one && prev.one.thumb !== "" ? "file://" + prev.one.thumb : ""
                fillMode: Image.PreserveAspectFit
                visible: full.status !== Image.Ready
                smooth: true
            }

            Image {
                id: full

                anchors.fill: parent
                anchors.margins: Theme.dp(8)
                // only once it has a size: before that a decode would be the original's
                source: prev.one && width > 0 ? prev.media : ""
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                smooth: true
                mipmap: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

        }

    }

    Component {
        id: gifView

        AnimatedImage {
            anchors.fill: parent
            anchors.margins: Theme.dp(8)
            source: prev.media
            fillMode: Image.PreserveAspectFit
            playing: prev.visible && prev.width > 0
            asynchronous: true
        }

    }

    // a pdf's first page, rendered here
    Component {
        id: pdfView

        Item {
            PdfDocument {
                id: doc

                source: prev.media
                onPageCountChanged: prev.pages = doc.pageCount
            }

            Rectangle {
                anchors.centerIn: page
                width: page.paintedWidth
                height: page.paintedHeight
                color: "white"
                visible: page.status === Image.Ready
            }

            PdfPageImage {
                id: page

                anchors.fill: parent
                anchors.margins: Theme.dp(10)
                document: doc
                currentFrame: 0
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.ceil(width * 2)
            }

        }

    }

    // the start of a text file, as it is
    Component {
        id: textView

        Flickable {
            id: tf

            anchors.fill: parent
            anchors.margins: Theme.dp(10)
            contentHeight: lines.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Text {
                id: lines

                width: tf.width
                text: prev.infoFits && prev.info.text !== undefined ? prev.info.text + (prev.info.cut ? "\n…" : "") : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                font.family: "monospace"
                font.pixelSize: Theme.dp(11)
                color: Theme.text
                opacity: 0.9
            }

        }

    }

    // several picked: the first few, fanned
    Component {
        id: manyView

        Item {
            Repeater {
                model: Math.min(3, prev.items.length)

                delegate: FileGlyph {
                    required property int index
                    readonly property var it: prev.items[Math.min(2, prev.items.length - 1) - index]

                    x: (parent.width - width) / 2 + (index - 1) * Theme.dp(26)
                    y: (parent.height - height) / 2 + Math.abs(index - 1) * Theme.dp(6)
                    rotation: (index - 1) * 9
                    size: Math.round(parent.height * 0.5)
                    slot: it ? it.slot : "file"
                    icon: it ? it.icon : ""
                    thumb: it ? it.thumb : ""
                    kind: it ? it.kind : "file"
                    legacy: prev.app.legacyIcons
                }

            }

        }

    }

    // a video: its frame until asked to play, then playing here, muted to start
    Component {
        id: videoView

        Item {
            id: vv

            property bool playing: false

            Image {
                anchors.fill: parent
                source: prev.one && prev.one.thumb !== "" ? "file://" + prev.one.thumb : ""
                fillMode: Image.PreserveAspectCrop
                visible: !vv.playing
            }

            Loader {
                anchors.fill: parent
                active: vv.playing

                sourceComponent: Item {
                    MediaPlayer {
                        id: player

                        source: prev.media
                        videoOutput: out
                        loops: MediaPlayer.Infinite
                        onDurationChanged: prev.duration = player.duration
                        Component.onCompleted: player.play()

                        audioOutput: AudioOutput {
                            muted: muteBtn.checked
                        }

                    }

                    VideoOutput {
                        id: out

                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: player.playbackState === MediaPlayer.PlayingState ? player.pause() : player.play()
                    }

                }

            }

            IconButton {
                anchors.centerIn: parent
                visible: !vv.playing
                variant: "filled"
                size: "m"
                icon: "play_arrow"
                tooltip: "Play"
                onClicked: vv.playing = true
            }

            IconButton {
                id: muteBtn

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(8)
                visible: vv.playing
                variant: "tonal"
                size: "xs"
                checkable: true
                checked: true
                icon: checked ? "volume_off" : "volume_up"
                tooltip: checked ? "Sound on" : "Mute"
                onClicked: checked = !checked
            }

        }

    }

    // sound: its glyph, and a button that plays it here
    Component {
        id: audioView

        Item {
            id: av

            property bool started: false

            FileGlyph {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -Theme.dp(14)
                size: Math.round(parent.height * 0.5)
                slot: prev.one ? prev.one.slot : "file"
                kind: "file"
                legacy: prev.app.legacyIcons
            }

            Loader {
                id: sound

                active: av.started

                sourceComponent: MediaPlayer {
                    source: prev.media
                    onDurationChanged: prev.duration = duration
                    Component.onCompleted: play()

                    audioOutput: AudioOutput {
                    }

                }

            }

            IconButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.dp(12)
                variant: "filled"
                icon: sound.item && sound.item.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                tooltip: sound.item && sound.item.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                onClicked: {
                    if (!av.started)
                        av.started = true;
                    else if (sound.item.playbackState === MediaPlayer.PlayingState)
                        sound.item.pause();
                    else
                        sound.item.play();
                }
            }

        }

    }

}
