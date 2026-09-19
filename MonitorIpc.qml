import Quickshell
import Quickshell.Io
import qs

IpcHandler {
    target: "displays"

    // qs ipc call -- displays shell middle, or here, next, auto, or DP-2
    function shell(where: string): string {
        return Monitors.aimSurfaceLabel("shell", where);
    }

    // the bar and dock can sit apart from the rest; auto puts them back with it
    function bar(where: string): string {
        return Monitors.aimSurfaceLabel("bar", where);
    }

    function dock(where: string): string {
        return Monitors.aimSurfaceLabel("dock", where);
    }

    // a number on every screen, the one its box carries on the page
    function identify(): void {
        Monitors.identify();
    }

    function list(): string {
        return Monitors.rundown();
    }

    function settings(): void {
        Prefs.settingsRequested("displays");
    }

}
