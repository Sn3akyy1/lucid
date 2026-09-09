import Quickshell
import qs

Region {
    id: reg

    property var frame: null
    property bool blur: false
    // "card" is the widget itself, "menu" the options panel floating beside it
    property string part: "card"

    readonly property bool isMenu: reg.part === "menu"
    // a bare variant draws straight onto the wallpaper, so nothing frosts behind it
    readonly property bool bareCard: !reg.isMenu && reg.frame !== null && reg.frame.bare === true
    readonly property bool live: reg.frame !== null && !(reg.blur && reg.bareCard) && (reg.isMenu ? reg.frame.menuVisible : (reg.frame.visible && reg.frame.width > 0.5))
    // the compositor's blur mask needs a horizontal hair of inset or the edge crawls
    readonly property real inset: reg.blur ? 1 : 0
    readonly property real bx: !reg.live ? 0 : (reg.isMenu ? reg.frame.menuX : reg.frame.x + reg.frame.surfaceX)
    readonly property real by: !reg.live ? 0 : (reg.isMenu ? reg.frame.menuY : reg.frame.y + reg.frame.surfaceY)
    readonly property real bw: !reg.live ? 0 : (reg.isMenu ? reg.frame.menuW : reg.frame.surfaceWidth)
    readonly property real bh: !reg.live ? 0 : (reg.isMenu ? reg.frame.menuH : reg.frame.surfaceHeight)
    readonly property int rad: !reg.live ? 0 : (reg.isMenu ? reg.frame.menuRadius : reg.frame.surfaceRadius)

    function lo(v) {
        return Math.ceil(v - 0.002);
    }

    function hi(v) {
        return Math.floor(v + 0.002);
    }

    Region {
        x: reg.lo(reg.bx + reg.inset)
        y: reg.lo(reg.by + reg.inset)
        width: Math.max(0, reg.hi(reg.bx + reg.bw - reg.inset) - reg.lo(reg.bx + reg.inset))
        height: Math.max(0, reg.hi(reg.by + reg.bh - reg.inset) - reg.lo(reg.by + reg.inset))
        radius: Math.max(0, reg.rad - reg.inset)
    }

    // the blur mask is hard edged, so the rounded rect above leaves notches at the corners
    Region {
        x: reg.lo(reg.bx + reg.rad)
        y: reg.lo(reg.by)
        width: reg.blur ? Math.max(0, reg.hi(reg.bx + reg.bw - reg.rad) - reg.lo(reg.bx + reg.rad)) : 0
        height: Math.max(0, reg.hi(reg.by + reg.bh) - reg.lo(reg.by))
    }

    Region {
        x: reg.lo(reg.bx)
        y: reg.lo(reg.by + reg.rad)
        width: reg.blur ? Math.max(0, reg.hi(reg.bx + reg.bw) - reg.lo(reg.bx)) : 0
        height: Math.max(0, reg.hi(reg.by + reg.bh - reg.rad) - reg.lo(reg.by + reg.rad))
    }

}
