import QtQuick
import Quickshell.Hyprland._FocusGrab
import qs

Item {
    id: pill

    property var hostWindow: null
    property bool shown: true
    property bool expanded: false
    property bool altOpen: false
    property int compactWidth: 0
    property int compactHeight: Theme.dp(Prefs.barHeight)
    property int panelWidth: Theme.dp(320)
    property int panelHeight: Theme.dp(200)
    property int altWidth: 0
    property int altHeight: 0
    property int expandedRadius: Theme.radiusLg
    // how far the compact face shrinks as the panel opens
    property real compactCollapseScale: 0.82
    property bool compactInteractive: true
    property bool focusGrabs: true
    property bool panelFades: true
    property bool surfaceLayered: false

    signal compactClicked()

    property alias compactContent: compactHolder.data
    property alias altContent: altHolder.data
    property alias panelContent: panelHolder.data
    property alias overlayContent: overlayHolder.data
    property bool overlayOpen: false
    property Item overlayItem: null

    readonly property int morphDuration: Theme.barDurEnter
    readonly property var morphEasing: Theme.easeEmphasizedDecel

    // the id the bar knows this pill by
    function moduleId() {
        const map = pill.hostWindow && pill.hostWindow.moduleById ? pill.hostWindow.moduleById : {};
        for (const id in map) {
            if (map[id] === pill)
                return id;

        }
        return "";
    }

    function beginTransition() {
        panelTransitionTimer.restart();
    }

    readonly property bool anyOpen: pill.expanded || pill.altOpen

    property int panelFadePause: 0
    property int panelFadeDuration: Theme.barMs(220)
    property int compactFadePause: 0
    property int compactFadeDuration: Theme.barMs(220)

    function syncFadeTimings() {
        var open = pill.expanded || pill.altOpen;
        pill.panelFadePause = Theme.barMs(pill.expanded ? 150 : 0);
        pill.panelFadeDuration = Theme.barMs(pill.expanded ? 220 : 150);
        pill.compactFadePause = Theme.barMs(open ? 0 : 150);
        pill.compactFadeDuration = Theme.barMs(open ? 150 : 220);
    }

    onExpandedChanged: pill.syncFadeTimings()
    onAltOpenChanged: pill.syncFadeTimings()
    property bool compactHovered: false
    property bool panelTransitioning: false

    // joined to a neighbour in Settings > Bar: the shared edge loses its corners
    // and its gap, so the group reads as one island (or one notch). the bar works
    // it out; the open popup of popup mode stands apart either way
    readonly property string modId: pill.moduleId()
    readonly property bool joinLeft: !!pill.hostWindow && !!pill.hostWindow.joinedLeftOf && pill.modId !== "" && pill.hostWindow.joinedLeftOf(pill.modId)
    readonly property bool joinRight: !!pill.hostWindow && !!pill.hostWindow.joinedRightOf && pill.modId !== "" && pill.hostWindow.joinedRightOf(pill.modId)
    readonly property bool joined: pill.joinLeft || pill.joinRight

    // growing sideways would run into a joined neighbour, so a joined pill lights
    // up in place instead
    readonly property bool hoverLift: Prefs.barHoverGrow > 0 && pill.compactHovered && !pill.anyOpen && pill.shown && !pill.joined
    property real hoverGrow: pill.hoverLift ? Math.min(Theme.dp(Prefs.barHoverGrow), Math.max(0, Theme.dp(Prefs.barSpacing) / 2)) : 0

    property int hoverGrowDuration: Theme.barMs(150)

    onCompactHoveredChanged: pill.hoverGrowDuration = Theme.barMs(pill.compactHovered ? 150 : 220)

    Behavior on hoverGrow {
        NumberAnimation {
            duration: pill.hoverGrowDuration
            easing.type: Easing.OutCubic
        }

    }

    readonly property bool popupMode: Prefs.barPopupMode
    readonly property int openWidth: pill.altOpen ? pill.altWidth : (pill.expanded ? pill.panelWidth : pill.compactWidth)
    readonly property int openHeight: pill.altOpen ? pill.altHeight : (pill.expanded ? pill.panelHeight : pill.compactHeight)
    readonly property int cornerRadius: pill.popupMode ? Math.min(pill.expandedRadius, Math.round(shell.height / 2)) : (pill.anyOpen ? pill.expandedRadius : Prefs.barPillRadius)
    readonly property int topRadius: Prefs.barNotch && !pill.popupMode ? 0 : pill.cornerRadius
    readonly property int pillTopRadius: Prefs.barNotch ? 0 : Prefs.barPillRadius
    readonly property int barRadius: pill.popupMode ? Prefs.barPillRadius : pill.cornerRadius
    readonly property int barTopRadius: pill.popupMode ? pill.pillTopRadius : pill.topRadius

    property string popupAlign: "left"
    property bool popupIsAlt: false

    onAnyOpenChanged: {
        if (pill.anyOpen)
            pill.popupIsAlt = pill.altOpen && !pill.expanded;

        panelTransitionTimer.restart();
    }

    readonly property int popupWidth: pill.popupIsAlt ? pill.altWidth : pill.panelWidth
    readonly property int popupHeight: pill.popupIsAlt ? pill.altHeight : pill.panelHeight
    readonly property real popupX: {
        if (!pill.popupMode)
            return 0;

        if (pill.popupAlign === "right")
            return pill.compactWidth - pill.popupWidth;

        if (pill.popupAlign === "center")
            return (pill.compactWidth - pill.popupWidth) / 2;

        return 0;
    }
    readonly property bool popupExpanding: pill.popupMode && pill.anyOpen
    readonly property bool popupOpen: pill.shown && pill.popupMode && shell.y > 0.5
    readonly property Item popupItem: shell

    readonly property real surfaceX: -pill.hoverGrow
    readonly property real surfaceY: 0
    readonly property real surfaceWidth: (pill.popupMode ? pill.compactWidth : pill.width) + pill.hoverGrow * 2
    readonly property real surfaceHeight: pill.popupMode ? pill.compactHeight : pill.height

    implicitWidth: !pill.shown ? 0 : (pill.popupMode ? pill.compactWidth : pill.openWidth)
    implicitHeight: !pill.shown ? 0 : (pill.popupMode ? pill.compactHeight : pill.openHeight)
    opacity: pill.shown ? 1 : 0
    scale: pill.shown ? 1 : 0.82
    transformOrigin: Item.Center
    visible: pill.opacity > 0.01
    clip: !pill.popupMode && pill.anyOpen && !pill.overlayOpen
    z: (pill.popupOpen || pill.overlayOpen) ? 100 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.barMs(180)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.barMs(260)
            easing.type: pill.shown ? Easing.OutBack : Easing.InCubic
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: pill.morphDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: pill.morphEasing
        }

    }

    property bool shownTransition: false

    onShownChanged: {
        pill.shownTransition = true;
        shownTransitionTimer.restart();
    }

    Behavior on implicitHeight {
        enabled: !pill.anyOpen || pill.panelTransitioning || pill.shownTransition

        NumberAnimation {
            duration: pill.morphDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: pill.morphEasing
        }

    }

    Item {
        id: overlayHolder

        x: 0
        y: 0
        width: (pill.overlayOpen && pill.hostWindow) ? Math.max(pill.width, pill.hostWindow.width - pill.x) : pill.width
        height: (pill.overlayOpen && pill.hostWindow) ? Math.max(pill.height, pill.hostWindow.height - pill.y) : pill.height
        z: 200
    }

    Timer {
        id: shownTransitionTimer

        interval: Theme.barMs(420)
        onTriggered: pill.shownTransition = false
    }

    Timer {
        id: panelTransitionTimer

        interval: Theme.barMs(420)
        onTriggered: pill.panelTransitioning = false
        onRunningChanged: {
            if (running)
                pill.panelTransitioning = true;

        }
    }

    Rectangle {
        id: pillRect

        visible: pill.popupMode
        x: pill.surfaceX
        y: pill.surfaceY
        width: pill.compactWidth + pill.hoverGrow * 2
        height: pill.compactHeight
        color: Theme.bg
        clip: true
        radius: Prefs.barPillRadius
        topLeftRadius: pill.joinLeft ? 0 : pill.pillTopRadius
        topRightRadius: pill.joinRight ? 0 : pill.pillTopRadius
        bottomLeftRadius: pill.joinLeft ? 0 : Prefs.barPillRadius
        bottomRightRadius: pill.joinRight ? 0 : Prefs.barPillRadius

        Behavior on color {
            enabled: pill.hostWindow ? pill.hostWindow.laidOut : false

            ColorAnimation {
                duration: Theme.barMs(260)
                easing.type: Easing.OutCubic
            }

        }

    }

    Rectangle {
        id: shell

        width: pill.popupMode ? (pill.anyOpen ? pill.popupWidth : pill.compactWidth + pill.hoverGrow * 2) : pill.width + pill.hoverGrow * 2
        height: pill.popupMode ? (pill.anyOpen ? pill.popupHeight : pill.compactHeight) : pill.height
        x: pill.popupMode && pill.anyOpen ? pill.popupX : pill.surfaceX
        y: pill.popupMode && pill.anyOpen ? pill.compactHeight + Theme.dp(Prefs.barPopupGap) : pill.surfaceY
        visible: !pill.popupMode || shell.y > 0.5
        color: Theme.bg
        radius: pill.cornerRadius
        // opened in place, the panel hangs from its own stretch of the group: the
        // shared top corners stay square, the bottom ones round off below it
        topLeftRadius: pill.joinLeft && !pill.popupMode ? 0 : pill.topRadius
        topRightRadius: pill.joinRight && !pill.popupMode ? 0 : pill.topRadius
        bottomLeftRadius: pill.joinLeft && !pill.popupMode && !pill.anyOpen ? 0 : pill.cornerRadius
        bottomRightRadius: pill.joinRight && !pill.popupMode && !pill.anyOpen ? 0 : pill.cornerRadius
        clip: true
        layer.enabled: pill.surfaceLayered
        layer.samples: 4

        Behavior on x {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupExpanding ? pill.morphDuration : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on y {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupExpanding ? pill.morphDuration : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on width {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupExpanding ? pill.morphDuration : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on height {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupExpanding ? pill.morphDuration : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.barMs(380)
                easing.type: Easing.OutCubic
            }

        }

        Item {
            id: compactFace

            parent: pill.popupMode ? pillRect : shell
            anchors.fill: parent
            opacity: pill.popupMode || !pill.anyOpen ? 1 : 0
            scale: pill.popupMode || !pill.anyOpen ? 1 : pill.compactCollapseScale
            visible: opacity > 0.01

            // a joined pill doesn't grow on hover, so its stretch of the group lights up
            Rectangle {
                anchors.fill: parent
                visible: pill.joined && opacity > 0
                color: Theme.text
                opacity: pill.compactHovered && !pill.anyOpen ? Theme.stateHover : 0
                topLeftRadius: compactFace.parent ? compactFace.parent.topLeftRadius : 0
                topRightRadius: compactFace.parent ? compactFace.parent.topRightRadius : 0
                bottomLeftRadius: compactFace.parent ? compactFace.parent.bottomLeftRadius : 0
                bottomRightRadius: compactFace.parent ? compactFace.parent.bottomRightRadius : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(150)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // the seam between two joined modules, drawn by the right-hand one
            Rectangle {
                visible: pill.joinLeft && Prefs.barJoinDividers
                x: 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, Theme.dp(1))
                height: Math.round(parent.height * 0.42)
                radius: width / 2
                color: Theme.alpha(Theme.text, 0.14)
            }

            MouseArea {
                anchors.fill: parent
                enabled: pill.compactInteractive
                hoverEnabled: pill.compactInteractive
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onEntered: pill.compactHovered = true
                onExited: pill.compactHovered = false
                onClicked: (mouse) => {
                    // a right click opens this module's card in Settings
                    if (mouse.button === Qt.RightButton) {
                        const id = pill.moduleId();
                        if (id !== "")
                            Prefs.openBarModule(id);

                        return ;
                    }
                    pill.compactClicked();
                    pill.expanded = true;
                }
            }

            Item {
                id: compactHolder

                anchors.centerIn: parent
                width: pill.compactWidth
                height: pill.compactHeight
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: pill.compactFadePause
                    }

                    NumberAnimation {
                        duration: pill.compactFadeDuration
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Item {
            id: altHolder

            anchors.fill: parent
            opacity: pill.altOpen && !pill.expanded ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barMs(200)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Item {
            id: panelHolder

            anchors.fill: parent
            opacity: (!pill.panelFades || pill.expanded) ? 1 : 0
            scale: (!pill.panelFades || pill.expanded) ? 1 : 1.04
            visible: opacity > 0.01

            HyprlandFocusGrab {
                active: pill.expanded && pill.focusGrabs
                windows: pill.hostWindow ? [pill.hostWindow] : []
                onCleared: pill.expanded = false
            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: pill.panelFadePause
                    }

                    NumberAnimation {
                        duration: pill.panelFadeDuration
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: pill.panelFadePause
                    }

                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

    }

}
