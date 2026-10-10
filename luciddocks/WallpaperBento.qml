import QtQuick
import qs

// The wallpaper picker as a bento: the selected wallpaper large in the middle
// of the left, the next five in tiles of different sizes to its right and the
// two before it stacked at the edge. Stepping slides every wallpaper into its
// new place, growing, shrinking and changing corners on the way.
WallpaperSlots {
    id: root

    // Settings -> Theme -> Bento: how large the main wallpaper is, and whether the
    // two before it are shown (without them the main one starts at the edge)
    readonly property bool showPrev: Prefs.wallpaperBentoPrev !== false
    readonly property real heroShare: Prefs.wallpaperBentoHero === "small" ? 0.28 : (Prefs.wallpaperBentoHero === "large" ? 0.45 : 0.34)
    readonly property real gap: 8
    readonly property real prevW: root.showPrev ? Math.round(root.width * 0.11) : 0
    readonly property real mainW: Math.round(root.width * root.heroShare)
    readonly property real restW: root.width - root.prevW - root.mainW - (root.showPrev ? 4 : 3) * root.gap
    readonly property real aW: Math.round(root.restW * 0.4)
    readonly property real bW: Math.round(root.restW * 0.3)
    readonly property real cW: root.restW - root.aW - root.bW
    readonly property real xMain: root.showPrev ? root.prevW + root.gap : 0
    readonly property real xA: root.xMain + root.mainW + root.gap
    readonly property real xB: root.xA + root.aW + root.gap
    readonly property real xC: root.xB + root.bW + root.gap
    readonly property real half: (root.stageH - root.gap) / 2
    readonly property real tall: Math.round((root.stageH - root.gap) * 0.58)
    readonly property real short: (root.stageH - root.gap) - root.tall

    slotRect: function (offset) {
        switch (offset) {
        case 0:
            return root.cell(root.xMain, 0, root.mainW, root.stageH, Theme.radiusXl, 1);
        case 1:
            return root.cell(root.xA, 0, root.aW, root.stageH, Theme.radiusLg, 0.95);
        case 2:
            return root.cell(root.xB, 0, root.bW, root.tall, Theme.radiusMd, 0.9);
        case 3:
            return root.cell(root.xB, root.tall + root.gap, root.bW, root.short, Theme.radiusMd, 0.9);
        case 4:
            return root.cell(root.xC, 0, root.cW, root.short, Theme.radiusMd, 0.85);
        case 5:
            return root.cell(root.xC, root.short + root.gap, root.cW, root.tall, Theme.radiusMd, 0.85);
        case -1:
            if (root.showPrev)
                return root.cell(0, 0, root.prevW, root.half, Theme.radiusMd, 0.8);

            break;
        case -2:
            if (root.showPrev)
                return root.cell(0, root.half + root.gap, root.prevW, root.half, Theme.radiusMd, 0.7);

            break;
        }
        // out of the picture: parked past the edge it left by
        return root.cell(offset > 0 ? root.width : -root.mainW, 0, root.cW, root.half, Theme.radiusMd, 0);
    }

    function cell(x, y, w, h, r, o) {
        return {
            "x": x,
            "y": y,
            "w": w,
            "h": h,
            "r": r,
            "o": o
        };
    }
}
