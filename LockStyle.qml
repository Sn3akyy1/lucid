pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "lucidlock/parts/Catalog.js" as Catalog

// the lock screen's layout: which preset, which widget in which slot, each
// widget's options, and the backdrop. the lock and the settings' preview read
// it here; every change is also sent on to the login screen, which wears the
// same layout for this account
Singleton {
    id: root

    // the catalogue in the shell's language; ids and the rest stay as they are
    readonly property var presets: Catalog.presets.map((p) => {
        return root.localized(p);
    })
    readonly property var widgets: Catalog.widgets.map((w) => {
        return root.localized(w);
    })
    readonly property var sizes: Catalog.sizes.map((s) => {
        return [s[0], I18n.tr(s[1])]; // i18n-dynamic
    })
    readonly property var layout: Catalog.build(Prefs.lockPreset, Prefs.lockSlots, Prefs.lockWidgetOpts, {
        "blur": Prefs.lockBlur,
        "dim": Prefs.lockDim,
        "tint": Prefs.lockTint,
        "other": Prefs.lockOtherScreens
    })
    // ── the style editor's draft ───────────────────────────────────────────
    // the full-screen editor works on a copy: the lock keeps the applied layout
    // until Apply, and closing the editor without it changes nothing
    property bool editorOpen: false
    property bool drafting: false
    // the sheet the editor opens on: "" or "widgets"
    property string editorSheet: ""
    // ── the editor and LucidShot ───────────────────────────────────────────
    // the editor's window is on screen, and on which display
    property bool editorShown: false
    property string editorScreen: ""
    // a beat after it maps: LucidShot's pins, cards and recording pill, mapped
    // before it, restack over it then (same-layer surfaces stack in map order)
    property bool editorSettled: false
    // what LucidShot's window mode offers while the editor hides the windows:
    // [{x, y, w, h, title, round}] in the display's logical pixels
    property var shotTargets: []

    onEditorShownChanged: {
        if (root.editorShown) {
            settle.restart();
        } else {
            settle.stop();
            root.editorSettled = false;
            root.shotTargets = [];
        }
    }
    // {preset, slots: {preset: {slot: [types]}}, opts: {type: {...}}}
    property var draft: null
    readonly property var extras: ({
        "blur": Prefs.lockBlur,
        "dim": Prefs.lockDim,
        "tint": Prefs.lockTint,
        "other": Prefs.lockOtherScreens
    })
    // what every edit below reads and writes: the draft while there is one
    readonly property var work: root.drafting && root.draft ? Catalog.build(root.draft.preset, JSON.stringify(root.draft.slots), JSON.stringify(root.draft.opts), root.extras) : root.layout
    readonly property string preset: root.work.preset
    readonly property bool dirty: root.drafting && !!root.draft && (root.draft.preset !== Prefs.lockPreset || JSON.stringify(root.draft.slots) !== JSON.stringify(Catalog.parse(Prefs.lockSlots, {})) || JSON.stringify(root.draft.opts) !== JSON.stringify(Catalog.parse(Prefs.lockWidgetOpts, {})))

    function openEditor(sheet) {
        root.editorSheet = sheet || "";
        if (!root.editorOpen) {
            root.draft = {
                "preset": Catalog.preset(Prefs.lockPreset).id,
                "slots": Catalog.parse(Prefs.lockSlots, {}),
                "opts": Catalog.parse(Prefs.lockWidgetOpts, {})
            };
            root.drafting = true;
        }
        root.editorOpen = true;
    }

    // asked to go from outside (the close bind): the editor asks first when
    // there are changes to drop, as its own close does
    signal dismissRequested()

    // the window plays its way out, then calls endDraft
    function closeEditor(keep) {
        if (keep)
            root.apply();

        root.editorOpen = false;
    }

    function endDraft() {
        if (root.editorOpen)
            return ;

        root.drafting = false;
        root.draft = null;
    }

    function apply() {
        if (!root.drafting || !root.draft)
            return ;

        var d = root.draft;
        Prefs.lockPreset = d.preset;
        Prefs.lockSlots = Object.keys(d.slots).length === 0 ? "" : JSON.stringify(d.slots);
        Prefs.lockWidgetOpts = Object.keys(d.opts).length === 0 ? "" : JSON.stringify(d.opts);
    }

    function _slotsAll() {
        return root.drafting && root.draft ? JSON.parse(JSON.stringify(root.draft.slots)) : Catalog.parse(Prefs.lockSlots, {});
    }

    function _optsAll() {
        return root.drafting && root.draft ? JSON.parse(JSON.stringify(root.draft.opts)) : Catalog.parse(Prefs.lockWidgetOpts, {});
    }

    function _setSlotsAll(all) {
        if (root.drafting && root.draft)
            root.draft = Object.assign({}, root.draft, {
                "slots": all
            });
        else
            Prefs.lockSlots = Object.keys(all).length === 0 ? "" : JSON.stringify(all);
    }

    function _setOptsAll(all) {
        if (root.drafting && root.draft)
            root.draft = Object.assign({}, root.draft, {
                "opts": all
            });
        else
            Prefs.lockWidgetOpts = Object.keys(all).length === 0 ? "" : JSON.stringify(all);
    }

    // a catalogue entry with its names, blurb, styles and choices translated
    function localized(o) {
        if (Array.isArray(o))
            return o.map((x) => {
                return root.localized(x);
            });

        if (o === null || typeof o !== "object")
            return o;

        var out = {};
        for (var k in o) {
            var v = o[k];
            if ((k === "name" || k === "blurb" || k === "kind") && typeof v === "string")
                out[k] = I18n.tr(v); // i18n-dynamic
            else if ((k === "styles" || k === "choices") && Array.isArray(v))
                out[k] = v.map((p) => {
                    return Array.isArray(p) ? [p[0], I18n.tr(p[1])] : p; // i18n-dynamic
                });
            else if (k === "slots" || k === "options")
                out[k] = root.localized(v);
            else
                out[k] = v;
        }
        return out;
    }

    function presetInfo(id) {
        return root.presets.find((p) => {
            return p.id === id;
        }) || root.presets[0];
    }

    function widgetInfo(id) {
        return root.widgets.find((w) => {
            return w.id === id;
        }) || null;
    }

    function slotInfo(id) {
        return root.presetInfo(root.preset).slots.find((s) => {
            return s.id === id;
        }) || null;
    }

    // the slot a widget sits in on the current preset, or ""
    function placedIn(type) {
        return Catalog.placed(root.work.slots, type);
    }

    function opt(type, key) {
        return Catalog.opt(root.work, type, key);
    }

    function presetOpt(key) {
        return Catalog.presetOpt(root.work, key);
    }

    // a widget's options as the editor offers them: those that apply to its
    // current style, and only those the screen being edited can show
    function optionsFor(type, greeter) {
        var w = root.widgetInfo(type);
        if (!w || !w.options)
            return [];

        var style = root.opt(type, "style");
        return w.options.filter((o) => {
            return (!o.styles || o.styles.indexOf(style) !== -1) && (!greeter || o.where !== "lock");
        });
    }

    // ── edits ──────────────────────────────────────────────────────────────
    function setPreset(id) {
        var p = Catalog.preset(id);
        if (root.drafting && root.draft) {
            if (p.id !== root.draft.preset)
                root.draft = Object.assign({}, root.draft, {
                    "preset": p.id
                });

        } else if (p.id !== Prefs.lockPreset) {
            Prefs.lockPreset = p.id;
        }
    }

    function _writeSlots(next) {
        var all = root._slotsAll();
        all[root.preset] = next;
        root._setSlotsAll(all);
    }

    function add(slot, type, index) {
        if (!Catalog.hasSlot(root.preset, slot) || !Catalog.widget(type))
            return ;

        root._writeSlots(Catalog.withWidget(root.work.slots, slot, type, index));
    }

    function remove(type) {
        root._writeSlots(Catalog.without(root.work.slots, type));
    }

    // one step along its slot, or into the next slot at either end
    function nudge(type, by) {
        var slots = root.work.slots;
        var here = Catalog.placed(slots, type);
        if (here === "")
            return ;

        var list = slots[here];
        var i = list.indexOf(type) + by;
        if (i >= 0 && i < list.length) {
            root._writeSlots(Catalog.withWidget(slots, here, type, i));
            return ;
        }
        var order = Catalog.preset(root.preset).slots.map((s) => {
            return s.id;
        });
        var j = order.indexOf(here) + by;
        if (j < 0 || j >= order.length)
            return ;

        root._writeSlots(Catalog.withWidget(slots, order[j], type, by > 0 ? 0 : -1));
    }

    function move(type, slot, index) {
        root.add(slot, type, index);
    }

    function setOpt(type, key, value) {
        var all = root._optsAll();
        var mine = Object.assign({}, all[type] || {});
        mine[key] = value;
        all[type] = mine;
        root._setOptsAll(all);
    }

    function setPresetOpt(key, value) {
        root.setOpt(root.preset, key, value);
    }

    // this preset's slots back to how it ships; options stay
    function resetSlots() {
        var all = root._slotsAll();
        delete all[root.preset];
        root._setSlotsAll(all);
    }

    // one widget's options back to the preset's own
    function resetOpts(type) {
        var all = root._optsAll();
        delete all[type];
        root._setOptsAll(all);
    }

    function hasOwnOpts(type) {
        var all = root.drafting && root.draft ? root.draft.opts : Catalog.parse(Prefs.lockWidgetOpts, {});
        return !!all[type] && Object.keys(all[type]).length > 0;
    }

    // ── the login screen ───────────────────────────────────────────────────
    // the last reading, for a login screen that has no network of its own. no
    // place and no coordinates: only what the sky was doing, and when
    readonly property var weatherSnap: {
        var r = WeatherSource.report;
        if (!Prefs.lockLoginWeather || !r)
            return null;

        var today = r.days && r.days.length > 0 ? r.days[0] : null;
        return {
            "code": r.code,
            "kind": WeatherSource.kindFor(r.code, r.isDay === false),
            "temp": Units.deg(r.tempC, r.tempF),
            "desc": WeatherSource.descFor(r.code),
            "hi": today ? Units.deg(today.maxC, today.maxF) : "",
            "lo": today ? Units.deg(today.minC, today.minF) : "",
            "feels": Units.deg(r.feelsC, r.feelsF),
            "at": Math.round(WeatherSource.fetchedAt / 1000)
        };
    }
    readonly property string layoutJson: JSON.stringify(root.layout)
    readonly property string weatherJson: root.weatherSnap ? JSON.stringify(root.weatherSnap) : ""
    // lock ok | lock old | lock readonly | lock notheme | lock notlucid | "" before the first run
    property string loginStatus: ""
    property real loginSyncedAt: 0
    readonly property string syncScript: Quickshell.env("HOME") + "/.config/lucid/sync-sddm.sh"

    function syncNow() {
        if (!Prefs.loaded || !Prefs.lockLoginSync)
            return ;

        if (sync.running) {
            syncAgain.restart();
            return ;
        }
        sync.command = [root.syncScript, "--lock", root.layoutJson, root.weatherJson];
        sync.running = true;
    }

    onLayoutJsonChanged: syncSoon.restart()
    onWeatherJsonChanged: syncSoon.restart()

    // the editor writes on every click; the login screen only needs the last
    Timer {
        id: syncSoon

        interval: 1500
        onTriggered: root.syncNow()
    }

    Timer {
        id: syncAgain

        interval: 400
        onTriggered: root.syncNow()
    }

    // once after the shell settles, so a fresh login screen is never behind
    Timer {
        running: Prefs.loaded
        interval: 15000
        onTriggered: root.syncNow()
    }

    Timer {
        id: settle

        interval: 160
        onTriggered: root.editorSettled = true
    }

    // qs ipc call lockstyle open
    IpcHandler {
        target: "lockstyle"

        function open(): void {
            root.openEditor("");
        }

        function close(): void {
            root.closeEditor(false);
        }

        // what the close bind calls: like the editor's own close button
        function dismiss(): void {
            if (root.editorOpen)
                root.dismissRequested();

        }

        function apply(): void {
            root.closeEditor(true);
        }
    }

    Process {
        id: sync

        stdout: StdioCollector {
            onStreamFinished: {
                var line = this.text.trim().split("\n").filter((l) => {
                    return l.indexOf("lock ") === 0;
                }).pop() || "";
                root.loginStatus = line;
                if (line === "lock ok" || line === "lock old")
                    root.loginSyncedAt = Date.now();

            }
        }

    }

}
