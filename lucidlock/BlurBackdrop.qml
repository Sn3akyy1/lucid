import QtQuick
import QtQuick.Effects
import qs

// real blurred-wallpaper backdrop for a lock-screen panel/card. overlay is a
// fullscreen opaque window (bgImage covers it entirely) so there's nothing
// compositor-visible behind it for BackgroundEffect.blurRegion to work with
// - Qt composites bgImage + everything else into one opaque surface before
// the compositor ever sees it. this gets the same "real blur, not just a
// tinted rectangle" result client-side: crop the raw wallpaper to this
// item's on-screen rect and blur that crop, mirroring the
// mprisArtLayer/mprisMask pattern already used for the mpris album art.
//
// must be declared as the FIRST child of the item it backs, with that
// item's own color set to "transparent" and the tint moved into a
// Rectangle declared right after this one - a z:-1 sibling looked right on
// paper but Qt Quick's opaque-batch renderer drew the parent's own opaque
// fill on top of it regardless of z, so paint order here is guaranteed by
// plain declaration order instead.
Item {
    id: backdrop

    required property Item wallpaper
    property real cardRadius: 0
    // the crop/blur used to be sampled exactly at this item's own bounds
    // with no headroom, so the Gaussian blur's kernel had no real pixels
    // to sample past the edge and produced a visible seam right at the
    // mask boundary - oversampling a margin of wallpaper beyond the
    // visible rect (then masking back down to the real size) gives the
    // blur real neighboring data to draw from instead
    readonly property real blurMargin: 32

    anchors.fill: parent
    visible: Theme.blurAmount > 0

    Item {
        id: crop
        x: -backdrop.blurMargin
        y: -backdrop.blurMargin
        width: backdrop.width + backdrop.blurMargin * 2
        height: backdrop.height + backdrop.blurMargin * 2
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backdropMask
        }

        ShaderEffectSource {
            id: cropSource
            anchors.fill: parent
            sourceItem: backdrop.wallpaper
            live: true
            hideSource: false
            sourceRect: Qt.rect(backdrop.mapToItem(backdrop.wallpaper, -backdrop.blurMargin, -backdrop.blurMargin).x, backdrop.mapToItem(backdrop.wallpaper, -backdrop.blurMargin, -backdrop.blurMargin).y, crop.width, crop.height)
        }

        MultiEffect {
            anchors.fill: parent
            source: cropSource
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Theme.blurAmount
        }
    }

    Item {
        id: backdropMask
        x: crop.x
        y: crop.y
        width: crop.width
        height: crop.height
        visible: false
        layer.enabled: true

        Rectangle {
            x: backdrop.blurMargin
            y: backdrop.blurMargin
            width: backdrop.width
            height: backdrop.height
            radius: backdrop.cardRadius
        }
    }
}
