import "../lucidwidgets"
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs

// a layout drawn small: your wallpaper, the bar and dock, and the real widgets on it
ClippingRectangle {
    id: thumb

    property var cards: []
    property string wallpaper: ""

    readonly property var screenInfo: Monitors.mainScreen
    readonly property real screenW: thumb.screenInfo ? thumb.screenInfo.width : 1920
    readonly property real screenH: thumb.screenInfo ? thumb.screenInfo.height : 1080
    readonly property real fit: thumb.width / thumb.screenW

    implicitHeight: Math.round(thumb.width * thumb.screenH / thumb.screenW)
    radius: Theme.radiusMd
    color: Theme.bgSunken

    Image {
        anchors.fill: parent
        source: thumb.wallpaper !== "" ? "file://" + thumb.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        // every tile asks for the same size, so they share one decode
        sourceSize.width: 480
        sourceSize.height: 270
        opacity: status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

    }

    // built off the main thread, so the page opens at once and the cards drop in
    Loader {
        anchors.fill: parent
        asynchronous: true

        sourceComponent: Item {
            Repeater {
                model: thumb.cards

                WidgetPreview {
                    id: card

                    required property var modelData
                    readonly property real cw: card.modelData.bw * card.modelData.zoom * thumb.fit
                    readonly property real ch: card.modelData.bh * card.modelData.zoom * thumb.fit

                    x: Math.max(0, Math.min(thumb.width - card.cw, card.modelData.wx * thumb.fit))
                    y: Math.max(0, Math.min(thumb.height - card.ch, card.modelData.wy * thumb.fit))
                    width: card.cw
                    height: card.ch
                    wtype: card.modelData.type
                    wvariant: card.modelData.variant
                    bodyW: card.modelData.bw
                    bodyH: card.modelData.bh
                    // a full-width visualiser at fine detail is hundreds of bars under a pixel wide
                    opts: card.modelData.type === "visualiser" ? Object.assign({}, card.modelData.opts || {}, {
                        "density": "wide"
                    }) : (card.modelData.opts || ({}))
                }

            }

        }

    }

    // the bar's three islands and the dock, above the cards like the real thing
    Repeater {
        model: Prefs.barEnabled ? [[0.009, 0.212], [0.463, 0.074], [0.851, 0.14]] : []

        Rectangle {
            required property var modelData

            x: thumb.width * modelData[0]
            y: Prefs.effectiveBarTopMargin * thumb.fit
            width: thumb.width * modelData[1]
            height: Math.max(2, Prefs.barHeight * thumb.fit)
            radius: height / 2
            color: Theme.bgOpaque
        }

    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Prefs.effectiveDockBottomMargin * thumb.fit
        width: thumb.width * 0.22
        height: Math.max(3, (Prefs.dockIconSize + 20) * thumb.fit)
        radius: height * 0.3
        color: Theme.bgOpaque
        visible: Prefs.dockEnabled && !Prefs.dockAutoHide
    }

}
