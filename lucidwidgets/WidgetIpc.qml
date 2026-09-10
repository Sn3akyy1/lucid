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
