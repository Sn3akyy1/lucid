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

    // a module with several overlay parts hands them over as rects; anything else
    // still gets the single-item region below
    readonly property var oparts: {
        if (!reg.mod || !reg.mod.overlayOpen || reg.mod.overlayRects === undefined)
            return [];

        if (reg.blur && reg.mod.overlayBlurReady !== true)
            return [];

        return reg.mod.overlayRects;
    }
    readonly property var op0: reg.oparts.length > 0 ? reg.oparts[0] : null
    readonly property var op1: reg.oparts.length > 1 ? reg.oparts[1] : null
    readonly property real o0x: reg.op0 ? reg.mod.x + reg.op0.x : 0
    readonly property real o0y: reg.op0 ? reg.mod.y + reg.op0.y : 0
    readonly property real o1x: reg.op1 ? reg.mod.x + reg.op1.x : 0
    readonly property real o1y: reg.op1 ? reg.mod.y + reg.op1.y : 0

    Region {
        item: (reg.mod && reg.mod.overlayOpen && reg.mod.overlayRects === undefined) ? reg.mod.overlayItem : null
        radius: Theme.radiusSm
    }

    Region {
        x: reg.op0 ? reg.lo(reg.o0x + reg.inset) : 0
        y: reg.op0 ? reg.lo(reg.o0y + reg.inset) : 0
        width: reg.op0 ? Math.max(0, reg.hi(reg.o0x + reg.op0.w - reg.inset) - reg.lo(reg.o0x + reg.inset)) : 0
        height: reg.op0 ? Math.max(0, reg.hi(reg.o0y + reg.op0.h - reg.inset) - reg.lo(reg.o0y + reg.inset)) : 0
        radius: reg.op0 ? Math.max(0, reg.op0.r - reg.inset) : 0
    }

    Region {
        x: reg.op0 ? reg.lo(reg.o0x + reg.op0.r) : 0
        y: reg.op0 ? reg.lo(reg.o0y) : 0
        width: (reg.blur && reg.op0) ? Math.max(0, reg.hi(reg.o0x + reg.op0.w - reg.op0.r) - reg.lo(reg.o0x + reg.op0.r)) : 0
        height: reg.op0 ? Math.max(0, reg.hi(reg.o0y + reg.op0.h) - reg.lo(reg.o0y)) : 0
    }

    Region {
        x: reg.op0 ? reg.lo(reg.o0x) : 0
        y: reg.op0 ? reg.lo(reg.o0y + reg.op0.r) : 0
        width: (reg.blur && reg.op0) ? Math.max(0, reg.hi(reg.o0x + reg.op0.w) - reg.lo(reg.o0x)) : 0
        height: reg.op0 ? Math.max(0, reg.hi(reg.o0y + reg.op0.h - reg.op0.r) - reg.lo(reg.o0y + reg.op0.r)) : 0
    }

    Region {
        x: reg.op1 ? reg.lo(reg.o1x + reg.inset) : 0
        y: reg.op1 ? reg.lo(reg.o1y + reg.inset) : 0
        width: reg.op1 ? Math.max(0, reg.hi(reg.o1x + reg.op1.w - reg.inset) - reg.lo(reg.o1x + reg.inset)) : 0
        height: reg.op1 ? Math.max(0, reg.hi(reg.o1y + reg.op1.h - reg.inset) - reg.lo(reg.o1y + reg.inset)) : 0
        radius: reg.op1 ? Math.max(0, reg.op1.r - reg.inset) : 0
    }

    Region {
        x: reg.op1 ? reg.lo(reg.o1x + reg.op1.r) : 0
        y: reg.op1 ? reg.lo(reg.o1y) : 0
        width: (reg.blur && reg.op1) ? Math.max(0, reg.hi(reg.o1x + reg.op1.w - reg.op1.r) - reg.lo(reg.o1x + reg.op1.r)) : 0
        height: reg.op1 ? Math.max(0, reg.hi(reg.o1y + reg.op1.h) - reg.lo(reg.o1y)) : 0
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
