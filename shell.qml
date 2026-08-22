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

        // Held unmapped until the settings are real. margins.top is committed
        // with the layer surface, so mapping a frame early pinned the bar at
        // the default style's 22px margin for the rest of the session even
        // though the binding read 0 the whole time.
        visible: Prefs.loaded
        // set a tick after construction, once the Rows have positioned their
        // children - see blurRegion below
        property bool laidOut: false
        // With every module switched off there is nothing for the united bar
        // to hold, and it was left standing as a bare stub of a pill - the
        // spacing between three groups that were no longer there.
        readonly property bool anyModuleShown: bar.leftGroupWidth + clockMod.width + bar.rightGroupWidth > 0.5
        // ---- module placement ----
        // Every module is positioned the way the clock always was: by an x of
        // its own, measured from one origin and the widths in front of it. The
        // left and right groups used to be Rows, and a Row drops a child from
        // its layout the moment that child stops being visible - so a module
        // switched off left the row in one frame while its own fade still had
        // most of its length to run, and the bar closed the gap around it
        // instantly. The clock never sat in a Row, which is exactly why it was
        // the one module that already animated out properly.
        //
        // The spacing after a module is scaled by how much of it is left, so a
        // collapsing module gives its gap back continuously instead of dropping
        // the last few pixels in a single step.
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

        // Morph mode only. The workspaces pill flies to the centre of the
        // screen when it opens, so the space it held closes up behind it. This
        // is a 0..1 factor rather than a Behavior on the width itself: the
        // width is already animated as the dots grow under the pointer, and a
        // second animation on top of that lagged the pill behind the gap.
        property real wsCollapse: (workspacesMod.expanded && !Prefs.barPopupMode) ? 0 : 1
        readonly property var leftWidths: [workspacesMod.width * bar.wsCollapse, mprisMod.width, sysTrayMod.width]
        readonly property var rightWidths: [bluetoothMod.width, networkMod.width, notifMod.width, systemMod.width]
        readonly property real leftGroupWidth: bar.placeGroup(bar.leftWidths, 0)[bar.leftWidths.length]
        readonly property real rightGroupWidth: bar.placeGroup(bar.rightWidths, 0)[bar.rightWidths.length]
        readonly property real leftOriginX: bar.sideMargin
        readonly property real rightOriginX: bar.width - bar.rightGroupWidth - bar.sideMargin
        readonly property var leftPlaces: bar.placeGroup(bar.leftWidths, bar.leftOriginX)
        readonly property var rightPlaces: bar.placeGroup(bar.rightWidths, bar.rightOriginX)

        Behavior on wsCollapse {
            NumberAnimation {
                duration: Theme.ms(380)
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
        // Tall enough for a detached pop-up panel to fit inside it. At the
        // old flat 800 the tallest panel (System, up to 820) started 45px
        // down and ran past the window's own bottom edge, so it was clipped -
        // the window is transparent and input is limited by its mask, so the
        // extra height costs nothing.
        implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : 800
        // Nothing left in the bar means nothing to reserve room for either -
        // otherwise an empty bar goes on holding a strip of the screen that
        // windows cannot use and that has nothing drawn in it.
        exclusiveZone: bar.anyModuleShown ? Prefs.barHeight : 0

        anchors {
            top: true
            bottom: false
            left: true
            right: true
        }

        margins {
            // notches sit flush against the screen edge, so the margin that
            // makes the pills read as floating islands collapses to nothing
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
            // free width packs the three groups together at the ordinary module
            // spacing; otherwise the clock holds the centre and is only pushed
            // aside when a group grows far enough to reach it
            x: Math.min(Math.max((parent.width - width) / 2, bar.sideMargin + bar.leftGroupWidth + sideGap), bar.width - bar.rightGroupWidth - bar.sideMargin - width - sideGap)

        }

        BluetoothWidget {
            id: bluetoothMod

            popupAlign: "right"

            hostWindow: bar
            x: bar.rightPlaces[0]
            anchors.top: parent.top

        }

        Network {
            id: networkMod

            popupAlign: "right"

            hostWindow: bar
            x: bar.rightPlaces[1]
            anchors.top: parent.top

        }

        Notifications {
            id: notifMod

            popupAlign: "right"

            hostWindow: bar
            x: bar.rightPlaces[2]
            anchors.top: parent.top

        }

        System {
            id: systemMod

            popupAlign: "right"

            hostWindow: bar
            networkMod: networkMod
            bluetoothMod: bluetoothMod
            notifMod: notifMod
            mprisMod: mprisMod
            x: bar.rightPlaces[3]
            anchors.top: parent.top

        }

        Dock {
            id: dock
        }

        Screenshot {
            id: screenshotMod

            onCaptured: snapMod.open = false
        }

        SnapOverlay {
            id: snapMod

            // cut both out of the freeze frame the overlay is already
            // showing, rather than re-grimming a screen the overlay is
            // still fading off of
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

        // Every module contributes twice: its own bounds, and the surface it
        // opens. In morph mode the two are the same rectangle and the union
        // is a no-op; in pop-up mode the second one is the detached panel,
        // which sits outside the module's own bounds and would otherwise be
        // visible but unclickable. The inline bar joins in when it exists.
        mask: Region {
            Region {
                item: workspacesMod
            }

            Region {
                item: workspacesMod.popupOpen ? workspacesMod.popupItem : null
            }

            Region {
                item: mprisMod
            }

            Region {
                item: mprisMod.popupOpen ? mprisMod.popupItem : null
            }

            Region {
                item: sysTrayMod
            }

            Region {
                item: sysTrayMod.popupOpen ? sysTrayMod.popupItem : null
            }

            Region {
                item: clockMod
            }

            Region {
                item: clockMod.popupOpen ? clockMod.popupItem : null
            }

            Region {
                item: bluetoothMod
            }

            Region {
                item: bluetoothMod.popupOpen ? bluetoothMod.popupItem : null
            }

            Region {
                item: networkMod
            }

            Region {
                item: networkMod.popupOpen ? networkMod.popupItem : null
            }

            Region {
                item: notifMod
            }

            Region {
                item: notifMod.popupOpen ? notifMod.popupItem : null
            }

            Region {
                item: systemMod
            }

            Region {
                item: systemMod.popupOpen ? systemMod.popupItem : null
            }

        }

        // real compositor blur (ext-background-effect-v1, not a Hyprland
        // config rule) scoped to just the visible pills instead of this
        // window's whole oversized transparent canvas - see mask above for
        // the same per-widget region pattern. Paired with Theme.blurAmount
        // fading each pill's own opacity, so what shows through is a real
        // frosted-glass blur of the desktop behind. Off entirely at
        // blurAmount 0 so the compositor isn't blurring behind fully
        // opaque pills for no reason.
        // Held back until the bar has actually laid out. A blur region is
        // committed to the compositor and persists until the next commit, so
        // publishing one while the modules are still at their startup geometry
        // paints blurred rectangles over the desktop that nothing is drawn in -
        // which is what the stray panes at launch were.
        BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && bar.laidOut) ? barBlurRegion : null

        Region {
            id: barBlurRegion

            // the joined rows, on the same half-way rule. Without these the
            // stretch of surface filling the gaps between modules would sit over
            // unblurred desktop while the modules themselves stayed frosted.
            Region {
                item: workspacesMod
                radius: workspacesMod.barRadius
                topLeftRadius: workspacesMod.barTopRadius
                topRightRadius: workspacesMod.barTopRadius
            }

            Region {
                item: workspacesMod.popupOpen ? workspacesMod.popupItem : null
                radius: workspacesMod.cornerRadius
                topLeftRadius: workspacesMod.topRadius
                topRightRadius: workspacesMod.topRadius
            }

            Region {
                item: mprisMod
                radius: mprisMod.barRadius
                topLeftRadius: mprisMod.barTopRadius
                topRightRadius: mprisMod.barTopRadius
            }

            Region {
                item: mprisMod.popupOpen ? mprisMod.popupItem : null
                radius: mprisMod.cornerRadius
                topLeftRadius: mprisMod.topRadius
                topRightRadius: mprisMod.topRadius
            }

            Region {
                item: sysTrayMod
                radius: sysTrayMod.barRadius
                topLeftRadius: sysTrayMod.barTopRadius
                topRightRadius: sysTrayMod.barTopRadius
            }

            Region {
                item: sysTrayMod.popupOpen ? sysTrayMod.popupItem : null
                radius: sysTrayMod.cornerRadius
                topLeftRadius: sysTrayMod.topRadius
                topRightRadius: sysTrayMod.topRadius
            }

            Region {
                item: clockMod
                radius: clockMod.barRadius
                topLeftRadius: clockMod.barTopRadius
                topRightRadius: clockMod.barTopRadius
            }

            Region {
                item: clockMod.popupOpen ? clockMod.popupItem : null
                radius: clockMod.cornerRadius
                topLeftRadius: clockMod.topRadius
                topRightRadius: clockMod.topRadius
            }

            Region {
                item: bluetoothMod
                radius: bluetoothMod.barRadius
                topLeftRadius: bluetoothMod.barTopRadius
                topRightRadius: bluetoothMod.barTopRadius
            }

            Region {
                item: bluetoothMod.popupOpen ? bluetoothMod.popupItem : null
                radius: bluetoothMod.cornerRadius
                topLeftRadius: bluetoothMod.topRadius
                topRightRadius: bluetoothMod.topRadius
            }

            Region {
                item: networkMod
                radius: networkMod.barRadius
                topLeftRadius: networkMod.barTopRadius
                topRightRadius: networkMod.barTopRadius
            }

            Region {
                item: networkMod.popupOpen ? networkMod.popupItem : null
                radius: networkMod.cornerRadius
                topLeftRadius: networkMod.topRadius
                topRightRadius: networkMod.topRadius
            }

            Region {
                item: notifMod
                radius: notifMod.barRadius
                topLeftRadius: notifMod.barTopRadius
                topRightRadius: notifMod.barTopRadius
            }

            Region {
                item: notifMod.popupOpen ? notifMod.popupItem : null
                radius: notifMod.cornerRadius
                topLeftRadius: notifMod.topRadius
                topRightRadius: notifMod.topRadius
            }

            Region {
                item: systemMod
                radius: systemMod.barRadius
                topLeftRadius: systemMod.barTopRadius
                topRightRadius: systemMod.barTopRadius
            }

            Region {
                item: systemMod.popupOpen ? systemMod.popupItem : null
                radius: systemMod.cornerRadius
                topLeftRadius: systemMod.topRadius
                topRightRadius: systemMod.topRadius
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
