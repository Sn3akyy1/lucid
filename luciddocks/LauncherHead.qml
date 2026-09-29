import QtQuick
import qs
import qs.lucidprefs as LP
import qs.lucidui

// the launcher's head: the mark it grew out of, the modes as an m3 expressive
// navigation set — every mode an icon, the live one opening into a labelled
// accent pill — and, on the trailing edge, what the results add up to
Item {
    id: head

    property var modes: []
    property string current: "apps"
    property string countLabel: ""
    readonly property real cs: Prefs.launcherScale
    readonly property int pill: Math.round(34 * head.cs)
    readonly property int glyph: Math.round(20 * head.cs)
    readonly property int gap: Math.round(4 * head.cs)

    // bumped by the face when the panel opens, so the set assembles rather
    // than simply being there
    property int entrance: 0

    signal chosen(string key)
    signal homeRequested()

    function playEntrance() {
        head.entrance++;
    }

    implicitHeight: Prefs.launcherHeadH

    // the dock's launcher button, again, at the corner the panel grew from.
    // tapping it drops whatever mode is on and goes back to the apps
    Item {
        id: mark

        // centred over the leading slot the results below it line up on
        x: Math.max(0, Prefs.launcherEdgeSpace + Math.round(Prefs.launcherLeadSlot / 2) - Math.round(head.pill / 2))
        width: head.pill
        height: head.pill
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.text
            opacity: markTap.pressed ? Theme.statePressed : (markHover.hovered ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        LP.LucidaMark {
            anchors.centerIn: parent
            width: Math.round(head.pill * 0.8)
            height: Math.round(head.pill * 0.8)
            strokeWidth: 2.4
            // the mark leans on the accent while a mode is on, so the way back reads
            starColor: head.current === "apps" ? Theme.text : Theme.accent
            scale: markTap.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durFastSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

        }

        HoverHandler {
            id: markHover
        }

        TapHandler {
            id: markTap

            onTapped: head.homeRequested()
        }

    }

    Row {
        id: modeRow

        anchors.left: mark.right
        anchors.leftMargin: Math.round(10 * head.cs)
        anchors.verticalCenter: parent.verticalCenter
        spacing: head.gap

        Repeater {
            model: head.modes

            Item {
                id: entry

                required property var modelData
                readonly property bool on: head.current === entry.modelData.key
                readonly property color content: entry.on ? Theme.fgAccent : Theme.subtext

                required property int index

                width: entry.on ? Math.round(12 * head.cs) + head.glyph + Math.round(7 * head.cs) + label.implicitWidth + Math.round(14 * head.cs) : head.pill
                height: head.pill
                transformOrigin: Item.Center

                Connections {
                    target: head

                    function onEntranceChanged() {
                        arrive.restart();
                    }

                }

                SequentialAnimation {
                    id: arrive

                    PauseAnimation {
                        duration: Theme.ms(30 + entry.index * 34)
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: entry
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.durEnter
                        }

                        NumberAnimation {
                            target: entry
                            property: "scale"
                            from: 0.6
                            to: 1
                            duration: Theme.durEnter
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.shapeFull
                    color: entry.on ? Theme.accent : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durDefaultEffects
                        }

                    }

                    StateLayer {
                        radius: Theme.shapeFull
                        tint: entry.content
                        onClicked: head.chosen(entry.modelData.key)
                    }

                }

                Icon {
                    id: sym

                    x: entry.on ? Math.round(12 * head.cs) : Math.round((entry.width - head.glyph) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    name: entry.modelData.icon
                    size: head.glyph
                    fill: entry.on ? 1 : 0
                    color: entry.content

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

                LText {
                    id: label

                    anchors.left: sym.right
                    anchors.leftMargin: Math.round(7 * head.cs)
                    anchors.verticalCenter: parent.verticalCenter
                    role: "labelLarge"
                    size: Math.round(Theme.typeSize("labelLarge") * head.cs)
                    text: entry.modelData.label
                    color: entry.content
                    opacity: entry.on ? 1 : 0
                    visible: label.opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durFastEffects
                        }

                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }

            }

        }

    }

    LText {
        anchors.right: parent.right
        anchors.rightMargin: Math.round(6 * head.cs)
        anchors.verticalCenter: parent.verticalCenter
        role: "labelSmall"
        size: Math.round(Theme.typeSize("labelSmall") * head.cs)
        text: head.countLabel
        color: Theme.subtextDim
        visible: head.countLabel !== ""
        opacity: head.countLabel !== "" ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFastEffects
            }

        }

    }

}
