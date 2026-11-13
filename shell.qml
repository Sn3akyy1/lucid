//@ pragma Env QSG_DISTANCEFIELD_ANTIALIASING=gray
// qt's default subpixel text splits into colour fringes on translucent surfaces
import "./lucidbar"
import "./luciddesktop"
import "./luciddocks"
import "./lucidedit"
import "./lucidkeys"
import "./lucidlock"
import "./lucidmoji"
import "./lucidnews"
import "./lucidnotif"
import "./lucidosd"
import "./lucidpolkit"
import "./lucidprefs"
import "./lucidsession"
import "./lucidshot"
import "./lucidswitch"
import "./lucidupdate"
import "./lucidwidgets"
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.lucidicons

ShellRoot {
    id: root

    // singletons are made lazily, and these have to be up before anything
    // asks: the KDE Connect bridge and its ipc target, the bluez extras, the
    // idle daemon, which owns hypridle.conf, the environment, which owns
    // the gtk and qt appearance files, and the special workspaces, which own
    // lucid-specials.lua, the glass mirror, which owns kitty's opacity file,
    // the displays, which own lucid-monitors.lua, the bluetooth file
    // receiver, which has to be listening before anyone sends something, the
    // pairing agent, which bluez asks before letting a device in, the
    // Hyprland options, which own lucid-settings.lua and follow the palette
    // in border colours,
    // the update check, which runs whether or not the settings app is
    // ever opened, the clipboard, which owns the wl-paste watchers and so
    // has to be up long before the launcher is first opened, and night
    // light, whose schedule runs whether or not the System pill is shown,
    // the sounds, so their ipc target answers before anything has played,
    // storage, which warns when space runs low and empties old trash, the
    // alarms, which ring whether or not anything shows them, and the clock
    // app's line, which has to be listening before the app is opened
    Component.onCompleted: {
        void KdeConnect.installed;
        void Bt.present;
        void BtReceive.status;
        void BtAgent.status;
        void Net.connectivity;
        void Idle.probed;
        void Env.probed;
        void Pointer.ready;
        void Specials.moduleProbed;
        void Glass.probed;
        void Monitors.probed;
        void HyprConfig.moduleProbed;
        void Startup.moduleProbed;
        void Updates.current;
        void Notifs.count;
        void Clip.probed;
        void Users.probed;
        void Polkit.registered;
        void Chrono.now;
        void Agenda.tick;
        void Alarms.tick;
        void ClockLink.peerCount;
        void Zones.offsets;
        void Capture.state;
        void NightLight.active;
        void LiveWall.wanted;
        void Sounds.dir;
        void Storage.watching;
        void WallTransitions.active;
        void Edit.active;
        // the combined output is remade at login by the service that keeps it
        if (Prefs.audioCombine !== "")
            void Audio.sink;

    }

    // lucid's icon set, picked on the Environment page; lumen reads prefs.json for its own
    Binding {
        target: LucidIcons
        property: "set"
        value: Prefs.envIconSet
    }

    // a capture nobody on screen is showing yet: a card, a notification, or
    // nothing but the clipboard, as Settings says
    function announceShot(entry) {
        if (Prefs.shotPreview === "preview") {
            shotCards.show(entry);
            return ;
        }
        if (Prefs.shotPreview !== "notify")
            return ;

        const where = String(entry.file).replace(Quickshell.env("HOME"), "~");
        if (entry.kind === "video")
            Quickshell.execDetached(["notify-send", "-a", "LucidShot", "-i", "media-record", "Recording saved", where]);
        else
            Quickshell.execDetached(["sh", "-c", "a=$(notify-send -a LucidShot -i \"$1\" -A 'edit=Mark up' -A 'open=Open' --wait \"$2\" \"$3\"); case \"$a\" in edit) qs ipc call snap edit \"$1\" ;; open) xdg-open \"$1\" ;; esac; true", "sh", entry.file, entry.temp ? "Screenshot copied" : "Screenshot saved", entry.temp ? "It is on the clipboard only" : where]);
    }

    // the bar that speaks for the shell, of however many there are
    function mainBar() {
        const list = bars.instances;
        for (let i = 0; i < list.length; i++) {
            if (list[i].primary)
                return list[i];

        }
        return list.length > 0 ? list[0] : null;
    }

    // the modules' own ipc targets, here rather than in each bar, which would
    // claim them once per display: each reaches the main bar
    IpcHandler {
        target: "clock"

        // qs ipc call clock open timer
        function open(page: string): void {
            const b = root.mainBar();
            if (b)
                b.clockModule.openTab(page === "" ? "today" : page);

        }

        // the clock app, on a page or where it was left
        function app(page: string): void {
            Quickshell.execDetached(page === "" ? [Quickshell.shellPath("lucidclock/clock")] : [Quickshell.shellPath("lucidclock/clock"), page]);
        }

        function toggle(): void {
            const b = root.mainBar();
            if (b)
                b.clockModule.expanded = !b.clockModule.expanded;

        }

        function close(): void {
            const b = root.mainBar();
            if (b)
                b.clockModule.expanded = false;

        }

    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            const b = root.mainBar();
            if (!b)
                return ;

            if (b.mprisModule.expanded)
                b.mprisModule.expanded = false;
            else
                b.mprisModule.openPanel("player");
        }

        function open(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.openPanel("player");

        }

        function close(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.expanded = false;

        }

        function identify(): void {
            const b = root.mainBar();
            if (!b)
                return ;

            b.mprisModule.openPanel("shazam");
            b.mprisModule.startListening();
        }

        function lyrics(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.openPanel("lyrics");

        }

        function playPause(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.togglePlay();

        }

        function next(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.skip(1);

        }

        function previous(): void {
            const b = root.mainBar();
            if (b)
                b.mprisModule.skip(-1);

        }

    }

    IpcHandler {
        target: "workspaces"

        function toggle(): void {
            const b = root.mainBar();
            if (b)
                b.workspacesModule.expanded = !b.workspacesModule.expanded;

        }

        function open(): void {
            const b = root.mainBar();
            if (b)
                b.workspacesModule.expanded = true;

        }

        function close(): void {
            const b = root.mainBar();
            if (b)
                b.workspacesModule.expanded = false;

        }

    }

    IpcHandler {
        target: "controlcentre"

        function toggle(): void {
            const b = root.mainBar();
            if (b)
                b.systemModule.expanded = !b.systemModule.expanded;

        }

        function open(): void {
            const b = root.mainBar();
            if (b)
                b.systemModule.expanded = true;

        }

        function close(): void {
            const b = root.mainBar();
            if (b)
                b.systemModule.expanded = false;

        }

    }

    // one bar, or one on every display when Settings > Displays asks for it
    Variants {
        id: bars

        model: Monitors.barEverywhere ? Quickshell.screens : [""]

        PanelWindow {
            id: bar

            // a display from Quickshell.screens with a bar on every one, or "" for the one bar
            required property var modelData
            // the bar that speaks for the shell: it alone turns into notification
            // popups, raises the privacy toast and answers the modules' ipc
            readonly property bool primary: !Monitors.barEverywhere || bar.screen === Monitors.popupScreen
            // what the shell's ipc targets reach on the main bar
            readonly property var clockModule: clockMod
            readonly property var mprisModule: mprisMod
            readonly property var workspacesModule: workspacesMod
            readonly property var systemModule: systemMod

            PaletteFade {
                active: bar.visible
            }

            PointerPoke {
            }

            // the display Settings > Displays picks, or this one's own. gated,
            // because unset must leave the choice to hyprland, which null would not
            Binding {
                target: bar
                property: "screen"
                value: bar.modelData !== "" ? bar.modelData : Monitors.barPlacement
                when: bar.modelData !== "" || Monitors.barPlacement !== null
            }

            visible: Prefs.loaded && Prefs.barEnabled && Monitors.surfacesUp
            property bool laidOut: false
            // stand-ins take room in edit mode, so this asks after the modules themselves
            readonly property bool anyModuleShown: Prefs.barZones.some((zone) => {
                return bar.zoneKeys(zone).some((key) => {
                    return bar.realWidthOf(key) > 0.5;
                });
            })
            // edit mode: the module in hand, how far it sits off its slot, and the
            // arrangement the bar shows while it is held
            property real editT: Edit.active ? 1 : 0
            // in edit mode the modules part a little, so each gap has room for its clasp
            readonly property real editGap: Theme.dp(16) * bar.editT
            property string dragKey: ""
            property real dragShift: 0
            property real dragLift: 0
            property var dragGroups: null
            property bool dragHeld: false

            Behavior on editT {
                NumberAnimation {
                    duration: Theme.barMs(320)
                    easing.type: Easing.OutCubic
                }

            }

            function xOf(key) {
                return bar.placeFor(key) + (key === bar.dragKey ? bar.dragShift : 0);
            }

            function liftOf(key) {
                return key === bar.dragKey ? bar.dragLift : 0;
            }

            // a right click on a module: its sheet, on the side of the screen away from it
            function editModule(key) {
                const mod = bar.pillFor[key];
                const cx = bar.xOf(key) + (mod ? mod.width : 0) / 2;
                Edit.openSheet("module", key, Edit.sideFor(cx, bar.width), bar.screen ? bar.screen.name : "");
            }

            // the sheet's open button: this bar's module opens as a click would open it
            Connections {
                function onModuleOpenRequested(id, screen) {
                    if (screen !== "" ? (!bar.screen || bar.screen.name !== screen) : !bar.primary)
                        return ;

                    const mod = bar.pillFor[id];
                    if (!mod)
                        return ;

                    if (id === "start") {
                        dock.openLauncher("");
                    } else if (id === "media") {
                        mod.openPanel("player");
                    } else {
                        if (mod.compactClicked)
                            mod.compactClicked();

                        mod.expanded = true;
                    }
                }

                target: Edit
            }

            // keys, when given, lets modules joined to the next one sit flush against it
            function placeGroup(widths, originX, keys) {
                const gap = Theme.dp(Prefs.barSpacing) + bar.editGap;
                const out = [];
                // on whole pixels: two joined modules meeting mid-pixel would each
                // antialias the shared edge and let the wallpaper through there
                let x = Math.round(originX);
                let end = x;
                let any = false;
                for (let i = 0; i < widths.length; i++) {
                    out.push(x);
                    const w = widths[i];
                    if (w > 0.5) {
                        end = x + w;
                        const trailing = keys && bar.joinedAfter(keys, widths, i) ? 0 : (gap > 0 ? gap * Math.min(1, w / gap) : 0);
                        x = Math.floor(end + trailing);
                        any = true;
                    }
                }
                out.push(any ? end : originX);
                return out;
            }

            // whether the module at i is joined to the next one in the bar this
            // moment. ones that have emptied out between them (a tray with no
            // icons, workspaces off in the overview) carry the join when every
            // link across them is on, and part the group where one is off
            function joinedAfter(keys, widths, i) {
                if (!(widths[i] > 0.5 && bar.realWidthOf(keys[i]) > 0.5))
                    return false;

                // an edit-mode stand-in has room but nothing in it: it parts the group
                for (let j = i + 1; j < keys.length; j++) {
                    if (!Prefs.barJoinedNow(keys[j - 1], keys[j]))
                        return false;

                    if (widths[j] > 0.5)
                        return bar.realWidthOf(keys[j]) > 0.5;

                }
                return false;
            }

            // what a module's pill reads to square off the corners it shares
            function joinedLeftOf(key) {
                const at = bar.placeMap[key];
                if (!at || bar.realWidthOf(key) <= 0.5)
                    return false;

                const keys = bar.zoneKeys(at.zone);
                for (let j = at.at - 1; j >= 0; j--) {
                    if (!Prefs.barJoinedNow(keys[j], keys[j + 1]))
                        return false;

                    if (bar.widthOf(keys[j]) > 0.5)
                        return bar.realWidthOf(keys[j]) > 0.5;

                }
                return false;
            }

            function joinedRightOf(key) {
                const at = bar.placeMap[key];
                return !!at && bar.joinedAfter(bar.zoneKeys(at.zone), bar.widthsOf(at.zone), at.at);
            }

            // per module key, radius caps where a hanging panel meets the islands: {corners, tops, sides, fillets},
            // plus what the full bar fills between merged open panels: {bridges, merged, edges}
            readonly property var hangPlan: bar.planHangs()

            function surfaceSpan(mod) {
                const l = mod.x + (mod.surfaceX !== undefined ? mod.surfaceX : 0);
                return [l, l + (mod.surfaceWidth !== undefined ? mod.surfaceWidth : mod.width)];
            }

            // the launcher standing on this bar, if it is the one that speaks for the shell
            readonly property var cover: bar.primary ? dock.barCover : null
            // whether an island's top runs on under each of the launcher's lower corners
            function underAt(x) {
                // the full bar's strip runs under every point, between modules too
                if (Prefs.barFull)
                    return true;

                const f = Theme.dp(Prefs.dockNotchFlare);
                const covered = (p) => {
                    return bar.modules.some((m) => {
                        const span = bar.surfaceSpan(m);
                        return m.visible && span[1] - span[0] > 0.5 && span[0] <= p && span[1] >= p;
                    });
                };
                return covered(x - f) && covered(x + f);
            }

            Connections {
                function onBarAutoHideChanged() {
                    Qt.callLater(() => {
                        return bar.exclusionTick++;
                    });
                }

                target: Prefs
            }

            Binding {
                target: dock
                property: "barUnderLeft"
                value: !bar.cover || bar.underAt(bar.cover.l)
                when: bar.primary
            }

            Binding {
                target: dock
                property: "barUnderRight"
                value: !bar.cover || bar.underAt(bar.cover.r)
                when: bar.primary
            }

            // how far a notch module's edge blend reaches into the top edge on one side:
            // the whole Edge blend, less where a neighbour or the screen side is closer
            function notchFlareOf(mod, toTheLeft) {
                if (!Prefs.barNotch || !mod || mod.width <= 0.5 || !mod.visible || (bar.dragLift > 0.5 && bar.pillFor[bar.dragKey] === mod))
                    return 0;

                // the workspace overview off its slot, until it has fully landed: its seat blends there instead
                if (mod.detach > 0)
                    return 0;

                // a side that meets the screen's is filled out to it instead
                const meets = bar.hangPlan.meets[mod.modId];
                if (meets && meets[toTheLeft ? "left" : "right"])
                    return 0;

                const edge = toTheLeft ? mod.x : mod.x + mod.width;
                const toEdge = toTheLeft ? edge : bar.width - edge;
                let toNeighbour = 100000;
                for (const o of bar.modules) {
                    if (!o || o === mod || o.width <= 0.5 || !o.visible || o.detach > 0)
                        continue;

                    const d = toTheLeft ? edge - (o.x + o.width) : o.x - edge;
                    if (d >= 0)
                        toNeighbour = Math.min(toNeighbour, d);

                }
                return Math.max(0, Math.min(Theme.dp(Prefs.barNotchFlare), Math.floor(toNeighbour / 2), Math.floor(toEdge)));
            }

            // how far down the module's side that blend reaches: as far as it sweeps
            // out, but no further than the side runs straight. past where the far
            // corner starts to round, the curve's tip would stand off it in a step,
            // so a short module takes a wide blend as a quarter ellipse instead
            function notchDepthOf(mod, toTheLeft) {
                const reach = bar.notchFlareOf(mod, toTheLeft);
                if (reach <= 0)
                    return 0;

                const far = toTheLeft ? mod.barBottomLeftRadius : mod.barBottomRightRadius;
                const side = (mod === workspacesMod ? mod.compactHeight : mod.height) - (far !== undefined ? far : Prefs.barPillRadius);
                return Math.max(0, Math.min(reach, Math.floor(side)));
            }

            // full bar: how far the concave corner where an open panel's side meets the
            // strip's lower edge reaches. it grows with the panel's height, so a folding
            // panel takes it with it; never past the screen edge, never into the screen
            // corner that already rounds that side, none where a merged neighbour covers it
            function panelFlareSize(mod, toTheLeft) {
                if (!Prefs.barFull || Prefs.barPopupMode || !mod || mod === workspacesMod)
                    return 0;

                // surfaceOpen, not the height alone: a pill that is only resizing its
                // compact face is see-through on the full bar
                const reach = mod.visible && mod.width > 0.5 && mod.surfaceOpen === true ? mod.height - Theme.dp(Prefs.barHeight) : 0;
                const merged = bar.hangPlan.merged[mod.modId];
                if (merged && (toTheLeft ? merged.left : merged.right))
                    return 0;

                const corner = Theme.dp(Prefs.barFullCorner);
                const toEdge = toTheLeft ? mod.x : bar.width - mod.x - mod.width;
                const room = toEdge - (toEdge < corner * 2 ? corner : 0);
                return Math.max(0, Math.floor(Math.min(corner, reach, room)));
            }

            function planHangs() {
                const plan = ({
                    "corners": ({}),
                    "tops": ({}),
                    "sides": ({}),
                    "fillets": [],
                    "bridges": [],
                    "merged": ({}),
                    "edges": ({}),
                    "meets": ({})
                });
                const popups = Prefs.barPopupMode;
                const most = Theme.dp(Prefs.barNotchFlare);
                const cap = (key, corner, v) => {
                    const c = plan.corners[key] || (plan.corners[key] = ({}));
                    c[corner] = Math.min(c[corner] === undefined ? 1e6 : c[corner], Math.max(0, v));
                };
                const fillet = (x, y, size, mirrored, flipped, owner) => {
                    if (size >= 1)
                        plan.fillets.push({ "x": x, "y": y, "size": size, "mirrored": mirrored, "flipped": flipped, "mod": owner || null });

                };
                // notches: a module against a screen side curves into it below
                // its bottom, or below its panel when that is open. one kept off it
                // by the side margin reaches it all the same, the margin filled in
                if (Prefs.barNotch && Prefs.barNotchEdge) {
                    const row = bar.modules.filter((m) => {
                        return m.visible && m.width > 0.5 && !(m.detach > 0);
                    }).sort((p, q) => {
                        return p.x - q.x;
                    });
                    const meet = (m, left) => {
                        const h = m === workspacesMod ? m.compactHeight : m.height;
                        const y = m.y + h;
                        cap(m.modId, left ? "bl" : "br", 0);
                        fillet(left ? 0 : bar.width - most, y, most, left, false, m);
                        const gap = left ? m.x : bar.width - m.x - m.width;
                        if (gap > 0.5)
                            plan.bridges.push({ "x": left ? 0 : Math.floor(m.x + m.width), "y": m.y, "w": left ? Math.ceil(m.x) : bar.width - Math.floor(m.x + m.width), "h": h, "mod": m });

                        // where the curve starts, for edit mode's outline
                        (plan.meets[m.modId] || (plan.meets[m.modId] = ({})))[left ? "left" : "right"] = ({ "y": y, "size": most });
                    };
                    // the overview's seat closing up at a side: the module sliding in behind
                    // fuses with it, its facing corner matching the seat's as that narrows
                    // (by its width: the gap is floored to whole pixels and would jitter), so
                    // it takes the meet over already square
                    const fuse = (seat, next, left) => {
                        const f = Math.max(0, Math.min(Prefs.barPillRadius, seat.width / 2));
                        cap(next.modId, left ? "bl" : "br", f);
                        cap(seat.modId, left ? "br" : "bl", f);
                    };
                    if (row.length > 0 && row[0].x < bar.sideMargin + 0.5) {
                        meet(row[0], true);
                        if (row[0] === wsSeat && row.length > 1)
                            fuse(row[0], row[1], true);

                    }
                    const last = row.length - 1;
                    if (last >= 0 && bar.width - row[last].x - row[last].width < bar.sideMargin + 0.5) {
                        meet(row[last], false);
                        if (row[last] === wsSeat && last > 0)
                            fuse(row[last], row[last - 1], false);

                    }

                }
                if (popups && !Prefs.barPopupNotched)
                    return plan;

                // full bar and notches: open panels side by side become one shape.
                // the gap between them fills in, and the shorter one's shared corner
                // turns into a fillet against the taller one's side
                if ((Prefs.barFull || Prefs.barNotch) && !popups) {
                    // a notch has no strip under the gap, so it fills from the top
                    const strip = Prefs.barFull ? Theme.dp(Prefs.barHeight) : 0;
                    const corner = Prefs.barFull ? Theme.dp(Prefs.barFullCorner) : most;
                    // a module an open panel covers fades out where it stood, under it;
                    // counted, it sorted between two open panels and parted them
                    const row = bar.modules.filter((m) => {
                        return m.visible && m.width > 0.5 && m.covered !== true;
                    }).sort((p, q) => {
                        return p.x - q.x;
                    });
                    for (let i = 0; i + 1 < row.length; i++) {
                        const a = row[i];
                        const b = row[i + 1];
                        // pills easing to new places overlap by a pixel or so mid-move;
                        // counting that as apart made the corner flicker
                        const gap = b.x - (a.x + a.width);
                        if (a === workspacesMod || b === workspacesMod || a.surfaceOpen !== true || b.surfaceOpen !== true || Math.abs(gap) > corner)
                            continue;

                        const low = Math.min(a.height, b.height);
                        const diff = Math.abs(a.height - b.height);
                        const shortLeft = a.height < b.height;
                        const f = Math.floor(Math.min(corner, diff / 2));
                        (plan.merged[a.modId] || (plan.merged[a.modId] = ({}))).right = true;
                        (plan.merged[b.modId] || (plan.merged[b.modId] = ({}))).left = true;
                        cap(a.modId, "br", shortLeft ? 0 : diff - f);
                        cap(b.modId, "bl", shortLeft ? diff - f : 0);
                        // whole pixels, out to both panels: a fill ending mid-pixel against
                        // a panel's soft edge left a dark seam while they moved
                        if (gap > 0.5 && low > strip)
                            plan.bridges.push({ "x": Math.floor(a.x + a.width), "y": a.y + strip, "w": Math.ceil(b.x) - Math.floor(a.x + a.width), "h": low - strip });

                        if (shortLeft)
                            fillet(b.x - f, a.y + low, f, false, false);
                        else
                            fillet(a.x + a.width, a.y + low, f, true, false);
                    }
                    // on the full bar, a panel this close to a screen side merges into
                    // it the same way, the side standing in for an endlessly tall neighbour
                    const edge = (m, side, gap) => {
                        if (m === workspacesMod || m.surfaceOpen !== true || Math.abs(gap) > corner)
                            return ;

                        const left = side === "left";
                        (plan.merged[m.modId] || (plan.merged[m.modId] = ({})))[side] = true;
                        plan.edges[side] = true;
                        cap(m.modId, left ? "bl" : "br", 0);
                        if (gap > 0.5 && m.height > strip)
                            plan.bridges.push({ "x": left ? 0 : Math.floor(m.x + m.width), "y": m.y + strip, "w": left ? Math.ceil(m.x) : bar.width - Math.floor(m.x + m.width), "h": m.height - strip });

                        fillet(left ? 0 : bar.width - corner, m.y + m.height, corner, left, false);
                    };
                    if (Prefs.barFull && row.length > 0) {
                        edge(row[0], "left", row[0].x);
                        edge(row[row.length - 1], "right", bar.width - row[row.length - 1].x - row[row.length - 1].width);
                    }
                }
                // islands: runs of joined modules as they stand
                const islands = [];
                const shelves = [];
                for (const zone of Prefs.barZones) {
                    const keys = bar.zoneKeys(zone);
                    let run = null;
                    for (let i = 0; i < keys.length; i++) {
                        const mod = bar.pillFor[keys[i]];
                        if (!mod || bar.widthOf(keys[i]) <= 0.5)
                            continue;

                        if (run && bar.joinedLeftOf(keys[i])) {
                            run.keys.push(keys[i]);
                            run.r = bar.surfaceSpan(mod)[1];
                        } else {
                            run = ({ "keys": [keys[i]], "l": bar.surfaceSpan(mod)[0], "r": bar.surfaceSpan(mod)[1], "top": mod.y, "bottom": mod.y + mod.compactHeight });
                            islands.push(run);
                        }
                    }
                }
                // what hangs: a notched pop-up, or a joined module opened in place
                for (const isle of islands) {
                    for (let j = 0; j < isle.keys.length; j++) {
                        const m = bar.pillFor[isle.keys[j]];
                        if (popups) {
                            const pop = m.notchedPopup === true && m.popupOpen ? m.popupItem : null;
                            if (pop && pop.height > 0.5)
                                shelves.push({ "key": isle.keys[j], "l": m.x + pop.x, "r": m.x + pop.x + pop.width, "y": m.y + pop.y, "depth": pop.height });

                        } else if (isle.keys.length > 1 && m !== workspacesMod && m.height - m.compactHeight > 0.5) {
                            const depth = m.height - m.compactHeight;
                            const side = ({});
                            // a side merged into an open neighbour has no island bottom to meet
                            const merged = plan.merged[isle.keys[j]] || ({});
                            // a neighbour open as well is a side to meet, not the island's
                            // bottom: the shorter one's shared corner squares off and the
                            // taller one curves out under it
                            const openAt = (k) => {
                                const n = bar.pillFor[isle.keys[k]];
                                return n !== workspacesMod && n.height - n.compactHeight > 0.5 ? n : null;
                            };
                            const meetOpen = (n, left) => {
                                const below = m.y + m.height - (n.y + n.height);
                                if (below <= 0.5)
                                    return 0;

                                const f = Math.floor(Math.min(most, below / 2, n.width / 2));
                                fillet(left ? m.x - f : m.x + m.width, n.y + n.height, f, !left, false);
                                return below - f;
                            };
                            if (j > 0 && !merged.left) {
                                const n = openAt(j - 1);
                                if (n) {
                                    side.bl = meetOpen(n, true);
                                } else {
                                    const run = m.x - isle.l;
                                    const f = Math.floor(Math.min(most, run / 2, depth / 2));
                                    fillet(m.x - f, isle.bottom, f, false, false);
                                    cap(isle.keys[0], "bl", run - f);
                                    side.bl = depth - f;
                                }
                            }
                            if (j < isle.keys.length - 1 && !merged.right) {
                                const n = openAt(j + 1);
                                if (n) {
                                    side.br = meetOpen(n, false);
                                } else {
                                    const run = isle.r - (m.x + m.width);
                                    const f = Math.floor(Math.min(most, run / 2, depth / 2));
                                    fillet(m.x + m.width, isle.bottom, f, true, false);
                                    cap(isle.keys[isle.keys.length - 1], "br", run - f);
                                    side.br = depth - f;
                                }
                            }
                            plan.sides[isle.keys[j]] = side;
                        }
                    }
                }
                // a pop-up's top is the screen edge upside down: islands stand on it or it hangs from them
                for (const shelf of shelves) {
                    const over = islands.filter((isle) => {
                        return isle.l < shelf.r - 0.5 && isle.r > shelf.l + 0.5 && Math.abs(isle.bottom - shelf.y) < 1;
                    });
                    const top = ({});
                    plan.tops[shelf.key] = top;
                    if (over.length === 0)
                        continue;

                    for (let k = 0; k < over.length; k++) {
                        const isle = over[k];
                        const first = isle.keys[0];
                        const last = isle.keys[isle.keys.length - 1];
                        const tall = isle.bottom - isle.top;
                        const dl = isle.l - shelf.l;
                        if (k > 0) {
                            const f = Math.floor(Math.min(most, (isle.l - over[k - 1].r) / 2, tall));
                            fillet(isle.l - f, shelf.y - f, f, false, true);
                            cap(first, "bl", 0);
                        } else if (dl > 0.5) {
                            const f = Math.floor(Math.min(most, dl / 2, tall));
                            fillet(isle.l - f, shelf.y - f, f, false, true);
                            cap(first, "bl", 0);
                            top.tl = dl - f;
                        } else if (dl < -0.5) {
                            const f = Math.floor(Math.min(most, -dl / 2, shelf.depth / 2));
                            fillet(shelf.l - f, shelf.y, f, false, false);
                            cap(first, "bl", -dl - f);
                            top.tl = 0;
                        } else {
                            cap(first, "bl", 0);
                            top.tl = 0;
                        }
                        const dr = shelf.r - isle.r;
                        if (k < over.length - 1) {
                            const f = Math.floor(Math.min(most, (over[k + 1].l - isle.r) / 2, tall));
                            fillet(isle.r, shelf.y - f, f, true, true);
                            cap(last, "br", 0);
                        } else if (dr > 0.5) {
                            const f = Math.floor(Math.min(most, dr / 2, tall));
                            fillet(isle.r, shelf.y - f, f, true, true);
                            cap(last, "br", 0);
                            top.tr = dr - f;
                        } else if (dr < -0.5) {
                            const f = Math.floor(Math.min(most, -dr / 2, shelf.depth / 2));
                            fillet(shelf.r, shelf.y, f, true, false);
                            cap(last, "br", -dr - f);
                            top.tr = 0;
                        } else {
                            cap(last, "br", 0);
                            top.tr = 0;
                        }
                    }
                }
                return plan;
            }

            property real wsCollapse: (workspacesMod.expanded && !Prefs.barPopupMode) ? 0 : 1

            // the modules are addressed by their id in Prefs.barModules; the
            // groups in Prefs.barLayout decide which slot each one lands in
            readonly property var pillFor: ({
                "workspaces": workspacesMod,
                "media": mprisMod,
                "tray": sysTrayMod,
                "clock": clockMod,
                "notifications": notifMod,
                "system": systemMod,
                "privacy": privacyMod,
                "power": powerMod,
                "window": windowMod,
                "start": startMod,
                "apps": appsMod
            })
            // what BarPill looks itself up in, for a right click to its card
            readonly property var moduleById: bar.pillFor
            readonly property var modules: [workspacesMod, mprisMod, sysTrayMod, clockMod, notifMod, systemMod, privacyMod, powerMod, windowMod, startMod, appsMod, launcherPanel, wsSeat]

            // which modules switched on have left the bar for now, for the Bar
            // page's arrangement
            Binding {
                target: Prefs
                property: "barModulesAway"
                when: bar.primary
                value: Prefs.barModules.filter((m) => {
                    const mod = bar.pillFor[m.id];
                    return Prefs[m.key] === true && mod && !mod.shown;
                }).map((m) => {
                    return m.id;
                })
            }

            // a module on its way out of the bar keeps the slot it had until its
            // pill has finished emptying, so its neighbours close the gap at the
            // rate it shrinks rather than dropping into it
            function zoneKeys(zone) {
                const live = bar.dragGroups ? bar.dragGroups[zone === "centre" ? "center" : zone].filter((id) => {
                    return Prefs.barShown(id);
                }) : Prefs.barKeysOf(zone);
                const r = Prefs.barRetiring;
                if (!r || r.zone !== zone || Prefs.barHas(r.key))
                    return live;

                const out = live.slice();
                out.splice(Math.min(r.at, out.length), 0, r.key);
                return out;
            }

            readonly property var retiring: Prefs.barRetiring

            onRetiringChanged: {
                if (bar.retiring)
                    retireTimer.restart();

            }

            Timer {
                id: retireTimer

                interval: Theme.barMs(560)
                onTriggered: Prefs.barClearRetiring()
            }

            // key -> which zone it sits in and how far along
            readonly property var placeMap: {
                const out = ({});
                for (var z = 0; z < Prefs.barZones.length; z++) {
                    const zone = Prefs.barZones[z];
                    const keys = bar.zoneKeys(zone);
                    for (var i = 0; i < keys.length; i++) out[keys[i]] = ({ "zone": zone, "at": i })
                }
                return out;
            }

            // workspaces empties its slot as it flies to the screen centre, so the
            // rest of its zone closes up behind it. the slot is the pill's, not the
            // growing card's: that widened it first and pushed the neighbours away
            function realWidthOf(key) {
                const it = bar.pillFor[key];
                if (!it)
                    return 0;

                if (it === workspacesMod && bar.wsCollapse < 1)
                    return (it.shown ? it.compactWidth : 0) * bar.wsCollapse;

                return it.width;
            }

            // in edit mode a module with nothing to show keeps a stand-in's room
            function widthOf(key) {
                return Math.max(bar.realWidthOf(key), barEdit.ghostWidthOf(key));
            }

            function widthsOf(zone) {
                return bar.zoneKeys(zone).map(bar.widthOf);
            }

            function placesOf(zone) {
                return zone === "left" ? bar.leftPlaces : (zone === "centre" ? bar.centrePlaces : bar.rightPlaces);
            }

            function alignFor(zone) {
                return zone === "centre" ? "center" : (zone === "right" ? "right" : "left");
            }

            function placeFor(key) {
                const at = bar.placeMap[key];
                if (!at)
                    return 0;

                const places = bar.placesOf(at.zone);
                return at.at < places.length ? places[at.at] : 0;
            }

            function alignOf(key) {
                const at = bar.placeMap[key];
                return bar.alignFor(at ? at.zone : "left");
            }

            readonly property var leftWidths: bar.widthsOf("left")
            readonly property var centreWidths: bar.widthsOf("centre")
            readonly property var rightWidths: bar.widthsOf("right")
            readonly property real leftGroupWidth: bar.placeGroup(bar.leftWidths, 0, bar.zoneKeys("left"))[bar.leftWidths.length]
            readonly property real centreGroupWidth: bar.placeGroup(bar.centreWidths, 0, bar.zoneKeys("centre"))[bar.centreWidths.length]
            readonly property real rightGroupWidth: bar.placeGroup(bar.rightWidths, 0, bar.zoneKeys("right"))[bar.rightWidths.length]
            readonly property int zoneGap: Theme.dp(Prefs.barZoneGap)

            // pills ease to their new slots only while the arrangement is changing.
            // a Behavior left on all the time would sit on top of the width
            // animations a panel opening or a tray icon arriving already drive, and
            // one that restarts every frame never arrives
            readonly property int reorderTick: Prefs.barReorderTick
            property bool shuffling: false

            onReorderTickChanged: {
                bar.shuffling = true;
                shuffleTimer.restart();
            }

            Timer {
                id: shuffleTimer

                interval: Theme.barMs(520)
                onTriggered: bar.shuffling = false
            }

            readonly property real leftOriginX: bar.sideMargin
            readonly property real rightOriginX: bar.width - bar.rightGroupWidth - bar.sideMargin
            readonly property real centreOriginX: Math.min(Math.max((bar.width - bar.centreGroupWidth) / 2, bar.leftOriginX + bar.leftGroupWidth + bar.zoneGap), bar.rightOriginX - bar.centreGroupWidth - bar.zoneGap)
            readonly property var leftPlaces: bar.placeGroup(bar.leftWidths, bar.leftOriginX, bar.zoneKeys("left"))
            readonly property var centrePlaces: bar.placeGroup(bar.centreWidths, bar.centreOriginX, bar.zoneKeys("centre"))
            readonly property var rightPlaces: bar.placeGroup(bar.rightWidths, bar.rightOriginX, bar.zoneKeys("right"))

            Behavior on wsCollapse {
                NumberAnimation {
                    duration: Theme.barMs(380)
                    easing.type: Easing.OutCubic
                }

            }
            // kept when notches meet the screen sides too: the end modules reach the
            // sides across it, and it keeps their contents off them
            readonly property real sideMargin: Theme.dp(Prefs.barSideMargin)

            // busy: a panel is open somewhere on the bar, so it stays out
            // regardless of the pointer. held: the pointer is on the reveal
            // strip or already on a module - either keeps it from hiding
            readonly property bool barBusy: bar.modules.some((m) => {
                return m.expanded === true || m.anyOpen === true;
            })
            property bool slidingAway: false
            readonly property bool pointerOnBar: revealArea.containsMouse || (!bar.slidingAway && bar.modules.some((m) => {
                return m.visible && (m.surfaceHovered === true || m.compactHovered === true);
            }))
            // let go a beat after the pointer leaves: passing between the strip
            // and a pill can read as off both for a moment, and the slide away
            // would start in that gap
            property bool heldByPointer: false
            // a write to exclusiveZone puts exclusionMode back to Normal, so the mode is
            // asked for again once auto-hide has been switched
            property int exclusionTick: 0

            onPointerOnBarChanged: {
                if (bar.pointerOnBar) {
                    letGoTimer.stop();
                    bar.heldByPointer = true;
                } else {
                    letGoTimer.restart();
                }
            }

            Timer {
                id: letGoTimer

                interval: 180
                onTriggered: bar.heldByPointer = bar.pointerOnBar
            }

            readonly property bool barRevealed: (!Prefs.barAutoHide || bar.barBusy || bar.heldByPointer || Edit.active) && !Prefs.barRelocating
            // auto-hide puts the window's top at the screen's own edge and lowers
            // the row by the gap instead, so the bar slides out from the edge
            // rather than appearing at the gap's lower line
            readonly property real topInset: Prefs.barAutoHide ? Prefs.effectiveBarTopMargin : 0
            // where the compact row sits in the window: below the gap while out,
            // and past the window's top edge while hidden, so it clips away for free
            property real rowY: bar.barRevealed ? bar.topInset : -(Theme.dp(Prefs.barHeight) + Theme.dp(4))

            Behavior on rowY {
                NumberAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.Bezier
                    // leaving for the other edge it picks up speed, so it is seen to go
                    easing.bezierCurve: Prefs.barRelocating ? Theme.easeEmphasizedAccel : Theme.easeEmphasizedDecel
                }

            }

            onBarRevealedChanged: {
                if (bar.barRevealed) {
                    bar.slidingAway = false;
                    slideAwayTimer.stop();
                } else {
                    bar.slidingAway = true;
                    slideAwayTimer.restart();
                }
            }

            Timer {
                id: slideAwayTimer

                interval: Theme.durLong
                onTriggered: bar.slidingAway = false
            }

            Component.onCompleted: {
                bar.contentItem.transform = [barMirror];
                laidOutTimer.start();
            }

            Timer {
                id: laidOutTimer

                interval: 120
                onTriggered: bar.laidOut = true
            }

            color: "transparent"
            implicitHeight: bar.screen ? bar.screen.height - (Prefs.barBottom ? bar.margins.bottom : bar.margins.top) : Theme.dp(800)
            // auto-hide first, so a hiding bar never writes its zone again
            exclusiveZone: (!Prefs.barAutoHide && Prefs.barEnabled && bar.anyModuleShown) ? Theme.dp(Prefs.barHeight) + Prefs.shellGap : 0
            // a hiding bar comes out of the edge itself, not above a dock's zone
            exclusionMode: (bar.exclusionTick, Prefs.barAutoHide) ? ExclusionMode.Ignore : ExclusionMode.Normal

            anchors {
                top: !Prefs.barBottom
                bottom: Prefs.barBottom
                left: true
                right: true
            }

            margins {
                top: Prefs.barBottom ? 0 : Prefs.effectiveBarTopMargin - bar.topInset
                bottom: Prefs.barBottom ? Prefs.effectiveBarTopMargin - bar.topInset : 0
            }

            // a bottom bar is the top bar mirrored: every shape keeps its maths,
            // and the modules turn their own content back the right way up
            Scale {
                id: barMirror

                origin.y: bar.height / 2
                yScale: Prefs.barBottom ? -1 : 1
            }

            // full bar: one strip across the whole top edge, under every module
            Rectangle {
                id: fullStrip

                visible: Prefs.barFull && bar.anyModuleShown
                x: 0
                y: bar.rowY
                z: -2
                width: bar.width
                height: Theme.dp(Prefs.barHeight)
                color: Theme.bg

                Behavior on color {
                    enabled: bar.laidOut

                    ColorAnimation {
                        duration: Theme.barMs(260)
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // a launcher wider than the bar stands on a strip the bar puts out
            // to its width, curving into the screen edge where it passes the bar
            Rectangle {
                id: coverStrip

                // fades once the launcher has sunk, so nothing is left standing on the bar
                opacity: bar.cover && bar.cover.up ? 1 : 0
                visible: !!bar.cover && !Prefs.barFull && opacity > 0
                x: bar.cover ? bar.cover.l : 0
                y: bar.rowY
                z: -2
                width: bar.cover ? bar.cover.r - bar.cover.l : 0
                height: Theme.dp(Prefs.barHeight)
                color: Theme.bg

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            BarFlare {
                visible: coverStrip.visible && !dock.barUnderLeft
                opacity: coverStrip.opacity
                size: Theme.dp(Prefs.barNotchFlare)
                depth: Math.min(size, Theme.dp(Prefs.barHeight))
                x: coverStrip.x - width
                y: bar.rowY
                z: -2
            }

            BarFlare {
                visible: coverStrip.visible && !dock.barUnderRight
                opacity: coverStrip.opacity
                mirrored: true
                size: Theme.dp(Prefs.barNotchFlare)
                depth: Math.min(size, Theme.dp(Prefs.barHeight))
                x: coverStrip.x + coverStrip.width
                y: bar.rowY
                z: -2
            }

            // rounded corners hanging off the strip where it meets the screen sides
            BarFlare {
                visible: fullStrip.visible && size > 0 && !bar.hangPlan.edges.left
                mirrored: true
                size: Theme.dp(Prefs.barFullCorner)
                x: 0
                y: Theme.dp(Prefs.barHeight) + bar.rowY
                z: -2
            }

            BarFlare {
                visible: fullStrip.visible && size > 0 && !bar.hangPlan.edges.right
                size: Theme.dp(Prefs.barFullCorner)
                x: bar.width - width
                y: Theme.dp(Prefs.barHeight) + bar.rowY
                z: -2
            }

            // full bar: an open panel hangs off the strip, so round the two concave
            // corners where its sides meet the strip's lower edge. They grow with
            // the panel's height, so a folding panel takes them with it
            Repeater {
                model: (Prefs.barFull && !Prefs.barPopupMode) ? bar.modules.filter((m) => {
                    return m !== workspacesMod;
                }) : []

                Item {
                    id: panelFlares

                    required property var modelData

                    anchors.fill: parent
                    z: -1

                    BarFlare {
                        size: bar.panelFlareSize(panelFlares.modelData, true)
                        // butted against the panel: half a pixel over it was a second coat on its edge
                        x: panelFlares.modelData.x - width
                        y: Theme.dp(Prefs.barHeight)
                    }

                    BarFlare {
                        mirrored: true
                        size: bar.panelFlareSize(panelFlares.modelData, false)
                        x: panelFlares.modelData.x + panelFlares.modelData.width
                        y: Theme.dp(Prefs.barHeight)
                    }

                }

            }

            Mpris {
                id: mprisMod

                popupAlign: bar.alignOf("media")

                hostWindow: bar
                x: bar.xOf("media")
                editLifted: bar.dragKey === "media"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("media")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "media"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            SysTray {
                id: sysTrayMod

                popupAlign: bar.alignOf("tray")

                hostWindow: bar
                x: bar.xOf("tray")
                editLifted: bar.dragKey === "tray"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("tray")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "tray"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Clock {
                id: clockMod

                popupAlign: bar.alignOf("clock")

                hostWindow: bar
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("clock")
                x: bar.xOf("clock")
                editLifted: bar.dragKey === "clock"

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "clock"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Notifications {
                id: notifMod

                showsPopups: bar.primary
                popupAlign: bar.alignOf("notifications")

                hostWindow: bar
                x: bar.xOf("notifications")
                editLifted: bar.dragKey === "notifications"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("notifications")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "notifications"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Privacy {
                id: privacyMod

                popupAlign: bar.alignOf("privacy")
                toast: bar.primary ? toastMod : null

                hostWindow: bar
                x: bar.xOf("privacy")
                editLifted: bar.dragKey === "privacy"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("privacy")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "privacy"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            SessionMenu {
                id: powerMod

                popupAlign: bar.alignOf("power")

                hostWindow: bar
                x: bar.xOf("power")
                editLifted: bar.dragKey === "power"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("power")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "power"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            // the launcher, when this bar draws it: centred on the strip it grows out of
            LauncherPanel {
                id: launcherPanel

                hostWindow: bar
                dockMod: dock
                x: Math.round((bar.width - width) / 2)
                anchors.top: parent.top
                anchors.topMargin: bar.rowY
            }

            StartButton {
                id: startMod

                popupAlign: bar.alignOf("start")

                hostWindow: bar
                dockMod: dock
                x: bar.xOf("start")
                editLifted: bar.dragKey === "start"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("start")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "start"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Apps {
                id: appsMod

                popupAlign: bar.alignOf("apps")

                hostWindow: bar
                dockMod: dock
                x: bar.placeFor("apps")
                anchors.top: parent.top
                anchors.topMargin: bar.rowY

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            ActiveWindow {
                id: windowMod

                popupAlign: bar.alignOf("window")

                hostWindow: bar
                x: bar.xOf("window")
                editLifted: bar.dragKey === "window"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("window")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "window"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            System {
                id: systemMod

                popupAlign: bar.alignOf("system")

                hostWindow: bar
                mprisMod: mprisMod
                x: bar.xOf("system")
                editLifted: bar.dragKey === "system"
                anchors.top: parent.top
                anchors.topMargin: bar.rowY + bar.liftOf("system")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "system"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            Repeater {
                model: Prefs.barNotch ? bar.modules : []

                Item {
                    id: flares

                    required property var modelData

                    readonly property bool present: flares.modelData && flares.modelData.width > 0.5 && flares.modelData.visible && !(bar.dragLift > 0.5 && bar.pillFor[bar.dragKey] === flares.modelData)
                    readonly property bool modHovered: flares.modelData ? (flares.modelData.compactHovered === true && flares.modelData !== workspacesMod) : false

                    anchors.fill: parent
                    z: -1
                    visible: Prefs.barNotch && flares.present

                    // butted against the module, not tucked under it: an overlap is
                    // a second coat of the translucent fill, a light seam down the side
                    BarFlare {
                        hovered: flares.modHovered
                        size: bar.notchFlareOf(flares.modelData, true)
                        depth: bar.notchDepthOf(flares.modelData, true)
                        x: flares.modelData ? flares.modelData.x - width : 0
                        y: bar.rowY
                    }

                    BarFlare {
                        hovered: flares.modHovered
                        mirrored: true
                        size: bar.notchFlareOf(flares.modelData, false)
                        depth: bar.notchDepthOf(flares.modelData, false)
                        x: flares.modelData ? flares.modelData.x + flares.modelData.width : 0
                        y: bar.rowY
                    }

                }

            }

            // fillets where a hanging panel meets the islands above it
            Repeater {
                model: 16

                BarFlare {
                    required property int index
                    readonly property var spec: bar.hangPlan.fillets.length > index ? bar.hangPlan.fillets[index] : null
                    // the curve a module meets the screen side with lights up with it
                    readonly property var owner: spec && spec.mod ? spec.mod : null

                    z: 0
                    hovered: owner !== null && owner !== workspacesMod && owner.compactHovered === true && owner.anyOpen !== true
                    size: spec ? spec.size : 0
                    mirrored: spec ? spec.mirrored : false
                    flipped: spec ? spec.flipped : false
                    x: spec ? spec.x : 0
                    y: spec ? spec.y : 0
                }

            }

            // the gaps filled between open panels the bar merges, and between a
            // notch and the screen side it meets across the side margin
            Repeater {
                model: 8

                Rectangle {
                    id: bridge

                    required property int index
                    readonly property var spec: bar.hangPlan.bridges.length > index ? bar.hangPlan.bridges[index] : null
                    // a module's own stretch lights up with it, as its edge blends do
                    readonly property var owner: bridge.spec && bridge.spec.mod ? bridge.spec.mod : null

                    z: 0
                    visible: spec !== null
                    x: spec ? spec.x : 0
                    y: spec ? spec.y : 0
                    width: spec ? spec.w : 0
                    height: spec ? spec.h : 0
                    color: Theme.bg

                    Rectangle {
                        anchors.fill: parent
                        visible: opacity > 0
                        color: Theme.text
                        opacity: bridge.owner && bridge.owner !== workspacesMod && bridge.owner.compactHovered === true && bridge.owner.anyOpen !== true ? Theme.stateHover : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(150)
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                }

            }

            // where the workspace overview sat, on a notch bar, while its card is off it:
            // the slot stays a stretch of the bar, closing up as the zone slides in (and
            // opening as the card comes home), so its side meet and blends hand over to
            // the next module instead of vanishing there and turning up on it
            Rectangle {
                id: wsSeat

                readonly property string modId: "workspacesSeat"
                readonly property var hostWindow: bar
                readonly property bool active: Prefs.barNotch && workspacesMod.shown && workspacesMod.detach > 0
                readonly property real compactHeight: workspacesMod.compactHeight
                readonly property var hangCorners: bar.hangPlan.corners[wsSeat.modId] || null
                readonly property int pillRadius: Prefs.barPillRadius
                // the corners ModuleRegion's blur follows
                readonly property int barRadius: wsSeat.pillRadius
                readonly property int barTopRadius: 0
                readonly property int topRadius: 0
                readonly property int cornerRadius: wsSeat.pillRadius
                readonly property real barTopLeftRadius: 0
                readonly property real barTopRightRadius: 0
                readonly property real barBottomLeftRadius: wsSeat.bottomLeftRadius
                readonly property real barBottomRightRadius: wsSeat.bottomRightRadius

                function capped(corner, v) {
                    return wsSeat.hangCorners && wsSeat.hangCorners[corner] !== undefined ? Math.max(0, Math.min(v, wsSeat.hangCorners[corner])) : v;
                }

                z: 0
                visible: wsSeat.active && !bar.covers(wsSeat)
                x: bar.xOf("workspaces")
                y: workspacesMod.restY
                width: wsSeat.active ? bar.realWidthOf("workspaces") : 0
                height: wsSeat.compactHeight
                color: Theme.bg
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: wsSeat.capped("bl", bar.joinedLeftOf("workspaces") ? 0 : wsSeat.pillRadius)
                bottomRightRadius: wsSeat.capped("br", bar.joinedRightOf("workspaces") ? 0 : wsSeat.pillRadius)
            }

            Workspaces {
                id: workspacesMod

                hostWindow: bar
                dockMod: dock
                restX: bar.xOf("workspaces")
                restY: bar.rowY + bar.liftOf("workspaces")
                z: bar.dragKey === "workspaces" ? 120 : (workspacesMod.popupOpen ? 100 : 1)

                Behavior on restX {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "workspaces"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            mask: Region {

                ModuleRegion {
                    mod: workspacesMod
                }

                ModuleRegion {
                    mod: mprisMod
                }

                ModuleRegion {
                    mod: sysTrayMod
                }

                ModuleRegion {
                    mod: clockMod
                }

                ModuleRegion {
                    mod: notifMod
                }

                ModuleRegion {
                    mod: systemMod
                }

                ModuleRegion {
                    mod: privacyMod
                }

                ModuleRegion {
                    mod: powerMod
                }

                ModuleRegion {
                    mod: windowMod
                }

                ModuleRegion {
                    mod: startMod
                }

                ModuleRegion {
                    mod: appsMod
                }

                ModuleRegion {
                    mod: launcherPanel
                }

                BridgeRegion {
                    host: bar
                    index: 0
                }

                BridgeRegion {
                    host: bar
                    index: 1
                }

                BridgeRegion {
                    host: bar
                    index: 2
                }

                BridgeRegion {
                    host: bar
                    index: 3
                }

                BridgeRegion {
                    host: bar
                    index: 4
                }

                BridgeRegion {
                    host: bar
                    index: 5
                }

                BridgeRegion {
                    host: bar
                    index: 6
                }

                BridgeRegion {
                    host: bar
                    index: 7
                }

                // by numbers, not by item: the window does not see the mirror
                Region {
                    y: Prefs.barBottom ? bar.height - revealArea.height : 0
                    width: Prefs.barAutoHide ? revealArea.width : 0
                    height: revealArea.height
                }

                Region {
                    y: Prefs.barBottom ? bar.height - height : 0
                    width: bar.dragHeld || Edit.active ? bar.width : 0
                    height: bar.dragHeld ? bar.height : (Edit.active ? bar.topInset + Theme.dp(Prefs.barHeight) + Theme.dp(4) : 0)
                }

            }

            BarEdit {
                id: barEdit

                host: bar
            }

            // touching this strip at the screen's edge reveals the bar. once the
            // pointer has it out, it reaches through the gap and the row under
            // the pills, so neither drops it on the way to a pill
            MouseArea {
                id: revealArea

                x: 0
                y: 0
                width: bar.width
                height: bar.heldByPointer ? bar.topInset + Theme.dp(Prefs.barHeight) : Theme.dp(4)
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: Prefs.barAutoHide
                visible: Prefs.barAutoHide
            }

            // with the bar on the bottom edge the launcher stands where its panels
            // open, so a panel and the launcher shut each other as well
            readonly property bool panelExpanded: bar.modules.some((m) => {
                return m !== workspacesMod && m.expanded === true;
            })

            readonly property bool launcherUp: bar.primary && Prefs.barHoldsBottom && dock.menuInDock

            onPanelExpandedChanged: {
                if (bar.panelExpanded && bar.primary && Prefs.barHoldsBottom && dock.menuInDock)
                    dock.menuOpen = false;

            }

            // an open panel too wide for its place stands over other modules, as one
            // can only once the centre is too narrow for it: then the whole bar steps
            // aside while it is open, not just the modules under it
            readonly property bool panelOverBar: bar.modules.some((m) => {
                return m.width > 0.5 && m.surfaceOpen !== true && bar.overlapped(m);
            })

            // a whole pixel or more: placeGroup starts a joined neighbour at the floor of
            // this one's end, so while a width animates the two share under a pixel.
            // read as standing over it, that faded the whole bar out and back every frame
            function overlapped(mod) {
                const l = mod.x;
                const r = mod.x + mod.width;
                return bar.modules.some((o) => {
                    return o !== mod && o.surfaceOpen === true && o.popupMode !== true && o.coversBar !== false && o.x <= r - 1 && o.x + o.width >= l + 1;
                });
            }

            function covers(mod) {
                return !!mod && mod.surfaceOpen !== true && bar.panelOverBar;
            }

            // a fullscreen window hides the bar's layer, so while one of its panels is
            // open there, and as it shuts, the bar goes up to the overlay with it
            readonly property bool fullscreenHere: {
                const m = Hyprland.monitorFor(bar.screen);
                return !!m && !!m.activeWorkspace && m.activeWorkspace.hasFullscreen;
            }
            readonly property bool panelUp: bar.modules.some((m) => {
                return m.expanded === true;
            })

            onPanelUpChanged: {
                if (bar.panelUp)
                    panelDownTimer.stop();
                else
                    panelDownTimer.restart();
            }

            Timer {
                id: panelDownTimer

                interval: Theme.barDurEnter + Theme.barMs(80)
            }

            WlrLayershell.layer: bar.fullscreenHere && (bar.panelUp || panelDownTimer.running) ? WlrLayer.Overlay : WlrLayer.Top

            // the Start module linked to the Apps module lights as the first icon of its
            // row. the link as set, on the full bar too, which draws no joins
            readonly property bool startJoinsApps: Prefs.barJoined("start", "apps") && startMod.shown && appsMod.shown && bar.adjacent("start", "apps")

            // on a full bottom bar the bar draws the launcher, so it grows out of the strip
            // as one piece of glass with it; elsewhere the dock keeps it
            readonly property bool hostsLauncher: Prefs.barFull && Prefs.barHoldsBottom && !Prefs.barPopupMode

            Binding {
                target: dock
                property: "barLauncher"
                value: bar.hostsLauncher ? launcherPanel : null
                when: bar.primary
            }

            // the launcher's search takes the keyboard here while the bar holds it
            WlrLayershell.keyboardFocus: dock.launcherHost === launcherPanel ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            function adjacent(a, b) {
                const p = bar.placeMap[a];
                const q = bar.placeMap[b];
                return !!p && !!q && p.zone === q.zone && Math.abs(p.at - q.at) === 1;
            }

            // the overview and the dock menu shut each other
            Connections {
                function onExpandedChanged() {
                    if (workspacesMod.expanded)
                        dock.menuOpen = false;

                }

                target: workspacesMod
            }

            Connections {
                function onMenuOpenChanged() {
                    if (!dock.menuOpen)
                        return ;

                    workspacesMod.expanded = false;
                    // the launcher is a panel of the bar's own now, or stands where they open
                    if (bar.primary && (dock.launcherHost || Prefs.barHoldsBottom)) {
                        for (const m of bar.modules) {
                            if (m.expanded === true && m !== dock.launcherHost)
                                m.expanded = false;

                        }
                    }
                }

                target: dock
            }

            BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && bar.laidOut) ? barBlurRegion : null

            // clipped to the surface: hyprland frosts the whole layer for a region
            // wholly outside it, which is where a hidden bar's pills are
            Region {
                id: barBlurRegion

                intersection: Intersection.Intersect

                Region {
                    x: 0
                    y: !fullStrip.visible ? 0 : (Prefs.barBottom ? bar.height - bar.rowY - height : bar.rowY)
                    width: fullStrip.visible ? Math.round(bar.width) : 0
                    height: fullStrip.visible ? Theme.dp(Prefs.barHeight) : 0
                }

                Region {
                    x: coverStrip.visible ? Math.round(coverStrip.x) : 0
                    y: Prefs.barBottom ? bar.height - bar.rowY - Theme.dp(Prefs.barHeight) : bar.rowY
                    width: coverStrip.visible && coverStrip.opacity > 0.5 ? Math.round(coverStrip.width) : 0
                    height: coverStrip.visible ? Theme.dp(Prefs.barHeight) : 0
                }

                ModuleRegion {
                    blur: true
                    mod: workspacesMod
                }

                ModuleRegion {
                    blur: true
                    mod: wsSeat
                }

                ModuleRegion {
                    blur: true
                    mod: mprisMod
                }

                ModuleRegion {
                    blur: true
                    mod: sysTrayMod
                }

                ModuleRegion {
                    blur: true
                    mod: clockMod
                }

                ModuleRegion {
                    blur: true
                    mod: notifMod
                }

                ModuleRegion {
                    blur: true
                    mod: systemMod
                }

                ModuleRegion {
                    blur: true
                    mod: privacyMod
                }

                ModuleRegion {
                    blur: true
                    mod: powerMod
                }

                ModuleRegion {
                    blur: true
                    mod: windowMod
                }

                ModuleRegion {
                    blur: true
                    mod: startMod
                }

                ModuleRegion {
                    blur: true
                    mod: appsMod
                }

                ModuleRegion {
                    blur: true
                    mod: launcherPanel
                }

                BridgeRegion {
                    host: bar
                    index: 0
                }

                BridgeRegion {
                    host: bar
                    index: 1
                }

                BridgeRegion {
                    host: bar
                    index: 2
                }

                BridgeRegion {
                    host: bar
                    index: 3
                }

                BridgeRegion {
                    host: bar
                    index: 4
                }

                BridgeRegion {
                    host: bar
                    index: 5
                }

                BridgeRegion {
                    host: bar
                    index: 6
                }

                BridgeRegion {
                    host: bar
                    index: 7
                }

                // the concave corners the bar draws outside any module: the full
                // strip's ends at the screen sides, a cover strip's ends, and the
                // hang plan's fillets. the modules' own come with their regions
                FlareRegion {
                    host: bar
                    on: fullStrip.visible && !bar.hangPlan.edges.left
                    mirrored: true
                    size: Theme.dp(Prefs.barFullCorner)
                    fx: 0
                    fy: Theme.dp(Prefs.barHeight) + bar.rowY
                }

                FlareRegion {
                    host: bar
                    on: fullStrip.visible && !bar.hangPlan.edges.right
                    size: Theme.dp(Prefs.barFullCorner)
                    fx: bar.width - size
                    fy: Theme.dp(Prefs.barHeight) + bar.rowY
                }

                FlareRegion {
                    host: bar
                    on: coverStrip.visible && coverStrip.opacity > 0.5 && !dock.barUnderLeft
                    size: Theme.dp(Prefs.barNotchFlare)
                    depth: Math.min(size, Theme.dp(Prefs.barHeight))
                    fx: coverStrip.x - size
                    fy: bar.rowY
                }

                FlareRegion {
                    host: bar
                    on: coverStrip.visible && coverStrip.opacity > 0.5 && !dock.barUnderRight
                    mirrored: true
                    size: Theme.dp(Prefs.barNotchFlare)
                    depth: Math.min(size, Theme.dp(Prefs.barHeight))
                    fx: coverStrip.x + coverStrip.width
                    fy: bar.rowY
                }

                FilletRegions {
                    host: bar
                }

            }

        }

    }

    Dock {
        id: dock

        osd: osdMod
    }

    // edit mode's toolbar and its sheet of options, over everything
    EditLayer {
    }

    // lucidshot: the engine that saves and copies captures, the overlay they
    // are chosen on, the cards they land in, pins, and the recording controls
    ShotEngine {
        id: shotEngine

        cards: shotCards
        onReady: (entry) => {
            // the overlay made its card already and only needed the file
            if (entry.owner === "overlay") {
                shotCards.update(entry);
                return ;
            }
            if (entry.owner === "pin")
                return ;

            root.announceShot(entry);
        }
        onFailed: (id, why) => {
            return toastMod.popup("warning", why, true);
        }
        onTextRead: (r) => {
            // the overlay and the cards take their own; this is a read over ipc
            if (!shotEngine.claim(r.id))
                return ;

            if (r.status === "ok") {
                if (Prefs.shotPreview === "preview")
                    shotCards.show({
                    "id": r.id,
                    "kind": "text",
                    "text": r.text,
                    "codes": r.codes,
                    "screen": Monitors.focusedScreen ? Monitors.focusedScreen.name : ""
                });
                else
                    toastMod.popup("copy", "Text copied", false);
            } else if (r.status === "notool") {
                toastMod.popup("alert", "Install tesseract to copy text", true);
            } else {
                toastMod.popup("alert", "No text found", true);
            }
        }
    }

    ShotOverlay {
        id: shotOverlay

        engine: shotEngine
        cards: shotCards
        pins: shotPins
        onNotify: (icon, text, warn) => {
            return toastMod.popup(icon, text, warn);
        }
        onSwatch: (hex, text) => {
            return toastMod.popupSwatch(hex, text);
        }
        onFreezeFailed: (why) => {
            return toastMod.popup("alert", "Couldn't capture the screen", true);
        }
    }

    ShotCards {
        id: shotCards

        engine: shotEngine
        pins: shotPins
        overlay: shotOverlay
    }

    PinBoard {
        id: shotPins

        engine: shotEngine
    }

    RecordHud {
    }

    Connections {
        function onSaved(file, seconds) {
            root.announceShot({
                "id": "rec-" + Date.now(),
                "kind": "video",
                "file": file,
                "duration": seconds,
                "screen": Capture.output
            });
        }

        function onFailed(why) {
            toastMod.popup("warning", why, true);
        }

        target: Capture
    }


    WidgetLayer {
        id: widgetLayer
    }

    WidgetIpc {
    }

    MonitorIpc {
    }

    Desktop {
    }

    // the desktop icons' overlays: the rename field, the undo snackbar and the
    // confirm dialog, built only while the icons are on
    LazyLoader {
        active: DesktopIcons.live

        Scope {
            IconRename {
            }

            DeskSnackbar {
            }

            DeskDialog {
            }

        }

    }

    Osd {
        id: osdMod

        dockWindow: dock
    }

    PinnedWindows {
    }

    UrgentWindows {
    }

    Toast {
        id: toastMod
    }

    ToastEvents {
        toast: toastMod
        osd: osdMod
    }

    Lock {
        id: lockMod
    }

    Moji {
        id: mojiMod
    }

    Keyboard {
        id: keyboardMod
    }

    KeybindSheet {
        id: keybindSheetMod
    }

    WhatsNew {
        id: whatsNewMod
    }

    // the update pop-up: warning, password, progress, restart
    UpdateSheet {
        id: updateSheetMod
    }

    SettingsHost {
        id: settingsMod
    }

    // the numbers the Displays page puts on every screen
    DisplayIdentify {
    }

    // "keep these display settings?" on every screen while a change is on trial
    DisplayTrial {
    }

    // the map on the Displays page marks the displays these sit on
    Binding {
        target: Monitors
        property: "barWindows"
        value: bars.instances
    }

    Auth {
        id: polkitMod
    }

    Session {
        id: sessionMod
    }

    Switcher {
        id: switcherMod

        dockMod: dock
    }

    Connections {
        function onSettingsRequested() {
            settingsMod.show("notifications");
        }

        target: Notifs
    }

    PanelWindow {
        id: clickCatcher

        visible: dock.menuInDock && Monitors.surfacesUp
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: dock.menuOpen = false
        }

    }

    // every surface there is one of, on the display Settings > Displays picks —
    // the dock can be sent to one of its own (the bar places itself), the rest
    // follow the shell. gated, because unset must leave the choice to hyprland,
    // which null would not. emoji and screenshot act on the window you are in,
    // so they follow the focus, and so does the launcher while the dock is off
    // (Dock.launcherPlacement)
    Instantiator {
        model: [dock, clickCatcher]

        Binding {
            required property var modelData

            target: modelData
            property: "screen"
            value: dock.launcherPlacement || Monitors.dockPlacement
            when: (dock.launcherPlacement || Monitors.dockPlacement) !== null
        }

    }

    Instantiator {
        model: [toastMod, keyboardMod, polkitMod, keybindSheetMod, whatsNewMod]

        Binding {
            required property var modelData

            target: modelData
            property: "screen"
            value: Monitors.shellPlacement
            when: Monitors.shellPlacement !== null
        }

    }

    // the osd follows the shell too, unless no display is picked for it: then
    // it shows on the one being worked on, as the launcher does (Osd.placement)
    Binding {
        target: osdMod
        property: "screen"
        value: osdMod.placement || Monitors.shellPlacement
        when: (osdMod.placement || Monitors.shellPlacement) !== null
    }

    Connections {
        function onKeyboardRequested() {
            keyboardMod.show();
        }

        target: Prefs
    }

    Connections {
        function onDesktopActionRequested(action) {
            if (action === "wallpaper")
                dock.openLauncher(">wallpaper");
            else if (action === "theme")
                dock.openLauncher(">theme");
            else if (action === "screenshot")
                shotOverlay.begin("shot", "");

        }

        target: Prefs
    }

}
