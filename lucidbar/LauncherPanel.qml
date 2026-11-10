import QtQuick
import Quickshell
import qs

// the launcher on a full bottom bar. the dock lends its face to this panel, which
// the bar draws, so the launcher grows out of the strip as one piece of glass with
// it: drawn by the dock, a surface of its own, it frosted the bar under it and its
// glass never matched the strip's
BarPill {
    id: root

    property var dockMod: null
    readonly property bool hosting: !!root.dockMod && root.dockMod.launcherHost === root
    readonly property Item faceSlot: launcherSlot
    // it stands over the strip, not over the modules, so they stay while it is open
    readonly property bool coversBar: false

    opensOnHover: false
    compactInteractive: false
    compactHovered: false
    shown: !!root.dockMod
    compactWidth: 0
    panelWidth: root.dockMod ? Math.round(root.dockMod.menuWidth) : Theme.dp(480)
    // the strip it rises from, then the launcher above it
    panelHeight: (root.dockMod ? Math.round(root.dockMod.menuHeight) : Theme.dp(400)) + root.compactHeight
    expandedRadius: Theme.shapeXl
    onHostingChanged: {
        if (root.hosting)
            faceHome.stop();

        root.expanded = root.hosting;
    }
    onExpandedChanged: {
        // shut from the bar's side, by a click away say
        if (!root.expanded && root.hosting)
            root.dockMod.menuOpen = false;

        if (!root.expanded)
            faceHome.restart();

    }

    // the face goes back to the dock once the panel has shut
    Timer {
        id: faceHome

        interval: Theme.barDurEnter + Theme.barMs(120)
        onTriggered: {
            if (root.dockMod)
                root.dockMod.returnFace(root);

        }
    }

    panelContent: [
        // where the dock's launcher face sits: above the strip, clear of the modules on it
        Item {
            id: launcherSlot

            width: root.dockMod ? root.dockMod.menuWidth - root.dockMod.panelPadding : 0
            height: root.dockMod ? root.dockMod.menuHeight - root.dockMod.panelPadding : 0
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - root.compactHeight - height) / 2) + (Prefs.barBottom ? 0 : root.compactHeight)
        }
    ]
}
