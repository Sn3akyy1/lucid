import QtQuick
import "../lucidwidgets"
import qs

Item {
    id: tile

    property string wtype: ""
    property var variant: null

    readonly property int placed: tile.variant ? Widgets.countOfVariant(tile.wtype, tile.variant.id) : 0

    signal summoned()

    implicitWidth: Theme.dp(178)
    implicitHeight: Theme.dp(180)

    opacity: Widgets.full ? 0.4 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        id: shell

        anchors.fill: parent
        radius: Theme.radiusLg
        color: area.containsMouse ? Theme.bgHover : Theme.bgSunken
        scale: area.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        Item {
            id: stage

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(10)
            height: Theme.dp(102)
            clip: true

            WidgetPreview {
                anchors.fill: parent
                wtype: tile.wtype
                wvariant: tile.variant ? tile.variant.id : ""
                hovered: area.containsMouse
                staggered: true
            }

        }

        Text {
            id: name

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: stage.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            anchors.topMargin: Theme.dp(8)
            text: tile.variant ? tile.variant.name : ""
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.variableAxes: Theme.axes(Theme.fontBody, 640, 0)
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: name.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            anchors.topMargin: 1
            text: tile.variant ? tile.variant.blurb : ""
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        // how many of this exact variant are already out there
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(8)
            width: Theme.dp(20)
            height: Theme.dp(20)
            radius: Theme.dp(10)
            color: Theme.accent
            opacity: tile.placed > 0 ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Text {
                anchors.centerIn: parent
                text: tile.placed
                color: Theme.fgAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.variableAxes: Theme.axes(Theme.fs(10), 640, 0)
                font.bold: true
            }

        }

        Rectangle {
            anchors.centerIn: stage
            width: Theme.dp(34)
            height: Theme.dp(34)
            radius: Theme.dp(17)
            color: Theme.accent
            opacity: area.containsMouse ? 1 : 0
            scale: area.containsMouse ? 1 : 0.7
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durEnter
                    easing.type: Theme.easeStandard
                }

            }

            WidgetGlyph {
                anchors.centerIn: parent
                name: "add"
                size: Theme.dp(20)
                color: Theme.fgAccent
            }

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: !Widgets.full
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Widgets.spawn(tile.wtype, tile.variant ? tile.variant.id : "");
            tile.summoned();
        }
    }

}
