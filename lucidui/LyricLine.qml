import QtQuick
import qs
import "Lyrics.js" as Lyrics

// one line of a song, drawn word by word. while it is the line being sung its
// letters fill with colour as they are sung and the word being sung lifts a
// little; a line with no words is a pause, three dots that fill through it,
// breathe with it and let go just before the next line. how big the line is
// against the others is the host's to set
Item {
    id: ll

    property var line: null
    property real pos: 0
    // -1 sung already, 0 being sung, 1 still to come
    property int when: 1
    property bool synced: true
    property int px: Theme.dp(16)
    property real weight: 640
    property bool centred: false
    // a line that is not being sung
    property color ink: Theme.subtext
    // the line being sung: letters still to come, and the ones sung
    property color inkAhead: Theme.text
    property color inkLit: Theme.accent

    readonly property bool pause: !ll.line || ll.line.text === ""
    readonly property var words: {
        if (!ll.line || ll.line.text === "")
            return [];

        if (ll.line.words && ll.line.words.length)
            return ll.line.words;

        return ll.line.text.split(/\s+/).map((t) => {
            return {
                "t": -1,
                "end": -1,
                "text": t
            };
        });
    }
    // read the font, so a new size or weight measures again
    // a little wider than a space, so a word standing up never touches its neighbours
    readonly property real spaceW: metrics.font.pixelSize > 0 ? Math.round(metrics.advanceWidth(" ") * 1.3) : 0
    // the words broken into rows that fit, the way the text would wrap
    readonly property var rows: {
        // read the font first, so a new size or weight measures again
        if (metrics.font.pixelSize <= 0)
            return [];

        var out = [], row = [], at = 0, room = ll.width;
        for (var i = 0; i < ll.words.length; i++) {
            var wd = metrics.advanceWidth(ll.words[i].text);
            if (row.length && at + ll.spaceW + wd > room) {
                out.push(row);
                row = [];
                at = 0;
            }
            at += (row.length ? ll.spaceW : 0) + wd;
            row.push(ll.words[i]);
        }
        if (row.length)
            out.push(row);

        return out;
    }
    // 0..1 through a pause
    readonly property real gap: {
        if (!ll.pause || ll.when !== 0 || !ll.line || ll.line.end <= ll.line.t)
            return ll.when < 0 ? 1 : 0;

        return Math.max(0, Math.min(1, (ll.pos - ll.line.t) / (ll.line.end - ll.line.t)));
    }

    implicitHeight: ll.pause ? (ll.synced ? Math.round(ll.px * 1.3) : Math.round(ll.px * 0.6)) : rowsCol.implicitHeight

    LText {
        id: probe

        visible: false
        text: " "
        size: ll.px
        weight: ll.weight
    }

    FontMetrics {
        id: metrics

        font: probe.font
    }

    Column {
        id: rowsCol

        width: parent.width
        visible: !ll.pause

        Repeater {
            model: ll.rows

            delegate: Row {
                id: lineRow

                required property var modelData

                x: ll.centred ? Math.round((rowsCol.width - lineRow.implicitWidth) / 2) : 0
                spacing: ll.spaceW

                Repeater {
                    model: lineRow.modelData

                    delegate: Item {
                        id: wd

                        required property var modelData
                        readonly property int n: wd.modelData.text.length
                        // letters sung so far, the one being sung partly; only the line being sung reads the clock
                        readonly property real sung: ll.when < 0 ? wd.n : (ll.when > 0 || !ll.synced || wd.modelData.t < 0 ? 0 : Lyrics.lettersSung(wd.modelData, ll.pos))
                        readonly property bool now: ll.when === 0 && wd.sung > 0 && wd.sung < wd.n
                        readonly property real fillW: {
                            if (wd.sung <= 0)
                                return 0;

                            if (wd.sung >= wd.n)
                                return wd.width;

                            const whole = Math.floor(wd.sung);
                            const t = wd.modelData.text;
                            const a = metrics.advanceWidth(t.slice(0, whole));
                            return a + (wd.sung - whole) * (metrics.advanceWidth(t.slice(0, whole + 1)) - a);
                        }

                        width: base.implicitWidth
                        height: base.implicitHeight
                        transformOrigin: Item.Bottom
                        scale: wd.now ? 1.03 : 1
                        transform: Translate {
                            y: wd.now ? -Math.round(ll.px * 0.1) : 0

                            Behavior on y {
                                NumberAnimation {
                                    duration: Theme.durShort
                                    easing.type: Theme.jelly > 0 ? Easing.OutBack : Easing.OutCubic
                                    easing.overshoot: 1.2 + Theme.jelly
                                }

                            }

                        }

                        LText {
                            id: base

                            text: wd.modelData.text
                            size: ll.px
                            weight: ll.weight
                            color: ll.when === 0 ? ll.inkAhead : ll.ink

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durMedium
                                }

                            }

                        }

                        // the sung letters, over the word from the left; a sung line lets go of them slowly
                        Item {
                            width: wd.fillW
                            height: wd.height
                            clip: true
                            opacity: ll.when === 0 ? 1 : 0
                            visible: wd.fillW > 0 && opacity > 0

                            LText {
                                text: wd.modelData.text
                                size: ll.px
                                weight: ll.weight
                                color: ll.inkLit
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durLong
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

                    }

                }

            }

        }

    }

    // a pause: three dots filling one after another
    Row {
        id: dots

        readonly property real d: Math.round(ll.px * 0.42)
        // a slow breath while the pause is on, and the dots let go of it at its end
        readonly property real breath: ll.when === 0 ? 1 + 0.07 * Math.sin(ll.pos * Math.PI * 1.6) : 1
        readonly property real leaving: ll.when === 0 ? Math.max(0, Math.min(1, (ll.gap - 0.9) / 0.1)) : 0

        visible: ll.pause && ll.synced
        anchors.verticalCenter: parent.verticalCenter
        x: ll.centred ? Math.round((ll.width - dots.implicitWidth) / 2) : Math.round(ll.px * 0.1)
        spacing: Math.round(ll.px * 0.3)
        scale: dots.breath * (1 - dots.leaving)
        transformOrigin: ll.centred ? Item.Center : Item.Left

        Repeater {
            model: 3

            delegate: Rectangle {
                id: dot

                required property int index
                readonly property real fill: Math.max(0, Math.min(1, ll.gap * 3 - dot.index))

                width: dots.d
                height: dots.d
                radius: dots.d / 2
                color: ll.when === 0 ? Qt.tint(ll.ink, Qt.rgba(ll.inkLit.r, ll.inkLit.g, ll.inkLit.b, dot.fill)) : ll.ink
                opacity: ll.when === 0 ? 0.45 + 0.55 * dot.fill : 0.5
                scale: ll.when === 0 ? 0.7 + 0.3 * dot.fill : 0.7

                Behavior on opacity {
                    enabled: ll.when !== 0

                    NumberAnimation {
                        duration: Theme.durMedium
                    }

                }

            }

        }

    }

}
