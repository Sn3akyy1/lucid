import QtQuick
import qs

// squash and stretch on a damped spring; kick() sets it wobbling. the item it
// bends should carry jellyWobbling: <id>.wobbling, so icons inside it filter
Scale {
    id: jelly

    property Item target: null
    // the point held still, as fractions of the target
    property real anchorX: 0.5
    property real anchorY: 0.5
    // how far a stretch pulls the sides in; 0 only bobs. a wide flat thing takes
    // less, or its far ends would swing a long way
    property real spread: jelly.naturalSpread
    readonly property real naturalSpread: jelly.target && jelly.target.width > 0 ? Math.max(0.2, Math.min(0.8, 2 * jelly.target.height / jelly.target.width)) : 0.7
    // wobbles per second, and a damping ratio: lower rings on longer
    property real frequency: 4
    property real damping: 0.22
    property real timeScale: Theme.motionScale
    // + is taller and narrower, - shorter and wider
    property real stretch: 0
    property real _v: 0
    readonly property bool wobbling: jelly._run.running || jelly._delay.running
    // how far the painted top left corner sits from the target's own
    readonly property real shiftX: jelly.origin.x * (1 - jelly.xScale)
    readonly property real shiftY: jelly.origin.y * (1 - jelly.yScale)
    readonly property real gain: Theme.jelly

    function kick(amp) {
        const a = Math.max(-0.25, Math.min(0.25, amp * jelly.gain));
        if (a === 0 || jelly.timeScale <= 0)
            return ;

        const w = 2 * Math.PI * jelly.frequency;
        const x = jelly.stretch;
        const before = Math.sqrt(x * x + (jelly._v / w) * (jelly._v / w));
        let v = jelly._v + a * w;
        // kicks in a row swing no further than the biggest of them
        const most = Math.max(before, Math.abs(a));
        if (Math.sqrt(x * x + (v / w) * (v / w)) > most) {
            const keep = Math.sqrt(Math.max(0, most * most - x * x)) * w;
            v = v >= 0 ? keep : -keep;
        }
        jelly._v = v;
        jelly._run.running = true;
    }

    // ms comes scaled by the caller, to land with the motion it rides on
    function kickAfter(amp, ms) {
        if (jelly.gain <= 0)
            return ;

        if (ms <= 0) {
            jelly._delay.stop();
            jelly.kick(amp);
            return ;
        }
        jelly._delay.amp = amp;
        jelly._delay.interval = ms;
        jelly._delay.restart();
    }

    function rest() {
        jelly._delay.stop();
        jelly._run.running = false;
        jelly._v = 0;
        jelly.stretch = 0;
    }

    onGainChanged: {
        if (jelly.gain <= 0)
            jelly.rest();

    }
    origin.x: jelly.target ? jelly.target.width * jelly.anchorX : 0
    origin.y: jelly.target ? jelly.target.height * jelly.anchorY : 0
    xScale: 1 - jelly.stretch * jelly.spread
    yScale: 1 + jelly.stretch

    property Timer _delay: Timer {
        property real amp: 0

        onTriggered: jelly.kick(amp)
    }

    property FrameAnimation _run: FrameAnimation {
        onTriggered: {
            const w = 2 * Math.PI * jelly.frequency;
            const c = 2 * jelly.damping * w;
            const dt = Math.min(0.05, frameTime) / Math.max(0.05, jelly.timeScale);
            const steps = Math.max(1, Math.ceil(dt / 0.004));
            const h = dt / steps;
            let x = jelly.stretch;
            let v = jelly._v;
            for (let i = 0; i < steps; i++) {
                v += (-w * w * x - c * v) * h;
                x += v * h;
            }
            if (Math.abs(x) < 0.0003 && Math.abs(v) < 0.006 * w) {
                x = 0;
                v = 0;
                running = false;
            }
            jelly._v = v;
            jelly.stretch = x;
        }
    }

}
