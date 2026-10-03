import QtQuick
import qs

// the glanceable half of a status bar, for a screen that has no bar. one
// connected group: round at its two ends, tight joins in between
Row {
    id: chips

    readonly property bool btShown: !!Lockscreen.btAdapter
    readonly property bool dndShown: Notifs.dnd

    spacing: 3

    component Chip: Rectangle {
        id: chip

        property string glyph: ""
        property string label: ""
        property color tone: Theme.subtext
        // which ends of the group this chip closes
        property bool lead: false
        property bool tail: false

        height: 40
        width: content.implicitWidth + 32
        color: Lockscreen.card
        topLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        bottomLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        topRightRadius: chip.tail ? height / 2 : Theme.shapeSm
        bottomRightRadius: chip.tail ? height / 2 : Theme.shapeSm

        Row {
            id: content

            anchors.centerIn: parent
            spacing: 9

            LockGlyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyph
                size: 18
                color: chip.tone
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
            }

        }

    }

    Chip {
        visible: Lockscreen.hasBattery
        lead: true
        // the battery symbol that matches the level, in eighths like the bar's
        glyph: {
            if (Lockscreen.charging)
                return "battery_charging_full";

            const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
            return steps[Math.max(0, Math.min(7, Math.floor(Lockscreen.batteryPercent / 100 * 8)))];
        }
        label: Lockscreen.batteryPercent + "%"
        tone: Lockscreen.batteryLow ? Theme.error : (Lockscreen.charging ? Theme.success : Theme.subtext)
    }

    Chip {
        lead: !Lockscreen.hasBattery
        tail: !chips.btShown && !chips.dndShown
        glyph: Lockscreen.netGlyph
        label: Lockscreen.netLabel
        tone: (Lockscreen.ethernet || Lockscreen.wifiUp) ? Theme.accent : Theme.subtextDim
    }

    Chip {
        tail: !chips.dndShown
        glyph: Lockscreen.btOn ? "bluetooth" : "bluetoothOff"
        label: Lockscreen.btLabel
        tone: Lockscreen.btDevices.length > 0 ? Theme.accent : Theme.subtextDim
        visible: chips.btShown
    }

    Chip {
        tail: true
        glyph: "bellOff"
        label: "Do not disturb"
        tone: Theme.warning
        visible: chips.dndShown
    }

}
