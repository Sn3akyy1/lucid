import Quickshell
import qs

Region {
    id: reg

    property var frame: null
    property var panel: null
    property bool blur: false
    // "card" is the widget itself. "menu" is the options panel, which lives in a
    // window of its own, and "sheet" the widget panel's: both hand their own box
    // over as panel
    property string part: "card"

    readonly property bool ownBox: reg.part !== "card"
    // a bare variant draws straight onto the wallpaper, so nothing frosts behind it
    readonly property bool bareCard: !reg.ownBox && reg.frame !== null && reg.frame.bare === true
    // the menu window is only up while the panel is, so its region tracks size,
    // not visibility: an empty region would have Hyprland blur the whole layer
    // the blur can't fade, so it's behind a card only while the card is all there:
    // left on, it outlasts a card closing, being put away or blanking out
    readonly property bool solid: !reg.blur || (reg.frame !== null && reg.frame.opacity > 0.95)
    readonly property bool live: reg.ownBox ? (reg.panel !== null && reg.panel.width > 0.5 && reg.panel.height > 0.5) : (reg.frame !== null && !(reg.blur && reg.bareCard) && reg.frame.visible && reg.frame.width > 0.5 && reg.solid)
    // the compositor's blur mask needs a horizontal hair of inset or the edge crawls
    readonly property real inset: reg.blur ? 1 : 0
    readonly property real bx: !reg.live ? 0 : (reg.ownBox ? reg.panel.x : reg.frame.x + reg.frame.surfaceX)
    readonly property real by: !reg.live ? 0 : (reg.ownBox ? reg.panel.y : reg.frame.y + reg.frame.surfaceY)
    readonly property real bw: !reg.live ? 0 : (reg.ownBox ? reg.panel.width : reg.frame.surfaceWidth)
    readonly property real bh: !reg.live ? 0 : (reg.ownBox ? reg.panel.height : reg.frame.surfaceHeight)
    readonly property int rad: !reg.live ? 0 : (reg.ownBox ? (reg.panel.cornerRadius !== undefined ? reg.panel.cornerRadius : Theme.radiusLg) : reg.frame.surfaceRadius)

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
