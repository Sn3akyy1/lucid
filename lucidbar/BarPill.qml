import QtQuick
import Quickshell.Hyprland._FocusGrab
import qs

// The bar's pill shell, in one place.
//
// Every module used to carry its own byte-identical copy of this: the same
// ~150 lines of morph/pop-up geometry, the same four Behaviors, the same
// radius derivations, the same show/hide latch, the same compact-face
// cross-fade - right down to the comments, which is what gave the copying
// away. Eight copies meant eight places to fix anything and eight chances for
// one module to quietly drift from the rest.
//
// A module now sets sizes and supplies content; this owns the chrome and all
// of the motion. Nothing about how a pill *looks* changed in the factoring -
// the values below are the ones the modules were already using.
//
// Deliberately a plain .qml file with no qmldir, matching how every other
// type here resolves (Quickshell's implicit directory import).
Item {
    id: pill

    // ---------------- what a module supplies ----------------
    property var hostWindow: null
    // A hidden module collapses to zero size as well as going invisible, so
    // the bar's input mask and blur region collapse with it instead of
    // leaving a dead rectangle behind at its last position.
    property bool shown: true
    property bool expanded: false
    // A second surface that is not the panel - the clock's reminder toast,
    // Notifications' arrival toast. It opens the same way the panel does and
    // shares its motion, but never takes focus.
    property bool altOpen: false
    property int compactWidth: 0
    property int compactHeight: Prefs.barHeight
    property int panelWidth: 320
    property int panelHeight: 200
    property int altWidth: 0
    property int altHeight: 0
    // the radius the surface settles into once open; the collapsed end is
    // always the pill's own
    property int expandedRadius: Theme.radiusLg
    // how far the compact face shrinks as the panel takes over from it
    property real compactCollapseScale: 0.82
    // Workspaces drives its own hover (it lights individual slots rather than
    // the pill) and handles its own clicks, so it opts out of both.
    property bool compactInteractive: true
    property bool focusGrabs: true
    // Mpris cross-fades two pages inside its panel and already gates both on
    // `expanded`, so the holder must not fade them a second time - that would
    // stack a second curve on top of the one the module runs itself.
    property bool panelFades: true
    // Render the panel through a layer, so its rounded clip is antialiased.
    // Opt-in: a layer costs texture memory per module and only the ones that
    // needed it carried it before the shells were factored together.
    property bool surfaceLayered: false

    signal compactClicked()

    // ---------------- content slots ----------------
    // Named rather than default, so a module's Timers, Processes and FileViews
    // stay ordinary children of the module root where they read naturally,
    // and only the two faces go into the shell.
    property alias compactContent: compactHolder.data
    property alias altContent: altHolder.data
    property alias panelContent: panelHolder.data

    // ---------------- one timebase for the container transform ----------------
    // The panel resizing and whatever a module cross-fades inside it are one
    // movement, so they cannot each pick their own duration and curve. They
    // used to: the height ran 380ms OutCubic in morph mode and 320ms
    // emphasized in pop-up mode, while the content ran 280ms on a third
    // schedule with a 140ms offset on top - four different end times in a
    // single transition, which is what read as unsynchronised. A module
    // animating anything for a view change reads these two instead.
    // The shell's ordinary enter timing - the same token the pill itself
    // opens on, so a panel changing views moves at the speed everything else
    // in the bar does rather than on a schedule of its own.
    readonly property int morphDuration: Theme.barDurEnter
    readonly property var morphEasing: Theme.easeEmphasizedDecel

    // Lets a module re-arm the height Behavior for a change that is not an
    // open or a close - the System panel swapping between its views, which
    // resizes the panel by as much as opening it did.
    function beginTransition() {
        panelTransitionTimer.restart();
    }

    // ---------------- state ----------------
    readonly property bool anyOpen: pill.expanded || pill.altOpen
    property bool compactHovered: false
    property bool panelTransitioning: false

    // ---------------- hover affordance ----------------
    // A pill that opens should say so before it is clicked. It grows a couple
    // of logical pixels out of its own centre on hover - motion only, no
    // tint, no border, no shadow.
    //
    // Real geometry rather than `scale`, because a compositor blur region is
    // a pixel rectangle that tracks bounds and knows nothing about a
    // transform: scaled, the pill would grow while its frosted backing stayed
    // put, and the surface's own antialiased edge would slide off the blurred
    // patch behind it. The bar's mask and blur regions read surfaceX/Width
    // below, so the backing grows with the pill exactly.
    //
    // Growth is outward from the centre and never changes implicitWidth, so
    // neighbours stay where they are - it eats into the gap between modules,
    // which is why it is capped well under barSpacing.
    //
    // Sideways and *downward* only. The bar window's own top edge is y = 0
    // (the island style's top margin belongs to the layer surface, outside
    // the window), so a pill growing upward would simply be clipped off. Down
    // is also the direction its panel opens, which is the thing the growth is
    // there to advertise.
    readonly property bool hoverLift: Prefs.barHoverGrow > 0 && pill.compactHovered && !pill.anyOpen && pill.shown
    property real hoverGrow: pill.hoverLift ? Math.min(Prefs.barHoverGrow, Math.max(0, Prefs.barSpacing / 2)) : 0

    // The surface itself stays disciplined - no overshoot. This number drives
    // the compositor blur region and decides how close the pill comes to its
    // neighbour, so it must never exceed the cap above even for a frame. The
    // springiness lives on the content instead, where it is a transform and
    // can collide with nothing. Quicker in than out, so the pill answers the
    // pointer immediately and relaxes rather than snapping back.
    Behavior on hoverGrow {
        NumberAnimation {
            duration: Theme.barMs(pill.hoverLift ? 240 : 170)
            easing.type: Easing.OutCubic
        }

    }

    // ---------------- settings-driven behaviour ----------------
    // Pop-up mode: the pill stops morphing into the panel and stays put in
    // the bar, with the panel becoming a detached surface below it.
    readonly property bool popupMode: Prefs.barPopupMode
    // the size this module takes when open, in morph mode
    readonly property int openWidth: pill.altOpen ? pill.altWidth : (pill.expanded ? pill.panelWidth : pill.compactWidth)
    readonly property int openHeight: pill.altOpen ? pill.altHeight : (pill.expanded ? pill.panelHeight : pill.compactHeight)
    // mirrors shell's own radius below. In pop-up mode the radius rides the
    // panel's animated height, so the surface leaves the pill wearing the
    // pill's own round end and settles into the panel's flatter corner as it
    // grows - and the bar's blur region, which reads this, keeps the same
    // shape the whole way. The collapsed branch belongs to the morphing pill:
    // left in the expression it snapped the detached panel into a blob on the
    // first frame of the exit.
    readonly property int cornerRadius: pill.popupMode ? Math.min(pill.expandedRadius, Math.round(shell.height / 2)) : (pill.anyOpen ? pill.expandedRadius : Prefs.barPillRadius)
    // a notch squares off only the edge that actually meets the screen; a
    // detached pop-up panel touches nothing and stays rounded all round
    readonly property int topRadius: Prefs.barNotch && !pill.popupMode ? 0 : pill.cornerRadius
    readonly property int pillTopRadius: Prefs.barNotch ? 0 : Prefs.barPillRadius
    // The radii this module's own bounds are actually drawn with, so the
    // bar's mask and blur regions can mirror them exactly.
    readonly property int barRadius: pill.popupMode ? Prefs.barPillRadius : pill.cornerRadius
    readonly property int barTopRadius: pill.popupMode ? pill.pillTopRadius : pill.topRadius

    // Which edge of the pill the detached panel lines up with, set from
    // shell.qml - the only thing that knows whether this module sits in the
    // left group, the centre, or the right group.
    property string popupAlign: "left"
    // Latched when a surface opens, so the panel keeps its own size for the
    // whole of the exit instead of resizing to the other surface's halfway
    // out.
    property bool popupIsAlt: false

    onAnyOpenChanged: {
        if (pill.anyOpen)
            pill.popupIsAlt = pill.altOpen && !pill.expanded;

        panelTransitionTimer.restart();
    }

    // The panel's own size, with no collapsed branch. openWidth/openHeight
    // fold back to the pill the instant it closes, so anything derived from
    // them raced that change - the panel snapped to a stub and only then
    // faded, which is why closing read as vanishing rather than retreating.
    readonly property int popupWidth: pill.popupIsAlt ? pill.altWidth : pill.panelWidth
    readonly property int popupHeight: pill.popupIsAlt ? pill.altHeight : pill.panelHeight
    readonly property real popupX: {
        if (!pill.popupMode)
            return 0;

        // popupWidth, not openWidth: openWidth folds back to the pill's width
        // the instant the panel closes, which slid the panel sideways mid-exit.
        if (pill.popupAlign === "right")
            return pill.compactWidth - pill.popupWidth;

        if (pill.popupAlign === "center")
            return (pill.compactWidth - pill.popupWidth) / 2;

        return 0;
    }
    // Intent: true from the moment the panel is asked to open. The enter and
    // exit animations read this to pick their duration and curve.
    readonly property bool popupExpanding: pill.popupMode && pill.anyOpen
    // Painted: true for as long as the panel actually has extent on screen,
    // which includes the whole of the exit animation. Read off the drop
    // rather than the size, because a closed pop-up still carries the pill's
    // footprint. `shown` first: a blur region is pure geometry and does not
    // care that a module is switched off, so ungated a hidden module still
    // published its panel's rectangle and the compositor frosted a pane of
    // desktop with nothing drawn on it.
    readonly property bool popupOpen: pill.shown && pill.popupMode && shell.y > 0.5
    readonly property Item popupItem: shell

    // ---------------- geometry the bar's regions track ----------------
    // The pill's painted bounds in module-local coordinates, hover growth
    // included, so the mask and the blur region follow it exactly.
    readonly property real surfaceX: -pill.hoverGrow
    readonly property real surfaceY: 0
    readonly property real surfaceWidth: (pill.popupMode ? pill.compactWidth : pill.width) + pill.hoverGrow * 2
    readonly property real surfaceHeight: (pill.popupMode ? pill.compactHeight : pill.height) + pill.hoverGrow

    implicitWidth: !pill.shown ? 0 : (pill.popupMode ? pill.compactWidth : pill.openWidth)
    implicitHeight: !pill.shown ? 0 : (pill.popupMode ? pill.compactHeight : pill.openHeight)
    // Switching a module off used to take it out of the bar between frames.
    // It now scales down and fades while its width collapses, so the row
    // closes the gap behind something that is visibly leaving rather than
    // something that was simply deleted.
    opacity: pill.shown ? 1 : 0
    scale: pill.shown ? 1 : 0.82
    transformOrigin: Item.Center
    visible: pill.opacity > 0.01
    // Only while something is actually open. `shell` below clips its own
    // contents already, so this was never what kept the panel tidy - but in
    // morph mode it *did* clip the pill back to exactly compactWidth, which
    // silently cancelled the hover growth: the surface grew and was cut back
    // to its old bounds in the same frame, so the affordance never rendered at
    // all. Collapsed, there is nothing to contain and every reason to let the
    // pill swell past its layout box.
    clip: !pill.popupMode && pill.anyOpen
    z: pill.popupOpen ? 100 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.barMs(180)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.barMs(260)
            // a little overshoot on the way in, so it reads as popping into
            // place rather than inflating
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

    // The height Behavior below is gated so it only runs during a real
    // transition - a panel's height changes constantly as its content does,
    // and animating every one of those lagged the panel behind its own
    // contents. Hiding the module from settings is also a transition, but not
    // a *panel* one, so it fell outside that gate: implicitHeight snapped to 0
    // in a single frame and the module vanished no matter how nicely its width
    // and opacity were still animating. This latch is what puts show/hide
    // inside the gate too.
    property bool shownTransition: false

    onShownChanged: {
        pill.shownTransition = true;
        shownTransitionTimer.restart();
    }

    Behavior on implicitHeight {
        enabled: pill.panelTransitioning || pill.shownTransition

        NumberAnimation {
            duration: Theme.barMs(380)
            easing.type: Easing.OutCubic
        }

    }

    Timer {
        id: shownTransitionTimer

        interval: Theme.barMs(420)
        onTriggered: pill.shownTransition = false
    }

    Timer {
        id: panelTransitionTimer

        // Theme.ms, not a raw 400. This gate has to outlast the animation it
        // opens - the implicitHeight Behavior below runs for Theme.barMs(380),
        // which scales with motionScale while a literal 400 does not. At any
        // motionScale above ~1.05 the gate shut mid-animation, the Behavior
        // was disabled under a running animation, and the panel snapped to its
        // target height. Every module inherited the literal from the shell
        // they were each carrying a copy of.
        interval: Theme.barMs(420)
        onTriggered: pill.panelTransitioning = false
        onRunningChanged: {
            if (running)
                pill.panelTransitioning = true;

        }
    }

    // In pop-up mode this is the pill that stays in the bar, and the compact
    // face reparents into it. In morph mode it is unused - the rectangle
    // below is both pill and panel.
    Rectangle {
        id: pillRect

        visible: pill.popupMode
        x: pill.surfaceX
        y: pill.surfaceY
        width: pill.compactWidth + pill.hoverGrow * 2
        height: pill.compactHeight + pill.hoverGrow
        // Fades out as shell.qml's united bar fades in, over the same
        // duration. Switched outright, the islands lost their backs in the
        // same frame the shared surface appeared behind them.
        color: Theme.bg
        clip: true
        radius: Prefs.barPillRadius
        topLeftRadius: pill.pillTopRadius
        topRightRadius: pill.pillTopRadius

        Behavior on color {
            // not before the bar has laid out: inline mode reads false for the
            // frame before the config file lands, so at startup this would
            // always cross-fade in from an island that was never really there
            enabled: pill.hostWindow ? pill.hostWindow.laidOut : false

            ColorAnimation {
                duration: Theme.barMs(260)
                easing.type: Easing.OutCubic
            }

        }

    }

    Rectangle {
        id: shell

        // morph mode: fills the root, which is the thing that morphs.
        // pop-up mode: a detached panel hanging below the pill.
        //
        // Pop-up mode expands the panel out of the pill the same way morph
        // mode expands the pill itself - small to big. The growth has to be
        // real geometry rather than opacity or scale: the frosted backing
        // behind a panel is a compositor blur region (see shell.qml), a
        // hard-edged rectangle that tracks this item's bounds and cannot fade
        // along with it. A cross-fade therefore flashed a blurred empty pane
        // for a frame before the panel had drawn anything, and on the way out
        // dropped the backing on the very first frame. Geometry is what the
        // blur region follows, so growing keeps the surface and its backing
        // the same shape every frame.
        width: pill.popupMode ? (pill.anyOpen ? pill.popupWidth : pill.compactWidth + pill.hoverGrow * 2) : pill.width + pill.hoverGrow * 2
        height: pill.popupMode ? (pill.anyOpen ? pill.popupHeight : pill.compactHeight + pill.hoverGrow) : pill.height + pill.hoverGrow
        x: pill.popupMode && pill.anyOpen ? pill.popupX : pill.surfaceX
        y: pill.popupMode && pill.anyOpen ? pill.compactHeight + Prefs.barPopupGap : pill.surfaceY
        visible: !pill.popupMode || shell.y > 0.5
        color: Theme.bg
        radius: pill.cornerRadius
        topLeftRadius: pill.topRadius
        topRightRadius: pill.topRadius
        clip: true
        layer.enabled: pill.surfaceLayered
        layer.samples: 4

        // popupExpanding rather than popupOpen: popupOpen follows the very
        // geometry these animations drive, so reading it here would have
        // picked the exit duration for every enter. All four share one
        // duration and curve so the panel expands as a single movement.
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

        // COMPACT FACE
        Item {
            id: compactFace

            // in pop-up mode the compact face belongs to the pill that stays
            // in the bar, not to the panel that drops away below it
            parent: pill.popupMode ? pillRect : shell
            anchors.fill: parent
            // in pop-up mode the pill is not the thing that opens, so its
            // face stays put and lit instead of fading out into a panel
            opacity: pill.popupMode || !pill.anyOpen ? 1 : 0
            scale: pill.popupMode || !pill.anyOpen ? 1 : pill.compactCollapseScale
            visible: opacity > 0.01

            MouseArea {
                anchors.fill: parent
                enabled: pill.compactInteractive
                hoverEnabled: pill.compactInteractive
                cursorShape: Qt.PointingHandCursor
                onEntered: pill.compactHovered = true
                onExited: pill.compactHovered = false
                onClicked: {
                    pill.compactClicked();
                    pill.expanded = true;
                }
            }

            // The module's own compact content, centred in whatever the pill
            // currently measures - which is what lets the hover growth push
            // the surface outward without the content sliding inside it.
            Item {
                id: compactHolder

                anchors.centerIn: parent
                width: pill.compactWidth
                height: pill.compactHeight
                // The content lifts with the surface rather than sitting still
                // inside a growing box - without this the growth reads as the
                // pill gaining padding, not as the module coming forward. A
                // scale, not geometry: it cannot touch a neighbour or drag the
                // blur region out of shape, which is what lets it overshoot.
                scale: pill.hoverLift ? 1.04 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.barMs(pill.hoverLift ? 280 : 180)
                        easing.type: pill.hoverLift ? Easing.OutBack : Easing.OutCubic
                        easing.overshoot: 2.4
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

        // ALT FACE - a toast or other non-panel surface
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

        // EXPANDED FACE
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

            // held back a beat on the way in, so the panel has grown to
            // something worth showing before its contents arrive
            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.barMs(pill.expanded ? 140 : 0)
                    }

                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.barMs(pill.expanded ? 140 : 0)
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
