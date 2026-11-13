import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
pragma Singleton

// what a window needs to draw the pointer itself (DrawnPointer, HeldPointer): the
// pictures cursortheme.py keeps of lucid's theme, and whether a pointer drawn on a
// surface is seen at a point. it only reads, so lumen and lens can have it too
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/icons/lucid-cursors"
    property var stamp: null
    property string stampText: ""
    // hyprcursor can find the theme; legacy cursors retire it
    property bool live: false
    // bumped whenever the theme is drawn again, so pictures load anew
    property int revision: 0
    readonly property bool usable: root.live && root.stamp !== null && root.stamp.pictures !== undefined && root.stamp.hotspots !== undefined
    // the size the compositor draws the pointer at
    readonly property int size: root.stamp && root.stamp.size ? root.stamp.size : 24
    // where hyprland said things were when a drag last started: {clients, monitors}
    property var hypr: null
    // how far shake to find has grown the compositor's pointer, 1 when it hasn't.
    // the cursor plugin says so every frame while it is grown (shake.ipc)
    property real zoom: 1

    // the name qtwayland sends each of qt's shapes under
    function cssName(shape) {
        switch (shape) {
        case Qt.ArrowCursor:
            return "default";
        case Qt.UpArrowCursor:
            return "n-resize";
        case Qt.CrossCursor:
            return "crosshair";
        case Qt.IBeamCursor:
            return "text";
        case Qt.SizeVerCursor:
            return "ns-resize";
        case Qt.SizeHorCursor:
            return "ew-resize";
        case Qt.SizeBDiagCursor:
            return "nesw-resize";
        case Qt.SizeFDiagCursor:
            return "nwse-resize";
        case Qt.SizeAllCursor:
            return "all-scroll";
        case Qt.SplitVCursor:
            return "row-resize";
        case Qt.SplitHCursor:
            return "col-resize";
        case Qt.PointingHandCursor:
            return "pointer";
        case Qt.ForbiddenCursor:
            return "not-allowed";
        case Qt.WhatsThisCursor:
            return "help";
        case Qt.OpenHandCursor:
            return "grab";
        case Qt.ClosedHandCursor:
            return "grabbing";
        case Qt.DragCopyCursor:
            return "copy";
        case Qt.DragMoveCursor:
            return "move";
        case Qt.DragLinkCursor:
            return "alias";
        }
        return "";
    }

    // the picture one of qt's shapes is drawn from, "" for none
    function pictureOf(shape) {
        const css = root.cssName(shape);
        return root.usable && css !== "" && root.stamp.pictures[css] ? root.stamp.pictures[css] : "";
    }

    // read the theme again, and where the windows are: a drag starting is the moment
    // to be sure of both
    function refresh() {
        stampFile.reload();
        manifest.reload();
        if (!hyprProc.running)
            hyprProc.running = true;

    }

    // whether a pointer drawn on a window of this screen is seen at x, y of it. on the
    // overlay and top layers it always is; under them the strips the bar and the dock
    // keep, any window over the point, and not knowing all hide it. layer is a
    // WlrLayer, or -1 for an app's own window, which has to be the one in front
    function openAt(screen, x, y, layer) {
        if (layer === WlrLayer.Overlay || layer === WlrLayer.Top)
            return true;

        const h = root.hypr;
        const mon = h && screen ? h.monitors.find((m) => {
            return m.name === screen.name;
        }) : null;
        if (!mon || !mon.reserved || !(mon.scale > 0))
            return false;

        const pid = Number(Quickshell.processId);
        let gx = mon.x + x;
        let gy = mon.y + y;
        if (layer < 0) {
            const me = h.clients.find((c) => {
                return Number(c.pid) === pid && c.focusHistoryID === 0;
            });
            if (!me || !me.at)
                return false;

            gx = me.at[0] + x;
            gy = me.at[1] + y;
        }
        const turned = (mon.transform || 0) % 2 === 1;
        const w = (turned ? mon.height : mon.width) / mon.scale;
        const ht = (turned ? mon.width : mon.height) / mon.scale;
        const r = mon.reserved;
        const sx = gx - mon.x;
        const sy = gy - mon.y;
        if (sx < r[0] || sy < r[1] || sx >= w - r[2] || sy >= ht - r[3])
            return false;

        const ws = mon.activeWorkspace ? mon.activeWorkspace.id : null;
        const special = mon.specialWorkspace ? mon.specialWorkspace.id : 0;
        for (const c of h.clients) {
            if (!c.mapped || c.hidden || !c.workspace || !c.at || !c.size)
                continue;

            if (c.workspace.id !== ws && (special === 0 || c.workspace.id !== special))
                continue;

            // an app's own windows are under the one in front, whatever a reload left behind
            if (layer < 0 && Number(c.pid) === pid)
                continue;

            if (gx >= c.at[0] && gx < c.at[0] + c.size[0] && gy >= c.at[1] && gy < c.at[1] + c.size[1])
                return false;

        }
        return true;
    }

    // shakeupdate carries x,y,trail,diagonal,zoom
    Connections {
        function onRawEvent(event) {
            if (event.name === "shakeupdate") {
                const z = Number(String(event.data).split(",")[4]);
                root.zoom = z > 1 ? z : 1;
                shakeQuiet.restart();
            } else if (event.name === "shakeend") {
                root.zoom = 1;
            }
        }

        target: Hyprland
    }

    // the updates come every frame, so a pause means the end went unheard
    Timer {
        id: shakeQuiet

        interval: 250
        onTriggered: root.zoom = 1
    }

    Process {
        id: hyprProc

        command: ["sh", "-c", "printf '{\"clients\":'; hyprctl -j clients 2>/dev/null || printf '[]'; printf ',\"monitors\":'; hyprctl -j monitors 2>/dev/null || printf '[]'; printf '}'"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hypr = JSON.parse(this.text);
                } catch (e) {
                    root.hypr = null;
                }
            }
        }

    }

    FileView {
        id: stampFile

        path: root.dir + "/lucid.json"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: {
            const t = this.text();
            if (t === root.stampText)
                return ;

            root.stampText = t;
            try {
                root.stamp = JSON.parse(t);
            } catch (e) {
                root.stamp = null;
            }
            root.revision++;
        }
        onLoadFailed: {
            root.stampText = "";
            root.stamp = null;
        }
    }

    FileView {
        id: manifest

        path: root.dir + "/manifest.hl"
        watchChanges: true
        printErrors: false
        onFileChanged: this.reload()
        onLoaded: root.live = true
        onLoadFailed: root.live = false
    }

}
