import QtQuick
import qs

// m3 chip. "filter" grows a check when selected; "assist" and "input" carry an icon
Item {
    id: chip

    // "filter" | "assist" | "input" | "suggestion"
    property string kind: "filter"
    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool closable: false
    property bool disabled: false

    signal clicked()
    signal closeClicked()

    readonly property bool showLead: (chip.kind === "filter" && chip.selected) || chip.icon !== ""
    readonly property color content: chip.selected ? Theme.fgSecondaryContainer : (chip.kind === "assist" ? Theme.text : Theme.subtext)

    implicitHeight: 30
    implicitWidth: row.implicitWidth + (chip.showLead ? 10 : 14) + (chip.closable ? 8 : 14)
    opacity: chip.disabled ? Theme.disabledContent : 1

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.durFastSpatial
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: chip.selected ? Theme.secondaryContainer : "transparent"
        border.width: chip.selected ? 0 : 1
        border.color: Theme.outline

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        StateLayer {
            radius: 8
            tint: chip.content
            disabled: chip.disabled
            onClicked: chip.clicked()
        }

    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: chip.showLead ? 8 : 14
        spacing: 6

        Icon {
            visible: chip.showLead
            anchors.verticalCenter: parent.verticalCenter
            name: chip.kind === "filter" && chip.selected ? "check" : chip.icon
            size: 17
            color: chip.selected ? Theme.fgSecondaryContainer : Theme.primary
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "labelLarge"
            text: chip.text
            color: chip.content
        }

        Icon {
            visible: chip.closable
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: 16
            color: chip.content

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: chip.closeClicked()
            }

        }

    }

}
