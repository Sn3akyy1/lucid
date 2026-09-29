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
import "./lucidsession"
import "./lucidshot"
import "./lucidwidgets"
import QtQuick
import Quickshell
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
        void Chrono.now;
        void Agenda.tick;
        void Zones.offsets;
        void Capture.state;
    }

    PanelWindow {
        id: bar

        PaletteFade {
            active: bar.visible
        }

        visible: Prefs.loaded && Prefs.barEnabled && Monitors.surfacesUp
        property bool laidOut: false
        readonly property bool anyModuleShown: bar.leftGroupWidth + bar.centreGroupWidth + bar.rightGroupWidth > 0.5
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

        // the six modules are addressed by key; the three zone lists in Prefs
        // decide which slot each one lands in
        readonly property var pillFor: ({
            "workspaces": workspacesMod,
            "media": mprisMod,
            "tray": sysTrayMod,
            "clock": clockMod,
            "notifications": notifMod,
            "system": systemMod
        })
        readonly property var modules: [workspacesMod, mprisMod, sysTrayMod, clockMod, notifMod, systemMod]

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
        readonly property int zoneGap: Prefs.barZoneGap

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
    // the bar and dock can be sent to one of their own, the rest follow the shell.
    // gated, because unset must leave the choice to hyprland, which null would not.
    // emoji and screenshot act on the window you are in, so they follow the focus
    Binding {
        target: bar
        property: "screen"
        value: Monitors.barPlacement
        when: Monitors.barPlacement !== null
    }

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

}
