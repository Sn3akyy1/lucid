import Quickshell

// One bar module's contribution to the window's input mask or its compositor
// blur region.
//
// shell.qml used to spell this out per module: four Region blocks each, eight
// times over for the blur and twice more for the mask, with the module's id
// pasted through every line. Adding a module meant remembering all six places.
// Region.regions is read-only, so it cannot be bound to a generated array -
// but it *is* the default property, so a Region subtype can carry the whole
// per-module block and shell.qml just names the module once.
//
// A module contributes twice: its own pill, and the surface it opens. In morph
// mode the two are the same rectangle and the second is a no-op; in pop-up
// mode the second is the detached panel, which sits outside the module's own
// bounds and would otherwise be visible but unclickable.
Region {
    id: reg

    // any module built on BarPill
    property var mod: null
    // Blur regions are eroded by a pixel where they curve; input masks are
    // not. See the band regions below for why.
    property bool blur: false

    readonly property real inset: reg.blur ? 1 : 0
    // A BarPill reports its painted bounds separately from its layout bounds,
    // because the hover affordance grows the surface without moving its
    // neighbours. Anything not yet on BarPill has no such distinction, so it
    // falls back to its own rectangle.
    readonly property real bx: reg.mod ? reg.mod.x + (reg.mod.surfaceX !== undefined ? reg.mod.surfaceX : 0) : 0
    readonly property real by: reg.mod ? reg.mod.y + (reg.mod.surfaceY !== undefined ? reg.mod.surfaceY : 0) : 0
    readonly property real bw: reg.mod ? (reg.mod.surfaceWidth !== undefined ? reg.mod.surfaceWidth : reg.mod.width) : 0
    readonly property real bh: reg.mod ? (reg.mod.surfaceHeight !== undefined ? reg.mod.surfaceHeight : reg.mod.height) : 0
    readonly property int rad: reg.mod ? reg.mod.barRadius : 0

    // The pill itself.
    //
    // A blur region is a hard-edged pixel mask; a rounded corner is not. Laid
    // on a module's exact bounds the mask keeps every pixel the curve touches
    // at all, so the outermost pixels of the surface's own antialiased edge
    // sit over fully frosted desktop that the surface has barely begun to
    // paint over. That reads as a pale hairline tracing the curve.
    Region {
        x: Math.round(reg.bx + reg.inset)
        y: Math.round(reg.by + reg.inset)
        width: Math.max(0, Math.round(reg.bw - reg.inset * 2))
        height: Math.max(0, Math.round(reg.bh - reg.inset * 2))
        radius: Math.max(0, reg.rad - reg.inset)
        topLeftRadius: (reg.mod && reg.mod.barTopRadius > 0) ? reg.mod.barTopRadius - reg.inset : 0
        topRightRadius: (reg.mod && reg.mod.barTopRadius > 0) ? reg.mod.barTopRadius - reg.inset : 0
    }

    // Only the *curved* part of an outline has that problem. A flat edge is
    // hard on both sides and already lines up exactly, so pulling one in
    // leaves a pixel of surface over unblurred desktop and draws a far louder
    // dark line - which matters because in morph mode every module grows into
    // a card in place, and a pill's caps and a card's long flat sides are the
    // same edges. These two bands put the flat edges back at full extent, so
    // only the corner arcs end up pulled in. Zero-width for an input mask,
    // which wants the plain rectangle above.
    Region {
        x: Math.round(reg.bx + reg.rad)
        y: Math.round(reg.by)
        width: reg.blur ? Math.max(0, Math.round(reg.bw - reg.rad * 2)) : 0
        height: Math.round(reg.bh)
    }

    Region {
        x: Math.round(reg.bx)
        y: Math.round(reg.by + reg.rad)
        width: reg.blur ? Math.round(reg.bw) : 0
        height: Math.max(0, Math.round(reg.bh - reg.rad * 2))
    }

    // The detached pop-up panel. Keyed off popupOpen rather than the item
    // alone: a Region takes its item's geometry regardless of visibility, so
    // a closed panel's rectangle went on blurring the desktop under every
    // pill - and, less visibly, went on swallowing clicks there too.
    Region {
        item: (reg.mod && reg.mod.popupOpen) ? reg.mod.popupItem : null
        radius: reg.mod ? reg.mod.cornerRadius : 0
        topLeftRadius: reg.mod ? reg.mod.topRadius : 0
        topRightRadius: reg.mod ? reg.mod.topRadius : 0
    }

}
