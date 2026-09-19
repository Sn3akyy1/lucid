import "./lucidbar"
import "./luciddesktop"
import "./luciddocks"
import "./lucidkeys"
import "./lucidlock"
import "./lucidmoji"
import "./lucidnotif"
import "./lucidosd"
import "./lucidpolkit"
import "./lucidprefs"
import "./lucidshot"
import "./lucidwidgets"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // singletons are made lazily, and these have to be up before anything
    // asks: the KDE Connect bridge and its ipc target, the bluez extras, the
    // idle daemon, which owns hypridle.conf, the environment, which owns
    // the gtk and qt appearance files, and the special workspaces, which own
    // lucid-specials.lua, the glass mirror, which owns kitty's opacity file,
    // the displays, which own lucid-monitors.lua,
    // the update check, which runs whether or not the settings app is
    // ever opened, and the clipboard, which owns the wl-paste watchers and so
    // has to be up long before the launcher is first opened
    Component.onCompleted: {
        void KdeConnect.installed;
        void Bt.present;
        void Net.connectivity;
        void Idle.probed;
        void Env.probed;
        void Specials.moduleProbed;
        void Glass.probed;
        void Monitors.probed;
        void Updates.current;
        void Notifs.count;
        void Clip.probed;
        void Users.probed;
        void Polkit.registered;
    }

    // one bar, or one on every display when Settings > Displays asks for it
    Variants {
        id: bars

        model: Monitors.barEverywhere ? Quickshell.screens : [""]

        PanelWindow {
            id: bar

            required property var modelData
            readonly property var workspacesModule: workspacesMod
            readonly property var mprisModule: mprisMod

            visible: Prefs.loaded && Prefs.barEnabled && Monitors.surfacesUp
            property bool laidOut: false
            readonly property bool anyModuleShown: bar.leftGroupWidth + clockMod.width + bar.rightGroupWidth > 0.5
            function placeGroup(widths, originX) {
                const gap = Prefs.barSpacing;
                const out = [];
                let x = originX;
                let any = false;
                for (let i = 0; i < widths.length; i++) {
                    out.push(x);
                    const w = widths[i];
                    if (w > 0.5) {
                        x += w + (gap > 0 ? gap * Math.min(1, w / gap) : 0);
                        any = true;
                    }
                }
                out.push(any ? Math.max(originX, x - Prefs.barSpacing) : originX);
                return out;
            }

            property real wsCollapse: (workspacesMod.expanded && !Prefs.barPopupMode) ? 0 : 1
            readonly property var leftWidths: [workspacesMod.width * bar.wsCollapse, mprisMod.width, sysTrayMod.width]
            readonly property var rightWidths: [notifMod.width, systemMod.width]
            readonly property var modules: [workspacesMod, mprisMod, sysTrayMod, clockMod, notifMod, systemMod]
            readonly property real leftGroupWidth: bar.placeGroup(bar.leftWidths, 0)[bar.leftWidths.length]
            readonly property real rightGroupWidth: bar.placeGroup(bar.rightWidths, 0)[bar.rightWidths.length]
            readonly property real leftOriginX: bar.sideMargin
            readonly property real rightOriginX: bar.width - bar.rightGroupWidth - bar.sideMargin
            readonly property var leftPlaces: bar.placeGroup(bar.leftWidths, bar.leftOriginX)
            readonly property var rightPlaces: bar.placeGroup(bar.rightWidths, bar.rightOriginX)

            Behavior on wsCollapse {
                NumberAnimation {
                    duration: Theme.barMs(380)
                    easing.type: Easing.OutCubic
                }

            }
            readonly property real sideMargin: Prefs.barSideMargin

            Component.onCompleted: laidOutTimer.start()

            Timer {
                id: laidOutTimer

                interval: 120
                onTriggered: bar.laidOut = true
            }

            color: "transparent"
            implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : 800
            exclusiveZone: (Prefs.barEnabled && bar.anyModuleShown) ? Prefs.barHeight : 0

            anchors {
                top: true
                bottom: false
                left: true
                right: true
            }

            margins {
                top: Prefs.effectiveBarTopMargin
            }

            Mpris {
                id: mprisMod

                popupAlign: "left"

                hostWindow: bar
                x: bar.leftPlaces[1]
                anchors.top: parent.top

            }

            SysTray {
                id: sysTrayMod

                popupAlign: "left"

                hostWindow: bar
                x: bar.leftPlaces[2]
                anchors.top: parent.top

            }

            Clock {
                id: clockMod

                popupAlign: "center"

                readonly property int sideGap: 28

                hostWindow: bar
                anchors.top: parent.top
                x: Math.min(Math.max((parent.width - width) / 2, bar.sideMargin + bar.leftGroupWidth + sideGap), bar.width - bar.rightGroupWidth - bar.sideMargin - width - sideGap)

            }

            Notifications {
                id: notifMod

                popupAlign: "right"
                showsPopups: !Monitors.barEverywhere || bar.screen === Monitors.popupScreen

                hostWindow: bar
                x: bar.rightPlaces[0]
                anchors.top: parent.top

            }

            System {
                id: systemMod

                popupAlign: "right"

                hostWindow: bar
                mprisMod: mprisMod
                x: bar.rightPlaces[1]
                anchors.top: parent.top

            }

            Repeater {
                model: Prefs.barNotch ? bar.modules : []

                Item {
                    id: flares

                    required property var modelData

                    readonly property bool present: flares.modelData && flares.modelData.width > 0.5 && flares.modelData.visible
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
                        return Math.max(0, Math.min(Prefs.barNotchFlare, Math.floor(toNeighbour / 2), Math.floor(toEdge)));
                    }

                    anchors.fill: parent
                    z: -1
                    visible: Prefs.barNotch && flares.present

                    readonly property real bite: 0.5

                    BarFlare {
                        hovered: flares.modHovered
                        size: flares.flareFor(true)
                        x: flares.modelData ? flares.modelData.x - width + flares.bite : 0
                        y: 0
                    }

                    BarFlare {
                        hovered: flares.modHovered
                        mirrored: true
                        size: flares.flareFor(false)
                        x: flares.modelData ? flares.modelData.x + flares.modelData.width - flares.bite : 0
                        y: 0
                    }

                }

            }

            Workspaces {
                id: workspacesMod

                hostWindow: bar
                dockMod: dock
                restX: bar.leftPlaces[0]
                restY: 0

            }

            // a bar of its own display when there is one on each; otherwise the one
            // bar goes where Settings > Displays puts it. unset must leave the
            // choice to hyprland, which null would not, so it is gated
            Binding {
                target: bar
                property: "screen"
                value: bar.modelData !== "" ? bar.modelData : Monitors.barPlacement
                when: bar.modelData !== "" || Monitors.barPlacement !== null
            }

            Connections {
                function onExpandedChanged() {
                    if (workspacesMod.expanded)
                        dock.menuOpen = false;

                }

                target: workspacesMod
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

            }

            BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && bar.laidOut) ? barBlurRegion : null

            Region {
                id: barBlurRegion

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

            }

        }

    }

    Dock {
        id: dock
    }

    Screenshot {
        id: screenshotMod

        onCaptured: snapMod.open = false
        onTextResult: (status) => {
            snapMod.finishTextRead();
            if (status === "copied")
                toastMod.popup("copy", "Text copied", false);
            else if (status === "notool")
                toastMod.popup("alert", "Install tesseract to copy text", true);
            else
                toastMod.popup("alert", "No text found", true);
        }
        onColorResult: (value, hex, status) => {
            if (status === "notool") {
                toastMod.popup("alert", "Install hyprpicker to pick colours", true);
            } else if (status === "ok") {
                snapMod.open = false;
                if (hex === "")
                    toastMod.popup("copy", value, false);
                else
                    toastMod.popupSwatch(hex, value);
            }
        }
    }

    SnapOverlay {
        id: snapMod

        onFullscreenRequested: screenshotMod.captureFull(false, snapMod.freezePath)
        onRegionRequested: (x, y, w, h) => {
            return screenshotMod.captureRegion(x, y, w, h, false, snapMod.freezePath, snapMod.freezeScale);
        }
        onTextRequested: (x, y, w, h) => {
            return screenshotMod.copyText(x, y, w, h, snapMod.freezePath, snapMod.freezeScale);
        }
        onColorPickRequested: (format) => screenshotMod.pickColor(format)
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

    Osd {
        id: osdMod
    }

    Toast {
        id: toastMod
    }

    ToastEvents {
        toast: toastMod
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

    Settings {
        id: settingsMod
    }

    Auth {
        id: polkitMod
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
    // the dock can be sent to one of its own, the rest follow the shell.
    // gated, because unset must leave the choice to hyprland, which null would not.
    // emoji and screenshot act on the window you are in, so they follow the focus
    Instantiator {
        model: [dock, clickCatcher]

        Binding {
            required property var modelData

            target: modelData
            property: "screen"
            value: Monitors.dockPlacement
            when: Monitors.dockPlacement !== null
        }

    }

    Instantiator {
        model: [osdMod, toastMod, keyboardMod, polkitMod, keybindSheetMod]

        Binding {
            required property var modelData

            target: modelData
            property: "screen"
            value: Monitors.shellPlacement
            when: Monitors.shellPlacement !== null
        }

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
                snapMod.beginOpen();

        }

        target: Prefs
    }

    Connections {
        function onMenuOpenChanged() {
            if (!dock.menuOpen)
                return ;

            for (const b of bars.instances)
                b.workspacesModule.expanded = false;
        }

        target: dock
    }

    // the bar on the display being worked on, for ipc aimed at "the" bar
    function focusedBar() {
        const list = bars.instances;
        const scr = Monitors.focusedScreen;
        for (const b of list) {
            if (scr && b.screen && b.screen.name === scr.name)
                return b;

        }
        return list.length > 0 ? list[0] : null;
    }

    // here rather than in the modules, which there can be one of per display
    IpcHandler {
        target: "workspaces"

        function toggle(): void {
            const b = root.focusedBar();
            if (b)
                b.workspacesModule.expanded = !b.workspacesModule.expanded;

        }

        function open(): void {
            const b = root.focusedBar();
            if (b)
                b.workspacesModule.expanded = true;

        }

        function close(): void {
            const b = root.focusedBar();
            if (b)
                b.workspacesModule.expanded = false;

        }

    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            const b = root.focusedBar();
            if (!b)
                return ;

            if (b.mprisModule.expanded)
                b.mprisModule.expanded = false;
            else
                b.mprisModule.openPanel("player");
        }

        function open(): void {
            const b = root.focusedBar();
            if (b)
                b.mprisModule.openPanel("player");

        }

        function close(): void {
            const b = root.focusedBar();
            if (b)
                b.mprisModule.expanded = false;

        }

        function identify(): void {
            const b = root.focusedBar();
            if (!b)
                return ;

            b.mprisModule.openPanel("shazam");
            b.mprisModule.startListening();
        }

        function playPause(): void {
            const b = root.focusedBar();
            if (b)
                b.mprisModule.togglePlay();

        }

        function next(): void {
            const b = root.focusedBar();
            if (b)
                b.mprisModule.skip(1);

        }

        function previous(): void {
            const b = root.focusedBar();
            if (b)
                b.mprisModule.skip(-1);

        }

    }

}
