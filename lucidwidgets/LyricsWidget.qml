import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs
import qs.lucidui
import "../lucidui/Lyrics.js" as Lyrics

WidgetBody {
    id: w

    readonly property var players: Mpris.players.values.filter((p) => {
        return !(p.dbusName && p.dbusName.indexOf("playerctld") !== -1);
    })
    readonly property var player: {
        for (var i = 0; i < w.players.length; i++) {
            if (w.players[i].isPlaying)
                return w.players[i];

        }
        return w.players.length > 0 ? w.players[0] : null;
    }
    readonly property bool cardOn: w.opt("card") !== false
    // the words and where the song is in them: the track's, or a made-up verse in a gallery tile
    readonly property var lines: w.preview ? w.demoLines : lyr.lines
    readonly property bool synced: w.preview ? true : lyr.synced
    readonly property real pos: w.preview ? w.demoPos : lyr.pos
    readonly property int index: w.preview ? Lyrics.lineAt(w.demoLines, w.demoPos, -1) : lyr.index
    readonly property var line: w.index >= 0 && w.index < w.lines.length ? w.lines[w.index] : null
    readonly property var nextLine: w.index + 1 < w.lines.length ? w.lines[w.index + 1] : null
    // the word being sung in the current line, -1 between words
    readonly property int wordIndex: {
        if (!w.line)
            return -1;

        var at = -1;
        for (var i = 0; i < w.line.words.length; i++) if (w.line.words[i].t <= w.pos)
            at = i;
        return at;
    }
    // what can be shown: the two timed looks need timed lyrics, classic reads plain ones too
    readonly property bool showing: w.preview || (lyr.status === "found" && (w.synced || w.variant === "classic"))
    property bool fresh: false
    readonly property color fg: w.cardOn ? w.ink : "white"
    readonly property color fgLit: w.cardOn ? w.inkAccent : Theme.atTone(Theme.accent, 84)
    readonly property color fgFaint: w.cardOn ? w.inkFaint : Qt.rgba(1, 1, 1, 0.5)
    readonly property string waiting: {
        if (!w.player)
            return "Nothing playing";

        switch (lyr.status) {
        case "loading":
            return "Looking for the words";
        case "instrumental":
            return "Instrumental";
        case "offline":
            return "Couldn't reach lrclib.net";
        case "found":
            return "No timed lyrics for this track";
        }
        return "No lyrics for this track";
    }
    // a gallery tile's verse, on a loop
    property real demoPos: 0
    readonly property var demoLines: Lyrics.finish([{
        "t": 0,
        "end": -1,
        "text": "City lights calling",
        "words": []
    }, {
        "t": 3.2,
        "end": -1,
        "text": "Every street a song",
        "words": []
    }, {
        "t": 6.4,
        "end": -1,
        "text": "Hold the night",
        "words": []
    }, {
        "t": 9.4,
        "end": -1,
        "text": "Till the morning",
        "words": []
    }], 12.4)

    // a line cut into the few words a caption shows at once, so a long one never shrinks to fit
    function pagesOf(l) {
        var out = [];
        if (!l)
            return out;

        var cur = [], chars = 0;
        for (var i = 0; i < l.words.length; i++) {
            var n = l.words[i].text.length;
            if (cur.length && (chars + n > 20 || cur.length >= 5)) {
                out.push(cur);
                cur = [];
                chars = 0;
            }
            cur.push(l.words[i]);
            chars += n + 1;
        }
        if (cur.length)
            out.push(cur);

        return out;
    }

    bare: !w.cardOn
    hidden: w.opt("idleFade") !== false && !w.preview && !w.fresh && !w.showing
    onBornChanged: {
        if (w.born) {
            w.fresh = true;
            settle.restart();
        }
    }

    LyricsSource {
        id: lyr

        player: w.player
        active: w.live
    }

    Timer {
        id: settle

        interval: 5000
        onTriggered: w.fresh = false
    }

    FrameAnimation {
        running: w.preview && w.visible
        onTriggered: w.demoPos = (w.demoPos + frameTime) % 12.4
    }

    Item {
        id: stage

        anchors.fill: parent
        anchors.margins: w.cardOn ? w.pad : Theme.dp(6)
        // the words are drawn on the wallpaper without a card: a soft shadow keeps them readable
        layer.enabled: !w.cardOn
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.55
            shadowBlur: 0.5
            shadowVerticalOffset: 1.5
        }

        LText {
            anchors.centerIn: parent
            width: parent.width
            visible: !w.showing
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            role: "bodyLarge"
            color: w.fgFaint
            text: w.waiting
        }

        Loader {
            anchors.fill: parent
            active: w.showing
            sourceComponent: w.variant === "karaoke" ? karaoke : (w.variant === "classic" ? classic : words)
        }

    }

    // each word pops in as it is sung, a few at a time, the way short videos caption a song
    Component {
        id: words

        Item {
            id: cap

            readonly property var pages: w.pagesOf(w.line)
            readonly property int page: {
                // the words themselves, not indices: a page never points into a line it was not cut from
                var at = w.line ? w.line.words[Math.max(0, w.wordIndex)] : null;
                for (var p = 0; p < cap.pages.length; p++) if (cap.pages[p].indexOf(at) !== -1)
                    return p;
                return 0;
            }
            readonly property var shown: cap.pages.length ? cap.pages[cap.page] : []
            // now and then one word of a page is drawn as its outline only, the
            // way edited captions vary them. picked from the line, so it holds still
            readonly property int hollow: {
                if (w.opt("outline") === false || cap.shown.length < 2 || !w.line)
                    return -1;

                var key = w.line.text + "\u0001" + cap.page, h = 5381;
                for (var i = 0; i < key.length; i++) h = ((h * 33) ^ key.charCodeAt(i)) >>> 0
                // about two pages in three, and never a word too short to read hollow
                if (h % 3 === 0)
                    return -1;

                var fit = [];
                for (var k = 0; k < cap.shown.length; k++) if (cap.shown[k].text.length >= 3)
                    fit.push(k);
                return fit.length ? fit[(h >>> 2) % fit.length] : -1;
            }
            readonly property int px: Math.round(Math.max(Theme.dp(16), Math.min(Theme.dp(72), cap.height * 0.42)))

            LText {
                anchors.centerIn: parent
                visible: !w.line || w.line.words.length === 0
                text: "♪"
                size: cap.px
                color: w.fgFaint
            }

            Row {
                id: capRow

                anchors.centerIn: parent
                spacing: Math.round(cap.px * 0.28)
                scale: capRow.implicitWidth > cap.width ? cap.width / capRow.implicitWidth : 1

                Repeater {
                    // a new array per page: the words of the next one start from nothing
                    model: cap.shown.slice()

                    delegate: LText {
                        id: word

                        required property var modelData
                        required property int index
                        readonly property bool sung: w.pos >= word.modelData.t
                        readonly property bool now: word.sung && w.pos < word.modelData.end
                        readonly property bool hollow: word.index === cap.hollow

                        text: word.modelData.text
                        size: cap.px
                        weight: 760
                        rounded: 100
                        color: word.hollow ? "transparent" : (word.now ? w.fgLit : w.fg)
                        // the glyph edge only: Qt's own outline keeps the shapes and the baseline of the filled words
                        style: word.hollow ? Text.Outline : Text.Normal
                        styleColor: word.now ? w.fgLit : w.fg
                        opacity: word.sung ? 1 : 0
                        scale: word.sung ? (word.now ? 1.08 : 1) : 0.55
                        transform: Translate {
                            y: word.sung ? 0 : cap.px * 0.35

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.durMedium
                                    easing.type: Easing.OutBack
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
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

        }

    }

    // the line fills with colour word by word as it is sung, the next one waiting under it
    Component {
        id: karaoke

        Item {
            id: kar

            // a gallery tile shrinks the whole card, so its sample line is drawn larger
            readonly property int px: Math.round(Math.max(Theme.dp(15), Math.min(Theme.dp(56), kar.height * (w.preview ? 0.45 : 0.3))))

            onVisibleChanged: enter.restart()

            Connections {
                function onIndexChanged() {
                    enter.restart();
                }

                target: w
            }

            ParallelAnimation {
                id: enter

                NumberAnimation {
                    target: karCol
                    property: "opacity"
                    from: 0.25
                    to: 1
                    duration: Theme.durMedium
                }

                NumberAnimation {
                    target: karShift
                    property: "y"
                    from: kar.px * 0.6
                    to: 0
                    duration: Theme.durMedium
                    easing.type: Easing.OutCubic
                }

            }

            Column {
                id: karCol

                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(kar.px * 0.35)
                transform: Translate {
                    id: karShift
                }

                // a line height even with no words, or the column drops it and the note with it
                Item {
                    width: parent.width
                    height: Math.max(karRow.height, Math.round(kar.px * 1.3))

                    LText {
                        anchors.centerIn: parent
                        visible: !w.line || w.line.words.length === 0
                        text: "♪"
                        size: kar.px
                        color: w.fgFaint
                    }

                    Row {
                        id: karRow

                        anchors.centerIn: parent
                        spacing: Math.round(kar.px * 0.26)
                        scale: karRow.implicitWidth > parent.width ? parent.width / karRow.implicitWidth : 1

                        Repeater {
                            model: w.line ? w.line.words : []

                            delegate: Item {
                                id: kw

                                required property var modelData
                                // letters sung so far, the one being sung partly
                                readonly property real sung: Lyrics.lettersSung(kw.modelData, w.pos)
                                readonly property int whole: Math.floor(kw.sung)
                                readonly property real fillW: {
                                    if (kw.sung <= 0)
                                        return 0;

                                    if (kw.sung >= kw.modelData.text.length)
                                        return kw.width;

                                    const t = kw.modelData.text;
                                    const a = kwMetrics.advanceWidth(t.slice(0, kw.whole));
                                    return a + (kw.sung - kw.whole) * (kwMetrics.advanceWidth(t.slice(0, kw.whole + 1)) - a);
                                }

                                width: kwBase.implicitWidth
                                height: kwBase.implicitHeight

                                LText {
                                    id: kwBase

                                    text: kw.modelData.text
                                    size: kar.px
                                    weight: 720
                                    color: w.fgFaint
                                }

                                FontMetrics {
                                    id: kwMetrics

                                    font: kwBase.font
                                }

                                // the sung letters, drawn over the word from the left
                                Item {
                                    width: kw.fillW
                                    height: kw.height
                                    clip: true

                                    LText {
                                        text: kw.modelData.text
                                        size: kar.px
                                        weight: 720
                                        color: w.fgLit
                                    }

                                }

                            }

                        }

                    }

                }

                LText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: !w.preview
                    text: w.nextLine ? w.nextLine.text : ""
                    size: Math.round(kar.px * 0.62)
                    weight: 600
                    color: w.fgFaint
                }

            }

        }

    }

    // the whole song going by, the line being sung lit up in the middle
    Component {
        id: classic

        ListView {
            id: list

            readonly property int px: Math.round(w.preview ? Math.min(Theme.dp(48), w.width * 0.085) : Math.max(Theme.dp(13), Math.min(Theme.dp(30), w.width * 0.05)))

            clip: true
            model: w.lines
            spacing: Math.round(list.px * 0.6)
            interactive: !w.synced
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: w.index
            highlightRangeMode: w.synced ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
            preferredHighlightBegin: Math.round(list.height * 0.42)
            preferredHighlightEnd: Math.round(list.height * 0.42) + list.px * 2
            highlightMoveDuration: Theme.durLong
            highlightMoveVelocity: -1

            delegate: LText {
                id: cl

                required property var modelData
                required property int index
                readonly property int away: Math.abs(cl.index - w.index)

                // room for the lit line to grow without the list clipping its ends
                x: Math.round(list.width * 0.03)
                width: Math.round(list.width * 0.94)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: cl.modelData.text !== "" ? cl.modelData.text : "♪"
                size: list.px
                weight: 680
                color: w.synced && cl.away === 0 ? w.fgLit : w.fg
                // distance shows in steps, none of them too faint to read
                opacity: !w.synced ? 0.9 : Math.max(0.72, 1 - cl.away * 0.14)
                scale: w.synced && cl.away === 0 ? 1.06 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durMedium
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durMedium
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    enabled: w.synced && !w.preview && w.player !== null && w.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: lyr.seekLine(cl.index)
                }

            }

        }

    }

}
