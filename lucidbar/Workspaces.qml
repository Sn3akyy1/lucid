import QtQml.Models
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.lucidui
import "../lucidui/Shapes.js" as Shapes

Item {
    id: root

    readonly property int cornerRadius: root.popupMode ? Math.min(Theme.radiusLg, Math.round(shell.height / 2)) : (root.expanded ? Theme.radiusLg : Prefs.barPillRadius)
    property var hostWindow: null
    property var dockMod: null
    property bool expanded: false
    property real restX: 0
    property real restY: 0
    property bool everExpanded: false
    readonly property var wsById: {
        const m = ({});
        for (const w of Hyprland.workspaces.values) {
            if (w.id > 0)
                m[w.id] = w;

        }
        return m;
    }
    readonly property var monById: {
        const m = ({});
        for (const mon of Hyprland.monitors.values) m[mon.id] = mon
        return m;
    }
    readonly property var tlByAddress: {
        const m = ({});
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (o && o.address)
                m[o.address] = t;

        }
        return m;
    }
    // every display has a workspace up, so the one in use is the focused display's
    readonly property int activeWsId: {
        let shown = -1;
        for (const w of Hyprland.workspaces.values) {
            if (w.id <= 0)
                continue;

            if (w.focused)
                return w.id;

            if (w.active && shown === -1)
                shown = w.id;

        }
        return shown;
    }
    readonly property int highestWorkspaceId: {
        let max = 0;
        for (const w of Hyprland.workspaces.values) {
            if (w.id > max)
                max = w.id;

        }
        return max;
    }
    readonly property int maxWorkspaces: Prefs.workspacesShown
    // the overview has every workspace the keys reach, made yet or not; the bar
    // keeps to the first few and whatever is open past them
    readonly property int slotCount: Math.max(Monitors.workspaceCount, root.highestWorkspaceId)
    readonly property int barCount: Math.max(root.maxWorkspaces, root.highestWorkspaceId)
    // with more than one display, each workspace shows which one it is on,
    // numbered as the Displays page and its Identify overlay number them
    readonly property bool multiDisplay: Prefs.workspacesByDisplay && Monitors.workspaceKeys.length > 1
    // per regular slot: the display it is on now, or, before it exists, the one
    // the per-display plan sends it to. "" opens wherever you are
    readonly property var slotDisplays: {
        const out = [];
        for (let i = 0; i < root.slotCount; i++) {
            const ws = root.wsById[i + 1];
            const mon = ws ? ws.monitor : null;
            let key = mon ? Monitors.keyFor(mon.name, mon.description) : "";
            if (!mon && Monitors.workspacesSplit) {
                const planned = Monitors.workspacePlan.assign[String(i + 1)] || "";
                key = Monitors.workspaceKeys.indexOf(planned) !== -1 ? planned : "";
            }
            out.push(key);
        }
        return out;
    }
    readonly property var specialList: {
        const out = [];
        for (const w of Hyprland.workspaces.values) {
            if (w.id < 0 && w.name.indexOf("special:") === 0)
                out.push(w);

        }
        // lucid's own in key order, others after
        out.sort((a, b) => {
            const d = Specials.order(a.name) - Specials.order(b.name);
            return d !== 0 ? d : (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
        });
        return out;
    }
    readonly property int specialCount: root.specialList.length
    // special slots follow the regular ones, in both the pill and the overview
    readonly property int totalSlots: root.slotCount + root.specialCount
    // quickshell never marks a special workspace active, so this comes from the monitor
    readonly property string shownSpecial: {
        const o = root.refMonitor ? root.refMonitor.lastIpcObject : null;
        return o && o.specialWorkspace && o.specialWorkspace.name ? o.specialWorkspace.name : "";
    }
    readonly property int shownSpecialSlot: {
        for (let i = 0; i < root.specialCount; i++) {
            if (root.specialList[i].name === root.shownSpecial)
                return root.slotCount + i;

        }
        return -1;
    }
    readonly property int activeSlot: root.shownSpecialSlot >= 0 ? root.shownSpecialSlot : root.activeWsId - 1
    // apps stashed in each special workspace, one entry per app, parallel to specialList
    readonly property var specialApps: {
        const byName = ({});
        for (const t of Hyprland.toplevels.values) {
            const ws = t.workspace;
            if (!ws || ws.id >= 0)
                continue;

            const o = t.lastIpcObject;
            const a = String(t.address);
            const address = a.indexOf("0x") === 0 ? a : "0x" + a;
            const cls = (t.wayland && t.wayland.appId) || (o && o.class) || "";
            if (!byName[ws.name])
                byName[ws.name] = [];

            const list = byName[ws.name];
            let app = list.find((x) => {
                return x.appClass.toLowerCase() === cls.toLowerCase();
            });
            if (!app) {
                app = {
                    "address": address,
                    "appClass": cls,
                    "focused": false
                };
                list.push(app);
            }
            // a click should land on the window that was last in use
            if (t.activated === true) {
                app.address = address;
                app.focused = true;
            }
        }
        return root.specialList.map((w) => {
            return byName[w.name] || [];
        });
    }
    readonly property bool sunk: root.shownSpecialSlot >= 0 && !root.rowHovered
    // a square cell per workspace, inset from the pill's edge as far all round
    readonly property int cellInset: Theme.dp(4)
    readonly property int cellSize: Math.max(Theme.dp(16), root.compactHeight - root.cellInset * 2)
    readonly property int horizontalPadding: root.cellInset
    readonly property int dotGap: 0
    readonly property int specialGap: Theme.dp(6)
    readonly property int displayGap: Theme.dp(6)
    readonly property int badgeSize: Theme.dp(20)
    readonly property int badgeGap: Theme.dp(6)
    readonly property int litGrow: Theme.dp(14)
    readonly property int sunkSize: Theme.dp(14)
    readonly property int stashIcon: Theme.dp(16)
    readonly property int stashLead: Theme.dp(6)
    readonly property int stashMax: 3
    readonly property int stashFan: Theme.dp(20)
    readonly property int compactHeight: Theme.dp(Prefs.barHeight)
    property int hoveredSlot: -1
    readonly property bool rowHovered: rowHover.hovered && !root.expanded
    // numbered keeps the numbers the hover shows; shapes trade them for marks
    readonly property bool numbered: Prefs.workspacesStyle === "numbers"
    readonly property bool showNumbers: root.rowHovered || root.numbered
    // the shapes a workspace takes while it is the one in use, one dealt per visit
    readonly property var focusShapes: ["slanted", "oval", "pill", "triangle", "arrow", "diamond", "pentagon", "gem", "verySunny", "sunny", "cookie4", "cookie6", "cookie7", "cookie9", "cookie12", "clover4", "softBurst", "ghostish"]
    // runs of workspaces in use share one surface behind their cells
    readonly property color runColor: Theme.withBlur(Theme.surfaceHighest)
    property real sinkFade: root.sunk ? 0.5 : 1
    readonly property int litSlot: root.rowHovered && root.hoveredSlot !== -1 ? root.hoveredSlot : root.activeSlot
    onLitSlotChanged: activePill.retarget()
    readonly property bool litIndexValid: root.litSlot >= 0 && root.litSlot < root.totalSlots
    readonly property real dotsWidth: root.totalSlots > 0 ? root.slotX(root.totalSlots) - root.dotGap : 0
    property real dotsWidthAnim: root.dotsWidth
    readonly property int compactWidth: Math.round(root.dotsWidthAnim) + root.horizontalPadding * 2
    property real wheelAccum: 0
    readonly property var refMonitor: {
        if (root.hostWindow && root.hostWindow.screen) {
            const m = Hyprland.monitorFor(root.hostWindow.screen);
            if (m)
                return m;

        }
        return Hyprland.focusedMonitor;
    }
    readonly property real screenW: root.hostWindow && root.hostWindow.screen ? root.hostWindow.screen.width : 1920
    readonly property real screenH: root.hostWindow && root.hostWindow.screen ? root.hostWindow.screen.height : 1080
    readonly property real tileAspect: {
        const m = root.refMonitor;
        if (!m || !m.width || !m.height)
            return 16 / 9;

        const s = m.scale > 0 ? m.scale : 1;
        const res = (m.lastIpcObject && m.lastIpcObject.reserved) || [0, 0, 0, 0];
        const w = m.width / s - res[0] - res[2];
        const h = m.height / s - res[1] - res[3];
        if (w <= 0 || h <= 0)
            return 16 / 9;

        return Math.max(0.5, Math.min(3.6, w / h));
    }
    readonly property int basePreviewH: Theme.dp(130)
    readonly property int baseTileSpacing: Theme.dp(16)
    readonly property int baseCardPadding: Theme.dp(22)
    readonly property int baseLabelGap: Theme.dp(6)
    readonly property int baseLabelHeight: Theme.dp(16)
    readonly property int baseGroupGap: Theme.dp(40)
    // per display, every workspace has a home, so the overview shows them all,
    // made yet or not. shared, they open wherever you are, so it shows the ones
    // that exist and ends each display's block with a tile that opens a new one there
    readonly property bool sharedWorkspaces: !Monitors.workspacesSplit
    // the overview's blocks: one per display, left to right as they stand on the
    // desk, or a single one with no heading. a workspace that belongs nowhere yet
    // opens on the display in use, so it sits with that one
    readonly property var overviewGroups: {
        const shown = (i) => {
            return !root.sharedWorkspaces || !!root.wsById[i + 1];
        };
        // one block, every slot, an empty one offering a + as before
        if (!root.multiDisplay) {
            const all = [];
            for (let i = 0; i < root.slotCount; i++) all.push(i)
            return [{
                "key": "",
                "slots": all,
                "plus": false
            }];
        }
        const keys = Monitors.workspaceKeys;
        const fm = Hyprland.focusedMonitor;
        const fk = fm ? Monitors.keyFor(fm.name, fm.description) : "";
        const here = keys.indexOf(fk) !== -1 ? fk : keys[0];
        const out = [];
        for (const k of keys) {
            const slots = [];
            for (let i = 0; i < root.slotCount; i++) {
                const d = root.slotDisplays[i];
                if (shown(i) && (keys.indexOf(d) !== -1 ? d : here) === k)
                    slots.push(i);

            }
            if (slots.length > 0 || root.sharedWorkspaces)
                out.push({
                "key": k,
                "slots": slots,
                "plus": root.sharedWorkspaces
            });

        }
        return out;
    }
    // the new-workspace tiles come after every other slot, one per block
    readonly property int plusCount: root.multiDisplay && root.sharedWorkspaces ? root.overviewGroups.length : 0
    readonly property var gridPlan: {
        const groups = root.overviewGroups;
        const sizes = groups.map((g) => {
            return Math.max(1, g.slots.length + (g.plus ? 1 : 0));
        });
        const most = Math.max(1, ...sizes);
        const availW = root.screenW * 0.86 - root.baseCardPadding * 2;
        const availH = root.screenH * 0.78 - root.baseCardPadding * 2;
        const labelBlock = root.baseLabelGap + root.baseLabelHeight;
        const head = root.multiDisplay ? labelBlock : 0;
        const basePreviewW = root.basePreviewH * root.tileAspect;
        // the spacing between a block's own columns, and the wider gap between blocks
        const fixedWidth = (total) => {
            return (total - groups.length) * root.baseTileSpacing + (groups.length - 1) * root.baseGroupGap;
        };
        // a lone block tries every width; several keep their rows level, each
        // as narrow as that allows
        const candidates = [];
        for (let k = 1; k <= most; k++) {
            if (groups.length === 1)
                candidates.push([k]);
            else
                candidates.push(sizes.map((n) => {
                return Math.ceil(n / k);
            }));
        }
        let best = null;
        for (const cols of candidates) {
            let total = 0;
            let rows = 1;
            for (let g = 0; g < cols.length; g++) {
                total += cols[g];
                rows = Math.max(rows, Math.ceil(sizes[g] / cols[g]));
            }
            const wLimit = (availW - fixedWidth(total)) / total;
            const hLimit = (availH - head - (rows - 1) * root.baseTileSpacing) / rows - labelBlock;
            if (wLimit <= 24 || hLimit <= 16)
                continue;

            const previewW = Math.min(wLimit, hLimit * root.tileAspect, basePreviewW);
            const scale = previewW / basePreviewW;
            const gw = total * previewW + fixedWidth(total);
            const gh = head + rows * (previewW / root.tileAspect + labelBlock) + (rows - 1) * root.baseTileSpacing;
            const shapePenalty = Math.abs(Math.log(gw / gh / root.tileAspect));
            const score = scale - shapePenalty * 0.08;
            if (!best || score > best.score)
                best = {
                "groups": groups,
                "cols": cols,
                "total": total,
                "rows": rows,
                "previewW": previewW,
                "scale": scale,
                "score": score
            };

        }
        if (!best)
            best = {
            "groups": groups,
            "cols": sizes,
            "total": sizes.reduce((a, b) => {
                return a + b;
            }, 0),
            "rows": 1,
            "previewW": 90,
            "scale": 0.5,
            "score": 0
        };

        // columns come from the regular grid alone, so specials only ever add rows below it
        if (root.specialCount > 0) {
            const rows = best.rows + Math.ceil(root.specialCount / best.total);
            const wLimit = (availW - fixedWidth(best.total)) / best.total;
            const hLimit = (availH - head - (rows - 0.5) * root.baseTileSpacing - labelBlock) / rows - labelBlock;
            const previewW = Math.min(wLimit, hLimit * root.tileAspect, basePreviewW);
            if (previewW > 24)
                best = {
                "groups": groups,
                "cols": best.cols,
                "total": best.total,
                "rows": best.rows,
                "previewW": previewW,
                "scale": previewW / basePreviewW,
                "score": best.score
            };

        }
        return best;
    }
    readonly property int gridColumns: root.gridPlan.total
    readonly property int regularRows: root.gridPlan.rows
    readonly property int specialRows: Math.ceil(root.specialCount / root.gridColumns)
    readonly property real gridScale: Math.max(0.5, root.gridPlan.scale)
    readonly property int previewW: Math.round(root.gridPlan.previewW)
    readonly property int previewH: Math.max(Theme.dp(24), Math.round(root.gridPlan.previewW / root.tileAspect))
    readonly property int labelGap: Math.max(Theme.dp(3), Math.round(root.baseLabelGap * root.gridScale))
    readonly property int labelHeight: Math.max(Theme.dp(11), Math.round(root.baseLabelHeight * root.gridScale))
    readonly property int tileW: root.previewW
    readonly property int tileH: root.previewH + root.labelGap + root.labelHeight
    readonly property int tileSpacing: Math.max(Theme.dp(8), Math.round(root.baseTileSpacing * root.gridScale))
    readonly property int cardPadding: Math.max(Theme.dp(12), Math.round(root.baseCardPadding * Math.min(1, root.gridScale + 0.25)))
    readonly property int groupGap: Math.max(Theme.dp(16), Math.round(root.baseGroupGap * root.gridScale))
    readonly property int groupHead: root.multiDisplay ? root.labelHeight + root.labelGap : 0
    // where each display's block starts, and how wide it runs
    readonly property var groupBoxes: {
        const out = [];
        let x = 0;
        for (const c of root.gridPlan.cols) {
            const w = c * root.tileW + (c - 1) * root.tileSpacing;
            out.push({
                "x": x,
                "w": w
            });
            x += w + root.groupGap;
        }
        return out;
    }
    // every slot's place in the grid, regular ones in their display's block with
    // its new-workspace tile last. a slot the overview leaves out has none
    readonly property var slotPos: {
        const out = [];
        const stepX = root.tileW + root.tileSpacing;
        const stepY = root.tileH + root.tileSpacing;
        const plan = root.gridPlan;
        for (let g = 0; g < plan.groups.length; g++) {
            const c = Math.max(1, plan.cols[g]);
            const box = root.groupBoxes[g];
            const cells = plan.groups[g].slots.slice();
            if (plan.groups[g].plus)
                cells.push(root.totalSlots + g);

            for (let p = 0; p < cells.length; p++) out[cells[p]] = {
                "x": (box ? box.x : 0) + p % c * stepX,
                "y": root.groupHead + Math.floor(p / c) * stepY
            }
        }
        for (let j = 0; j < root.specialCount; j++) out[root.slotCount + j] = {
            "x": j % root.gridColumns * stepX,
            "y": root.specialTop + Math.floor(j / root.gridColumns) * stepY
        }
        return out;
    }
    // the slots as the eye reads them, row by row across the blocks
    readonly property var visualOrder: {
        const order = [];
        for (let i = 0; i < root.totalSlots + root.plusCount; i++) {
            if (root.slotPos[i])
                order.push(i);

        }
        return order.sort((a, b) => {
            return root.slotPosY(a) - root.slotPosY(b) || root.slotPosX(a) - root.slotPosX(b);
        });
    }
    readonly property var visualRank: {
        const rank = [];
        for (let k = 0; k < root.visualOrder.length; k++) rank[root.visualOrder[k]] = k
        return rank;
    }
    readonly property int gridWidth: {
        const boxes = root.groupBoxes;
        const last = boxes.length > 0 ? boxes[boxes.length - 1] : null;
        return last ? last.x + last.w : 0;
    }
    readonly property int regularBottom: root.groupHead + root.regularRows * (root.tileH + root.tileSpacing) - root.tileSpacing
    readonly property int captionY: root.regularBottom + Math.round(root.tileSpacing * 1.5)
    readonly property int specialTop: root.captionY + root.labelHeight + root.labelGap
    readonly property int gridHeight: root.specialRows > 0 ? root.specialTop + root.specialRows * (root.tileH + root.tileSpacing) - root.tileSpacing : root.regularBottom
    readonly property int cardWidth: root.gridWidth + root.cardPadding * 2
    readonly property int cardHeight: root.gridHeight + root.cardPadding * 2
    readonly property real labelFontSize: Math.max(Theme.dp(9), 12 * root.gridScale)
    readonly property real plusFontSize: Math.max(Theme.dp(16), 28 * root.gridScale)
    property int selectedIndex: -1
    property bool dragging: false
    property int dropSlot: -1
    property string swapTarget: ""
    property real reveal: root.expanded ? 1 : 0
    property var pendingMoves: ({
    })
    property var pendingSwaps: ({
    })
    readonly property int pendingCount: Object.keys(root.pendingMoves).length + Object.keys(root.pendingSwaps).length
    readonly property var windowList: {
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.address || !o.at || !o.size || !o.workspace)
                continue;

            if (o.mapped === false || o.hidden === true)
                continue;

            const mv = root.pendingMoves[o.address];
            const slot = root.slotForWsId(mv !== undefined ? mv.wsId : o.workspace.id);
            // a window can land on a workspace a beat before its tile does
            if (slot < 0 || !root.slotPos[slot])
                continue;

            const sw = root.pendingSwaps[o.address];
            out.push({
                "address": o.address,
                "slotIndex": slot,
                "atX": sw ? sw.atX : o.at[0],
                "atY": sw ? sw.atY : o.at[1],
                "sizeW": sw ? sw.sizeW : o.size[0],
                "sizeH": sw ? sw.sizeH : o.size[1],
                "monitor": o.monitor,
                "appClass": o.class || "",
                "focused": t.activated === true,
                "floating": o.floating === true
            });
        }
        // floating sit above tiled, so draw them last
        out.sort((a, b) => {
            return (a.floating ? 1 : 0) - (b.floating ? 1 : 0);
        });
        return out;
    }
    property string modelSignature: ""
    readonly property int trackInterval: 90
    readonly property int trackEase: 130

    function wsAt(index) {
        if (index >= root.slotCount)
            return root.specialList[index - root.slotCount] || null;

        return root.wsById[index + 1] || null;
    }

    function slotWsId(index) {
        if (index < root.slotCount)
            return index + 1;

        const ws = root.wsAt(index);
        return ws ? ws.id : 0;
    }

    function slotForWsId(id) {
        if (id > 0)
            return id <= root.slotCount ? id - 1 : -1;

        for (let i = 0; i < root.specialCount; i++) {
            if (root.specialList[i].id === id)
                return root.slotCount + i;

        }
        return -1;
    }

    function slotItem(index) {
        if (index < 0)
            return null;

        return index < root.slotCount ? dotRepeater.itemAt(index) : chipRepeater.itemAt(index - root.slotCount);
    }

    function slotOccupied(index) {
        const ws = index >= 0 && index < root.barCount ? root.wsAt(index) : null;
        return ws ? (ws.toplevels ? ws.toplevels.values.length > 0 : true) : false;
    }

    // two cells share a run when both are in use and no display gap parts them
    function joined(a, b) {
        return a >= 0 && b < root.barCount && root.slotOccupied(a) && root.slotOccupied(b) && !root.startsGroup(b);
    }

    function dealShape(prev) {
        const pool = root.focusShapes.filter((s) => {
            return s !== prev;
        });
        return pool[Math.floor(Math.random() * pool.length)];
    }

    function slotWidth(index) {
        if (index >= root.slotCount)
            return root.chipWidth(index);

        if (root.sunk)
            return root.sunkSize;

        return root.rowHovered && root.litSlot === index ? root.cellSize + root.litGrow : root.cellSize;
    }

    function slotHeight(index) {
        if (index >= root.slotCount)
            return root.cellSize;

        return root.sunk ? root.sunkSize : root.cellSize;
    }

    // a special workspace's chip is there only while that workspace is on view
    function chipOpen(index) {
        return index === root.shownSpecialSlot;
    }

    function chipLabel(j) {
        const ws = root.specialList[j];
        const n = (root.specialApps[j] || []).length;
        return (ws ? root.specialName(ws.name) : "") + (n > root.stashMax ? "  +" + (n - root.stashMax) : "");
    }

    function chipIconsEnd(k) {
        return k > 0 ? root.stashLead + root.stashIcon + (k - 1) * root.stashFan + Theme.dp(6) : Theme.dp(12);
    }

    function chipWidth(index) {
        const j = index - root.slotCount;
        const k = Math.min((root.specialApps[j] || []).length, root.stashMax);
        if (!root.chipOpen(index))
            return 0;

        return root.chipIconsEnd(k) + root.textWidth(root.chipLabel(j)) + Theme.dp(12);
    }

    function textWidth(s) {
        void nameMetrics.font;
        return Math.ceil(nameMetrics.advanceWidth(s));
    }

    function iconFor(c) {
        if (c === "")
            return "";

        if (root.dockMod)
            return root.dockMod.iconForClass(c);

        let p = Quickshell.iconPath(c, true);
        if (p === "")
            p = Quickshell.iconPath(c.toLowerCase(), true);

        if (p === "") {
            const dot = c.lastIndexOf(".");
            if (dot >= 0)
                p = Quickshell.iconPath(c.slice(dot + 1).toLowerCase(), true);

        }
        return p;
    }

    function displayNumber(index) {
        const key = index >= 0 && index < root.slotCount ? root.slotDisplays[index] : "";
        return root.multiDisplay && key !== "" ? Monitors.numberFor(key) : "";
    }

    // a run of workspaces on one display starts wherever the display changes
    function startsGroup(index) {
        return root.multiDisplay && index >= 0 && index < root.slotCount && (index === 0 || root.slotDisplays[index] !== root.slotDisplays[index - 1]);
    }

    // the room ahead of a run: a gap from the run before, and on hover its badge
    function leadWidth(index) {
        if (!root.startsGroup(index))
            return 0;

        const gap = index > 0 ? root.displayGap : 0;
        return gap + (root.rowHovered && root.displayNumber(index) !== "" ? root.badgeSize + root.badgeGap : 0);
    }

    // the overview's slots past the bar's count have no dot
    function onBar(index) {
        return index < root.barCount || index >= root.slotCount;
    }

    function slotLead(index) {
        return root.leadWidth(index) + (index >= root.slotCount && index < root.totalSlots && root.chipOpen(index) ? root.specialGap : 0);
    }

    function slotX(index) {
        let x = 0;
        for (let i = 0; i < index; i++) {
            if (root.onBar(i))
                x += root.slotLead(i) + root.slotWidth(i) + root.dotGap;

        }
        return x + root.slotLead(index);
    }

    // the corner of a slot's card, so a window reaching it can follow it in
    function cardRadius(index) {
        const w = root.wsAt(index);
        const active = index >= root.slotCount ? index === root.shownSpecialSlot : (w ? w.active : false);
        return active ? Theme.rad(18) : Theme.rad(12);
    }

    function slotPosX(index) {
        const p = root.slotPos[index];
        return p ? p.x : 0;
    }

    function slotPosY(index) {
        const p = root.slotPos[index];
        return p ? p.y : 0;
    }

    // a display's model reads best on its own; the full label is the fallback
    function displayTitle(key) {
        const o = Monitors.output(key);
        const model = o ? o.model : "";
        return model !== "" && model.indexOf("0x") !== 0 ? model : Monitors.labelFor(key);
    }

    function slotAt(px, py) {
        let best = -1;
        let bestDist = Infinity;
        for (const i of root.visualOrder) {
            const dx = px - (root.slotPosX(i) + root.tileW / 2);
            const dy = py - (root.slotPosY(i) + root.previewH / 2);
            const d = dx * dx + dy * dy;
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    // tiles come in the order they are read, not by number
    function stagger(index, extra) {
        const rank = root.visualRank[index];
        const start = 0.18 + (rank !== undefined ? rank : index) / Math.max(1, root.visualOrder.length) * 0.4 + extra;
        const t = (root.reveal - start) / 0.3;
        const c = t < 0 ? 0 : (t > 1 ? 1 : t);
        return 1 - (1 - c) * (1 - c) * (1 - c);
    }

    function luaStr(s) {
        return "'" + String(s).replace(/\\/g, "\\\\").replace(/'/g, "\\'") + "'";
    }

    function specialShort(name) {
        return name.indexOf("special:") === 0 ? name.slice(8) : name;
    }

    function specialName(name) {
        return Specials.label(name);
    }

    function toggleSpecial(name) {
        Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + root.luaStr(root.specialShort(name)) + ")");
    }

    function showSpecial(name) {
        if (root.shownSpecial !== name)
            root.toggleSpecial(name);

    }

    function hideSpecial() {
        if (root.shownSpecial !== "")
            root.toggleSpecial(root.shownSpecial);

    }

    // picking a regular workspace from the bar means leaving the special one too
    function focusWorkspace(wsId) {
        root.hideSpecial();
        Hyprland.dispatch("hl.dsp.focus({workspace=" + wsId + "})");
    }

    function isPlus(index) {
        return index >= root.totalSlots && index < root.totalSlots + root.plusCount;
    }

    // the display a new-workspace tile opens on, by output name; "" is wherever you are
    function plusMonitor(index) {
        const group = root.gridPlan.groups[index - root.totalSlots];
        return group && group.key !== "" ? Monitors.nameOf(group.key) : "";
    }

    // the lowest number nothing uses yet
    function freeWorkspaceId() {
        let n = 1;
        while (root.wsById[n])
            n++;
        return n;
    }

    // a workspace opens on the focused display, so that display comes first
    function openNewWorkspace(monitor) {
        root.hideSpecial();
        const lua = (monitor !== "" ? "hl.dispatch(hl.dsp.focus({monitor=" + root.luaStr(monitor) + "})) " : "") + "hl.dispatch(hl.dsp.focus({workspace=" + root.freeWorkspaceId() + "}))";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // moving the window makes the workspace, on whichever display hyprland
    // picks, and then the workspace goes to the one asked for
    function moveWindowToNew(address, monitor) {
        const n = root.freeWorkspaceId();
        const lua = "hl.dispatch(hl.dsp.window.move({workspace=" + n + ", follow=false, window='address:" + address + "'}))" + (monitor !== "" ? " hl.dispatch(hl.dsp.workspace.move({workspace=" + n + ", monitor=" + root.luaStr(monitor) + "}))" : "");
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function activateSlot(index) {
        if (root.isPlus(index)) {
            root.openNewWorkspace(root.plusMonitor(index));
        } else if (index >= root.slotCount) {
            const ws = root.wsAt(index);
            if (ws)
                root.showSpecial(ws.name);

        } else if (index >= 0) {
            root.focusWorkspace(index + 1);
        }
        root.expanded = false;
    }

    function cycleWorkspace(dir) {
        const cur = root.activeWsId > 0 ? root.activeWsId : 1;
        let next = cur + dir;
        if (next < 1)
            next = root.barCount;

        if (next > root.barCount)
            next = 1;

        root.focusWorkspace(next);
    }

    function focusWindow(address) {
        Hyprland.dispatch("hl.dsp.focus({window='address:" + address + "'})");
    }

    // focusing a stashed window is what opens its scratchpad
    function openStashed(index, app) {
        if (index === root.shownSpecialSlot && app.focused)
            root.hideSpecial();
        else
            root.focusWindow(app.address);
    }

    // special workspaces go by name: a negative id reads as a relative move
    function moveWindowToSlot(address, index) {
        const ws = root.wsAt(index);
        const target = index < root.slotCount ? String(index + 1) : (ws ? root.luaStr(ws.name) : "");
        if (target !== "")
            Hyprland.dispatch("hl.dsp.window.move({workspace=" + target + ", follow=false, window='address:" + address + "'})");

    }

    function swapWindows(addressA, addressB) {
        Hyprland.dispatch("hl.dsp.window.swap({target='address:" + addressB + "', window='address:" + addressA + "'})");
    }

    function closeWindow(address) {
        const lua = "local w=nil for i,win in pairs(hl.get_windows()) do if win.address=='" + address + "' then w=win end end if w then hl.dispatch(hl.dsp.window.close({window=w})) end";
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    function setPendingMove(address, wsId) {
        const pm = Object.assign({
        }, root.pendingMoves);
        pm[address] = {
            "wsId": wsId,
            "at": Date.now()
        };
        root.pendingMoves = pm;
    }

    function setPendingSwap(addressA, rowA, addressB, rowB) {
        const ps = Object.assign({
        }, root.pendingSwaps);
        const now = Date.now();
        ps[addressA] = {
            "atX": rowB.atX,
            "atY": rowB.atY,
            "sizeW": rowB.sizeW,
            "sizeH": rowB.sizeH,
            "at": now
        };
        ps[addressB] = {
            "atX": rowA.atX,
            "atY": rowA.atY,
            "sizeW": rowA.sizeW,
            "sizeH": rowA.sizeH,
            "at": now
        };
        root.pendingSwaps = ps;
    }

    function prunePending() {
        const pm = Object.assign({
        }, root.pendingMoves);
        const ps = Object.assign({
        }, root.pendingSwaps);
        const now = Date.now();
        const seen = ({
        });
        let pmChanged = false;
        let psChanged = false;
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.address)
                continue;

            seen[o.address] = true;
            const mv = pm[o.address];
            if (mv && (o.workspace && o.workspace.id === mv.wsId || now - mv.at > 2500)) {
                delete pm[o.address];
                pmChanged = true;
            }
            const sw = ps[o.address];
            if (sw && (o.at && o.at[0] === sw.atX && o.at[1] === sw.atY || now - sw.at > 2500)) {
                delete ps[o.address];
                psChanged = true;
            }
        }
        for (const a in pm) {
            if (!seen[a]) {
                delete pm[a];
                pmChanged = true;
            }
        }
        for (const b in ps) {
            if (!seen[b]) {
                delete ps[b];
                psChanged = true;
            }
        }
        if (pmChanged)
            root.pendingMoves = pm;

        if (psChanged)
            root.pendingSwaps = ps;

    }

    function syncWindowModel() {
        const wanted = root.windowList;
        let sig = "";
        for (const w of wanted) sig += w.address + "|" + w.slotIndex + "|" + w.atX + "," + w.atY + "," + w.sizeW + "," + w.sizeH + "|" + (w.focused ? 1 : 0) + ";"
        if (sig === root.modelSignature)
            return ;

        root.modelSignature = sig;
        const wantedAddrs = ({
        });
        for (const w of wanted) wantedAddrs[w.address] = true
        for (let i = windowModel.count - 1; i >= 0; i--) {
            if (!wantedAddrs[windowModel.get(i).address])
                windowModel.remove(i, 1);

        }
        for (let k = 0; k < wanted.length; k++) {
            let existing = -1;
            for (let m = k; m < windowModel.count; m++) {
                if (windowModel.get(m).address === wanted[k].address) {
                    existing = m;
                    break;
                }
            }
            if (existing === -1) {
                windowModel.insert(k, wanted[k]);
            } else {
                if (existing !== k)
                    windowModel.move(existing, k, 1);

                windowModel.set(k, wanted[k]);
            }
        }
    }

    function rowForAddress(address) {
        for (let i = 0; i < windowModel.count; i++) {
            const r = windowModel.get(i);
            if (r.address === address)
                return r;

        }
        return null;
    }

    function findSwapTarget(excludeAddress, slotIdx, px, py) {
        for (let i = 0; i < windowModel.count; i++) {
            const row = windowModel.get(i);
            if (row.address === excludeAddress || row.slotIndex !== slotIdx)
                continue;

            const item = thumbRepeater.itemAt(i);
            if (!item)
                continue;

            if (px >= item.restX && px <= item.restX + item.restW && py >= item.restY && py <= item.restY + item.restH)
                return row.address;

        }
        return "";
    }

    // only over the tiles the overview has, which in shared mode skips numbers
    function moveSelection(dx, dy) {
        const order = root.visualOrder;
        const n = order.length;
        if (n === 0)
            return ;

        let cur = root.selectedIndex;
        if (order.indexOf(cur) < 0)
            cur = order.indexOf(root.activeSlot) >= 0 ? root.activeSlot : order[0];

        // across the blocks as they are laid out, not by number
        if (dx !== 0) {
            root.selectedIndex = order[((order.indexOf(cur) + dx) % n + n) % n];
            return ;
        }
        // rows can be ragged, so step to the nearest tile in the next row
        const rows = [];
        for (const i of order) {
            const y = root.slotPosY(i);
            if (rows.indexOf(y) < 0)
                rows.push(y);

        }
        rows.sort((a, b) => {
            return a - b;
        });
        const targetY = rows[((rows.indexOf(root.slotPosY(cur)) + dy) % rows.length + rows.length) % rows.length];
        const cx = root.slotPosX(cur);
        let best = cur;
        let bestDist = Infinity;
        for (const i of order) {
            if (root.slotPosY(i) !== targetY)
                continue;

            const d = Math.abs(root.slotPosX(i) - cx);
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        root.selectedIndex = best;
    }

    function activateSelection() {
        root.activateSlot(root.selectedIndex >= 0 ? root.selectedIndex : root.activeSlot);
    }

    onWindowListChanged: root.syncWindowModel()
    property int revealDuration: Theme.barMs(200)
    property int compactFadePause: 0

    onExpandedChanged: {
        root.revealDuration = Theme.barMs(root.expanded ? 420 : 200);
        root.compactFadePause = Theme.barMs(root.expanded ? 0 : 200);
        root.selectedIndex = -1;
        root.hoveredSlot = -1;
        if (root.expanded) {
            root.everExpanded = true;
            Hyprland.refreshToplevels();
            // the tiles leave out the bar's and the dock's strips, which only
            // reach lastIpcObject.reserved on a monitor refresh
            monitorRefresh.restart();
            keyCatcher.forceActiveFocus();
        }
    }
    Component.onCompleted: {
        root.syncWindowModel();
        monitorRefresh.restart();
    }
    readonly property bool shown: Prefs.barHas("workspaces")
    property bool showTransition: false

    onShownChanged: {
        root.showTransition = true;
        showTimer.restart();
    }

    Timer {
        id: showTimer

        interval: Theme.barMs(420)
        onTriggered: root.showTransition = false
    }

    Behavior on implicitWidth {
        enabled: root.showTransition

        NumberAnimation {
            duration: Theme.barMs(380)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        enabled: root.showTransition

        NumberAnimation {
            duration: Theme.barMs(380)
            easing.type: Easing.OutCubic
        }

    }
    readonly property bool popupMode: Prefs.barPopupMode
    readonly property bool compactHovered: root.rowHovered
    // joined to a neighbour in Settings > Bar, as BarPill does it. while the
    // overview is up the module has left its slot, so the bar parts it anyway
    readonly property bool joinLeft: !!root.hostWindow && !!root.hostWindow.joinedLeftOf && root.hostWindow.joinedLeftOf("workspaces")
    readonly property bool joinRight: !!root.hostWindow && !!root.hostWindow.joinedRightOf && root.hostWindow.joinedRightOf("workspaces")
    readonly property int topRadius: Prefs.barNotch && !root.popupMode ? 0 : root.cornerRadius
    readonly property int pillTopRadius: Prefs.barNotch ? 0 : Prefs.barPillRadius
    readonly property bool popupExpanding: root.popupMode && root.expanded
    readonly property bool popupOpen: root.shown && root.popupMode && shell.y > 0.5
    readonly property int barRadius: root.popupMode ? Prefs.barPillRadius : root.cornerRadius
    readonly property int barTopRadius: root.popupMode ? root.pillTopRadius : root.topRadius
    readonly property Item popupItem: shell

    implicitWidth: root.shown ? root.compactWidth : 0
    implicitHeight: root.shown ? root.compactHeight : 0
    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.82
    transformOrigin: Item.Center
    visible: root.opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.barMs(180)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.barMs(260)
            easing.type: root.shown ? Easing.OutBack : Easing.InCubic
        }

    }
    clip: false
    x: root.restX
    y: root.restY
    z: root.popupOpen ? 100 : 1

    ListModel {
        id: windowModel
    }

    FontMetrics {
        id: nameMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fs(12)
        font.bold: true
        font.variableAxes: Theme.axes(Theme.fs(12), 620, 0)
    }

    // the "workspaces" ipc target lives in shell.qml, which can have a bar per display

    Timer {
        interval: root.trackInterval
        repeat: true
        running: root.expanded
        onTriggered: Hyprland.refreshToplevels()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.pendingCount > 0
        onTriggered: root.prunePending()
    }

    Timer {
        id: wheelReset

        interval: 350
        onTriggered: root.wheelAccum = 0
    }

    Timer {
        id: monitorRefresh

        interval: 8
        onTriggered: Hyprland.refreshMonitors()
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "activespecial" || event.name === "activespecialv2")
                monitorRefresh.restart();

        }

        target: Hyprland
    }

    HyprlandFocusGrab {
        active: root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: root.expanded = false
    }

    HoverHandler {
        id: rowHover

        enabled: !root.expanded
        onHoveredChanged: {
            if (!hovered)
                root.hoveredSlot = -1;

        }
    }

    Behavior on dotsWidthAnim {
        NumberAnimation {
            duration: Theme.barMs(300)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on sinkFade {
        NumberAnimation {
            duration: Theme.barMs(200)
            easing.type: Easing.OutCubic
        }

    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.revealDuration
            easing.type: Easing.Linear
        }

    }

    Rectangle {
        id: pillRect

        visible: root.popupMode
        width: root.compactWidth
        height: root.compactHeight
        color: Theme.bg

        Behavior on color {
            enabled: root.hostWindow ? root.hostWindow.laidOut : false

            ColorAnimation {
                duration: Theme.barMs(260)
                easing.type: Easing.OutCubic
            }

        }

        clip: true
        radius: Prefs.barPillRadius
        topLeftRadius: root.joinLeft ? 0 : root.pillTopRadius
        topRightRadius: root.joinRight ? 0 : root.pillTopRadius
        bottomLeftRadius: root.joinLeft ? 0 : Prefs.barPillRadius
        bottomRightRadius: root.joinRight ? 0 : Prefs.barPillRadius
    }

    Rectangle {
        id: shell

        readonly property real cardX: root.hostWindow ? (root.hostWindow.screen.width - root.cardWidth) / 2 - root.hostWindow.margins.left : 0
        readonly property real cardY: root.hostWindow ? (root.hostWindow.screen.height - root.cardHeight) / 2 - root.hostWindow.margins.top : 0

        width: root.popupMode ? (root.expanded ? root.cardWidth : root.compactWidth) : root.width
        height: root.popupMode ? (root.expanded ? root.cardHeight : root.compactHeight) : root.height
        x: root.popupMode && root.expanded ? shell.cardX - root.x : 0
        y: root.popupMode && root.expanded ? shell.cardY - root.y : 0
        visible: !root.popupMode || shell.y > 0.5
        color: Theme.bg
        radius: root.cornerRadius
        topLeftRadius: root.joinLeft && !root.popupMode ? 0 : root.topRadius
        topRightRadius: root.joinRight && !root.popupMode ? 0 : root.topRadius
        bottomLeftRadius: root.joinLeft && !root.popupMode ? 0 : root.cornerRadius
        bottomRightRadius: root.joinRight && !root.popupMode ? 0 : root.cornerRadius
        clip: !root.dragging

        Behavior on x {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.barDurEnter : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on y {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.barDurEnter : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on width {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.barDurEnter : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on height {
            enabled: root.popupMode

            NumberAnimation {
                duration: root.popupExpanding ? Theme.barDurEnter : Theme.barDurExit
                easing.type: Easing.Bezier
                easing.bezierCurve: root.popupExpanding ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Item {
            id: compactFace

            parent: root.popupMode ? pillRect : shell
            anchors.fill: parent
            opacity: root.popupMode || !root.expanded ? 1 : 0
            scale: root.popupMode || !root.expanded ? 1 : 0.94
            visible: opacity > 0.01

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                // the middle button opens the overview; the right one, this
                // module's card in Settings, as on the other modules
                acceptedButtons: Qt.MiddleButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton)
                        Prefs.openBarModule("workspaces");
                    else
                        root.expanded = !root.expanded;
                }
                // the wheel is taken here: a WheelHandler beside this never
                // heard it past the MouseArea, so the wheel did nothing
                onWheel: (event) => {
                    if (root.expanded || !Prefs.workspacesWheel) {
                        event.accepted = false;
                        return ;
                    }
                    root.wheelAccum += event.angleDelta.y;
                    while (root.wheelAccum >= 120) {
                        root.wheelAccum -= 120;
                        root.cycleWorkspace(-1);
                    }
                    while (root.wheelAccum <= -120) {
                        root.wheelAccum += 120;
                        root.cycleWorkspace(1);
                    }
                    wheelReset.restart();
                }
            }

            Item {
                id: dotsRow

                anchors.centerIn: parent
                width: root.dotsWidthAnim
                height: root.cellSize

                // one surface under each run of workspaces in use, drawn solid and
                // faded as a whole so the joins between cells leave no seam
                Item {
                    anchors.fill: parent
                    opacity: root.runColor.a * root.sinkFade
                    layer.enabled: opacity < 1

                    Repeater {
                        model: root.barCount

                        Rectangle {
                            id: run

                            required property int index
                            readonly property bool occupied: root.slotOccupied(run.index)
                            readonly property bool joinL: run.occupied && root.joined(run.index - 1, run.index)
                            readonly property bool joinR: run.occupied && root.joined(run.index, run.index + 1)
                            readonly property real cap: Theme.pill(run.height)
                            property real leftRadius: run.joinL ? 0 : run.cap
                            property real rightRadius: run.joinR ? 0 : run.cap

                            // a pixel into a joined neighbour, so the two edges meet
                            x: root.slotX(run.index) - (run.joinL ? 1 : 0)
                            y: (parent.height - height) / 2
                            width: root.slotWidth(run.index) + (run.joinL ? 1 : 0) + (run.joinR ? 1 : 0)
                            height: root.slotHeight(run.index)
                            color: Theme.alpha(root.runColor, 1)
                            topLeftRadius: run.leftRadius
                            bottomLeftRadius: run.leftRadius
                            topRightRadius: run.rightRadius
                            bottomRightRadius: run.rightRadius
                            opacity: run.occupied ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on leftRadius {
                                NumberAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on rightRadius {
                                NumberAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                Item {
                    id: marks

                    anchors.fill: parent

                    Repeater {
                        id: dotRepeater

                        model: root.barCount
                        onItemAdded: Qt.callLater(activePill.retarget)

                        Item {
                            id: dot

                            required property int index
                            readonly property int wsId: dot.index + 1
                            readonly property var wsObj: root.wsAt(dot.index)
                            readonly property bool isFocused: dot.wsId === root.activeWsId
                            readonly property bool isUrgent: dot.wsObj ? dot.wsObj.urgent : false
                            readonly property bool occupied: root.slotOccupied(dot.index)
                            // up on another display, as that display's own
                            readonly property bool elsewhere: !dot.isFocused && dot.wsObj ? dot.wsObj.active : false
                            readonly property string displayNumber: root.startsGroup(dot.index) ? root.displayNumber(dot.index) : ""
                            property string focusShape: root.dealShape("")
                            // a dot while empty, a square in use, a new shape each visit
                            readonly property string shape: dot.isFocused ? dot.focusShape : (dot.occupied ? "square" : "circle")
                            readonly property real markSize: root.cellSize * (dot.isFocused ? 2 / 3 : (dot.elsewhere ? 0.45 : (dot.occupied ? 1 / 3 : 1 / 4))) * (root.sunk ? root.sunkSize / root.cellSize : 1)
                            property real drawnSize: dot.markSize
                            property color ink: dot.isUrgent ? Theme.error : (dot.isFocused || dot.occupied ? Theme.text : (dot.elsewhere ? Theme.subtext : Theme.alpha(Theme.subtext, 0.5)))
                            property var fromRadii: null
                            property var toRadii: null
                            property real morph: 1
                            // until it is built the shape draws as named, unmorphed
                            readonly property var radii: !dot.toRadii ? Shapes.radii(dot.shape) : (dot.morph >= 1 || !dot.fromRadii ? dot.toRadii : Shapes.mix(dot.fromRadii, dot.toRadii, dot.morph))

                            onIsFocusedChanged: {
                                if (dot.isFocused)
                                    dot.focusShape = root.dealShape(dot.focusShape);

                            }
                            // each change morphs on from wherever the last one had got to
                            onShapeChanged: {
                                if (!dot.toRadii)
                                    return ;

                                dot.fromRadii = dot.morph >= 1 || !dot.fromRadii ? dot.toRadii : Shapes.mix(dot.fromRadii, dot.toRadii, dot.morph);
                                dot.toRadii = Shapes.radii(dot.shape);
                                dot.morph = 0;
                                morphAnim.restart();
                            }
                            Component.onCompleted: dot.toRadii = Shapes.radii(dot.shape)
                            x: root.slotX(dot.index)
                            y: (parent.height - height) / 2
                            width: root.slotWidth(dot.index)
                            height: root.slotHeight(dot.index)
                            opacity: root.sinkFade

                            NumberAnimation {
                                id: morphAnim

                                target: dot
                                property: "morph"
                                from: 0
                                to: 1
                                duration: Theme.barMs(500)
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                            // too small for the curve renderer, so tessellated and multisampled
                            Item {
                                id: form

                                x: Math.round((dot.width - root.cellSize) / 2)
                                y: Math.round((dot.height - root.cellSize) / 2)
                                width: root.cellSize
                                height: root.cellSize
                                opacity: root.showNumbers ? 0 : 1
                                scale: root.showNumbers ? 0.5 : 1
                                visible: opacity > 0.01
                                layer.enabled: true
                                layer.samples: 8
                                layer.smooth: true

                                Shape {
                                    x: (form.width - dot.drawnSize) / 2
                                    y: (form.height - dot.drawnSize) / 2
                                    width: dot.drawnSize
                                    height: dot.drawnSize
                                    preferredRendererType: Shape.GeometryRenderer

                                    ShapePath {
                                        fillColor: dot.ink
                                        strokeColor: "transparent"
                                        strokeWidth: 0

                                        PathSvg {
                                            path: Shapes.svg(dot.radii, dot.drawnSize, 0)
                                        }

                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.barMs(200)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            // numbered, an empty workspace's number is the quieter colour;
                            // hovering elsewhere, the one in use keeps the accent
                            Text {
                                anchors.centerIn: parent
                                text: dot.wsId
                                opacity: root.showNumbers ? 1 : 0
                                scale: root.showNumbers ? 1 : 0.6
                                visible: opacity > 0.01
                                color: dot.isUrgent ? Theme.error : (dot.isFocused && root.litSlot !== dot.index ? Theme.accent : (dot.isFocused || dot.occupied || dot.elsewhere ? Theme.text : Theme.alpha(Theme.subtext, 0.55)))
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(root.rowHovered ? 13 : 12)
                                font.variableAxes: Theme.axes(Theme.fs(root.rowHovered ? 13 : 12), 680, 100)

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.barMs(200)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            // the display this run is on, ahead of its first cell
                            DisplayBadge {
                                x: -root.badgeSize - root.badgeGap
                                anchors.verticalCenter: parent.verticalCenter
                                size: root.badgeSize
                                number: dot.displayNumber
                                visible: dot.displayNumber !== "" && opacity > 0.01
                                opacity: root.rowHovered ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoveredSlot = dot.index;

                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (dot.isFocused && root.shownSpecial !== "")
                                        root.hideSpecial();
                                    else if (dot.isFocused)
                                        root.expanded = true;
                                    else
                                        root.focusWorkspace(dot.wsId);
                                }
                            }

                            Behavior on drawnSize {
                                NumberAnimation {
                                    duration: Theme.barMs(500)
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                            Behavior on ink {
                                ColorAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                    Repeater {
                        id: chipRepeater

                        model: root.specialCount
                        onItemAdded: Qt.callLater(activePill.retarget)

                        Item {
                            id: chip

                            required property int index
                            readonly property int slot: root.slotCount + chip.index
                            readonly property var wsObj: root.specialList[chip.index] || null
                            readonly property var apps: root.specialApps[chip.index] || []
                            readonly property int iconCount: Math.min(chip.apps.length, root.stashMax)
                            readonly property bool open: root.chipOpen(chip.slot)

                            x: root.slotX(chip.slot)
                            y: (parent.height - height) / 2
                            width: root.slotWidth(chip.slot)
                            height: root.slotHeight(chip.slot)
                            opacity: chip.open ? 1 : 0
                            visible: opacity > 0.01
                            enabled: chip.open
                            // grows in from nothing, so nothing spills past it meanwhile
                            clip: true

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        root.hoveredSlot = chip.slot;

                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (chip.wsObj)
                                        root.toggleSpecial(chip.wsObj.name);

                                }
                            }

                            Item {
                                id: stack

                                x: root.stashLead
                                y: Math.round((chip.height - root.stashIcon) / 2)
                                width: root.stashIcon + (chip.open ? Math.max(0, chip.iconCount - 1) * root.stashFan : 0)
                                height: root.stashIcon
                                opacity: chip.open ? 1 : 0.6

                                Repeater {
                                    model: chip.iconCount

                                    Item {
                                        id: stashed

                                        required property int index
                                        readonly property var app: chip.apps[stashed.index] || null
                                        // only the front one shows while tucked; the rest fan out on open
                                        readonly property bool shown: chip.open || stashed.index === 0
                                        readonly property string glyph: {
                                            // desktop entries stream in over a few seconds
                                            void Specials.entryCount;
                                            if (!stashed.app || !chip.wsObj)
                                                return "apps";

                                            return Specials.appGlyph(stashed.app.appClass, chip.wsObj.name);
                                        }

                                        x: chip.open ? stashed.index * root.stashFan : 0
                                        z: -stashed.index
                                        width: root.stashIcon
                                        height: root.stashIcon
                                        opacity: stashed.shown ? 1 : 0
                                        scale: stashedArea.containsMouse ? 1.15 : 1

                                        Icon {
                                            anchors.centerIn: parent
                                            name: Specials.glyphName(stashed.glyph)
                                            size: root.stashIcon
                                            fill: 1
                                            color: Theme.text
                                            animateColor: false
                                        }

                                        MouseArea {
                                            id: stashedArea

                                            anchors.fill: parent
                                            enabled: chip.open && stashed.shown
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (stashed.app)
                                                    root.openStashed(chip.slot, stashed.app);

                                            }
                                        }

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.barMs(300)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: Theme.barMs(300)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: Theme.barMs(150)
                                                easing.type: Easing.OutCubic
                                            }

                                        }

                                    }

                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Text {
                                x: root.chipIconsEnd(chip.iconCount)
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.chipLabel(chip.index)
                                opacity: chip.open ? 1 : 0
                                color: Theme.subtext
                                font.family: nameMetrics.font.family
                                font.pixelSize: nameMetrics.font.pixelSize
                                font.bold: true
                                font.variableAxes: nameMetrics.font.variableAxes

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.barMs(300)
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                Rectangle {
                    id: activePill

                    readonly property int litIndex: root.litSlot
                    readonly property var litWs: root.litIndexValid ? root.wsAt(activePill.litIndex) : null
                    // rides the lit slot's own geometry, so it cannot trail it. a switch
                    // starts from where the pill was and brings each edge back onto it,
                    // the leading one first and the trailing one after, so it stretches
                    property Item target: null
                    property real offL: 0
                    property real offR: 0
                    property real offH: 0
                    property bool holding: false

                    function place() {
                        const t = activePill.target;
                        if (!t || activePill.holding)
                            return ;

                        const left = t.x + activePill.offL;
                        activePill.x = left;
                        activePill.width = Math.max(0, t.x + t.width + activePill.offR - left);
                        activePill.height = t.height + activePill.offH;
                    }

                    function retarget() {
                        // litIndexValid is a binding and can be stale inside onLitSlotChanged
                        const i = root.litSlot;
                        const next = i >= 0 && i < root.totalSlots ? root.slotItem(i) : null;
                        if (!next || next === activePill.target)
                            return ;

                        glide.stop();
                        // a destroyed target nulls out, but the last drawn geometry still stands
                        const fresh = activePill.width <= 0;
                        const left = activePill.x;
                        const right = activePill.x + activePill.width;
                        activePill.holding = true;
                        activePill.offL = fresh ? 0 : left - next.x;
                        activePill.offR = fresh ? 0 : right - (next.x + next.width);
                        activePill.offH = fresh ? 0 : activePill.height - next.height;
                        activePill.target = next;
                        activePill.holding = false;
                        activePill.place();
                        // hover follows the pointer; a switch takes the long stretch
                        const hover = rowHover.hovered && !root.expanded;
                        const lead = hover ? Theme.barMs(160) : Theme.barMs(400);
                        const trail = Math.round(lead * 1.5);
                        const forward = next.x >= left;
                        glide.curve = hover ? Theme.curveStandard : Theme.curveDefaultSpatial;
                        leftEdge.duration = forward ? trail : lead;
                        rightEdge.duration = forward ? lead : trail;
                        heightEdge.duration = lead;
                        glide.restart();
                    }

                    visible: root.litIndexValid
                    x: 0
                    y: (parent.height - height) / 2
                    width: 0
                    height: 0
                    radius: Theme.pill(activePill.height)
                    color: activePill.litWs && activePill.litWs.urgent ? Theme.error : Theme.accent
                    onOffLChanged: activePill.place()
                    onOffRChanged: activePill.place()
                    onOffHChanged: activePill.place()

                    Connections {
                        function onXChanged() {
                            activePill.place();
                        }

                        function onWidthChanged() {
                            activePill.place();
                        }

                        function onHeightChanged() {
                            activePill.place();
                        }

                        target: activePill.target
                    }

                    ParallelAnimation {
                        id: glide

                        property var curve: Theme.curveDefaultSpatial

                        NumberAnimation {
                            id: leftEdge

                            target: activePill
                            property: "offL"
                            to: 0
                            easing.type: Easing.Bezier
                            easing.bezierCurve: glide.curve
                        }

                        NumberAnimation {
                            id: rightEdge

                            target: activePill
                            property: "offR"
                            to: 0
                            easing.type: Easing.Bezier
                            easing.bezierCurve: glide.curve
                        }

                        NumberAnimation {
                            id: heightEdge

                            target: activePill
                            property: "offH"
                            to: 0
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveStandard
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barMs(200)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // the pill's own outline in the colour that reads on it, kept to
                // whatever marks lie under it, so they turn as it passes over them
                Item {
                    id: pillInk

                    anchors.fill: parent
                    visible: false

                    Rectangle {
                        x: activePill.x
                        y: activePill.y
                        width: activePill.width
                        height: activePill.height
                        radius: activePill.radius
                        color: activePill.litWs && activePill.litWs.urgent ? Theme.fgError : Theme.fgPrimary
                    }

                }

                OpacityMask {
                    anchors.fill: parent
                    visible: activePill.visible
                    source: pillInk
                    maskSource: marks
                }

            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.compactFadePause
                    }

                    NumberAnimation {
                        duration: Theme.barMs(200)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.barMs(220)
                    easing.type: Easing.OutCubic
                }

            }

        }

        Item {
            id: expandedFace

            anchors.fill: parent
            visible: root.reveal > 0.001

            Item {
                id: keyCatcher

                anchors.fill: parent
                focus: root.expanded
                Keys.onEscapePressed: root.expanded = false
                Keys.onLeftPressed: root.moveSelection(-1, 0)
                Keys.onRightPressed: root.moveSelection(1, 0)
                Keys.onUpPressed: root.moveSelection(0, -1)
                Keys.onDownPressed: root.moveSelection(0, 1)
                Keys.onReturnPressed: root.activateSelection()
                Keys.onEnterPressed: root.activateSelection()
                Keys.onTabPressed: root.moveSelection(1, 0)
                Keys.onPressed: (event) => {
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        const n = event.key - Qt.Key_0;
                        if (n <= root.slotCount) {
                            root.focusWorkspace(n);
                            root.expanded = false;
                            event.accepted = true;
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = false
            }

            Item {
                id: grid

                width: root.gridWidth
                height: root.gridHeight
                anchors.centerIn: parent
                scale: 0.94 + 0.06 * (1 - Math.pow(1 - root.reveal, 3))

                Text {
                    y: root.captionY
                    height: root.labelHeight
                    visible: root.specialCount > 0
                    opacity: root.stagger(root.slotCount, 0)
                    verticalAlignment: Text.AlignVCenter
                    text: root.specialCount > 1 ? "Scratchpads" : "Scratchpad"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Math.max(Theme.dp(10), 12 * root.gridScale)
                    font.variableAxes: Theme.axes(Math.max(10, 12 * root.gridScale), 600, 0)
                }

                // each display's number and name over its block
                Repeater {
                    model: root.multiDisplay ? root.gridPlan.groups : []

                    Item {
                        id: groupHeading

                        required property var modelData
                        required property int index
                        readonly property var box: root.groupBoxes[groupHeading.index] || null

                        x: groupHeading.box ? groupHeading.box.x : 0
                        width: groupHeading.box ? groupHeading.box.w : 0
                        height: root.labelHeight
                        opacity: root.stagger(groupHeading.modelData.slots.length > 0 ? groupHeading.modelData.slots[0] : root.totalSlots + groupHeading.index, 0)

                        DisplayBadge {
                            id: headingBadge

                            anchors.verticalCenter: parent.verticalCenter
                            size: root.labelHeight
                            number: Monitors.numberFor(groupHeading.modelData.key)
                            tint: Theme.subtextDim
                        }

                        Text {
                            anchors.left: headingBadge.right
                            anchors.leftMargin: Math.round(root.labelHeight * 0.4)
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.displayTitle(groupHeading.modelData.key)
                            elide: Text.ElideRight
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Math.max(Theme.dp(8), Theme.dp(10) * root.gridScale)
                            font.letterSpacing: 1.2
                            font.capitalization: Font.AllUppercase
                        }

                    }

                }

                Repeater {
                    id: tileRepeater

                    model: root.totalSlots

                    Item {
                        id: tile

                        required property int index
                        readonly property var wsObj: root.wsAt(tile.index)
                        readonly property bool isSpecial: tile.index >= root.slotCount
                        readonly property bool isActive: tile.isSpecial ? tile.index === root.shownSpecialSlot : (tile.wsObj ? tile.wsObj.active : false)
                        readonly property bool isUrgent: tile.wsObj ? tile.wsObj.urgent : false
                        readonly property bool isDropTarget: root.dragging && root.dropSlot === tile.index
                        readonly property bool highlighted: tileHover.hovered || root.selectedIndex === tile.index
                        readonly property string label: {
                            const w = tile.wsObj;
                            if (tile.isSpecial)
                                return root.specialName(w ? w.name : "");

                            if (w && w.name && w.name !== String(tile.index + 1))
                                return w.name;

                            return "Workspace " + (tile.index + 1);
                        }

                        visible: !!root.slotPos[tile.index]
                        x: root.slotPosX(tile.index)
                        y: root.slotPosY(tile.index)
                        width: root.tileW
                        height: root.tileH
                        opacity: root.stagger(tile.index, 0)

                        Rectangle {
                            id: card

                            width: root.previewW
                            height: root.previewH
                            radius: tile.isActive ? Theme.rad(18) : Theme.rad(12)
                            color: Theme.withBlur(tile.highlighted ? Theme.surfaceHighest : Theme.surfaceHigh)
                            border.color: tile.isUrgent ? Theme.error : ((tile.isActive || tile.isDropTarget) ? Theme.primary : "transparent")
                            border.width: (tile.isActive || tile.isUrgent || tile.isDropTarget) ? 3 : 0
                            opacity: tile.wsObj || root.multiDisplay ? 1 : 0.55

                            Behavior on radius {
                                NumberAnimation {
                                    duration: Theme.durDefaultSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }
                            scale: tileClick.pressed ? 0.985 : (tile.highlighted ? 1.03 : 1)

                            Icon {
                                anchors.centerIn: parent
                                visible: !tile.wsObj && !root.multiDisplay
                                name: "add"
                                size: Math.round(root.plusFontSize * 1.1)
                                color: Theme.accent
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barMs(150)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            id: tileHover

                            onHoveredChanged: {
                                if (hovered)
                                    root.selectedIndex = -1;

                            }
                        }

                        Text {
                            anchors.top: card.bottom
                            anchors.horizontalCenter: card.horizontalCenter
                            anchors.topMargin: root.labelGap
                            text: tile.label
                            color: tile.isActive ? Theme.primary : (tile.highlighted ? Theme.text : Theme.subtext)
                            font.family: Theme.fontFamily
                            font.pixelSize: root.labelFontSize
                            font.variableAxes: Theme.axes(root.labelFontSize, tile.isActive ? 620 : 480, 0)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                        }

                        MouseArea {
                            id: tileClick

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateSlot(tile.index)
                        }

                    }

                }

                // shared mode: the last tile of each display's block opens a new workspace there
                Repeater {
                    model: root.plusCount

                    Item {
                        id: plusTile

                        required property int index
                        readonly property int slot: root.totalSlots + plusTile.index
                        readonly property bool isDropTarget: root.dragging && root.dropSlot === plusTile.slot
                        readonly property bool highlighted: plusHover.hovered || root.selectedIndex === plusTile.slot

                        x: root.slotPosX(plusTile.slot)
                        y: root.slotPosY(plusTile.slot)
                        width: root.tileW
                        height: root.tileH
                        opacity: root.stagger(plusTile.slot, 0)

                        Rectangle {
                            id: plusCard

                            width: root.previewW
                            height: root.previewH
                            radius: Theme.rad(12)
                            color: Theme.withBlur(plusTile.highlighted ? Theme.surfaceHighest : Theme.surfaceHigh)
                            border.color: plusTile.isDropTarget ? Theme.primary : "transparent"
                            border.width: plusTile.isDropTarget ? 3 : 0
                            opacity: plusTile.highlighted || plusTile.isDropTarget ? 1 : 0.55
                            scale: plusClick.pressed ? 0.985 : (plusTile.highlighted ? 1.03 : 1)

                            Icon {
                                anchors.centerIn: parent
                                name: "add"
                                size: Math.round(root.plusFontSize * 1.1)
                                color: Theme.accent
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.barMs(150)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        HoverHandler {
                            id: plusHover

                            onHoveredChanged: {
                                if (hovered)
                                    root.selectedIndex = -1;

                            }
                        }

                        Text {
                            anchors.top: plusCard.bottom
                            anchors.horizontalCenter: plusCard.horizontalCenter
                            anchors.topMargin: root.labelGap
                            text: "New workspace"
                            color: plusTile.highlighted ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: root.labelFontSize

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(150)
                                }

                            }

                        }

                        MouseArea {
                            id: plusClick

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activateSlot(plusTile.slot)
                        }

                    }

                }

                Repeater {
                    id: thumbRepeater

                    model: windowModel

                    ClippingRectangle {
                        id: thumb

                        required property string address
                        required property int slotIndex
                        required property int atX
                        required property int atY
                        required property int sizeW
                        required property int sizeH
                        required property int monitor
                        required property string appClass
                        required property bool focused
                        readonly property var monitorObj: root.monById[thumb.monitor] || root.refMonitor
                        readonly property real monScale: thumb.monitorObj && thumb.monitorObj.scale > 0 ? thumb.monitorObj.scale : 1
                        readonly property var reserved: (thumb.monitorObj && thumb.monitorObj.lastIpcObject && thumb.monitorObj.lastIpcObject.reserved) || [0, 0, 0, 0]
                        readonly property real usableMonX: thumb.monitorObj ? thumb.monitorObj.x + thumb.reserved[0] : 0
                        readonly property real usableMonY: thumb.monitorObj ? thumb.monitorObj.y + thumb.reserved[1] : 0
                        readonly property real usableMonW: thumb.monitorObj ? Math.max(1, thumb.monitorObj.width / thumb.monScale - thumb.reserved[0] - thumb.reserved[2]) : 1
                        readonly property real usableMonH: thumb.monitorObj ? Math.max(1, thumb.monitorObj.height / thumb.monScale - thumb.reserved[1] - thumb.reserved[3]) : 1
                        readonly property real fracX: Math.max(0, Math.min(1, (thumb.atX - thumb.usableMonX) / thumb.usableMonW))
                        readonly property real fracY: Math.max(0, Math.min(1, (thumb.atY - thumb.usableMonY) / thumb.usableMonH))
                        readonly property real fracW: Math.max(0, Math.min(1, thumb.sizeW / thumb.usableMonW))
                        readonly property real fracH: Math.max(0, Math.min(1, thumb.sizeH / thumb.usableMonH))
                        readonly property real insetPad: Theme.dp(3)
                        readonly property real thumbGap: Theme.dp(4)
                        readonly property real tileX: root.slotPosX(thumb.slotIndex)
                        readonly property real tileY: root.slotPosY(thumb.slotIndex)
                        readonly property real usableW: root.previewW - thumb.insetPad * 2
                        readonly property real usableH: root.previewH - thumb.insetPad * 2
                        readonly property real clampedW: Math.min(thumb.fracW * thumb.usableW, thumb.usableW)
                        readonly property real clampedH: Math.min(thumb.fracH * thumb.usableH, thumb.usableH)
                        readonly property real clampedX: Math.min(thumb.tileX + thumb.insetPad + thumb.fracX * thumb.usableW, thumb.tileX + thumb.insetPad + thumb.usableW - thumb.clampedW)
                        readonly property real clampedY: Math.min(thumb.tileY + thumb.insetPad + thumb.fracY * thumb.usableH, thumb.tileY + thumb.insetPad + thumb.usableH - thumb.clampedH)
                        readonly property real restX: thumb.clampedX + thumb.thumbGap / 2
                        readonly property real restY: thumb.clampedY + thumb.thumbGap / 2
                        readonly property real restW: Math.max(Theme.dp(2), thumb.clampedW - thumb.thumbGap)
                        readonly property real restH: Math.max(Theme.dp(2), thumb.clampedH - thumb.thumbGap)
                        readonly property var toplevel: root.tlByAddress[thumb.address] || null
                        readonly property string iconSource: root.iconFor(thumb.appClass)
                        readonly property bool hasPreview: thumb.everHadContent || preview.hasContent
                        readonly property bool isSwapTarget: !dragHandler.active && root.swapTarget === thumb.address
                        property bool everHadContent: false
                        property real dragOriginX: 0
                        property real dragOriginY: 0
                        property int dragOriginSlot: 0

                        // the card's corner less the inset, where the window reaches it
                        readonly property real inset: thumb.insetPad + thumb.thumbGap / 2
                        readonly property real edgeTol: Theme.dp(3)
                        readonly property bool atLeft: thumb.restX - thumb.tileX - thumb.inset <= thumb.edgeTol
                        readonly property bool atTop: thumb.restY - thumb.tileY - thumb.inset <= thumb.edgeTol
                        readonly property bool atRight: thumb.tileX + root.previewW - thumb.inset - (thumb.restX + thumb.restW) <= thumb.edgeTol
                        readonly property bool atBottom: thumb.tileY + root.previewH - thumb.inset - (thumb.restY + thumb.restH) <= thumb.edgeTol
                        readonly property real innerR: Theme.dp(6)
                        property real outerR: Math.max(thumb.innerR, root.cardRadius(thumb.slotIndex) - thumb.inset)

                        x: dragHandler.active ? thumb.dragOriginX + dragHandler.translation.x : thumb.restX
                        y: dragHandler.active ? thumb.dragOriginY + dragHandler.translation.y : thumb.restY
                        width: thumb.restW
                        height: thumb.restH
                        radius: thumb.innerR
                        topLeftRadius: !dragHandler.active && thumb.atLeft && thumb.atTop ? thumb.outerR : thumb.innerR
                        topRightRadius: !dragHandler.active && thumb.atRight && thumb.atTop ? thumb.outerR : thumb.innerR
                        bottomLeftRadius: !dragHandler.active && thumb.atLeft && thumb.atBottom ? thumb.outerR : thumb.innerR
                        bottomRightRadius: !dragHandler.active && thumb.atRight && thumb.atBottom ? thumb.outerR : thumb.innerR

                        // with the card's own corner as the workspace turns active
                        Behavior on outerR {
                            NumberAnimation {
                                duration: Theme.durDefaultSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveDefaultSpatial
                            }

                        }
                        color: Theme.withBlur(Theme.bgSunken)
                        border.width: dragHandler.active || thumb.isSwapTarget || thumb.focused ? 2 : 1
                        border.color: thumb.isSwapTarget || dragHandler.active || thumb.focused ? Theme.accent : Theme.alpha(Theme.text, 0.25)
                        scale: dragHandler.active ? 1.06 : 1
                        z: dragHandler.active ? 10 : 1
                        opacity: dragHandler.active ? 0.94 : root.stagger(thumb.slotIndex, 0.08)

                        DragHandler {
                            id: dragHandler

                            target: null
                            onActiveChanged: {
                                if (active) {
                                    root.dragging = true;
                                    thumb.dragOriginSlot = thumb.slotIndex;
                                    thumb.dragOriginX = thumb.x;
                                    thumb.dragOriginY = thumb.y;
                                    return ;
                                }
                                const targetSlot = root.dropSlot >= 0 ? root.dropSlot : thumb.dragOriginSlot;
                                const swapAddress = root.swapTarget;
                                root.dragging = false;
                                root.dropSlot = -1;
                                root.swapTarget = "";
                                if (targetSlot === thumb.dragOriginSlot) {
                                    if (swapAddress !== "") {
                                        const rowA = root.rowForAddress(thumb.address);
                                        const rowB = root.rowForAddress(swapAddress);
                                        if (rowA && rowB)
                                            root.setPendingSwap(thumb.address, rowA, swapAddress, rowB);

                                        root.swapWindows(thumb.address, swapAddress);
                                    }
                                    return ;
                                }
                                if (root.isPlus(targetSlot)) {
                                    root.moveWindowToNew(thumb.address, root.plusMonitor(targetSlot));
                                    return ;
                                }
                                root.setPendingMove(thumb.address, root.slotWsId(targetSlot));
                                root.moveWindowToSlot(thumb.address, targetSlot);
                            }
                            onCentroidChanged: {
                                if (!dragHandler.active)
                                    return ;

                                const cx = thumb.x + thumb.width / 2;
                                const cy = thumb.y + thumb.height / 2;
                                const slot = root.slotAt(cx, cy);
                                root.dropSlot = slot;
                                root.swapTarget = root.findSwapTarget(thumb.address, slot, cx, cy);
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            gesturePolicy: TapHandler.DragThreshold
                            onSingleTapped: (eventPoint, button) => {
                                if (button === Qt.MiddleButton) {
                                    root.closeWindow(thumb.address);
                                    return ;
                                }
                                root.focusWindow(thumb.address);
                                root.expanded = false;
                            }
                        }

                        ScreencopyView {
                            id: preview

                            anchors.centerIn: parent
                            constraintSize.width: thumb.width
                            constraintSize.height: thumb.height
                            captureSource: root.everExpanded && thumb.toplevel ? thumb.toplevel.wayland : null
                            live: root.expanded
                            visible: thumb.everHadContent || hasContent
                            onHasContentChanged: {
                                if (hasContent)
                                    thumb.everHadContent = true;

                            }

                            transform: Scale {
                                id: fitScale

                                origin.x: preview.width / 2
                                origin.y: preview.height / 2
                                xScale: preview.width > 0 && preview.height > 0 ? Math.max(thumb.width / preview.width, thumb.height / preview.height) : 1
                                yScale: fitScale.xScale
                            }

                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.margins: Theme.dp(4)
                            width: parent.width - Theme.dp(8)
                            visible: !thumb.hasPreview && (thumb.iconSource === "" || badgeIcon.status !== Image.Ready)
                            text: thumb.appClass
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            font.variableAxes: Theme.axes(Theme.fs(10), 420, 0)
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            id: appBadge

                            readonly property real iconSize: Math.max(Theme.dp(10), Math.min(Theme.dp(22), Math.min(thumb.restW, thumb.restH) * 0.35))

                            visible: !thumb.hasPreview && thumb.iconSource !== "" && badgeIcon.status === Image.Ready
                            anchors.centerIn: parent
                            width: appBadge.iconSize
                            height: appBadge.iconSize
                            radius: appBadge.iconSize * 0.28
                            color: Theme.alpha(Theme.bg, 0.85)

                            IconImage {
                                id: badgeIcon

                                anchors.fill: parent
                                anchors.margins: Math.max(1, appBadge.iconSize * 0.1)
                                source: thumb.iconSource
                                asynchronous: true
                            }

                        }

                        Behavior on x {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: Theme.barMs(root.trackEase)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on y {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: Theme.barMs(root.trackEase)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on width {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: Theme.barMs(root.trackEase)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on height {
                            enabled: !dragHandler.active

                            NumberAnimation {
                                duration: Theme.barMs(root.trackEase)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.barMs(150)
                            }

                        }

                    }

                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.barMs(340)
                easing.type: Easing.OutCubic
            }

        }

    }

    // the seam with a joined neighbour on the left, as BarPill draws it
    Rectangle {
        visible: root.joinLeft && Prefs.barJoinDividers && !root.expanded
        x: 0
        y: Math.round((root.compactHeight - height) / 2)
        z: 5
        width: Math.max(1, Theme.dp(1))
        height: Math.round(root.compactHeight * 0.42)
        radius: width / 2
        color: Theme.alpha(Theme.text, 0.14)
    }

    states: State {
        name: "expanded"
        when: root.expanded && !root.popupMode

        PropertyChanges {
            target: root
            implicitWidth: root.cardWidth
            implicitHeight: root.cardHeight
            x: root.hostWindow ? (root.hostWindow.screen.width - root.cardWidth) / 2 - root.hostWindow.margins.left : (parent.width - root.cardWidth) / 2
            y: root.hostWindow ? (root.hostWindow.screen.height - root.cardHeight) / 2 - root.hostWindow.margins.top : (parent.height - root.cardHeight) / 2
        }

    }

    transitions: [
        Transition {
            to: "expanded"

            NumberAnimation {
                properties: "x,y"
                duration: Theme.barMs(380)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                properties: "implicitWidth,implicitHeight"
                duration: Theme.barMs(420)
                easing.type: Easing.OutBack
                easing.overshoot: 0.22
            }

        },
        Transition {
            to: ""

            NumberAnimation {
                properties: "x,y,implicitWidth,implicitHeight"
                duration: Theme.barMs(380)
                easing.type: Easing.OutCubic
            }

        }
    ]

    // a display's number on a small screen, the number the Displays page gives it
    component DisplayBadge: Item {
        id: badge

        property string number: ""
        property color tint: Theme.subtext
        property int size: Theme.dp(20)

        width: badge.size
        height: badge.size

        Icon {
            anchors.centerIn: parent
            name: "monitor"
            size: badge.size
            color: badge.tint
        }

        // inside the screen, above the stand
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(badge.size * 0.17)
            height: Math.round(badge.size * 0.5)
            verticalAlignment: Text.AlignVCenter
            text: badge.number
            color: badge.tint
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Math.max(Theme.dp(7), Math.round(badge.size * 0.42))
        }

        Behavior on tint {
            ColorAnimation {
                duration: Theme.barMs(150)
            }

        }

    }
}
