import Quickshell
import qs

Region {
    id: reg

    property var mod: null
    property bool blur: false

    readonly property real inset: reg.blur ? 1 : 0
    readonly property real bx: reg.mod ? reg.mod.x + (reg.mod.surfaceX !== undefined ? reg.mod.surfaceX : 0) : 0
    readonly property real by: reg.mod ? reg.mod.y + (reg.mod.surfaceY !== undefined ? reg.mod.surfaceY : 0) : 0
    readonly property real bw: reg.mod ? (reg.mod.surfaceWidth !== undefined ? reg.mod.surfaceWidth : reg.mod.width) : 0
    readonly property real bh: reg.mod ? (reg.mod.surfaceHeight !== undefined ? reg.mod.surfaceHeight : reg.mod.height) : 0
    readonly property int rad: reg.mod ? reg.mod.barRadius : 0

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
        topLeftRadius: (reg.mod && reg.mod.barTopRadius > 0) ? reg.mod.barTopRadius - reg.inset : 0
        topRightRadius: (reg.mod && reg.mod.barTopRadius > 0) ? reg.mod.barTopRadius - reg.inset : 0
    }

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

    Region {
        item: (reg.mod && reg.mod.overlayOpen) ? reg.mod.overlayItem : null
        radius: Theme.radiusSm
    }

    readonly property var pop: (reg.mod && reg.mod.popupOpen) ? reg.mod.popupItem : null
    readonly property real px: reg.pop ? reg.mod.x + reg.pop.x : 0
    readonly property real py: reg.pop ? reg.mod.y + reg.pop.y : 0

    Region {
        x: reg.pop ? reg.lo(reg.px) : 0
        y: reg.pop ? reg.lo(reg.py) : 0
        width: reg.pop ? Math.max(0, reg.hi(reg.px + reg.pop.width) - reg.lo(reg.px)) : 0
        height: reg.pop ? Math.max(0, reg.hi(reg.py + reg.pop.height) - reg.lo(reg.py)) : 0
        radius: reg.mod ? reg.mod.cornerRadius : 0
        topLeftRadius: reg.mod ? reg.mod.topRadius : 0
        topRightRadius: reg.mod ? reg.mod.topRadius : 0
    }

}
