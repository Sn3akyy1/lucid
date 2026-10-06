import QtQuick
import qs
import qs.lucidui

// one of a bar module's styles, on its card: a sample of how it looks on a
// strip of bar (or, for a panel style, a small panel), its name and a line
// on what sets it apart. picking it writes the module's style pref
Item {
    id: tile

    property string moduleId: ""
    property string prefKey: ""
    property var style: null
    // a panel style: the sample is a panel, not a strip of bar
    property bool panel: false

    readonly property string key: tile.style ? tile.style.key : ""
    readonly property bool picked: tile.prefKey !== "" && Prefs[tile.prefKey] === tile.key

    implicitWidth: Theme.dp(172)
    implicitHeight: tile.panel ? Theme.dp(196) : Theme.dp(144)

    Rectangle {
        id: shell

        anchors.fill: parent
        radius: Theme.radiusLg
        color: tile.picked ? Theme.accentContainer : (area.containsMouse ? Theme.bgHover : Theme.bgSunken)
        border.width: tile.picked ? 2 : 0
        border.color: Theme.accent
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
            // clear of the check in the corner
            anchors.topMargin: Theme.dp(32)
            height: tile.panel ? Theme.dp(104) : Theme.dp(52)
            clip: true

            // a strip of bar, the sample's own width, as the bar shows it
            Rectangle {
                visible: !tile.panel
                anchors.centerIn: parent
                width: Math.min(parent.width, sample.implicitWidth + Theme.dp(24))
                height: Math.min(Theme.dp(34), Theme.dp(Prefs.barHeight))
                radius: height / 2
                color: Theme.bg
            }

            BarStyleSample {
                id: sample

                anchors.centerIn: parent
                moduleId: tile.moduleId
                styleKey: tile.key
                panel: tile.panel
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
            text: tile.style ? tile.style.name : ""
            color: tile.picked ? Theme.fgAccentContainer : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
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
            text: tile.style ? tile.style.blurb : ""
            color: tile.picked ? Theme.fgAccentContainer : Theme.subtextDim
            opacity: tile.picked ? 0.8 : 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        // the one in use: a check in the top right corner, inside the border
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.dp(8)
            width: Theme.dp(20)
            height: Theme.dp(20)
            radius: height / 2
            color: Theme.accent
            opacity: tile.picked ? 1 : 0
            scale: tile.picked ? 1 : 0.6
            visible: opacity > 0.01

            Icon {
                anchors.centerIn: parent
                name: "check"
                size: Theme.dp(16)
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
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (tile.prefKey !== "" && tile.key !== "")
                Prefs[tile.prefKey] = tile.key;

        }
    }

}
