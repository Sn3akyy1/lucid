import QtQuick
import qs

Item {
    id: body

    // set by the frame once the loader is ready
    property var host: null
    // a variant that draws straight onto the wallpaper with no container behind it
    property bool bare: false

    readonly property string variant: body.host ? body.host.wvariant : ""
    readonly property string uid: body.host ? body.host.uid : ""
    readonly property bool hovered: body.host ? body.host.hovered : false
    // true inside a settings gallery tile: no polling, no network, sample content
    readonly property bool preview: body.host ? body.host.preview === true : false
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

