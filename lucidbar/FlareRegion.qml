import Quickshell
import qs

// one BarFlare's patch of the bar's blur: its square less the circle its curve
// is drawn from, a pixel wider so the hard edge stays inside the curve's
// antialiasing. by numbers, as the window does not see a bottom bar's mirror
Region {
    id: reg

    property var host: null
    property bool on: true
    // as the BarFlare is placed and turned
    property real fx: 0
    property real fy: 0
    property int size: 0
    property bool mirrored: false
    property bool flipped: false

    readonly property bool shown: reg.on && !!reg.host && reg.size >= 1
    readonly property bool turned: Prefs.barBottom && !!reg.host
    readonly property real topY: reg.turned ? reg.host.height - reg.fy - reg.size : reg.fy
    // the circle sits on the square's corner across from the filled one
    readonly property real cx: reg.fx + (reg.mirrored ? reg.size : 0)
    readonly property real cy: reg.fy + (reg.flipped ? 0 : reg.size)
    readonly property real cyShown: reg.turned ? reg.host.height - reg.cy : reg.cy

    x: Math.floor(reg.fx)
    y: Math.floor(reg.topY)
    width: reg.shown ? Math.ceil(reg.fx + reg.size) - Math.floor(reg.fx) : 0
    height: reg.shown ? Math.ceil(reg.topY + reg.size) - Math.floor(reg.topY) : 0

    Region {
        shape: RegionShape.Ellipse
        intersection: Intersection.Subtract
        x: Math.round(reg.cx) - reg.size - 1
        y: Math.round(reg.cyShown) - reg.size - 1
        width: 2 * reg.size + 2
        height: 2 * reg.size + 2
    }

}
