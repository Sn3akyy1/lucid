import QtQuick
import qs
import qs.lucidui
import "ClockMath.js" as CM

// an alarm going off while the window is open takes the whole of it: the time,
// what it is for, and two big answers. a reminder coming due gets a banner
Item {
    id: ov

    property var app: null
    readonly property var ring: ov.app && ov.app.ringing.length > 0 ? ov.app.ringing[0] : null
    readonly property var reminder: {
        if (!ov.app || ov.ring || ov.app.remindersRinging.length === 0)
            return null;

        const id = ov.app.remindersRinging[0];
        return ov.app.reminders.find((r) => {
            return r.id === id;
        }) || null;
    }
    property var lastRing: null

    onRingChanged: {
        if (ov.ring)
            ov.lastRing = ov.ring;

    }
    visible: ov.ring !== null || scrim.opacity > 0 || banner.y > -banner.height

    // ---- an alarm
    Rectangle {
        id: scrim

        anchors.fill: parent
        // nearly solid whatever the glass: a ring takes the whole window
        color: Theme.alpha(Theme.surfaceLowest, 0.95)
        opacity: ov.ring ? 1 : 0

        MouseArea {
            anchors.fill: parent
            enabled: ov.ring !== null
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: (w) => {
                return w.accepted = true;
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
            }

        }

    }

    Column {
        id: face

        readonly property var r: ov.ring || ov.lastRing || ({
            "hour": 0,
            "minute": 0,
            "label": ""
        })

        anchors.centerIn: parent
        spacing: Theme.dp(18)
        opacity: ov.ring ? 1 : 0
        scale: ov.ring ? 1 : 0.9

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(132)
            height: Theme.dp(132)

            MaterialShape {
                anchors.fill: parent
                shape: "cookie12"
                color: Theme.primaryContainer

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                    running: ov.ring !== null
                }

            }

            Icon {
                anchors.centerIn: parent
                name: "alarm"
                size: Theme.dp(60)
                fill: 1
                color: Theme.fgPrimaryContainer
                transformOrigin: Item.Top

                SequentialAnimation on rotation {
                    loops: Animation.Infinite
                    running: ov.ring !== null

                    NumberAnimation {
                        from: -14
                        to: 14
                        duration: 160
                        easing.type: Easing.InOutQuad
                    }

                    NumberAnimation {
                        from: 14
                        to: -14
                        duration: 160
                        easing.type: Easing.InOutQuad
                    }

                }

            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(8)

            LText {
                id: big

                size: Theme.fs(96)
                weight: 420
                rounded: 60
                tabular: true
                text: CM.hourText(face.r.hour, ov.app ? ov.app.h24 : false) + ":" + CM.pad(face.r.minute)
            }

            LText {
                visible: ov.app && !ov.app.h24
                anchors.baseline: big.baseline
                role: "headlineMedium"
                color: Theme.subtext
                text: face.r.hour < 12 ? "AM" : "PM"
            }

        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "headlineSmall"
            color: Theme.subtext
            text: (face.r.label !== "" ? face.r.label : "Alarm") + (ov.app && ov.app.ringing.length > 1 ? "  ·  " + (ov.app.ringing.length - 1) + " more ringing" : "")
        }

        Item {
            width: 1
            height: Theme.dp(18)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.dp(20)

            Rectangle {
                width: Theme.dp(168)
                height: Theme.dp(72)
                radius: height / 2
                color: Theme.secondaryContainer

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(8)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "snooze"
                        size: Theme.dp(26)
                        color: Theme.fgSecondaryContainer
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleMedium"
                        color: Theme.fgSecondaryContainer
                        text: "Snooze " + (ov.app ? ov.app.alarmState.snoozeMinutes : 10) + " min"
                    }

                }

                StateLayer {
                    radius: parent.radius
                    tint: Theme.fgSecondaryContainer
                    onClicked: {
                        if (ov.ring)
                            ov.app.send("alarm.snooze", {
                            "id": ov.ring.id
                        });

                    }
                }

            }

            Rectangle {
                width: Theme.dp(168)
                height: Theme.dp(72)
                radius: height / 2
                color: Theme.primary

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.dp(8)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "stop"
                        size: Theme.dp(26)
                        fill: 1
                        color: Theme.fgPrimary
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "titleMedium"
                        color: Theme.fgPrimary
                        text: "Stop"
                    }

                }

                StateLayer {
                    radius: parent.radius
                    tint: Theme.fgPrimary
                    onClicked: {
                        if (ov.ring)
                            ov.app.send("alarm.stop", {
                            "id": ov.ring.id
                        });

                    }
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durMedium
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

    // ---- a reminder: a banner that drops in from the top
    Rectangle {
        id: banner

        readonly property var r: ov.reminder

        anchors.horizontalCenter: parent.horizontalCenter
        y: ov.reminder ? Theme.dp(16) : -height - Theme.dp(8)
        width: Math.min(parent.width - Theme.dp(32), Theme.dp(560))
        height: Theme.dp(72)
        radius: Theme.shapeXl
        color: Theme.tertiaryContainer

        Icon {
            id: bell

            x: Theme.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            name: "notifications_active"
            size: Theme.dp(26)
            fill: 1
            color: Theme.fgTertiaryContainer
        }

        Column {
            anchors.left: bell.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: acts.left
            anchors.rightMargin: Theme.dp(10)
            anchors.verticalCenter: parent.verticalCenter

            LText {
                width: parent.width
                role: "titleMedium"
                color: Theme.fgTertiaryContainer
                elide: Text.ElideRight
                text: banner.r ? banner.r.name : ""
            }

            LText {
                role: "bodyMedium"
                color: Theme.alpha(Theme.fgTertiaryContainer, 0.8)
                text: banner.r && ov.app ? "Reminder · " + ov.app.time(banner.r.hour, banner.r.minute) : ""
            }

        }

        Row {
            id: acts

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(6)

            Button {
                variant: "text"
                icon: "snooze"
                text: "10 min"
                contentOverride: Theme.fgTertiaryContainer
                onClicked: {
                    if (banner.r)
                        ov.app.send("rem.snooze", {
                        "id": banner.r.id,
                        "minutes": 10
                    });

                }
            }

            Button {
                variant: "filled"
                icon: "check"
                text: "Done"
                onClicked: {
                    if (banner.r)
                        ov.app.send("rem.dismiss", {
                        "id": banner.r.id
                    });

                }
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
