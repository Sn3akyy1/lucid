import QtQuick
import qs

// a motion pref is a length: 2 takes twice as long, 0 does not move at all.
// this shows it as a speed, faster to the right and instant at the end
M3Slider {
    id: speed

    // the lengths on offer, slowest first. 0, instant, goes last
    property var lengths: [1]
    property real length: 1

    signal picked(real length)

    // the stop nearest a length, by ratio, so a value saved before the stops
    // existed still lands on the closest one
    function stopOf(v) {
        if (v <= 0)
            return Math.max(0, speed.lengths.indexOf(0));

        let best = -1;
        for (let i = 0; i < speed.lengths.length; i++) {
            const l = speed.lengths[i];
            if (l > 0 && (best < 0 || Math.abs(Math.log(l / v)) < Math.abs(Math.log(speed.lengths[best] / v))))
                best = i;

        }
        return Math.max(0, best);
    }

    from: 0
    to: Math.max(1, speed.lengths.length - 1)
    stepSize: 1
    value: speed.stopOf(speed.length)
    onMoved: (v) => {
        return speed.picked(speed.lengths[Math.round(v)]);
    }
}
