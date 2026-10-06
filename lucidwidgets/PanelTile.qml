import QtQuick
import qs
import qs.lucidui

// one face of a widget in the panel's gallery, drawn live. a click puts it on the
// desktop in the first free spot; a drag carries it out to wherever it is let go
Item {
    id: tile

    property Item panel: null
    property string wtype: ""
    property var variant: null

    readonly property string variantId: tile.variant ? tile.variant.id : ""
    readonly property int placed: tile.variant ? Widgets.countOfVariant(tile.wtype, tile.variantId) : 0
    readonly property bool carrying: area.carrying

    // the preview's card as drawn, in the panel's coordinates, so the ghost starts on top of it
    function previewRect() {
        var w = preview.natW * preview.fit;
        var h = preview.natH * preview.fit;
        var c = preview.mapToItem(tile.panel, preview.width / 2, preview.height / 2);
        return ({
            "x": c.x - w / 2,
            "y": c.y - h / 2,
            "w": w,
            "h": h
        });
    }

    implicitWidth: Theme.dp(196)
    implicitHeight: Theme.dp(178)
    opacity: Widgets.full ? 0.4 : (tile.carrying ? 0.5 : 1)
    Component.onDestruction: {
        if (area.carrying && tile.panel)
            tile.panel.abandon();

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        id: shell

        anchors.fill: parent
        radius: Theme.radiusLg
        color: area.containsMouse && !Widgets.full ? Theme.withBlur(Theme.surfaceHighest) : Theme.withBlur(Theme.surfaceHigh)
        scale: area.pressed && !area.carrying ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

        Item {
            id: stage

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(10)
            height: Theme.dp(106)

            WidgetPreview {
                id: preview

                anchors.fill: parent
                wtype: tile.wtype
                wvariant: tile.variantId
                hovered: area.containsMouse
                staggered: true
            }

        }

        LText {
            id: name

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: stage.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            anchors.topMargin: Theme.dp(8)
            role: "titleSmall"
            text: tile.variant ? tile.variant.name : ""
            elide: Text.ElideRight
        }

        LText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: name.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            anchors.topMargin: Theme.dp(2)
            role: "bodySmall"
            color: Theme.subtext
            text: tile.variant ? tile.variant.blurb : ""
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            verticalAlignment: Text.AlignTop
        }

        // how many of this exact face are already out there
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(8)
            width: Math.max(Theme.dp(20), placedLabel.implicitWidth + Theme.dp(10))
            height: Theme.dp(20)
            radius: Theme.dp(10)
            color: Theme.primary
            opacity: tile.placed > 0 ? 1 : 0
            visible: opacity > 0.01

            LText {
                id: placedLabel

                anchors.centerIn: parent
                role: "labelSmall"
                color: Theme.fgPrimary
                text: tile.placed
                tabular: true
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    MouseArea {
        id: area

        property real pressX: 0
        property real pressY: 0
        property bool carrying: false

        anchors.fill: parent
        hoverEnabled: true
        enabled: !Widgets.full && tile.panel !== null
        // the gallery scrolls under a drag otherwise, and the card never leaves it
        preventStealing: true
        cursorShape: area.carrying ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            area.pressX = mouse.x;
            area.pressY = mouse.y;
            area.carrying = false;
        }
        onPositionChanged: (mouse) => {
            if (!area.pressed)
                return ;

            if (!area.carrying) {
                if (Math.abs(mouse.x - area.pressX) < 6 && Math.abs(mouse.y - area.pressY) < 6)
                    return ;

                area.carrying = true;
                tile.panel.pickUp(tile.wtype, tile.variantId, area.mapToItem(tile.panel, area.pressX, area.pressY), tile.previewRect());
            }
            var p = area.mapToItem(tile.panel, mouse.x, mouse.y);
            tile.panel.carry(p.x, p.y);
        }
        onReleased: {
            if (area.carrying)
                tile.panel.drop();
            else
                tile.panel.addCard(tile.wtype, tile.variantId);
            area.carrying = false;
        }
        onCanceled: {
            if (area.carrying)
                tile.panel.abandon();

            area.carrying = false;
        }
    }

}
