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

}

