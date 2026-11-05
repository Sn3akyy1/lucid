import QtQuick
import Quickshell
import qs

// one gap the bar fills between merged open panels, for the input mask and
// the blur. by numbers, as the window does not see a bottom bar's mirror
Region {
    id: reg

    property var host: null
    property int index: 0
    readonly property var spec: reg.host && reg.host.hangPlan.bridges.length > reg.index ? reg.host.hangPlan.bridges[reg.index] : null
    readonly property real topY: reg.spec ? (Prefs.barBottom ? reg.host.height - reg.spec.y - reg.spec.h : reg.spec.y) : 0

    x: reg.spec ? Math.floor(reg.spec.x) : 0
    y: reg.spec ? Math.floor(reg.topY) : 0
    width: reg.spec ? Math.ceil(reg.spec.x + reg.spec.w) - Math.floor(reg.spec.x) : 0
    height: reg.spec ? Math.ceil(reg.topY + reg.spec.h) - Math.floor(reg.topY) : 0
}
