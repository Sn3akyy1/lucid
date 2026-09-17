import QtQml.Models
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

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
    readonly property int activeWsId: {
        for (const w of Hyprland.workspaces.values) {
            if (w.active)
                return w.id;

        }
        return -1;
    }
    readonly property int highestWorkspaceId: {
        let max = 0;
        for (const w of Hyprland.workspaces.values) {
            if (w.id > max)
                max = w.id;

        }
        return max;
    }
    readonly property int maxWorkspaces: 6
    readonly property int slotCount: Math.max(root.maxWorkspaces, root.highestWorkspaceId)
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
    readonly property int horizontalPadding: 10
    readonly property int dotGap: 6
    readonly property int specialGap: 6
    readonly property int dotSize: 10
    readonly property int activeDotWidth: 24
    readonly property int hoverDotSize: 24
    readonly property int hoverActiveDotWidth: 38
    readonly property int sunkDotSize: 6
    readonly property int sunkActiveWidth: 14
    readonly property int stashIcon: 16
    readonly property int stashMax: 3
    readonly property int stashFan: 20
    readonly property int compactHeight: Prefs.barHeight
    property int hoveredSlot: -1
    readonly property bool rowHovered: rowHover.hovered && !root.expanded
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
    readonly property int basePreviewH: 130
    readonly property int baseTileSpacing: 16
    readonly property int baseCardPadding: 22
    readonly property int baseLabelGap: 6
    readonly property int baseLabelHeight: 16
    readonly property var gridPlan: {
        const n = Math.max(1, root.slotCount);
        const availW = root.screenW * 0.86 - root.baseCardPadding * 2;
        const availH = root.screenH * 0.78 - root.baseCardPadding * 2;
        const labelBlock = root.baseLabelGap + root.baseLabelHeight;
        const basePreviewW = root.basePreviewH * root.tileAspect;
        let best = null;
        for (let cols = 1; cols <= n; cols++) {
            const rows = Math.ceil(n / cols);
            const wLimit = (availW - (cols - 1) * root.baseTileSpacing) / cols;
            const hLimit = (availH - (rows - 1) * root.baseTileSpacing) / rows - labelBlock;
            if (wLimit <= 24 || hLimit <= 16)
                continue;

            const previewW = Math.min(wLimit, hLimit * root.tileAspect, basePreviewW);
            const scale = previewW / basePreviewW;
            const gw = cols * previewW + (cols - 1) * root.baseTileSpacing;
            const gh = rows * (previewW / root.tileAspect + labelBlock) + (rows - 1) * root.baseTileSpacing;
            const shapePenalty = Math.abs(Math.log(gw / gh / root.tileAspect));
            const score = scale - shapePenalty * 0.08;
            if (!best || score > best.score)
                best = {
                "cols": cols,
                "rows": rows,
                "previewW": previewW,
                "scale": scale,
                "score": score
            };

        }
        if (!best)
            best = {
            "cols": n,
            "rows": 1,
            "previewW": 90,
            "scale": 0.5,
            "score": 0
        };

        // columns come from the regular grid alone, so specials only ever add rows below it
        if (root.specialCount > 0) {
            const rows = Math.ceil(n / best.cols) + Math.ceil(root.specialCount / best.cols);
            const wLimit = (availW - (best.cols - 1) * root.baseTileSpacing) / best.cols;
            const hLimit = (availH - (rows - 0.5) * root.baseTileSpacing - labelBlock) / rows - labelBlock;
            const previewW = Math.min(wLimit, hLimit * root.tileAspect, basePreviewW);
            if (previewW > 24)
                best = {
                "cols": best.cols,
                "rows": rows,
                "previewW": previewW,
                "scale": previewW / basePreviewW,
                "score": best.score
            };

        }
        return best;
    }
    readonly property int gridColumns: root.gridPlan.cols
    readonly property int regularRows: Math.ceil(Math.max(1, root.slotCount) / root.gridColumns)
    readonly property int specialRows: Math.ceil(root.specialCount / root.gridColumns)
    readonly property real gridScale: Math.max(0.5, root.gridPlan.scale)
    readonly property int previewW: Math.round(root.gridPlan.previewW)
    readonly property int previewH: Math.max(24, Math.round(root.gridPlan.previewW / root.tileAspect))
    readonly property int labelGap: Math.max(3, Math.round(root.baseLabelGap * root.gridScale))
    readonly property int labelHeight: Math.max(11, Math.round(root.baseLabelHeight * root.gridScale))
    readonly property int tileW: root.previewW
    readonly property int tileH: root.previewH + root.labelGap + root.labelHeight
    readonly property int tileSpacing: Math.max(8, Math.round(root.baseTileSpacing * root.gridScale))
    readonly property int cardPadding: Math.max(12, Math.round(root.baseCardPadding * Math.min(1, root.gridScale + 0.25)))
    readonly property int gridWidth: root.gridColumns * root.tileW + (root.gridColumns - 1) * root.tileSpacing
    readonly property int regularBottom: root.regularRows * (root.tileH + root.tileSpacing) - root.tileSpacing
    readonly property int captionY: root.regularBottom + Math.round(root.tileSpacing * 1.5)
    readonly property int specialTop: root.captionY + root.labelHeight + root.labelGap
    readonly property int gridHeight: root.specialRows > 0 ? root.specialTop + root.specialRows * (root.tileH + root.tileSpacing) - root.tileSpacing : root.regularBottom
    readonly property int cardWidth: root.gridWidth + root.cardPadding * 2
    readonly property int cardHeight: root.gridHeight + root.cardPadding * 2
    readonly property real labelFontSize: Math.max(9, 12 * root.gridScale)
    readonly property real plusFontSize: Math.max(16, 28 * root.gridScale)
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
            if (slot < 0)
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

    // text flips as the accent pill arrives under it, not before
    function pillCovers(x, w) {
        const c = x + w / 2;
        return activePill.visible && c >= activePill.x && c <= activePill.x + activePill.width;
    }

    function slotWidth(index) {
        if (index >= root.slotCount)
            return root.chipWidth(index);

        if (root.rowHovered)
            return root.litSlot === index ? root.hoverActiveDotWidth : root.hoverDotSize;

        const ws = root.wsAt(index);
        const wide = index === root.activeSlot || (ws && (ws.active || ws.urgent));
        if (root.sunk)
            return wide ? root.sunkActiveWidth : root.sunkDotSize;

        return wide ? root.activeDotWidth : root.dotSize;
    }

    function slotHeight(index) {
        if (index >= root.slotCount)
            return root.chipOpen(index) ? root.hoverDotSize : root.stashIcon;

        if (root.rowHovered)
            return root.hoverDotSize;

        return root.sunk ? root.sunkDotSize : root.dotSize;
    }

    function chipOpen(index) {
        return root.rowHovered || index === root.shownSpecialSlot;
    }

    function chipLabel(j) {
        const ws = root.specialList[j];
        const n = (root.specialApps[j] || []).length;
        return (ws ? root.specialName(ws.name) : "") + (n > root.stashMax ? "  +" + (n - root.stashMax) : "");
    }

    function chipIconsEnd(k) {
        return k > 0 ? 4 + root.stashIcon + (k - 1) * root.stashFan + 6 : 10;
    }

    function chipWidth(index) {
        const j = index - root.slotCount;
        const k = Math.min((root.specialApps[j] || []).length, root.stashMax);
        if (!root.chipOpen(index))
            return k > 0 ? root.stashIcon : root.dotSize;

        return root.chipIconsEnd(k) + root.textWidth(root.chipLabel(j)) + 10;
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

    function slotX(index) {
        let x = 0;
        for (let i = 0; i < index; i++) {
            x += root.slotWidth(i) + root.dotGap;
            if (i + 1 >= root.slotCount && i + 1 < root.totalSlots)
                x += root.specialGap;

        }
        return x;
    }

    function slotPosX(index) {
        const i = index < root.slotCount ? index : index - root.slotCount;
        return i % root.gridColumns * (root.tileW + root.tileSpacing);
    }

    function slotPosY(index) {
        if (index < root.slotCount)
            return Math.floor(index / root.gridColumns) * (root.tileH + root.tileSpacing);

        return root.specialTop + Math.floor((index - root.slotCount) / root.gridColumns) * (root.tileH + root.tileSpacing);
    }

    function slotAt(px, py) {
        let best = -1;
        let bestDist = Infinity;
        for (let i = 0; i < root.totalSlots; i++) {
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

    function stagger(index, extra) {
        const start = 0.18 + index / Math.max(1, root.totalSlots) * 0.4 + extra;
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

    function activateSlot(index) {
        if (index >= root.slotCount) {
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
            next = root.slotCount;

        if (next > root.slotCount)
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

    function moveSelection(dx, dy) {
        const n = root.totalSlots;
        let cur = root.selectedIndex;
        if (cur < 0)
            cur = Math.max(0, Math.min(n - 1, root.activeSlot));

        if (dx !== 0) {
            root.selectedIndex = ((cur + dx) % n + n) % n;
            return ;
        }
        // rows can be ragged, so step to the nearest tile in the next row
        const rows = [];
        for (let i = 0; i < n; i++) {
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
        for (let i = 0; i < n; i++) {
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
            keyCatcher.forceActiveFocus();
        }
    }
    Component.onCompleted: root.syncWindowModel()
    readonly property bool shown: Prefs.showWorkspaces
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
        topLeftRadius: root.pillTopRadius
        topRightRadius: root.pillTopRadius
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
        topLeftRadius: root.topRadius
        topRightRadius: root.topRadius
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
                acceptedButtons: Qt.MiddleButton
                onClicked: root.expanded = !root.expanded
            }

            WheelHandler {
                enabled: !root.expanded
                onWheel: (event) => {
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
                height: root.hoverDotSize

                Rectangle {
                    id: activePill

                    readonly property int litIndex: root.litSlot
                    readonly property var litWs: root.litIndexValid ? root.wsAt(activePill.litIndex) : null
                    // rides the lit slot's own geometry, so it cannot trail it; a switch
                    // starts from where the pill was and glides the offset to zero
                    property Item target: null
                    property real offX: 0
                    property real offW: 0
                    property real offH: 0
                    property bool holding: false

                    function place() {
                        const t = activePill.target;
                        if (!t || activePill.holding)
                            return ;

                        activePill.x = t.x + activePill.offX;
                        activePill.width = t.width + activePill.offW;
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
                        activePill.holding = true;
                        activePill.offX = fresh ? 0 : activePill.x - next.x;
                        activePill.offW = fresh ? 0 : activePill.width - next.width;
                        activePill.offH = fresh ? 0 : activePill.height - next.height;
                        activePill.target = next;
                        activePill.holding = false;
                        activePill.place();
                        // hover follows the pointer; keyboard switches keep the long slide
                        glide.span = rowHover.hovered && !root.expanded ? Theme.barMs(80) : Theme.barMs(300);
                        glide.restart();
                    }

                    visible: root.litIndexValid
                    x: 0
                    y: (parent.height - height) / 2
                    width: 0
                    height: 0
                    radius: 999
                    color: activePill.litWs && activePill.litWs.urgent ? Theme.error : Theme.accent
                    onOffXChanged: activePill.place()
                    onOffWChanged: activePill.place()
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

                        property int span: 0

                        NumberAnimation {
                            target: activePill
                            property: "offX"
                            to: 0
                            duration: glide.span
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: activePill
                            property: "offW"
                            to: 0
                            duration: glide.span
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: activePill
                            property: "offH"
                            to: 0
                            duration: glide.span
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

                Repeater {
                    id: dotRepeater

                    model: root.slotCount
                    onItemAdded: Qt.callLater(activePill.retarget)

                    Rectangle {
                        id: dot

                        required property int index
                        readonly property int wsId: dot.index + 1
                        readonly property var wsObj: root.wsAt(dot.index)
                        readonly property bool isActive: dot.wsObj ? dot.wsObj.active : false
                        readonly property bool isUrgent: dot.wsObj ? dot.wsObj.urgent : false
                        readonly property bool isLit: root.rowHovered && root.pillCovers(dot.x, dot.width)

                        x: root.slotX(dot.index)
                        y: (parent.height - height) / 2
                        width: root.slotWidth(dot.index)
                        height: root.slotHeight(dot.index)
                        radius: 999
                        color: dot.isUrgent ? Theme.error : (root.rowHovered || dot.index === root.activeSlot ? "transparent" : Theme.withBlur(Theme._darken(Theme.subtext, 0.45)))

                        Text {
                            anchors.centerIn: parent
                            text: dot.wsId
                            opacity: root.rowHovered ? 1 : 0
                            color: dot.isLit ? Theme.bgOpaque : Theme.subtext
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(13)

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
                                if (dot.isActive && root.shownSpecial !== "")
                                    root.hideSpecial();
                                else if (dot.isActive)
                                    root.expanded = true;
                                else
                                    root.focusWorkspace(dot.wsId);
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

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(200)
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
                        readonly property bool lit: root.pillCovers(chip.x, chip.width)

                        x: root.slotX(chip.slot)
                        y: (parent.height - height) / 2
                        width: root.slotWidth(chip.slot)
                        height: root.slotHeight(chip.slot)

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

                            x: chip.open ? 4 : 0
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

                                    Shape {
                                        anchors.fill: parent
                                        preferredRendererType: Shape.CurveRenderer

                                        ShapePath {
                                            strokeWidth: 0
                                            fillColor: chip.lit ? Theme.bgOpaque : Theme.text

                                            PathSvg {
                                                path: Specials.glyphPath(stashed.glyph)
                                            }

                                        }

                                        transform: Scale {
                                            xScale: root.stashIcon / 24
                                            yScale: root.stashIcon / 24
                                        }

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

                            Behavior on x {
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

                        }

                        Text {
                            x: root.chipIconsEnd(chip.iconCount)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.chipLabel(chip.index)
                            opacity: chip.open ? 1 : 0
                            color: chip.lit ? Theme.bgOpaque : Theme.subtext
                            font.family: nameMetrics.font.family
                            font.pixelSize: nameMetrics.font.pixelSize
                            font.bold: true

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.barMs(300)
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.barMs(80)
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

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.barMs(300)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

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
                    text: root.specialCount > 1 ? "SCRATCHPADS" : "SCRATCHPAD"
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Math.max(8, 10 * root.gridScale)
                    font.letterSpacing: 1.2
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

                        x: root.slotPosX(tile.index)
                        y: root.slotPosY(tile.index)
                        width: root.tileW
                        height: root.tileH
                        opacity: root.stagger(tile.index, 0)

                        Rectangle {
                            id: card

                            width: root.previewW
                            height: root.previewH
                            radius: 10
                            color: tile.highlighted ? Theme.bgHover : "transparent"
                            border.color: tile.isUrgent ? Theme.error : ((tile.isActive || tile.highlighted || tile.isDropTarget) ? Theme.accent : Theme.alpha(Theme.text, 0.25))
                            border.width: (tile.isActive || tile.isUrgent || tile.highlighted || tile.isDropTarget) ? 2 : 1
                            opacity: tile.wsObj ? 1 : 0.5
                            scale: tileClick.pressed ? 0.985 : (tile.highlighted ? 1.03 : 1)

                            Text {
                                anchors.centerIn: parent
                                visible: !tile.wsObj
                                text: "+"
                                color: Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: root.plusFontSize
                                font.bold: true
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
                            color: tile.highlighted ? Theme.text : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: root.labelFontSize

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
                        readonly property real insetPad: 3
                        readonly property real thumbGap: 4
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
                        readonly property real restW: Math.max(2, thumb.clampedW - thumb.thumbGap)
                        readonly property real restH: Math.max(2, thumb.clampedH - thumb.thumbGap)
                        readonly property var toplevel: root.tlByAddress[thumb.address] || null
                        readonly property string iconSource: root.iconFor(thumb.appClass)
                        readonly property bool hasPreview: thumb.everHadContent || preview.hasContent
                        readonly property bool isSwapTarget: !dragHandler.active && root.swapTarget === thumb.address
                        property bool everHadContent: false
                        property real dragOriginX: 0
                        property real dragOriginY: 0
                        property int dragOriginSlot: 0

                        x: dragHandler.active ? thumb.dragOriginX + dragHandler.translation.x : thumb.restX
                        y: dragHandler.active ? thumb.dragOriginY + dragHandler.translation.y : thumb.restY
                        width: thumb.restW
                        height: thumb.restH
                        radius: 6
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
                            anchors.margins: 4
                            width: parent.width - 8
                            visible: !thumb.hasPreview && (thumb.iconSource === "" || badgeIcon.status !== Image.Ready)
                            text: thumb.appClass
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(10)
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Rectangle {
                            id: appBadge

                            readonly property real iconSize: Math.max(10, Math.min(22, Math.min(thumb.restW, thumb.restH) * 0.35))

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
}
