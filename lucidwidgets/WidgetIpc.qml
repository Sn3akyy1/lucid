import Quickshell.Io
import qs

IpcHandler {
    target: "widgets"

    // qs ipc call -- widgets add clock analog
    function add(type: string, variant: string): void {
        Widgets.spawn(type, variant === "" ? "" : variant);
    }

    function remove(uid: string): void {
        Widgets.close(uid);
    }

    function style(uid: string, variant: string): void {
        Widgets.setVariant(uid, variant);
    }

    function size(uid: string, zoom: string): void {
        Widgets.setScale(uid, parseFloat(zoom));
    }

    // only the variants that carry their own size take this
    function resize(uid: string, w: string, h: string): void {
        Widgets.setSize(uid, parseFloat(w), parseFloat(h));
    }

    function place(uid: string, x: string, y: string): void {
        Widgets.setPos(uid, parseFloat(x), parseFloat(y));
    }

    function pin(uid: string): void {
        Widgets.togglePinned(uid);
    }

    function set(uid: string, key: string, value: string): void {
        var v = value === "true" ? true : (value === "false" ? false : value);
        Widgets.setOption(uid, key, v);
    }

    function clear(): void {
        Widgets.closeAll();
    }

    // qs ipc call -- widgets preset collage, or the name of one you saved
    function preset(name: string): string {
        var p = Widgets.presetAt(name) || Widgets.userPresetNamed(name);
        if (p !== null && Widgets.applyPreset(p.id))
            return "";

        return "no preset called \"" + name + "\", see: qs ipc call widgets presets";
    }

    function presets(): string {
        return Widgets.userPresets.concat(Widgets.presets).map((p) => {
            return (Widgets.presetId === p.id ? "* " : "  ") + p.id + "  " + p.name + (p.blurb ? " - " + p.blurb : "  (saved, " + p.cards.length + " widgets)");
        }).join("\n");
    }

    // keeps the desktop as a preset; an existing name is updated
    function save(name: string): string {
        var id = Widgets.savePreset(name);
        return id !== "" ? id : "give it a name, and place a widget first";
    }

    function discard(name: string): string {
        var p = Widgets.userPresetNamed(name) || Widgets.presetAt(name);
        return (p !== null && Widgets.deletePreset(p.id)) ? "" : "no saved preset called \"" + name + "\"";
    }

    // back to the unsaved arrangement the last preset replaced
    function restore(): string {
        return Widgets.restoreLast() ? "" : "nothing to go back to";
    }

    function toggle(): void {
        Prefs.widgetsEnabled = !Prefs.widgetsEnabled;
    }

    function lock(): void {
        Prefs.widgetLockAll = true;
    }

    function unlock(): void {
        Prefs.widgetLockAll = false;
    }

    function settings(): void {
        Prefs.settingsRequested("widgets");
    }

    function list(): string {
        var out = [];
        for (var i = 0; i < Widgets.model.count; i++) {
            var e = Widgets.model.get(i);
            out.push(e.uid + "  " + e.wtype + "/" + e.wvariant + "  " + Math.round(e.wx) + "," + Math.round(e.wy) + (e.pinned ? "  pinned" : ""));
        }
        return out.length > 0 ? out.join("\n") : "no widgets on the desktop";
    }

    function catalogue(): string {
        var out = [];
        for (var i = 0; i < Widgets.catalogue.length; i++) {
            var t = Widgets.catalogue[i];
            out.push(t.id + ": " + t.variants.map((v) => {
                return v.id;
            }).join(", "));
        }
        return out.join("\n");
    }

}
