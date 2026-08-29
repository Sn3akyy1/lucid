import "./lucidbar"
import "./luciddocks"
import "./lucidlock"
import "./lucidmoji"
import "./lucidosd"
import "./lucidprefs"
import "./lucidshot"
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: bar

        visible: Prefs.loaded && Prefs.barEnabled
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

            hostWindow: bar
            x: bar.rightPlaces[0]
            anchors.top: parent.top

        }

        System {
            id: systemMod

            popupAlign: "right"

            hostWindow: bar
            notifMod: notifMod
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

        Dock {
            id: dock

            lockScreen: lockMod
        }

        Screenshot {
            id: screenshotMod

            onCaptured: snapMod.open = false
        }

        SnapOverlay {
            id: snapMod

            onFullscreenRequested: screenshotMod.captureFull(false, snapMod.freezePath)
            onRegionRequested: (x, y, w, h) => {
                return screenshotMod.captureRegion(x, y, w, h, false, snapMod.freezePath, snapMod.freezeScale);
            }
        }

        Workspaces {
            id: workspacesMod

            hostWindow: bar
            restX: bar.leftPlaces[0]
            restY: 0

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


    Osd {
        id: osdMod
    }

    Lock {
        id: lockMod

        notifMod: notifMod
    }

    Moji {
        id: mojiMod
    }

    Settings {
        id: settingsMod
    }

    PanelWindow {
        id: clickCatcher

        visible: dock.menuOpen
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
