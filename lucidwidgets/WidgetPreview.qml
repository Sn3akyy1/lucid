import QtQuick
import qs

Item {
    id: pv

    property string wtype: ""
    property string wvariant: ""
    property bool live: true
    property bool hovered: false
    // a card that owns its size, such as a stretched visualiser, draws at that size
    property real bodyW: 0
    property real bodyH: 0
    property var opts: ({})

    readonly property var info: Widgets.variantAt(pv.wtype, pv.wvariant)
    readonly property real natW: pv.bodyW > 0 ? pv.bodyW : (pv.info ? pv.info.w : 200)
    readonly property real natH: pv.bodyH > 0 ? pv.bodyH : (pv.info ? pv.info.h : 200)
    readonly property real fit: Math.min(pv.width / pv.natW, pv.height / pv.natH, 1)
    readonly property bool bare: card.item !== null && card.item.bare === true

    clip: true

    PreviewHost {
        id: host

        wtype: pv.wtype
        wvariant: pv.wvariant
        hovered: pv.hovered
        opts: pv.opts
    }

    Rectangle {
        anchors.centerIn: parent
        width: pv.natW
        height: pv.natH
        scale: pv.fit
        radius: Theme.radiusXl
        color: pv.bare ? "transparent" : Theme.bgOpaque
        clip: true
        enabled: false

        Loader {
            id: card

            anchors.fill: parent
            active: pv.live && pv.wtype !== ""
            source: pv.wtype === "" ? "" : pv.wtype.charAt(0).toUpperCase() + pv.wtype.slice(1) + "Widget.qml"
        }

        Binding {
            target: card.item
            property: "host"
            value: host
            when: card.status === Loader.Ready
        }

    }

}
