import QtQuick
import Quickshell.Services.Pipewire
import qs

// a live peak meter for one node, on a dB scale, with a short hold on the
// loudest recent peak. Monitoring opens a capture stream, so it only runs
// while `running` says someone is looking
Item {
    id: meter

    property var node: null
    property bool running: true
    property real level: 0
    property real held: 0
    property double heldAt: 0
    readonly property bool live: meter.running && meter.node !== null

    // linear peaks sit near zero until it is loud; -60..0 dB reads like a real meter
    function scale(p) {
        if (!(p > 0.001))
            return 0;

        return Math.max(0, Math.min(1, (20 * Math.log10(p) + 60) / 60));
    }

    implicitWidth: 200
    implicitHeight: 6
    onLiveChanged: {
        if (!meter.live) {
            meter.level = 0;
            meter.held = 0;
        }
    }

    PwNodePeakMonitor {
        id: monitor

        node: meter.live ? meter.node : null
        enabled: meter.live
    }

    Timer {
        interval: 33
        repeat: true
        running: meter.live
        onTriggered: {
            const target = meter.scale(monitor.peak);
            meter.level = target > meter.level ? target : Math.max(target, meter.level - 0.03);
            const now = Date.now();
            if (meter.level >= meter.held) {
                meter.held = meter.level;
                meter.heldAt = now;
            } else if (now - meter.heldAt > 900) {
                meter.held = Math.max(meter.level, meter.held - 0.015);
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bgTrack

        Rectangle {
            width: meter.level > 0 ? Math.max(parent.height, parent.width * meter.level) : 0
            height: parent.height
            radius: height / 2
            // mastered music lives within a few dB of full scale, so only
            // the last fraction of a dB, where it starts to clip, turns red
            color: meter.level > 0.99 ? Theme.error : Theme.accent
        }

        Rectangle {
            visible: meter.held > 0.02
            width: 3
            height: parent.height
            radius: 1.5
            x: Math.max(0, Math.min(parent.width - width, parent.width * meter.held - width / 2))
            color: meter.held > 0.99 ? Theme.error : Theme.accent
            opacity: 0.75
        }

    }

}
