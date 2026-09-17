import "../lucidwidgets"
import QtQuick
import qs

// one layout to pick: the desktop drawn small over its name
Item {
    id: tile

    property string title: ""
    property string blurb: ""
    property var cards: []
    property string wallpaper: ""
    property bool selected: false
    property bool removable: false
    // the mark shown on hover: "check" to put it on, "refresh" to go back to it
    property string mark: "check"

    readonly property bool hovered: area.containsMouse || removeArea.containsMouse

    signal chosen()
    signal removeRequested()

    implicitWidth: 240
    implicitHeight: thumb.height + 88

    Rectangle {
        id: shell

        anchors.fill: parent
        radius: Theme.radiusLg
        color: tile.selected ? Theme.accentContainer : (tile.hovered ? Theme.bgHover : Theme.bgSunken)
        scale: area.pressed && !tile.selected ? 0.97 : 1

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

        PresetThumb {
            id: thumb

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            height: thumb.implicitHeight
            cards: tile.cards
            wallpaper: tile.wallpaper
        }

        Text {
            id: name

            anchors.left: parent.left
            anchors.right: count.left
            anchors.top: thumb.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            anchors.topMargin: 10
            text: tile.title
            color: tile.selected ? Theme.fgAccentContainer : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            id: count

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.baseline: name.baseline
            text: tile.selected ? "In use" : (tile.cards.length + (tile.cards.length === 1 ? " widget" : " widgets"))
            color: tile.selected ? Theme.fgAccentContainer : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            font.bold: tile.selected
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: name.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 3
            height: 30
            text: tile.blurb
            color: tile.selected ? Theme.alpha(Theme.fgAccentContainer, 0.75) : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        // the promise of the click, over the preview
        Rectangle {
            anchors.centerIn: thumb
            width: 34
            height: 34
            radius: Theme.rad(17)
            color: Theme.accent
            opacity: area.containsMouse && !tile.selected ? 1 : 0
            scale: area.containsMouse && !tile.selected ? 1 : 0.7
            visible: opacity > 0.01

            WidgetGlyph {
                anchors.centerIn: parent
                name: tile.mark
                size: 20
                color: Theme.fgAccent
            }

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

        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: tile.selected ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (!tile.selected)
                tile.chosen();

        }
    }

    // only your own presets can go, and only from a corner of the preview
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        width: 28
        height: 28
        radius: Theme.rad(14)
        color: removeArea.containsMouse ? Theme.errorContainer : Theme.bgOpaque
        opacity: tile.removable && tile.hovered ? 1 : 0
        visible: opacity > 0.01

        WidgetGlyph {
            anchors.centerIn: parent
            name: "trash"
            size: 16
            color: removeArea.containsMouse ? Theme.fgErrorContainer : Theme.subtext
        }

        MouseArea {
            id: removeArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.removable
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.removeRequested()
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durQuick
            }

        }

    }

}
