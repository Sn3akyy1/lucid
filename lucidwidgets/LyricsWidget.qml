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
    // the pause being waited through: a line with no words, or the song's intro before the first one
    readonly property var pauseLine: w.line ? w.line : (w.synced && w.lines.length && w.lines[0].t > 0 ? {
        "t": 0,
        "end": w.lines[0].t,
        "text": "",
        "words": []
    } : null)
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

    // captions in two rows unless the card is set to one
    readonly property bool twoRows: w.opt("lines") !== "one"

    // a line cut into the few words a caption shows at once, so a long one never shrinks to fit
    function pagesOf(l) {
        var out = [];
        if (!l)
            return out;

        var cur = [], chars = 0;
        for (var i = 0; i < l.words.length; i++) {
            var n = l.words[i].text.length;
            if (cur.length && (chars + n > (w.twoRows ? 34 : 20) || cur.length >= (w.twoRows ? 9 : 5))) {
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
            // a new array per page: the words of the next one start from nothing
            readonly property var rows: w.twoRows ? Lyrics.splitRows(cap.shown) : [cap.shown.slice()]
            // now and then one word of a page is drawn as its outline only, the
            // way edited captions vary them. picked from the line, so it holds still
            readonly property var hollow: {
                if (w.opt("outline") === false || cap.shown.length < 2 || !w.line)
                    return null;

                var key = w.line.text + "\u0001" + cap.page, h = 5381;
                for (var i = 0; i < key.length; i++) h = ((h * 33) ^ key.charCodeAt(i)) >>> 0
                // about two pages in three, and never a word too short to read hollow
                if (h % 3 === 0)
                    return null;

                var fit = cap.shown.filter((wd) => {
                    return wd.text.length >= 3;
                });
                return fit.length ? fit[(h >>> 2) % fit.length] : null;
            }
            readonly property int px: Math.round(Math.max(Theme.dp(16), Math.min(Theme.dp(72), cap.height * (w.twoRows ? 0.3 : 0.42))))

            LyricLine {
                anchors.centerIn: parent
                width: parent.width
                visible: !w.line || w.line.words.length === 0
                line: w.pauseLine
                when: 0
                pos: w.pos
                px: cap.px
                centred: true
                ink: w.fgFaint
                inkLit: w.fgLit
            }

            Column {
                id: capRows

                anchors.centerIn: parent
                spacing: -Math.round(cap.px * 0.12)
                scale: Math.min(1, cap.width / Math.max(1, capRows.implicitWidth), cap.height / Math.max(1, capRows.implicitHeight))

                Repeater {
                    model: cap.rows

                    delegate: Row {
                        id: capRow

                        required property var modelData

                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Math.round(cap.px * 0.28)

                        Repeater {
                            model: capRow.modelData

                    delegate: LText {
                        id: word

                        required property var modelData
                        readonly property bool sung: w.pos >= word.modelData.t
                        readonly property bool now: word.sung && w.pos < word.modelData.end
                        // by start and text: a Repeater hands its delegate a copy of the word, never the same object
                        readonly property bool hollow: cap.hollow !== null && word.modelData.t === cap.hollow.t && word.modelData.text === cap.hollow.text
                        // which way it leans before it lands, picked from its start so it holds still
                        readonly property real tilt: (Math.round(word.modelData.t * 100) % 2 === 0 ? 1 : -1) * 9

                        text: word.modelData.text
                        size: cap.px
                        weight: 760
                        rounded: 100
                        color: word.hollow ? "transparent" : (word.now ? w.fgLit : w.fg)
                        // the glyph edge only: Qt's own outline keeps the shapes and the baseline of the filled words
                        style: word.hollow ? Text.Outline : Text.Normal
                        styleColor: word.now ? w.fgLit : w.fg
                        opacity: word.sung ? 1 : 0
                        scale: word.sung ? (word.now ? 1.1 : 1) : 0.55
                        rotation: word.sung ? 0 : word.tilt
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

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6 + Theme.jelly
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

        }

    }

    // the line fills with colour word by word as it is sung, the next one waiting under it
    Component {
        id: karaoke

        Item {
            id: kar

            // a gallery tile shrinks the whole card, so its sample line is drawn larger
            readonly property int px: Math.round(Math.max(Theme.dp(15), Math.min(Theme.dp(56), kar.height * (w.preview ? 0.45 : 0.3))))

            // the line on screen, so the one just sung can be shown leaving
            property string shownText: ""

            Component.onCompleted: kar.shownText = w.line ? w.line.text : ""
            onVisibleChanged: {
                kar.shownText = w.line ? w.line.text : "";
                promote.restart();
            }

            Connections {
                function onIndexChanged() {
                    ghost.text = kar.shownText;
                    kar.shownText = w.line ? w.line.text : "";
                    leave.restart();
                    promote.restart();
                }

                target: w
            }

            // the line that was waiting under it comes up into its place, growing to full size
            ParallelAnimation {
                id: promote

                NumberAnimation {
                    target: karShift
                    property: "y"
                    from: Math.round(kar.px * 1.3) + karCol.spacing
                    to: 0
                    duration: Theme.durLong
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: karNow
                    property: "scale"
                    from: 0.62
                    to: 1
                    duration: Theme.durLong
                    easing.type: Theme.jelly > 0 ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1 + Theme.jelly
                }

                SequentialAnimation {
                    PropertyAction {
                        target: karNext
                        property: "opacity"
                        value: 0
                    }

                    PauseAnimation {
                        duration: Theme.durShort
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: karNext
                            property: "opacity"
                            to: 1
                            duration: Theme.durMedium
                        }

                        NumberAnimation {
                            target: karNextShift
                            property: "y"
                            from: Math.round(kar.px * 0.5)
                            to: 0
                            duration: Theme.durMedium
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            // and the line just sung goes up and away, shrinking
            ParallelAnimation {
                id: leave

                NumberAnimation {
                    target: ghostShift
                    property: "y"
                    from: 0
                    to: -Math.round(kar.px * 1.6)
                    duration: Theme.durLong
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: ghost
                    property: "scale"
                    from: 1
                    to: 0.7
                    duration: Theme.durLong
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: ghost
                    property: "opacity"
                    from: 0.9
                    to: 0
                    duration: Theme.durLong
                }

            }

            LText {
                id: ghost

                width: parent.width
                y: karCol.y + karNow.y + Math.round((karNow.height - ghost.height) / 2)
                visible: ghost.opacity > 0.01 && ghost.text !== ""
                opacity: 0
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                size: kar.px
                weight: 720
                color: w.fgLit
                transform: Translate {
                    id: ghostShift
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

                // a line height even with no words, or the column drops it and the dots with it
                Item {
                    id: karNow

                    width: parent.width
                    height: Math.max(karRow.height, Math.round(kar.px * 1.3))

                    LyricLine {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: !w.line || w.line.words.length === 0
                        line: w.pauseLine
                        when: 0
                        pos: w.pos
                        px: kar.px
                        centred: true
                        ink: w.fgFaint
                        inkLit: w.fgLit
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

                                // the word being sung stands up a little
                                readonly property bool now: kw.sung > 0 && kw.sung < kw.modelData.text.length

                                width: kwBase.implicitWidth
                                height: kwBase.implicitHeight
                                transformOrigin: Item.Bottom
                                scale: kw.now ? 1.08 : 1
                                transform: Translate {
                                    y: kw.now ? -Math.round(kar.px * 0.08) : 0

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: Theme.durShort
                                            easing.type: Theme.jelly > 0 ? Easing.OutBack : Easing.OutCubic
                                            easing.overshoot: 1.2 + Theme.jelly
                                        }

                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durShort
                                        easing.type: Theme.jelly > 0 ? Easing.OutBack : Easing.OutCubic
                                        easing.overshoot: 1.2 + Theme.jelly
                                    }

                                }

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
                    id: karNext

                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    visible: !w.preview
                    text: w.nextLine ? w.nextLine.text : ""
                    size: Math.round(kar.px * 0.62)
                    transform: Translate {
                        id: karNextShift
                    }
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

            delegate: Item {
                id: cl

                required property var modelData
                required property int index
                readonly property int away: cl.index - w.index

                // room for the lit line to grow without the list clipping its ends
                x: Math.round(list.width * 0.03)
                width: Math.round(list.width * 0.94)
                height: clWords.implicitHeight
                // distance shows in steps, none of them too faint to read
                opacity: !w.synced ? 0.9 : Math.max(0.72, 1 - Math.abs(cl.away) * 0.14)
                // the line being sung comes up to full size, the rest wait smaller
                scale: !w.synced || cl.away === 0 ? 1 : 0.84

                LyricLine {
                    id: clWords

                    width: parent.width
                    line: cl.modelData
                    synced: w.synced
                    when: !w.synced ? 1 : (cl.away < 0 ? -1 : (cl.away === 0 ? 0 : 1))
                    pos: w.synced && cl.away === 0 ? w.pos : 0
                    px: list.px
                    weight: 680
                    centred: true
                    ink: w.fg
                    inkAhead: w.fg
                    inkLit: w.fgLit
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durMedium
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durLong
                        easing.type: Theme.jelly > 0 ? Easing.OutBack : Easing.OutCubic
                        easing.overshoot: 1 + Theme.jelly
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
