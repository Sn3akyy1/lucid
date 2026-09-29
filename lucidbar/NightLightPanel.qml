import QtQuick
import qs

// the night light sub-view: how warm, and when it comes on by itself
Item {
    id: root

    signal settingsRequested()

    // roughly the colour of a light at k kelvin, for painting the track
    function kelvinColor(k) {
        const t = k / 100;
        let r = 255;
        let g = 0;
        let b = 255;
        if (t <= 66) {
            g = 99.4708025861 * Math.log(t) - 161.1195681661;
            b = t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        } else {
            r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
            g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        }
        const c = (v) => {
            return Math.max(0, Math.min(255, v)) / 255;
        };
        return Qt.rgba(c(r), c(g), c(b), 1);
    }

    readonly property var schedules: [{
        "key": "off",
        "name": "By hand",
        "desc": "Only when you turn it on"
    }, {
        "key": "sun",
        "name": "Sunset to sunrise",
        "desc": NightLight.sun.polar ? "No sunset where you are today, so 9 pm to 7 am" : NightLight.clock(NightLight.sun.set) + " to " + NightLight.clock(NightLight.sun.rise) + (Loc.place !== "" ? " in " + Loc.place : "")
    }, {
        "key": "custom",
        "name": "Set hours",
        "desc": NightLight.clock(Prefs.nightLightFrom) + " to " + NightLight.clock(Prefs.nightLightTo)
    }]

    implicitHeight: col.implicitHeight

    Column {
        id: col

        width: root.width
        spacing: 12

        Text {
            width: col.width
            leftPadding: 4
            rightPadding: 4
            text: NightLight.available ? NightLight.status + (NightLight.active ? "  ·  " + NightLight.temperature + " K" : "") : "hyprsunset is not installed, so the screen can't be warmed."
            color: NightLight.available ? (NightLight.active ? Theme.accent : Theme.subtext) : Theme.warning
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(11)
            wrapMode: Text.WordWrap
        }

        // cooler to the left, warmer to the right, as the labels under it say
        Item {
            id: warmth

            readonly property real pos: (NightLight.maxTemp - NightLight.temperature) / (NightLight.maxTemp - NightLight.minTemp)

            function setAt(px) {
                const f = Math.max(0, Math.min(1, px / warmth.width));
                const k = NightLight.maxTemp - f * (NightLight.maxTemp - NightLight.minTemp);
                Prefs.nightLightTemp = Math.round(k / 100) * 100;
            }

            width: col.width
            height: 34

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 14
                radius: 7
                opacity: NightLight.active ? 1 : 0.55

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: root.kelvinColor(NightLight.maxTemp)
                    }

                    GradientStop {
                        position: 1
                        color: root.kelvinColor(NightLight.minTemp)
                    }

                }

            }

            Rectangle {
                x: Math.max(0, Math.min(warmth.width - width, warmth.pos * warmth.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 28
                radius: 3
                color: Theme.text
                border.width: 2
                border.color: Theme.bgOpaque
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                preventStealing: true
                onPressed: (mouse) => {
                    return warmth.setAt(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        warmth.setAt(mouse.x);

                }
            }

        }

        Item {
            width: col.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 4
                text: "Cooler"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 4
                text: "Warmer"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
            }

        }

        Column {
            width: col.width
            spacing: 4

            Repeater {
                model: root.schedules

                Rectangle {
                    id: option

                    required property var modelData
                    readonly property bool selected: Prefs.nightLightSchedule === option.modelData.key

                    width: col.width
                    height: 46
                    radius: 12
                    color: option.selected ? Theme.withBlur(Theme.bgActive) : (optionArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: radio.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: option.modelData.name
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: option.modelData.desc
                            color: option.selected ? Theme.accent : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            elide: Text.ElideRight
                        }

                    }

                    Rectangle {
                        id: radio

                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent"
                        border.width: 2
                        border.color: option.selected ? Theme.accent : Theme.outlineStrong

                        Rectangle {
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: Theme.accent
                            scale: option.selected ? 1 : 0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barMs(180)
                                    easing.type: Easing.OutBack
                                }

                            }

                        }

                    }

                    MouseArea {
                        id: optionArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Prefs.nightLightSchedule = option.modelData.key
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barMs(150)
                        }

                    }

                }

            }

        }

        Text {
            width: col.width
            leftPadding: 4
            rightPadding: 4
            text: "Hours and more in Settings"
            color: settingsArea.containsMouse ? Theme.accent : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            font.underline: settingsArea.containsMouse

            MouseArea {
                id: settingsArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingsRequested()
            }

        }

    }

}
