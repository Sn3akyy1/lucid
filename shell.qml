import "./lucidbar"
import "./luciddesktop"
import "./luciddocks"
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
    // the displays, which own lucid-monitors.lua, the Hyprland options,
    // which own lucid-settings.lua and follow the palette in border colours,
    // the update check, which runs whether or not the settings app is
    // ever opened, the clipboard, which owns the wl-paste watchers and so
    // has to be up long before the launcher is first opened, and night
    // light, whose schedule runs whether or not the System pill is shown,
    // the sounds, so their ipc target answers before anything has played, and
    // storage, which warns when space runs low and empties old trash
    Component.onCompleted: {
        void KdeConnect.installed;
        void Bt.present;
        void Net.connectivity;
        void Idle.probed;
        void Env.probed;
        void Specials.moduleProbed;
        void Glass.probed;
        void Monitors.probed;
        void HyprConfig.moduleProbed;
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
        void Sounds.dir;
        void Storage.watching;
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
            readonly property bool anyModuleShown: bar.leftGroupWidth + bar.centreGroupWidth + bar.rightGroupWidth > 0.5
            function placeGroup(widths, originX) {
                const gap = Theme.dp(Prefs.barSpacing);
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
                out.push(any ? Math.max(originX, x - Theme.dp(Prefs.barSpacing)) : originX);
                return out;
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
                "window": windowMod
            })
            // what BarPill looks itself up in, for a right click to its card
            readonly property var moduleById: bar.pillFor
            readonly property var modules: [workspacesMod, mprisMod, sysTrayMod, clockMod, notifMod, systemMod, privacyMod, powerMod, windowMod]

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
                const live = Prefs.barKeysOf(zone);
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
            function widthOf(key) {
                const it = bar.pillFor[key];
                if (!it)
                    return 0;

                return it === workspacesMod ? it.width * bar.wsCollapse : it.width;
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
            readonly property real leftGroupWidth: bar.placeGroup(bar.leftWidths, 0)[bar.leftWidths.length]
            readonly property real centreGroupWidth: bar.placeGroup(bar.centreWidths, 0)[bar.centreWidths.length]
            readonly property real rightGroupWidth: bar.placeGroup(bar.rightWidths, 0)[bar.rightWidths.length]
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
            readonly property var leftPlaces: bar.placeGroup(bar.leftWidths, bar.leftOriginX)
            readonly property var centrePlaces: bar.placeGroup(bar.centreWidths, bar.centreOriginX)
            readonly property var rightPlaces: bar.placeGroup(bar.rightWidths, bar.rightOriginX)

            Behavior on wsCollapse {
                NumberAnimation {
                    duration: Theme.barMs(380)
                    easing.type: Easing.OutCubic
                }

            }
            readonly property real sideMargin: Theme.dp(Prefs.barSideMargin)

            Component.onCompleted: laidOutTimer.start()

            Timer {
                id: laidOutTimer

                interval: 120
                onTriggered: bar.laidOut = true
            }

            color: "transparent"
            implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : Theme.dp(800)
            exclusiveZone: (Prefs.barEnabled && bar.anyModuleShown) ? Theme.dp(Prefs.barHeight) + Prefs.shellGap : 0

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

                popupAlign: bar.alignOf("media")

                hostWindow: bar
                x: bar.placeFor("media")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                x: bar.placeFor("tray")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                x: bar.placeFor("clock")

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                x: bar.placeFor("notifications")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                recorder: snapMod
                toast: bar.primary ? toastMod : null

                hostWindow: bar
                x: bar.placeFor("privacy")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                x: bar.placeFor("power")
                anchors.top: parent.top

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
                x: bar.placeFor("window")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                x: bar.placeFor("system")
                anchors.top: parent.top

                Behavior on x {
                    enabled: bar.laidOut && bar.shuffling

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
                restX: bar.placeFor("workspaces")
                restY: 0

                Behavior on restX {
                    enabled: bar.laidOut && bar.shuffling

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

            }

        }

    }

    Dock {
        id: dock
    }

    Screenshot {
        id: screenshotMod

        shotPreview: shotPreviewMod
        onCaptured: snapMod.open = false
        onSaved: (file, kind) => {
            return shotPreviewMod.show(file, kind, screenshotMod.screen);
        }
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

        shotPreview: shotPreviewMod
        onFullscreenRequested: screenshotMod.captureFull(false, snapMod.freezePath)
        onRegionRequested: (x, y, w, h) => {
            return screenshotMod.captureRegion(x, y, w, h, false, snapMod.freezePath, snapMod.freezeScale);
        }
        onTextRequested: (x, y, w, h) => {
            return screenshotMod.copyText(x, y, w, h, snapMod.freezePath, snapMod.freezeScale);
        }
        onColorPickRequested: (format) => screenshotMod.pickColor(format)
        onRecordingSaved: (file) => {
            return screenshotMod.announce(file, "video");
        }
    }

    ShotPreview {
        id: shotPreviewMod
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

    WhatsNew {
        id: whatsNewMod
    }

    SettingsHost {
        id: settingsMod
    }

    // the numbers the Displays page puts on every screen
    DisplayIdentify {
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
                snapMod.beginOpen();

        }

        target: Prefs
    }

}
