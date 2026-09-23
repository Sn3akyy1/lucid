import QtQuick
import qs

Item {
    id: body

    // set by the frame once the loader is ready
    property var host: null
    // a variant that draws straight onto the wallpaper with no container behind it
    property bool bare: false
    // a body with nothing worth showing right now: the frame fades the whole card
    // out and it drops out of the input mask, so it stops catching clicks too
    property bool hidden: false

    readonly property string variant: body.host ? body.host.wvariant : ""
    readonly property string uid: body.host ? body.host.uid : ""
    readonly property bool hovered: body.host ? body.host.hovered : false
    // true inside a settings gallery tile: no polling, no network, sample content
    readonly property bool preview: body.host ? body.host.preview === true : false
    // true only for a card just placed, not one restored from disk
    readonly property bool born: body.host ? body.host.born === true : false
    // true while a grip is held, for bodies that would rather not rebuild mid-drag
    readonly property bool resizing: body.host ? body.host.resizing === true : false
    readonly property real pad: 20
    readonly property real corner: body.host ? body.host.bodyRadius : Theme.radiusXl
    readonly property bool editing: body.uid !== "" && Widgets.editUid === body.uid
    // the card's m3 container, and the ink that reads on it. "auto" is the
    // widget's own default: the ones that are mostly one big reading go tonal
    property string defaultTone: "surface"
    readonly property string tone: {
        var t = body.opt("tone");
        return (t === undefined || t === "auto" || t === "") ? body.defaultTone : t;
    }
    readonly property bool tonal: body.tone !== "surface"
    readonly property color toneFill: {
        switch (body.tone) {
        case "primary":
            return Theme.withBlur(Theme.primaryContainer);
        case "secondary":
            return Theme.withBlur(Theme.secondaryContainer);
        case "tertiary":
            return Theme.withBlur(Theme.tertiaryContainer);
        }
        return Theme.bg;
    }
    readonly property color toneInk: {
        switch (body.tone) {
        case "primary":
            return Theme.fgPrimaryContainer;
        case "secondary":
            return Theme.fgSecondaryContainer;
        case "tertiary":
            return Theme.fgTertiaryContainer;
        }
        return Theme.text;
    }
    readonly property color toneInkAccent: {
        switch (body.tone) {
        case "primary":
            return Theme.primary;
        case "secondary":
            return Theme.secondary;
        case "tertiary":
            return Theme.tertiary;
        }
        return Theme.accent;
    }
    // what sits on an inkAccent fill
    readonly property color toneOnInkAccent: {
        switch (body.tone) {
        case "primary":
            return Theme.fgPrimary;
        case "secondary":
            return Theme.fgSecondary;
        case "tertiary":
            return Theme.fgTertiary;
        }
        return Theme.fgAccent;
    }

    function beginEdit() {
        Widgets.editUid = body.uid;
    }

    function endEdit() {
        if (Widgets.editUid === body.uid)
            Widgets.editUid = "";

    }

    function opt(key) {
        return body.host ? body.host.opt(key) : undefined;
    }

    function setOpt(key, value) {
        if (body.host)
            body.host.setOpt(key, value);

    }

    function pct(v) {
        return Math.round(Math.max(0, Math.min(100, v))) + "%";
    }

    // what the card and its contents are drawn in. a body can bind its own over
    // these, the way the media card follows its cover
    property color fill: body.toneFill
    property color ink: body.toneInk
    property color inkAccent: body.toneInkAccent
    property color onInkAccent: body.toneOnInkAccent
    property bool ownInk: false
    readonly property color inkDim: body.tonal || body.ownInk ? Theme.alpha(body.ink, 0.78) : Theme.subtext
    readonly property color inkFaint: body.tonal || body.ownInk ? Theme.alpha(body.ink, 0.56) : Theme.subtextDim

}
