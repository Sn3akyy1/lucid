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
    readonly property int activeIndex: {
        for (var i = 0; i < head.modes.length; i++) {
            if (head.modes[i].key === head.current)
                return i;

        }
        return -1;
    }
    readonly property Item activeEntry: {
        modeRep.count;
        return head.activeIndex >= 0 ? modeRep.itemAt(head.activeIndex) : null;
    }

    // premultiplied, as the results blend theirs: a straight blend toward a
    // translucent colour passes through one brighter than either end
    function mix(a, b, t) {
        var wa = a.a * (1 - t);
        var wb = b.a * t;
        var al = wa + wb;
        if (al <= 0)
            return Qt.rgba(0, 0, 0, 0);

        return Qt.rgba((a.r * wa + b.r * wb) / al, (a.g * wa + b.g * wb) / al, (a.b * wa + b.b * wb) / al, al);
    }

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

    // one accent shape that slides to the mode, as the results' pill slides to
    // a row, rather than one pill fading out while the next fades in. it is
    // aimed at where the mode will sit once the widths settle, on the widths'
    // own curve, so the two arrive together
    Rectangle {
        id: indicator

        property real slot: Math.max(0, head.activeIndex) * (head.pill + head.gap)
        property real span: head.activeEntry ? head.activeEntry.fullWidth : head.pill

        x: modeRow.x + indicator.slot
        y: modeRow.y
        width: indicator.span
        height: head.pill
        radius: Theme.shapeFull
        color: Theme.accent
        visible: head.activeEntry !== null
        // it arrives with its mode as the set assembles
        opacity: head.activeEntry ? head.activeEntry.opacity : 0
        scale: head.activeEntry ? head.activeEntry.scale : 1

        // a panel opening on another mode starts with it there, not on its way
        Behavior on slot {
            enabled: head.visible

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on span {
            enabled: head.visible

            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    Row {
        id: modeRow

        anchors.left: mark.right
        anchors.leftMargin: Math.round(10 * head.cs)
        anchors.verticalCenter: parent.verticalCenter
        spacing: head.gap

        Repeater {
            id: modeRep

            model: head.modes

            Item {
                id: entry

                required property var modelData
                readonly property bool on: head.current === entry.modelData.key
                readonly property int fullWidth: Math.round(12 * head.cs) + head.glyph + Math.round(7 * head.cs) + label.implicitWidth + Math.round(14 * head.cs)
                // how much of the indicator is over this entry this frame
                readonly property real lit: {
                    if (!indicator.visible)
                        return 0;

                    var left = indicator.x - modeRow.x;
                    var under = Math.min(left + indicator.width, entry.x + entry.width) - Math.max(left, entry.x);
                    return Math.max(0, Math.min(1, under / Math.max(1, entry.width)));
                }
                readonly property color content: head.mix(Theme.subtext, Theme.fgAccent, entry.lit)

                required property int index

                width: entry.on ? entry.fullWidth : head.pill
                height: head.pill
                transformOrigin: Item.Center
                // the label is uncovered as the entry opens, never laid over the next icon
                clip: true

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

                // the fill is the indicator's; this only answers the pointer
                StateLayer {
                    anchors.fill: parent
                    radius: Theme.shapeFull
                    tint: entry.content
                    onClicked: head.chosen(entry.modelData.key)
                }

                Icon {
                    id: sym

                    x: entry.on ? Math.round(12 * head.cs) : Math.round((entry.width - head.glyph) / 2)
                    anchors.verticalCenter: parent.verticalCenter
                    name: entry.modelData.icon
                    size: head.glyph
                    fill: entry.lit > 0.5 ? 1 : 0
                    color: entry.content
                    animateColor: false

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
                    // shown as the indicator settles over it, so the name comes and
                    // goes with the accent rather than on a clock of its own
                    opacity: Math.max(0, entry.lit * 2 - 1)
                    visible: label.opacity > 0.01
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
