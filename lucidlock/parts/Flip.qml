import QtQuick

// layout motion for one thing on the stage. the stage remembers where each
// thing was laid out last (its memo, by key); when a change puts it somewhere
// else, it starts from the old place and size and glides to the new one on the
// shell's spatial curve, the overshoot and all. a thing that was nowhere
// before pops in. the owner draws with dx, dy and ds (a glide, anchored at
// its top left) and ps and fade (a pop, about its centre)
Item {
    id: f

    property var stage: null
    property string key: ""
    // the laid-out item whose place is tracked, usually the owner itself
    property Item home: null
    // off for the drag's ghost, which follows the pointer instead
    property bool live: true
    property real dx: 0
    property real dy: 0
    property real ds: 1
    property real ps: 1
    property real fade: 1
    readonly property bool moving: glide.running || pop.running
    readonly property var theme: f.stage ? f.stage.theme : null

    // where the owner is laid out now, against what the memo says it was
    function place(animate) {
        if (!f.live || !f.stage || !f.home || f.key === "")
            return ;

        var w = f.home.width, h = f.home.height;
        // a widget folded away keeps the last place it was seen at
        if (!f.home.visible || w <= 0 || h <= 0)
            return ;

        var p = f.home.mapToItem(f.stage, 0, 0);
        var m = f.stage.memo[f.key];
        if (animate && f.stage.flipOk) {
            if (m) {
                var ddx = m.x - p.x, ddy = m.y - p.y;
                var grow = (m.w > 1 && m.h > 1) ? Math.sqrt((m.w * m.h) / (w * h)) : 1;
                var moved = Math.abs(ddx) > 0.5 || Math.abs(ddy) > 0.5;
                var resized = Math.abs(grow - 1) > 0.03;
                if (moved || resized || m.land) {
                    glide.stop();
                    // continuous with whatever glide was already under way
                    f.dx += ddx;
                    f.dy += ddy;
                    if (resized)
                        f.ds = Math.max(0.3, Math.min(3, f.ds * grow));

                    glide.dur = m.land ? f.theme.ms(420) : f.theme.ms(520);
                    glide.curve = m.land ? f.theme.curveFastSpatial : f.theme.curveDefaultSpatial;
                    glide.start();
                }
            } else {
                // nowhere before: it arrives
                pop.stop();
                f.ps = 0.84;
                f.fade = 0;
                pop.start();
            }
        }
        f.stage.memo[f.key] = {
            "x": p.x,
            "y": p.y,
            "w": w,
            "h": h
        };
    }

    // the same thing in a new look: it settles back in, a little smaller first
    function repop() {
        if (!f.live || !f.stage || !f.stage.flipOk)
            return ;

        pop.stop();
        f.ps = Math.min(f.ps, 0.94);
        f.fade = Math.min(f.fade, 0.35);
        pop.start();
    }

    Connections {
        function onMeasured(animate) {
            f.place(animate);
        }

        target: f.live ? f.stage : null
    }

    ParallelAnimation {
        id: glide

        property int dur: 520
        property var curve: [0.38, 1.21, 0.22, 1, 1, 1]

        NumberAnimation {
            target: f
            property: "dx"
            to: 0
            duration: glide.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: glide.curve
        }

        NumberAnimation {
            target: f
            property: "dy"
            to: 0
            duration: glide.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: glide.curve
        }

        NumberAnimation {
            target: f
            property: "ds"
            to: 1
            duration: glide.dur
            easing.type: Easing.BezierSpline
            easing.bezierCurve: glide.curve
        }

    }

    ParallelAnimation {
        id: pop

        NumberAnimation {
            target: f
            property: "ps"
            to: 1
            duration: f.theme ? f.theme.ms(500) : 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: f.theme ? f.theme.curveDefaultSpatial : [0.38, 1.21, 0.22, 1, 1, 1]
        }

        NumberAnimation {
            target: f
            property: "fade"
            to: 1
            duration: f.theme ? f.theme.ms(260) : 260
            easing.type: Easing.BezierSpline
            easing.bezierCurve: f.theme ? f.theme.curveEffects : [0.31, 0.94, 0.34, 1, 1, 1]
        }

    }

}
