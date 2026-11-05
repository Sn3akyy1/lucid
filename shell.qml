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
    // the sounds, so their ipc target answers before anything has played, and
    // storage, which warns when space runs low and empties old trash
    Component.onCompleted: {
        void KdeConnect.installed;
        void Bt.present;
        void BtReceive.status;
        void BtAgent.status;
        void Net.connectivity;
        void Idle.probed;
        void Env.probed;
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

            PaletteFade {
                active: bar.visible
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
                let x = originX;
                let any = false;
                let trailing = 0;
                for (let i = 0; i < widths.length; i++) {
                    out.push(x);
                    const w = widths[i];
                    if (w > 0.5) {
                        trailing = keys && bar.joinedAfter(keys, widths, i) ? 0 : (gap > 0 ? gap * Math.min(1, w / gap) : 0);
                        x += w + trailing;
                        any = true;
                    }
                }
                out.push(any ? Math.max(originX, x - trailing) : originX);
                return out;
            }

            // whether the module at i is joined to the one right after it. both
            // have to be in the bar this moment: one that has emptied out (a tray
            // with no icons, workspaces off in the overview) parts its group there
            function joinedAfter(keys, widths, i) {
                return i + 1 < keys.length && widths[i] > 0.5 && widths[i + 1] > 0.5 && bar.realWidthOf(keys[i]) > 0.5 && bar.realWidthOf(keys[i + 1]) > 0.5 && Prefs.barJoinedNow(keys[i], keys[i + 1]);
            }

            // what a module's pill reads to square off the corners it shares
            function joinedLeftOf(key) {
                const at = bar.placeMap[key];
                if (!at || at.at === 0)
                    return false;

                const keys = bar.zoneKeys(at.zone);
                return bar.realWidthOf(key) > 0.5 && bar.realWidthOf(keys[at.at - 1]) > 0.5 && Prefs.barJoinedNow(keys[at.at - 1], key);
            }

            function joinedRightOf(key) {
                const at = bar.placeMap[key];
                if (!at)
                    return false;

                const keys = bar.zoneKeys(at.zone);
                return at.at + 1 < keys.length && bar.realWidthOf(key) > 0.5 && bar.realWidthOf(keys[at.at + 1]) > 0.5 && Prefs.barJoinedNow(key, keys[at.at + 1]);
            }

            // per module key, radius caps where a hanging panel meets the islands: {corners, tops, sides, fillets},
            // plus what the full bar fills between merged open panels: {bridges, merged, edges}
            readonly property var hangPlan: bar.planHangs()

            function surfaceSpan(mod) {
                const l = mod.x + (mod.surfaceX !== undefined ? mod.surfaceX : 0);
                return [l, l + (mod.surfaceWidth !== undefined ? mod.surfaceWidth : mod.width)];
            }

            function planHangs() {
                const plan = ({
                    "corners": ({}),
                    "tops": ({}),
                    "sides": ({}),
                    "fillets": [],
                    "bridges": [],
                    "merged": ({}),
                    "edges": ({})
                });
                const popups = Prefs.barPopupMode;
                if (popups && !Prefs.barPopupNotched)
                    return plan;

                const most = Theme.dp(Prefs.barNotchFlare);
                const bite = 0.5;
                const cap = (key, corner, v) => {
                    const c = plan.corners[key] || (plan.corners[key] = ({}));
                    c[corner] = Math.min(c[corner] === undefined ? 1e6 : c[corner], Math.max(0, v));
                };
                const fillet = (x, y, size, mirrored, flipped) => {
                    if (size >= 1)
                        plan.fillets.push({ "x": x, "y": y, "size": size, "mirrored": mirrored, "flipped": flipped });

                };
                // full bar and notches: open panels side by side become one shape.
                // the gap between them fills in, and the shorter one's shared corner
                // turns into a fillet against the taller one's side
                if ((Prefs.barFull || Prefs.barNotch) && !popups && Prefs.barFullMerge) {
                    // a notch has no strip under the gap, so it fills from the top
                    const strip = Prefs.barFull ? Theme.dp(Prefs.barHeight) : 0;
                    const corner = Prefs.barFull ? Theme.dp(Prefs.barFullCorner) : most;
                    const row = bar.modules.filter((m) => {
                        return m.visible && m.width > 0.5;
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
                        if (gap > 0.5 && low > strip)
                            plan.bridges.push({ "x": a.x + a.width, "y": a.y + strip, "w": gap, "h": low - strip });

                        if (shortLeft)
                            fillet(b.x - f + bite, a.y + low - bite, f, false, false);
                        else
                            fillet(a.x + a.width - bite, a.y + low - bite, f, true, false);
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
                            plan.bridges.push({ "x": left ? 0 : m.x + m.width, "y": m.y + strip, "w": gap, "h": m.height - strip });

                        fillet(left ? -bite : bar.width - corner + bite, m.y + m.height - bite, corner, left, false);
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
                        if (!mod || bar.widthOf(keys[i]) <= 0.5) {
                            run = null;
                            continue;
                        }
                        if (run && Prefs.barJoinedNow(keys[i - 1], keys[i])) {
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
                            if (j > 0 && !merged.left) {
                                const run = m.x - isle.l;
                                const f = Math.floor(Math.min(most, run / 2, depth / 2));
                                fillet(m.x - f + bite, isle.bottom - bite, f, false, false);
                                cap(isle.keys[0], "bl", run - f);
                                side.bl = depth - f;
                            }
                            if (j < isle.keys.length - 1 && !merged.right) {
                                const run = isle.r - (m.x + m.width);
                                const f = Math.floor(Math.min(most, run / 2, depth / 2));
                                fillet(m.x + m.width - bite, isle.bottom - bite, f, true, false);
                                cap(isle.keys[isle.keys.length - 1], "br", run - f);
                                side.br = depth - f;
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
                            fillet(isle.l - f + bite, shelf.y - f + bite, f, false, true);
                            cap(first, "bl", 0);
                        } else if (dl > 0.5) {
                            const f = Math.floor(Math.min(most, dl / 2, tall));
                            fillet(isle.l - f + bite, shelf.y - f + bite, f, false, true);
                            cap(first, "bl", 0);
                            top.tl = dl - f;
                        } else if (dl < -0.5) {
                            const f = Math.floor(Math.min(most, -dl / 2, shelf.depth / 2));
                            fillet(shelf.l - f + bite, shelf.y - bite, f, false, false);
                            cap(first, "bl", -dl - f);
                            top.tl = 0;
                        } else {
                            cap(first, "bl", 0);
                            top.tl = 0;
                        }
                        const dr = shelf.r - isle.r;
                        if (k < over.length - 1) {
                            const f = Math.floor(Math.min(most, (over[k + 1].l - isle.r) / 2, tall));
                            fillet(isle.r - bite, shelf.y - f + bite, f, true, true);
                            cap(last, "br", 0);
                        } else if (dr > 0.5) {
                            const f = Math.floor(Math.min(most, dr / 2, tall));
                            fillet(isle.r - bite, shelf.y - f + bite, f, true, true);
                            cap(last, "br", 0);
                            top.tr = dr - f;
                        } else if (dr < -0.5) {
                            const f = Math.floor(Math.min(most, -dr / 2, shelf.depth / 2));
                            fillet(shelf.r - bite, shelf.y - bite, f, true, false);
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
                "start": startMod
            })
            // what BarPill looks itself up in, for a right click to its card
            readonly property var moduleById: bar.pillFor
            readonly property var modules: [workspacesMod, mprisMod, sysTrayMod, clockMod, notifMod, systemMod, privacyMod, powerMod, windowMod, startMod]

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
            // rest of its zone closes up behind it
            function realWidthOf(key) {
                const it = bar.pillFor[key];
                if (!it)
                    return 0;

                return it === workspacesMod ? it.width * bar.wsCollapse : it.width;
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
            readonly property real sideMargin: Theme.dp(Prefs.barSideMargin)

            // busy: a panel is open somewhere on the bar, so it stays out
            // regardless of the pointer. held: the pointer is on the reveal
            // strip or already on a module - either keeps it from hiding
            readonly property bool barBusy: bar.modules.some((m) => {
                return m.expanded === true || m.anyOpen === true;
            })
            property bool slidingAway: false
            readonly property bool heldByPointer: revealArea.containsMouse || (!bar.slidingAway && bar.modules.some((m) => {
                return m.visible && (m.surfaceHovered === true || m.compactHovered === true);
            }))
            readonly property bool barRevealed: !Prefs.barAutoHide || bar.barBusy || bar.heldByPointer || Edit.active
            // how far the compact content sits above its resting y=0 while
            // hidden - past the window's own top edge, so it clips away for free
            property real hiddenOffset: bar.barRevealed ? 0 : -(Theme.dp(Prefs.barHeight) + Prefs.effectiveBarTopMargin + Theme.dp(4))

            Behavior on hiddenOffset {
                NumberAnimation {
                    duration: Theme.durLong
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
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

            Component.onCompleted: laidOutTimer.start()

            Timer {
                id: laidOutTimer

                interval: 120
                onTriggered: bar.laidOut = true
            }

            color: "transparent"
            implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : Theme.dp(800)
            exclusiveZone: (Prefs.barEnabled && bar.anyModuleShown && !Prefs.barAutoHide) ? Theme.dp(Prefs.barHeight) + Prefs.shellGap : 0

            anchors {
                top: true
                bottom: false
                left: true
                right: true
            }

            margins {
                top: Prefs.effectiveBarTopMargin
            }

            // full bar: one strip across the whole top edge, under every module
            Rectangle {
                id: fullStrip

                visible: Prefs.barFull && bar.anyModuleShown
                x: 0
                y: bar.hiddenOffset
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

            // rounded corners hanging off the strip where it meets the screen sides
            BarFlare {
                visible: fullStrip.visible && size > 0 && !bar.hangPlan.edges.left
                mirrored: true
                size: Theme.dp(Prefs.barFullCorner)
                x: 0
                y: Theme.dp(Prefs.barHeight) + bar.hiddenOffset
                z: -2
            }

            BarFlare {
                visible: fullStrip.visible && size > 0 && !bar.hangPlan.edges.right
                size: Theme.dp(Prefs.barFullCorner)
                x: bar.width - width
                y: Theme.dp(Prefs.barHeight) + bar.hiddenOffset
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

                    // surfaceOpen, not the height alone: a pill that is only
                    // resizing its compact face is see-through on the full bar
                    readonly property real reach: (panelFlares.modelData.visible && panelFlares.modelData.surfaceOpen === true) ? panelFlares.modelData.height - Theme.dp(Prefs.barHeight) : 0

                    // never past the screen edge, and never into the screen corner
                    // that already rounds that side
                    function sizeFor(toTheLeft) {
                        var m = panelFlares.modelData;
                        // that side is merged into an open neighbour, which covers it
                        var merged = bar.hangPlan.merged[m.modId];
                        if (merged && (toTheLeft ? merged.left : merged.right))
                            return 0;

                        var corner = Theme.dp(Prefs.barFullCorner);
                        var toEdge = toTheLeft ? m.x : bar.width - m.x - m.width;
                        var room = toEdge - (toEdge < corner * 2 ? corner : 0);
                        return Math.max(0, Math.floor(Math.min(corner, panelFlares.reach, room)));
                    }

                    anchors.fill: parent
                    z: -1

                    BarFlare {
                        size: panelFlares.sizeFor(true)
                        x: panelFlares.modelData.x - width + 0.5
                        y: Theme.dp(Prefs.barHeight)
                    }

                    BarFlare {
                        mirrored: true
                        size: panelFlares.sizeFor(false)
                        x: panelFlares.modelData.x + panelFlares.modelData.width - 0.5
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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("media")

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("tray")

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("clock")
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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("notifications")

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("privacy")

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("power")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "power"

                    NumberAnimation {
                        duration: Theme.barDurEnter
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

            StartButton {
                id: startMod

                popupAlign: bar.alignOf("start")

                hostWindow: bar
                dockMod: dock
                x: bar.xOf("start")
                editLifted: bar.dragKey === "start"
                anchors.top: parent.top
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("start")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling && bar.dragKey !== "start"

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("window")

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
                anchors.topMargin: bar.hiddenOffset + bar.liftOf("system")

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

                    function flareFor(toTheLeft) {
                        if (!flares.present)
                            return 0;

                        var mods = bar.modules;
                        var edge = toTheLeft ? flares.modelData.x : flares.modelData.x + flares.modelData.width;
                        var toEdge = toTheLeft ? edge : bar.width - edge;
                        var toNeighbour = 100000;
                        for (var i = 0; i < mods.length; i++) {
                            var o = mods[i];
                            if (!o || o === flares.modelData || o.width <= 0.5 || !o.visible)
                                continue;

                            var d = toTheLeft ? edge - (o.x + o.width) : o.x - edge;
                            if (d >= 0)
                                toNeighbour = Math.min(toNeighbour, d);

                        }
                        return Math.max(0, Math.min(Theme.dp(Prefs.barNotchFlare), Math.floor(toNeighbour / 2), Math.floor(toEdge)));
                    }

                    anchors.fill: parent
                    z: -1
                    visible: Prefs.barNotch && flares.present

                    readonly property real bite: 0.5

                    BarFlare {
                        hovered: flares.modHovered
                        size: flares.flareFor(true)
                        x: flares.modelData ? flares.modelData.x - width + flares.bite : 0
                        y: bar.hiddenOffset
                    }

                    BarFlare {
                        hovered: flares.modHovered
                        mirrored: true
                        size: flares.flareFor(false)
                        x: flares.modelData ? flares.modelData.x + flares.modelData.width - flares.bite : 0
                        y: bar.hiddenOffset
                    }

                }

            }

            // fillets where a hanging panel meets the islands above it
            Repeater {
                model: 16

                BarFlare {
                    required property int index
                    readonly property var spec: bar.hangPlan.fillets.length > index ? bar.hangPlan.fillets[index] : null

                    z: 0
                    size: spec ? spec.size : 0
                    mirrored: spec ? spec.mirrored : false
                    flipped: spec ? spec.flipped : false
                    x: spec ? spec.x : 0
                    y: spec ? spec.y : 0
                }

            }

            // the gaps filled between open panels the full bar merges
            Repeater {
                model: 8

                Rectangle {
                    required property int index
                    readonly property var spec: bar.hangPlan.bridges.length > index ? bar.hangPlan.bridges[index] : null

                    z: 0
                    visible: spec !== null
                    x: spec ? spec.x : 0
                    y: spec ? spec.y : 0
                    width: spec ? spec.w : 0
                    height: spec ? spec.h : 0
                    color: Theme.bg
                }

            }

            Workspaces {
                id: workspacesMod

                hostWindow: bar
                dockMod: dock
                restX: bar.xOf("workspaces")
                restY: bar.hiddenOffset + bar.liftOf("workspaces")
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

                Region {
                    item: Prefs.barAutoHide ? revealArea : null
                }

                Region {
                    width: bar.dragHeld || Edit.active ? bar.width : 0
                    height: bar.dragHeld ? bar.height : (Edit.active ? Theme.dp(Prefs.barHeight) + Theme.dp(4) : 0)
                }

            }

            BarEdit {
                id: barEdit

                host: bar
            }

            // touching this strip reveals the bar
            MouseArea {
                id: revealArea

                x: 0
                y: 0
                width: bar.width
                height: Theme.dp(4)
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                enabled: Prefs.barAutoHide
                visible: Prefs.barAutoHide
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
                    if (dock.menuOpen)
                        workspacesMod.expanded = false;

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
                    y: fullStrip.visible ? bar.hiddenOffset : 0
                    width: fullStrip.visible ? Math.round(bar.width) : 0
                    height: fullStrip.visible ? Theme.dp(Prefs.barHeight) : 0
                }

                ModuleRegion {
                    blur: true
                    mod: workspacesMod
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

        visible: dock.menuOpen && Monitors.surfacesUp
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
