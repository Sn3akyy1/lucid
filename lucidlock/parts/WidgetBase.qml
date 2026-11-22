import QtQuick

// what every lock widget is handed by the slot it sits in. the theme and the
// data come in as objects, so the same file draws on the lock and on the
// login screen, each with its own
Item {
    id: w

    property var theme: null
    property var lock: null
    // this widget's options, every key resolved: style, size and the rest
    property var opts: ({})
    // which edge of its slot the widget leans on
    property int align: Qt.AlignLeft
    // the room the slot has across, and down
    property real avail: 480
    property real availH: 2000
    property real screenH: 1080
    // 0 resting, 1 while a password is being typed
    property real focusK: 0
    // how far a hero shrinks while typing, 1 for not at all
    property real shrinkTo: 1
    // the slot draws every widget on a card of its own; tonal when that card
    // is the accent's container rather than a plain surface
    property bool carded: false
    property bool tonal: false
    // the slot sits on a surface of the preset's own (the panel's sheet): the
    // widget's own fills step a tone up, or they would vanish into it
    property bool onCard: false
    property bool greeter: false
    property bool preview: false
    property bool editing: false
    // whether it has anything to show. the slot folds a widget that has not
    readonly property bool shown: w.hasContent
    property bool hasContent: true
    // the size option as a multiplier, for anything that is not the clock
    readonly property real k: {
        var s = w.opts ? w.opts.size : "M";
        return ({
            "S": 0.86,
            "M": 1,
            "L": 1.16,
            "XL": 1.32
        })[s] || 1;
    }
    readonly property int hAlign: w.align === Qt.AlignHCenter ? Text.AlignHCenter : (w.align === Qt.AlignRight ? Text.AlignRight : Text.AlignLeft)

    function dp(px) {
        return w.theme ? w.theme.dp(px) : px;
    }

    // a size times the widget's own size option
    function kp(px) {
        return Math.round(w.dp(px) * w.k);
    }

    // where a child of this width sits across the widget
    function xFor(childW, boxW) {
        if (w.align === Qt.AlignHCenter)
            return Math.round((boxW - childW) / 2);

        if (w.align === Qt.AlignRight)
            return Math.round(boxW - childW);

        return 0;
    }
}
