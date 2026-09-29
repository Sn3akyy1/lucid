import QtQuick
import Quickshell
import Quickshell.Io
import qs

// the settings window is forty-odd pages of ui and nothing reads it until it is
// opened, so it stays unbuilt until the first show. the ipc target and the prefs
// hookup live out here, where they answer from the first frame either way
Scope {
    id: host

    readonly property bool shown: window.item !== null && window.item.visible

    function show(page: string): void {
        window.active = true;
        if (window.item)
            window.item.show(page);
    }

    function hide(): void {
        if (window.item)
            window.item.visible = false;
    }

    LazyLoader {
        id: window

        active: false
        loading: false

        component: Component {
            Settings {
            }
        }

    }

    Connections {
        function onSettingsRequested(page) {
            host.show(page);
        }

        target: Prefs
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (host.shown)
                host.hide();
            else
                host.show("");
        }

        function open(): void {
            host.show("");
        }

        function close(): void {
            host.hide();
        }

        // qs ipc call settings show bar
        function show(page: string): void {
            host.show(page);
        }

        function general(): void {
            host.show("general");
        }

        function users(): void {
            host.show("users");
        }

        // the page is about accounts; both names reach it
        function accounts(): void {
            host.show("users");
        }

        function glass(): void {
            host.show("glass");
        }

        function bar(): void {
            host.show("bar");
        }

        function dock(): void {
            host.show("dock");
        }

        function colours(): void {
            host.show("colours");
        }

        function palettes(): void {
            host.show("palettes");
        }

        function environment(): void {
            host.show("environment");
        }

        function keybinds(): void {
            host.show("keybinds");
        }

        function displays(): void {
            host.show("displays");
        }

        // the page is about monitors; both names reach it
        function monitors(): void {
            host.show("displays");
        }

        function widgets(): void {
            host.show("widgets");
        }

        function workspaces(): void {
            host.show("workspaces");
        }

        function notifications(): void {
            host.show("notifications");
        }

        function sound(): void {
            host.show("sound");
        }

        // the page is called Sound; both names reach it
        function audio(): void {
            host.show("sound");
        }

        function network(): void {
            host.show("network");
        }

        function bluetooth(): void {
            host.show("bluetooth");
        }

        function kdeconnect(): void {
            host.show("kdeconnect");
        }

        // the page is called Phone now; the old name still works
        function phone(): void {
            host.show("kdeconnect");
        }

        function idle(): void {
            host.show("idle");
        }

        function datetime(): void {
            host.show("datetime");
        }

        function font(): void {
            host.show("environment");
            Prefs.fontPickerRequested();
        }

        function reset(): void {
            host.show("");
            Prefs.askReset("Reset every setting?", "Every setting on every page goes back to the value it ships with. Your theme, wallpaper, pinned applications and placed widgets are not touched.", Prefs.resetAllToken);
        }

    }

}
