import QtQuick
import qs

// The wallpaper picker as a row of pills: every wallpaper a narrow pill, the one
// under the selection opens into a card and its neighbours give way. The pills'
// height is a setting (Settings -> Theme -> Pill shape):
//   uniform  all alike, a little shorter than the card
//   full     the whole height of the panel, from edge to edge, like an accordion
//   wave     as tall as a bell around the card, falling away towards the edges
WallpaperSlots {
    id: root

    readonly property string shape: Prefs.wallpaperPillsShape === "full" || Prefs.wallpaperPillsShape === "wave" ? Prefs.wallpaperPillsShape : "uniform"
    readonly property real pillW: root.shape === "wave" ? 40 : 52
    readonly property real openW: root.shape === "full" ? Math.round(root.width * 0.4) : (root.shape === "wave" ? Math.round(root.heroW * 0.9) : root.heroW)
    // full fills the panel, so its pills share whatever the card leaves; the others keep their width
    readonly property int sides: root.shape === "full" ? 8 : Math.max(2, Math.floor(((root.width - root.openW) / 2) / (root.pillW + root.itemGap)))
    readonly property real slimW: root.shape === "full" ? Math.max(Theme.dp(8), ((root.width - root.openW) / 2 - root.sides * root.itemGap) / root.sides) : root.pillW

    slotRect: function (offset) {
        var n = Math.abs(offset);
        var open = offset === 0;
        var h = root.stageH;
        if (root.shape === "uniform")
            h = open ? root.heroH : Math.round(root.heroH * 0.62);
        else if (root.shape === "wave" && !open)
            h = Math.round(root.stageH * (0.2 + 0.58 * Math.exp(-(offset * offset) / (2 * 3.2 * 3.2))));
        var fade = root.shape === "full" ? 0.06 : (root.shape === "wave" ? 0.07 : 0.045);
        return {
            "x": root.rowX(offset, root.openW, root.slimW, root.itemGap, root.sides),
            "y": Math.round((root.stageH - h) / 2),
            "w": open ? root.openW : root.slimW,
            "h": h,
            "r": open ? Theme.radiusXl : Theme.pill(root.slimW),
            "o": n > root.sides ? 0 : (open ? 1 : Math.max(0.4, 0.92 - fade * (n - 1)))
        };
    }
}
