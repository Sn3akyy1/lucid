import QtQuick
import qs
import qs.lucidui as UI

Rectangle {
    id: preview

    // a stand-in app icon, half size, with the dock's running mark under it
    component Glyph: Item {
        id: glyph

        property real size: 0
        property bool strong: false
        property bool swell: false
        // 0 none, 1 a running dot, 2 the focused window's bar
        property int mark: 0

        width: glyph.size
        height: glyph.size

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(1, Prefs.dockIconInset * 0.5)
            radius: Math.min(Math.max(1, (Prefs.dockItemRadius - Prefs.dockIconInset) * 0.5), width / 2)
            scale: glyph.swell ? 1.35 : 1
            color: Theme.alpha(Theme.text, glyph.strong ? 0.5 : 0.28)

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeEmphasized
                    easing.overshoot: Theme.emphasizedOvershoot
                }

            }

        }

        Rectangle {
            width: glyph.mark === 2 ? Theme.dp(9) : Theme.dp(3)
            height: Theme.dp(3)
            radius: 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -Theme.dp(3)
            visible: Prefs.dockShowIndicators && glyph.mark > 0
            color: Theme.accent
        }

    }

    radius: Theme.radiusMd
    color: Theme.bgSunken
    clip: true
    implicitHeight: Theme.dp(116)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.dp(10)
        radius: Theme.radiusXs
        color: Theme.alpha(Theme.accent, 0.10)
        clip: true

        Item {
            id: bar

            readonly property real scaleFactor: 0.5
            readonly property real slot: Math.max(Theme.dp(6), Prefs.dockIconSize * bar.scaleFactor)
            readonly property real pad: Theme.dp(5)
            readonly property real gap: Math.max(Theme.dp(2), Prefs.dockSplitGap * bar.scaleFactor)
            readonly property real rad: Math.min(Prefs.dockRadius * bar.scaleFactor, bar.height / 2)
            // 0 as one slab, 1 as islands, which spring apart as Split is picked
            property real splitT: Prefs.dockSplit ? 1 : 0
            readonly property var groups: [launcherGroup, pinnedGroup, runningGroup]

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Prefs.dockNotch ? 0 : Math.max(Theme.dp(2), Prefs.dockBottomMargin * bar.scaleFactor * 0.5)
            width: icons.width + bar.pad * 2
            height: bar.slot + bar.pad * 2

            Behavior on splitT {
                NumberAnimation {
                    duration: Theme.durDefaultSpatial
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveDefaultSpatial
                }

            }

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Theme.easeStandard
                }

            }

            Rectangle {
                anchors.fill: parent
                visible: bar.splitT < 0.001
                color: Theme.bgOpaque
                radius: bar.rad
                bottomLeftRadius: Prefs.dockNotch ? 0 : bar.rad
                bottomRightRadius: Prefs.dockNotch ? 0 : bar.rad
            }

            // each group's island, spread over the slab until they part
            Repeater {
                model: 3

                Rectangle {
                    id: isle

                    required property int index
                    readonly property Item group: bar.groups[isle.index]
                    readonly property real restL: icons.x + isle.group.x - bar.pad
                    readonly property real restR: icons.x + isle.group.x + isle.group.width + bar.pad
                    readonly property real meetL: isle.index === 0 ? 0 : (icons.x + bar.groups[isle.index - 1].x + bar.groups[isle.index - 1].width + bar.pad + isle.restL) / 2
                    readonly property real meetR: isle.index === 2 ? bar.width : (isle.restR + icons.x + bar.groups[isle.index + 1].x - bar.pad) / 2
                    readonly property real inner: bar.rad * bar.splitT

                    visible: bar.splitT >= 0.001
                    x: isle.meetL + (isle.restL - isle.meetL) * bar.splitT
                    width: isle.meetR + (isle.restR - isle.meetR) * bar.splitT - isle.x
                    height: bar.height
                    color: Theme.bgOpaque
                    topLeftRadius: Math.min(isle.index === 0 ? bar.rad : isle.inner, isle.width / 2, isle.height / 2)
                    bottomLeftRadius: isle.topLeftRadius
                    topRightRadius: Math.min(isle.index === 2 ? bar.rad : isle.inner, isle.width / 2, isle.height / 2)
                    bottomRightRadius: isle.topRightRadius
                }

            }

            Row {
                id: icons

                anchors.centerIn: parent
                spacing: bar.pad

                Item {
                    id: launcherGroup

                    width: bar.slot
                    height: bar.slot

                    UI.LauncherGrid {
                        anchors.centerIn: parent
                        width: Math.round(bar.slot * 0.72)
                        height: width
                    }

                }

                // a divider on one slab, the gap between islands once split
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1 + (bar.gap - 1) * Math.max(0, bar.splitT)
                    height: Math.round(bar.slot * 0.5)
                    color: Theme.outline
                    opacity: 1 - Math.min(1, bar.splitT)
                }

                Row {
                    id: pinnedGroup

                    spacing: Math.max(1, Prefs.dockSpacing * bar.scaleFactor)

                    Repeater {
                        model: 4

                        Glyph {
                            required property int index

                            size: bar.slot
                            strong: index === 2
                            swell: Prefs.dockMagnify && index === 2
                            mark: index === 2 ? 2 : (index === 1 ? 1 : 0)
                        }

                    }

                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1 + (bar.gap - 1) * Math.max(0, bar.splitT)
                    height: Math.round(bar.slot * 0.5)
                    color: Theme.outline
                    opacity: 1 - Math.min(1, bar.splitT)
                }

                Row {
                    id: runningGroup

                    Glyph {
                        size: bar.slot
                        mark: 1
                    }

                }

            }

        }

    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(16)
        anchors.top: parent.top
        anchors.topMargin: Theme.dp(10)
        text: (Prefs.dockSplit ? "Split" : (Prefs.dockNotch ? "Notch" : "Island")) + (Prefs.dockAutoHide ? (Prefs.dockDynamicHide ? " · dynamic hiding" : " · auto-hide") : "")
        color: Theme.subtextDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabel
        font.variableAxes: Theme.axes(Theme.fontLabel, 420, 0)
    }

}
