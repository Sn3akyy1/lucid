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

    PanelWindow {
        id: bar

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

        // busy: a panel is open somewhere on the bar, so it stays out
        // regardless of the pointer. held: the pointer is on the reveal
        // strip or already on a module - either keeps it from hiding
        readonly property bool barBusy: workspacesMod.expanded || mprisMod.anyOpen || sysTrayMod.anyOpen || clockMod.anyOpen || notifMod.anyOpen || systemMod.anyOpen
        property bool slidingAway: false
        readonly property bool heldByPointer: revealArea.containsMouse || (!bar.slidingAway && (workspacesMod.compactHovered || mprisMod.surfaceHovered || sysTrayMod.surfaceHovered || clockMod.surfaceHovered || notifMod.surfaceHovered || systemMod.surfaceHovered))
        readonly property bool barRevealed: !Prefs.barAutoHide || bar.barBusy || bar.heldByPointer
        // how far the compact content sits above its resting y=0 while
        // hidden - past the window's own top edge, so it clips away for free
        property real hiddenOffset: bar.barRevealed ? 0 : -(Prefs.barHeight + Prefs.effectiveBarTopMargin + 4)

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
        implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : 800
        exclusiveZone: (Prefs.barEnabled && bar.anyModuleShown && !Prefs.barAutoHide) ? Prefs.barHeight : 0

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
            height: Prefs.barHeight
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
            visible: fullStrip.visible && size > 0
            mirrored: true
            size: Prefs.barFullCorner
            x: 0
            y: Prefs.barHeight + bar.hiddenOffset
            z: -2
        }

        BarFlare {
            visible: fullStrip.visible && size > 0
            size: Prefs.barFullCorner
            x: bar.width - width
            y: Prefs.barHeight + bar.hiddenOffset
            z: -2
        }

        // full bar: an open panel hangs off the strip, so round the two concave
        // corners where its sides meet the strip's lower edge. They grow with
        // the panel's height, so a folding panel takes them with it
        Repeater {
            model: (Prefs.barFull && !Prefs.barPopupMode) ? [mprisMod, sysTrayMod, clockMod, notifMod, systemMod] : []

            Item {
                id: panelFlares

                required property var modelData

                // surfaceOpen, not the height alone: a pill that is only
                // resizing its compact face is see-through on the full bar
                readonly property real reach: (panelFlares.modelData.visible && panelFlares.modelData.surfaceOpen === true) ? panelFlares.modelData.height - Prefs.barHeight : 0

                // never past the screen edge, and never into the screen corner
                // that already rounds that side
                function sizeFor(toTheLeft) {
                    var m = panelFlares.modelData;
                    var toEdge = toTheLeft ? m.x : bar.width - m.x - m.width;
                    var room = toEdge - (toEdge < Prefs.barFullCorner * 2 ? Prefs.barFullCorner : 0);
                    return Math.max(0, Math.floor(Math.min(Prefs.barFullCorner, panelFlares.reach, room)));
                }

                anchors.fill: parent
                z: -1

                BarFlare {
                    size: panelFlares.sizeFor(true)
                    x: panelFlares.modelData.x - width + 0.5
                    y: Prefs.barHeight
                }

                BarFlare {
                    mirrored: true
                    size: panelFlares.sizeFor(false)
                    x: panelFlares.modelData.x + panelFlares.modelData.width - 0.5
                    y: Prefs.barHeight
                }

            }

        }

        Mpris {
            id: mprisMod

            popupAlign: "left"

            hostWindow: bar
            x: bar.leftPlaces[1]
            anchors.top: parent.top
            anchors.topMargin: bar.hiddenOffset

        }

        SysTray {
            id: sysTrayMod

            popupAlign: "left"

            hostWindow: bar
            x: bar.leftPlaces[2]
            anchors.top: parent.top
            anchors.topMargin: bar.hiddenOffset

        }

        Clock {
            id: clockMod

            popupAlign: "center"

            readonly property int sideGap: 28

            hostWindow: bar
            anchors.top: parent.top
            anchors.topMargin: bar.hiddenOffset
            x: Math.min(Math.max((parent.width - width) / 2, bar.sideMargin + bar.leftGroupWidth + sideGap), bar.width - bar.rightGroupWidth - bar.sideMargin - width - sideGap)

        }

        Notifications {
            id: notifMod

            popupAlign: "right"

            hostWindow: bar
            x: bar.rightPlaces[0]
            anchors.top: parent.top
            anchors.topMargin: bar.hiddenOffset

        }

        System {
            id: systemMod

            popupAlign: "right"

            hostWindow: bar
            mprisMod: mprisMod
            x: bar.rightPlaces[1]
            anchors.top: parent.top
            anchors.topMargin: bar.hiddenOffset

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

        Workspaces {
            id: workspacesMod

            hostWindow: bar
            dockMod: dock
            restX: bar.leftPlaces[0]
            restY: bar.hiddenOffset

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

            Region {
                item: Prefs.barAutoHide ? revealArea : null
            }

        }

        // touching this strip reveals the bar
        MouseArea {
            id: revealArea

            x: 0
            y: 0
            width: bar.width
            height: 4
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            enabled: Prefs.barAutoHide
            visible: Prefs.barAutoHide
        }

        BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && bar.laidOut) ? barBlurRegion : null

        Region {
            id: barBlurRegion

            Region {
                x: 0
                y: fullStrip.visible ? bar.hiddenOffset : 0
                width: fullStrip.visible ? Math.round(bar.width) : 0
                height: fullStrip.visible ? Prefs.barHeight : 0
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

    Settings {
        id: settingsMod
    }

    // the numbers the Displays page puts on every screen
    DisplayIdentify {
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
