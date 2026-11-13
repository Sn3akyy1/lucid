import Quickshell
import qs

Region {
    id: reg

    property var mod: null
    property bool blur: false

    readonly property real inset: reg.blur ? 1 : 0
    readonly property real bx: reg.mod ? reg.mod.x + (reg.mod.surfaceX !== undefined ? reg.mod.surfaceX : 0) : 0
    readonly property real bw: reg.mod ? (reg.mod.surfaceWidth !== undefined ? reg.mod.surfaceWidth : reg.mod.width) : 0
    readonly property real bh: reg.mod ? (reg.mod.surfaceHeight !== undefined ? reg.mod.surfaceHeight : reg.mod.height) : 0
    // a bottom bar is the top one mirrored, so its regions are too; the window
    // works in its own coordinates and does not see the mirror
    readonly property bool mirrored: Prefs.barBottom && !!reg.mod && !!reg.mod.hostWindow
    readonly property real topY: reg.mod ? reg.mod.y + (reg.mod.surfaceY !== undefined ? reg.mod.surfaceY : 0) : 0
    readonly property real by: reg.mirrored ? reg.mod.hostWindow.height - reg.topY - reg.bh : reg.topY
    readonly property int rad: reg.mod ? reg.mod.barRadius : 0

    // a stretch of the module, given from its top edge, put where the mirror shows it
    function flipY(y, h) {
        return reg.mirrored ? reg.mod.hostWindow.height - y - h : y;
    }

    // a module with per-corner radii names them; others fall back to barRadius
    function corner(name, fallback) {
        const v = reg.mod ? reg.mod[name] : undefined;
        return Math.max(0, v !== undefined ? v : fallback);
    }

    readonly property real topLeft: reg.corner("barTopLeftRadius", reg.mod ? reg.mod.barTopRadius : 0)
    readonly property real topRight: reg.corner("barTopRightRadius", reg.mod ? reg.mod.barTopRadius : 0)
    readonly property real bottomLeft: reg.corner("barBottomLeftRadius", reg.rad)
    readonly property real bottomRight: reg.corner("barBottomRightRadius", reg.rad)
    readonly property real tlr: reg.mirrored ? reg.bottomLeft : reg.topLeft
    readonly property real trr: reg.mirrored ? reg.bottomRight : reg.topRight
    readonly property real blr: reg.mirrored ? reg.topLeft : reg.bottomLeft
    readonly property real brr: reg.mirrored ? reg.topRight : reg.bottomRight

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
        topLeftRadius: Math.max(0, reg.tlr - reg.inset)
        topRightRadius: Math.max(0, reg.trr - reg.inset)
        bottomLeftRadius: Math.max(0, reg.blr - reg.inset)
        bottomRightRadius: Math.max(0, reg.brr - reg.inset)
    }

    // bands put the flat edges back, stopping short of the rounder corner
    readonly property real leftIn: Math.max(reg.tlr, reg.blr)
    readonly property real rightIn: Math.max(reg.trr, reg.brr)
    readonly property real topIn: Math.max(reg.tlr, reg.trr)
    readonly property real bottomIn: Math.max(reg.blr, reg.brr)

    Region {
        x: reg.lo(reg.bx + reg.leftIn)
        y: reg.lo(reg.by)
        width: reg.blur ? Math.max(0, reg.hi(reg.bx + reg.bw - reg.rightIn) - reg.lo(reg.bx + reg.leftIn)) : 0
        height: Math.max(0, reg.hi(reg.by + reg.bh) - reg.lo(reg.by))
    }

    Region {
        x: reg.lo(reg.bx)
        y: reg.lo(reg.by + reg.topIn)
        width: reg.blur ? Math.max(0, reg.hi(reg.bx + reg.bw) - reg.lo(reg.bx)) : 0
        height: Math.max(0, reg.hi(reg.by + reg.bh - reg.bottomIn) - reg.lo(reg.by + reg.topIn))
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
    // the overlay layer counter-turns over the whole window height, so on the
    // bottom edge its own coordinates already are the window's
    readonly property real o0y: reg.op0 ? (reg.mirrored ? reg.op0.y : reg.mod.y + reg.op0.y) : 0
    readonly property real o1x: reg.op1 ? reg.mod.x + reg.op1.x : 0
    readonly property real o1y: reg.op1 ? (reg.mirrored ? reg.op1.y : reg.mod.y + reg.op1.y) : 0

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
    // a pop-up bent by jelly reports where it is painted
    readonly property bool painted: reg.pop !== null && reg.mod.popupPaintX !== undefined
    readonly property real pw: reg.pop ? (reg.painted ? reg.mod.popupPaintWidth : reg.pop.width) : 0
    readonly property real ph: reg.pop ? (reg.painted ? reg.mod.popupPaintHeight : reg.pop.height) : 0
    readonly property real px: reg.pop ? reg.mod.x + (reg.painted ? reg.mod.popupPaintX : reg.pop.x) : 0
    readonly property real py: reg.pop ? reg.flipY(reg.mod.y + (reg.painted ? reg.mod.popupPaintY : reg.pop.y), reg.ph) : 0
    readonly property real popTopLeft: reg.mod ? (reg.mod.popupTopLeftRadius !== undefined ? reg.mod.popupTopLeftRadius : reg.mod.topRadius) : 0
    readonly property real popTopRight: reg.mod ? (reg.mod.popupTopRightRadius !== undefined ? reg.mod.popupTopRightRadius : reg.mod.topRadius) : 0
    readonly property real popRadius: reg.mod ? reg.mod.cornerRadius : 0

    Region {
        x: reg.pop ? reg.lo(reg.px) : 0
        y: reg.pop ? reg.lo(reg.py) : 0
        width: reg.pop ? Math.max(0, reg.hi(reg.px + reg.pw) - reg.lo(reg.px)) : 0
        height: reg.pop ? Math.max(0, reg.hi(reg.py + reg.ph) - reg.lo(reg.py)) : 0
        topLeftRadius: reg.mirrored ? reg.popRadius : reg.popTopLeft
        topRightRadius: reg.mirrored ? reg.popRadius : reg.popTopRight
        bottomLeftRadius: reg.mirrored ? reg.popTopLeft : reg.popRadius
        bottomRightRadius: reg.mirrored ? reg.popTopRight : reg.popRadius
    }

    // on the blur only, the concave corners the bar draws beside the module: where
    // its open panel meets the full bar's strip, or its notch meets the top edge
    readonly property var host: reg.mod ? reg.mod.hostWindow : null
    readonly property bool flaring: reg.blur && !!reg.host && !!reg.host.notchFlareOf
    readonly property int panelLeft: reg.flaring ? reg.host.panelFlareSize(reg.mod, true) : 0
    readonly property int panelRight: reg.flaring ? reg.host.panelFlareSize(reg.mod, false) : 0
    readonly property int notchLeft: reg.flaring ? reg.host.notchFlareOf(reg.mod, true) : 0
    readonly property int notchRight: reg.flaring ? reg.host.notchFlareOf(reg.mod, false) : 0
    readonly property int notchLeftDepth: reg.flaring ? reg.host.notchDepthOf(reg.mod, true) : 0
    readonly property int notchRightDepth: reg.flaring ? reg.host.notchDepthOf(reg.mod, false) : 0

    FlareRegion {
        host: reg.host
        size: reg.panelLeft
        fx: reg.mod ? reg.mod.x - size : 0
        fy: Theme.dp(Prefs.barHeight)
    }

    FlareRegion {
        host: reg.host
        mirrored: true
        size: reg.panelRight
        fx: reg.mod ? reg.mod.x + reg.mod.width : 0
        fy: Theme.dp(Prefs.barHeight)
    }

    FlareRegion {
        host: reg.host
        size: reg.notchLeft
        depth: reg.notchLeftDepth
        fx: reg.mod ? reg.mod.x - size : 0
        fy: reg.host ? reg.host.rowY : 0
    }

    FlareRegion {
        host: reg.host
        mirrored: true
        size: reg.notchRight
        depth: reg.notchRightDepth
        fx: reg.mod ? reg.mod.x + reg.mod.width : 0
        fy: reg.host ? reg.host.rowY : 0
    }

}
