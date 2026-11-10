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
    // in hand in edit mode: over its neighbours, and on the full bar a pill of its own
    property bool editLifted: false

    readonly property int morphDuration: Theme.barDurEnter
    readonly property var morphEasing: Theme.easeEmphasizedDecel

    // the look picked on the module's card, and the one its face draws: a
    // switch fades the old look out, flips, and brings the new one in as the
    // pill takes its width. one set as the bar comes up just shows
    property string lookPref: ""
    property string look: ""
    property bool lookSettled: false

    function switchLook() {
        if (pill.look === pill.lookPref)
            return ;

        if (!pill.lookSettled || !pill.shown || !pill.visible) {
            lookSwitch.stop();
            // a pill on its way out keeps its contents faded
            if (pill.shown) {
                compactHolder.opacity = 1;
                compactHolder.scale = 1;
            }
            pill.look = pill.lookPref;
            return ;
        }
        lookSwitch.restart();
    }

    onLookPrefChanged: pill.switchLook()
    Component.onCompleted: pill.look = pill.lookPref

    Timer {
        interval: 1500
        running: Prefs.loaded && !pill.lookSettled
        onTriggered: pill.lookSettled = true
    }

    SequentialAnimation {
        id: lookSwitch

        ParallelAnimation {
            NumberAnimation {
                target: compactHolder
                property: "opacity"
                to: 0
                duration: Theme.barMs(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedAccel
            }

            NumberAnimation {
                target: compactHolder
                property: "scale"
                to: 0.86
                duration: Theme.barMs(120)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedAccel
            }

        }

        ScriptAction {
            script: pill.look = pill.lookPref
        }

        ParallelAnimation {
            NumberAnimation {
                target: compactHolder
                property: "opacity"
                to: 1
                duration: Theme.barMs(240)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

            NumberAnimation {
                target: compactHolder
                property: "scale"
                to: 1
                duration: Theme.barMs(320)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

    }

    // a height in the pill's own coordinates, in the overlay's. On the bottom edge
    // the overlay stands upright, turned over its own height, so it counts from
    // the other end; worked out rather than mapped, so it follows the overlay as
    // it grows instead of catching it halfway
    function overlayFromPill(y) {
        return Prefs.barBottom ? overlayHolder.height - y : y;
    }

    // where something `h` tall the module lays over the screen goes in the
    // overlay: `gap` off `fromY`, going away from the bar, so up from it on the
    // bottom edge
    function overlayY(fromY, gap, h) {
        const edge = pill.overlayFromPill(fromY);
        return Prefs.barBottom ? edge - gap - h : edge + gap;
    }

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
        if (pill.anyOpen && !openWobble.running) {
            pill.resizeFrom = pill.popupMode ? shell.height : pill.height;
            resizeWobble.restart();
        }
    }

    // tied to a neighbour, or to the screen edge by flares, a pill only bobs
    readonly property bool jellyPinned: pill.joined || Prefs.barFlush || pill.notchedPopup
    property real resizeFrom: 0

    // a soft cap, so a tall panel bends about as far as a short one
    function jellyAmp(rel, size) {
        return Math.min(rel, Theme.dp(26) / Math.max(1, size));
    }

    // kicked where the morph has slowed to the spring's pace, so it carries on past
    function wobbleOpen(open) {
        if (open) {
            jelly.kickAfter(pill.jellyAmp(0.06, pill.popupMode ? pill.popupHeight : pill.openHeight), Math.round(pill.morphDuration * 0.42));
        } else if (pill.popupMode) {
            jelly.rest();
            pillJelly.kickAfter(-0.15, Math.round(Theme.barDurExit * 0.9));
        } else {
            jelly.kickAfter(-0.15, Math.round(pill.morphDuration * 0.7));
        }
        openWobble.restart();
    }

    // an open and a resize in one go wobble once
    Timer {
        id: openWobble

        interval: pill.morphDuration
    }

    Timer {
        id: resizeWobble

        interval: Math.round(pill.morphDuration * 0.42)
        onTriggered: {
            const to = pill.popupMode ? pill.popupHeight : pill.openHeight;
            const dh = to - pill.resizeFrom;
            if (pill.anyOpen && !openWobble.running && Math.abs(dh) > Theme.dp(6))
                jelly.kick((dh > 0 ? 1 : -1) * pill.jellyAmp(0.035, to));

        }
    }

    readonly property bool anyOpen: pill.expanded || pill.altOpen

    property int panelFadePause: 0
    property int panelFadeDuration: Theme.barMs(220)
    property int compactFadePause: 0
    property int compactFadeDuration: Theme.barMs(220)

    // set in syncFadeTimings: popupExpanding is still stale when the Behaviors start
    property int popupMorphDuration: pill.morphDuration
    property var popupMorphCurve: Theme.easeEmphasizedDecel

    // a close takes as long as the open, but slow at first and soft at the end:
    // the enter curve went most of the way in its first frame, and whatever the
    // panel pushed aside jumped back. only while it closes: the face's own width
    // changes keep the enter curve
    property bool closing: false
    readonly property var closeCurve: [0.4, 0, 0.2, 1, 1, 1]

    Timer {
        id: closingTimer

        interval: pill.morphDuration
        onTriggered: pill.closing = false
    }

    function syncFadeTimings() {
        var open = pill.expanded || pill.altOpen;
        pill.closing = !open;
        if (open)
            closingTimer.stop();
        else
            closingTimer.restart();
        pill.popupMorphDuration = open ? pill.morphDuration : Theme.barDurExit;
        pill.popupMorphCurve = open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
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

    // how each corner meets a panel hanging below the bar, from shell.qml's hangPlan
    readonly property bool notchedPopup: pill.popupMode && Prefs.barPopupNotched
    readonly property var hangPlan: pill.hostWindow && pill.hostWindow.hangPlan ? pill.hostWindow.hangPlan : null
    readonly property var hangCorners: pill.hangPlan && pill.modId !== "" ? (pill.hangPlan.corners[pill.modId] || null) : null
    readonly property var hangTops: pill.hangPlan && pill.modId !== "" ? (pill.hangPlan.tops[pill.modId] || null) : null
    readonly property var hangSides: pill.hangPlan && pill.modId !== "" ? (pill.hangPlan.sides[pill.modId] || null) : null

    function capped(limits, corner, v) {
        return limits && limits[corner] !== undefined ? Math.max(0, Math.min(v, limits[corner])) : v;
    }

    // growing sideways would run into a joined neighbour, or a notch's own edge
    // blends, so those light up in place instead, blends and all
    readonly property bool hoverLift: Prefs.barHoverGrow > 0 && pill.compactHovered && !pill.anyOpen && pill.shown && !pill.joined && !Prefs.barNotch
    property real hoverGrow: pill.hoverLift ? Math.min(Theme.dp(Prefs.barHoverGrow), Math.max(0, Theme.dp(Prefs.barSpacing) / 2)) : 0

    property int hoverGrowDuration: Theme.barMs(150)

    onCompactHoveredChanged: {
        pill.hoverGrowDuration = Theme.barMs(pill.compactHovered ? 150 : 220);
        if (pill.compactHovered && !pill.anyOpen && pill.shown)
            (pill.popupMode ? pillJelly : jelly).kick(-0.07);

    }

    Behavior on hoverGrow {
        NumberAnimation {
            duration: pill.hoverGrowDuration
            easing.type: Easing.OutCubic
        }

    }

    // hover to open: the pill unfolds on its own once the pointer rests on it,
    // and folds back when the pointer leaves. Opened this way it deliberately
    // skips the focus grab - that pulls the keyboard off the focused window, and
    // merely passing over the bar must not do that - so a click anywhere on the
    // pill promotes it to an ordinary clicked-open panel, grab and all.
    // off for a pill that is only a button, with nothing to unfold
    property bool opensOnHover: true
    // not while the launcher stands on a bottom bar: a hover would shut it again
    readonly property bool hoverOpens: Prefs.barHoverOpen && pill.shown && pill.opensOnHover && !Edit.active && !(pill.hostWindow && pill.hostWindow.launcherUp === true)
    property bool hoverOpen: false
    readonly property bool surfaceHovered: pill.compactHovered || shellHover.hovered || pillHover.hovered

    function openOnHover() {
        if (!pill.hoverOpens || pill.anyOpen)
            return ;

        pill.hoverOpen = true;
        pill.compactClicked();
        pill.expanded = true;
    }

    function closeHoverOpen() {
        if (!pill.hoverOpen)
            return ;

        // collapse first: dropping hoverOpen while still expanded would arm the
        // focus grab for an instant on the way out
        pill.expanded = false;
        pill.hoverOpen = false;
    }

    onSurfaceHoveredChanged: {
        if (pill.surfaceHovered) {
            hoverCloseTimer.stop();
            if (pill.hoverOpens && !pill.anyOpen)
                hoverOpenTimer.restart();

        } else {
            hoverOpenTimer.stop();
            if (pill.hoverOpen)
                hoverCloseTimer.restart();

        }
    }
    onHoverOpensChanged: {
        if (!pill.hoverOpens)
            pill.closeHoverOpen();

    }

    // long enough that sweeping the pointer across the bar opens nothing
    Timer {
        id: hoverOpenTimer

        interval: 180
        onTriggered: pill.openOnHover()
    }

    // in pop-up mode the gap between pill and panel is outside the input region,
    // so crossing it unhovers both; this rides that out
    Timer {
        id: hoverCloseTimer

        interval: 320
        onTriggered: {
            if (!pill.surfaceHovered)
                pill.closeHoverOpen();

        }
    }

    readonly property bool popupMode: Prefs.barPopupMode
    readonly property int openWidth: pill.altOpen ? pill.altWidth : (pill.expanded ? pill.panelWidth : pill.compactWidth)
    readonly property int openHeight: pill.altOpen ? pill.altHeight : (pill.expanded ? pill.panelHeight : pill.compactHeight)
    readonly property int cornerRadius: pill.popupMode ? Math.min(pill.expandedRadius, Math.round(shell.height / 2)) : (pill.anyOpen ? pill.expandedRadius : Prefs.barPillRadius)
    readonly property int topRadius: Prefs.barFlush && !pill.popupMode ? 0 : pill.cornerRadius
    readonly property int pillTopRadius: Prefs.barFlush ? 0 : Prefs.barPillRadius
    // on the full bar the strip behind already paints the resting pill, so the
    // pill itself only shows a hover tint
    readonly property color restingColor: Prefs.barFull && !pill.editLifted ? Theme.alpha(Theme.bg, 0) : Theme.bg
    // still taller than the pill: a closing panel keeps its colour until it has
    // folded away, or on the full bar its fading contents float over the desktop
    readonly property bool surfaceOpen: pill.anyOpen || pill.height > pill.compactHeight + 0.5
    // on the full bar the strip already paints the band an open panel stands in, so
    // the panel paints only what hangs below it: both at once doubled the tint
    readonly property bool bodyBelowStrip: Prefs.barFull && !pill.popupMode && pill.surfaceOpen && !pill.editLifted
    readonly property int barRadius: pill.popupMode ? Prefs.barPillRadius : pill.cornerRadius
    readonly property int barTopRadius: pill.popupMode ? pill.pillTopRadius : pill.topRadius

    property string popupAlign: "left"
    property bool popupIsAlt: false

    onAnyOpenChanged: {
        if (pill.anyOpen)
            pill.popupIsAlt = pill.altOpen && !pill.expanded;
        else
            pill.hoverOpen = false;

        panelTransitionTimer.restart();
        pill.wobbleOpen(pill.anyOpen);
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
    readonly property bool popupOpen: pill.shown && pill.popupMode && (pill.notchedPopup ? shell.height > 0.5 : shell.y > 0.5)
    readonly property Item popupItem: shell

    readonly property real restX: -pill.hoverGrow
    // the surface as painted, jelly and all: what the mask and the blur follow
    readonly property real surfaceX: pill.restX + (pill.popupMode ? pillJelly.shiftX : jelly.shiftX)
    readonly property real surfaceY: pill.popupMode ? pillJelly.shiftY : jelly.shiftY
    readonly property real surfaceWidth: (pill.width + pill.hoverGrow * 2) * (pill.popupMode ? pillJelly.xScale : jelly.xScale)
    readonly property real surfaceHeight: pill.popupMode ? pill.compactHeight * pillJelly.yScale : pill.height * jelly.yScale
    readonly property real popupPaintX: shell.x + jelly.shiftX
    readonly property real popupPaintY: shell.y + jelly.shiftY
    readonly property real popupPaintWidth: shell.width * jelly.xScale
    readonly property real popupPaintHeight: shell.height * jelly.yScale
    // the corners ModuleRegion's mask and blur follow
    readonly property real barTopLeftRadius: pill.popupMode ? pillRect.topLeftRadius : shell.topLeftRadius
    readonly property real barTopRightRadius: pill.popupMode ? pillRect.topRightRadius : shell.topRightRadius
    readonly property real barBottomLeftRadius: pill.popupMode ? pillRect.bottomLeftRadius : shell.bottomLeftRadius
    readonly property real barBottomRightRadius: pill.popupMode ? pillRect.bottomRightRadius : shell.bottomRightRadius
    readonly property real popupTopLeftRadius: shell.topLeftRadius
    readonly property real popupTopRightRadius: shell.topRightRadius

    // leaving, the contents fade first, then the pill fades and shrinks as the
    // gap closes on the standard curve; its height holds until it has gone, so
    // it never squashes up into the bar's edge. set in onShownChanged, the one
    // place the animations below read it fresh
    property bool exiting: false

    implicitWidth: !pill.shown ? 0 : (pill.popupMode ? pill.compactWidth : pill.openWidth)
    implicitHeight: !pill.shown ? 0 : (pill.popupMode ? pill.compactHeight : pill.openHeight)
    // an open panel standing over it: out of the way until it shuts, not cut off at its edge
    readonly property bool covered: !!pill.hostWindow && !!pill.hostWindow.covers && pill.hostWindow.covers(pill)
    opacity: pill.shown && !pill.covered ? 1 : 0
    scale: pill.shown ? 1 : 0.86
    transformOrigin: Item.Center
    visible: pill.opacity > 0.01
    clip: !pill.popupMode && pill.anyOpen && !pill.overlayOpen && !jelly.wobbling
    // open in place, a panel stands over its neighbours, as wide as it may be
    z: pill.editLifted ? 120 : ((pill.popupOpen || pill.overlayOpen) ? 100 : (pill.surfaceOpen && !pill.popupMode ? 50 : 1))

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation {
                duration: pill.exiting ? Theme.barMs(40) : 0
            }

            NumberAnimation {
                duration: pill.exiting ? Theme.barMs(180) : Theme.barMs(180)
                easing.type: pill.exiting ? Easing.InOutCubic : Easing.OutCubic
            }

        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: pill.exiting ? Theme.barMs(300) : Theme.barMs(260)
            easing.type: pill.exiting ? Easing.InOutCubic : Easing.OutBack
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: pill.exiting ? Theme.barMs(360) : pill.morphDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: pill.exiting ? Theme.curveStandard : (pill.closing ? pill.closeCurve : pill.morphEasing)
        }

    }

    property bool shownTransition: false

    onShownChanged: {
        pill.exiting = !pill.shown;
        pill.shownTransition = true;
        shownTransitionTimer.restart();
        if (pill.exiting) {
            lookSwitch.stop();
            contentEnter.stop();
            contentExit.restart();
        } else {
            contentExit.stop();
            contentEnter.restart();
            if (pill.lookSettled)
                (pill.popupMode ? pillJelly : jelly).kickAfter(0.08, Theme.barMs(120));

        }
    }

    ParallelAnimation {
        id: contentExit

        NumberAnimation {
            target: compactHolder
            property: "opacity"
            to: 0
            duration: Theme.barMs(90)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: compactHolder
            property: "scale"
            to: 0.9
            duration: Theme.barMs(90)
            easing.type: Easing.OutCubic
        }

    }

    ParallelAnimation {
        id: contentEnter

        NumberAnimation {
            target: compactHolder
            property: "opacity"
            to: 1
            duration: Theme.barMs(200)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

        NumberAnimation {
            target: compactHolder
            property: "scale"
            to: 1
            duration: Theme.barMs(240)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedDecel
        }

    }

    Behavior on implicitHeight {
        enabled: !pill.anyOpen || pill.panelTransitioning || pill.shownTransition

        SequentialAnimation {
            PauseAnimation {
                duration: pill.exiting ? Theme.barMs(280) : 0
            }

            NumberAnimation {
                duration: pill.exiting ? 0 : pill.morphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.closing ? pill.closeCurve : pill.morphEasing
            }

        }

    }

    Item {
        id: overlayHolder

        x: 0
        y: 0
        width: (pill.overlayOpen && pill.hostWindow) ? Math.max(pill.width, pill.hostWindow.width - pill.x) : pill.width
        height: (pill.overlayOpen && pill.hostWindow) ? Math.max(pill.height, pill.hostWindow.height - pill.y) : pill.height
        z: 200

        // the bar is mirrored on the bottom edge; the content stands upright
        transform: Scale {
            origin.y: overlayHolder.height / 2
            yScale: Prefs.barBottom ? -1 : 1
        }

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
        x: pill.restX
        y: 0
        width: pill.width + pill.hoverGrow * 2
        height: pill.compactHeight
        color: pill.restingColor
        clip: true
        radius: Prefs.barPillRadius
        topLeftRadius: pill.joinLeft ? 0 : pill.pillTopRadius
        topRightRadius: pill.joinRight ? 0 : pill.pillTopRadius
        bottomLeftRadius: pill.capped(pill.hangCorners, "bl", pill.joinLeft ? 0 : Prefs.barPillRadius)
        bottomRightRadius: pill.capped(pill.hangCorners, "br", pill.joinRight ? 0 : Prefs.barPillRadius)
        readonly property bool jellyWobbling: pillJelly.wobbling
        transform: Jelly {
            id: pillJelly

            target: pillRect
            anchorY: pill.jellyPinned ? 0 : 0.5
            spread: pill.jellyPinned ? 0 : pillJelly.naturalSpread
            frequency: 5
        }

        HoverHandler {
            id: pillHover

            enabled: pill.popupMode
        }

        // over the contents, not on this rect: a handler on a parent never hears
        // a press a child MouseArea already took
        Item {
            anchors.fill: parent
            z: 1000

            PointHandler {
                enabled: pill.hoverOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onActiveChanged: {
                    if (active)
                        pill.hoverOpen = false;

                }
            }

        }

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

        // a notched pop-up grows down out of the pill's bottom edge, flush
        width: pill.popupMode ? (pill.anyOpen ? pill.popupWidth : pill.compactWidth + (pill.notchedPopup ? 0 : pill.hoverGrow * 2)) : pill.width + pill.hoverGrow * 2
        height: pill.popupMode ? (pill.anyOpen ? pill.popupHeight : (pill.notchedPopup ? 0 : pill.compactHeight)) : pill.height
        x: pill.popupMode && pill.anyOpen ? pill.popupX : (pill.notchedPopup ? 0 : pill.restX)
        y: pill.popupMode && (pill.anyOpen || pill.notchedPopup) ? pill.compactHeight + (pill.notchedPopup ? 0 : Theme.dp(Prefs.barPopupGap)) : 0
        visible: !pill.popupMode || (pill.notchedPopup ? shell.height > 0.5 : shell.y > 0.5)
        color: (pill.popupMode || pill.surfaceOpen) && !pill.bodyBelowStrip ? Theme.bg : pill.restingColor
        radius: pill.cornerRadius
        // opened in place, the panel hangs from its own stretch of the group: the
        // shared top corners stay square, the bottom ones round off below it
        topLeftRadius: pill.popupMode ? pill.capped(pill.notchedPopup ? pill.hangTops : null, "tl", pill.topRadius) : (pill.joinLeft ? 0 : pill.topRadius)
        topRightRadius: pill.popupMode ? pill.capped(pill.notchedPopup ? pill.hangTops : null, "tr", pill.topRadius) : (pill.joinRight ? 0 : pill.topRadius)
        bottomLeftRadius: pill.popupMode ? pill.cornerRadius : pill.capped(pill.hangSides, "bl", pill.capped(pill.hangCorners, "bl", pill.joinLeft && !pill.hangSides ? 0 : pill.cornerRadius))
        bottomRightRadius: pill.popupMode ? pill.cornerRadius : pill.capped(pill.hangSides, "br", pill.capped(pill.hangCorners, "br", pill.joinRight && !pill.hangSides ? 0 : pill.cornerRadius))
        clip: true
        layer.enabled: pill.surfaceLayered
        layer.samples: 4
        layer.smooth: jelly.wobbling
        readonly property bool jellyWobbling: jelly.wobbling
        // hung from its top edge while open, so it stays on the bar
        transform: Jelly {
            id: jelly

            target: shell
            anchorY: (pill.popupMode || pill.surfaceOpen || Prefs.barFlush) ? 0 : 0.5
            spread: pill.jellyPinned ? 0 : jelly.naturalSpread
            frequency: pill.surfaceOpen ? 3.2 : 5
        }

        // the panel below the strip. it starts where the strip ends on screen, so a
        // bob of the jelly opens no gap between them
        Rectangle {
            visible: pill.bodyBelowStrip
            y: Math.min(shell.height, pill.compactHeight / Math.max(0.5, jelly.yScale))
            width: shell.width
            height: Math.max(0, shell.height - y)
            color: Theme.bg
            bottomLeftRadius: shell.bottomLeftRadius
            bottomRightRadius: shell.bottomRightRadius
        }

        // handlers on the surface itself, so hovering the panel's own contents
        // still counts as hovering the pill
        HoverHandler {
            id: shellHover
        }

        // a passive grab, so the panel's buttons and drags keep working. On an
        // item stacked over the contents, not on the shell: a handler on a parent
        // never hears a press a child MouseArea already took (a right-click on a
        // tray item, say), and the panel folded away under the tray's menu
        Item {
            anchors.fill: parent
            z: 1000

            PointHandler {
                enabled: pill.hoverOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onActiveChanged: {
                    if (active)
                        pill.hoverOpen = false;

                }
            }

        }

        Behavior on x {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupMorphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupMorphCurve
            }

        }

        Behavior on y {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupMorphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupMorphCurve
            }

        }

        Behavior on width {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupMorphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupMorphCurve
            }

        }

        Behavior on height {
            enabled: pill.popupMode

            NumberAnimation {
                duration: pill.popupMorphDuration
                easing.type: Easing.Bezier
                easing.bezierCurve: pill.popupMorphCurve
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

            // on the full bar, hover lifts the module's own island out of the strip
            Rectangle {
                readonly property real inset: Theme.dp(4)

                y: inset
                width: parent.width
                height: parent.height - inset * 2
                visible: Prefs.barFull && opacity > 0
                radius: height / 2
                color: Theme.alpha(Theme.surfaceHigh, Theme.bg.a)
                opacity: pill.compactHovered && !pill.anyOpen ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: pill.hoverGrowDuration
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // a joined pill or a notch doesn't grow on hover, so it lights up as its edge blends do
            Rectangle {
                anchors.fill: parent
                visible: (pill.joined || Prefs.barNotch) && opacity > 0
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
                    // a right click opens this module's sheet in edit mode
                    if (mouse.button === Qt.RightButton) {
                        const id = pill.moduleId();
                        if (id !== "" && pill.hostWindow && pill.hostWindow.editModule)
                            pill.hostWindow.editModule(id);
                        else if (id !== "")
                            Prefs.openBarModule(id);

                        return ;
                    }
                    // a second click shuts a clicked-open pop-up; a hover-opened one stays, now clicked open
                    if (pill.popupMode && pill.expanded && !pill.hoverOpen) {
                        pill.expanded = false;
                        return ;
                    }
                    pill.hoverOpen = false;
                    pill.compactClicked();
                    pill.expanded = true;
                }
            }

            // centred in whole pixels of the pill's frame, not the surface's: hover
            // grows the surface by fractions, and centring in it stepped half a
            // pixel against that, so the content shook
            Item {
                id: compactHolder

                readonly property real frameX: compactFace.parent ? compactFace.parent.x : 0

                x: Math.round(compactHolder.frameX + (compactFace.width - compactHolder.width) / 2) - compactHolder.frameX
                y: Math.round((compactFace.height - compactHolder.height) / 2)
                width: pill.compactWidth
                height: pill.compactHeight

                // the bar is mirrored on the bottom edge; the content stands upright
                transform: Scale {
                    origin.y: compactHolder.height / 2
                    yScale: Prefs.barBottom ? -1 : 1
                }

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

            // the bar is mirrored on the bottom edge; the content stands upright
            transform: Scale {
                origin.y: altHolder.height / 2
                yScale: Prefs.barBottom ? -1 : 1
            }

        }

        Item {
            id: panelHolder

            anchors.fill: parent
            opacity: (!pill.panelFades || pill.expanded) ? 1 : 0
            scale: (!pill.panelFades || pill.expanded) ? 1 : 1.04
            visible: opacity > 0.01

            HyprlandFocusGrab {
                active: pill.expanded && pill.focusGrabs && !pill.hoverOpen
                // in edit mode the sheet beside it does not shut it
                windows: pill.hostWindow ? [pill.hostWindow].concat(Edit.active ? Edit.windows : []) : []
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

            // the bar is mirrored on the bottom edge; the content stands upright
            transform: Scale {
                origin.y: panelHolder.height / 2
                yScale: Prefs.barBottom ? -1 : 1
            }

        }

    }

}
