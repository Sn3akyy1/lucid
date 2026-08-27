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
        // Prefs.loaded gates the *first* map - margins.top is committed with
        // the layer surface, so mapping early pins the wrong margin for the
        // session. barEnabled is the user switching the bar off outright.
        visible: Prefs.loaded && Prefs.barEnabled
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
        readonly property var rightWidths: [notifMod.width, systemMod.width]
        // One list, named once. The flare repeater, the input mask and the
        // blur region all walked their own hardcoded copy of this, so adding
        // or removing a module meant remembering four places - which is
        // exactly how Bluetooth and Network came to be listed in some of them
        // and not others.
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
        // Tall enough for a detached pop-up panel to fit inside it. At the
        // old flat 800 the tallest panel (System, up to 820) started 45px
        // down and ran past the window's own bottom edge, so it was clipped -
        // the window is transparent and input is limited by its mask, so the
        // extra height costs nothing.
        implicitHeight: bar.screen ? bar.screen.height - Prefs.effectiveBarTopMargin : 800
        // Nothing left in the bar means nothing to reserve room for either -
        // otherwise an empty bar goes on holding a strip of the screen that
        // windows cannot use and that has nothing drawn in it.
        // A bar that is switched off reserves nothing, or it goes on holding a
        // strip of screen that windows cannot use and that draws nothing.
        exclusiveZone: (Prefs.barEnabled && bar.anyModuleShown) ? Prefs.barHeight : 0

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

        // ---- notched corners ----
        // Drawn here rather than inside each module because this is the only
        // place that knows where they all sit, and a corner has to be painted
        // *outside* its module's own rectangle. Same window as the modules, so
        // the two share one surface rather than being two stacked ones that can
        // never be made to match.
        //
        // Each flare is capped at half the clear space beside its edge, so two
        // growing toward each other across a gap meet exactly instead of
        // overlapping - an overlap would double-darken the seam once Glass is
        // on. Measured per edge rather than from barSpacing, because the clock
        // has most of the bar to either side of it and can afford a full-size
        // corner where two neighbours in a group cannot.
        Repeater {
            model: Prefs.barNotch ? bar.modules : []

            Item {
                id: flares

                required property var modelData

                readonly property bool present: flares.modelData && flares.modelData.width > 0.5 && flares.modelData.visible
                // A corner is the same material as the pill it grows out of,
                // so it has to light up with it - otherwise hovering a module
                // leaves its corners sitting dark beside a lit pill.
                //
                // Workspaces is deliberately left out: it reports hover like
                // everyone else, but lights individual workspace slots rather
                // than tinting its pill, so a lit corner there would be the
                // very mismatch this is fixing.
                readonly property bool modHovered: flares.modelData ? (flares.modelData.compactHovered === true && flares.modelData !== workspacesMod) : false

                // How big a corner this edge can carry.
                //
                // Against a *neighbour* it may take half the gap, so the one
                // growing back from the other side meets it exactly rather than
                // overlapping.
                //
                // Small gaps get small corners rather than none: two curving
                // into an 8px gap meet at 4px each and leave a shallow scallop
                // between the modules, which is wanted - the blend is supposed
                // to run the length of the bar, not only where it is roomy.
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
                    // The two outermost edges face the side margin rather
                    // than a neighbour, so nothing is growing back at them and
                    // the half-the-gap rule does not apply - they fall through
                    // to the blend setting, capped only by the margin itself.
                    return Math.max(0, Math.min(Prefs.barNotchFlare, Math.floor(toNeighbour / 2), Math.floor(toEdge)));
                }

                anchors.fill: parent
                z: -1
                visible: Prefs.barNotch && flares.present

                // Half a pixel *into* the module rather than exactly up to
                // it. Module positions are routinely fractional - the clock is
                // centred, and every module's x goes fractional while a
                // neighbour's width animates - so the join lands mid-pixel.
                // Two antialiased edges sharing a pixel each cover about half
                // of it and sum to less than one, which shows as a light
                // hairline splitting the flare from its module. Overlapping by
                // less than a pixel closes it, and stays well inside the gap,
                // so two flares reaching across it still never touch.
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

        // A blur region is a hard-edged pixel mask; a rounded corner is not.
        // Laid on a module's exact bounds the mask keeps every pixel the curve
        // touches at all, so the outermost pixels of the surface's own
        // antialiased edge sit over fully frosted desktop that the surface has
        // barely begun to paint over. That reads as a pale hairline tracing
        // the curve - the border that showed around the pills.
        // Only the *curved* part of an outline has the problem. A flat edge is
        // hard on both sides and already lines up exactly, so pulling one in
        // leaves a pixel of surface over unblurred desktop and draws a far
        // louder dark line - which matters here because in morph mode every
        // module grows into a card in place (a toast, an open panel), and a
        // pill's caps and a card's long flat sides are the same edges.
        // So each module's region is a union of three: its bounds eroded by a
        // pixel, then the two middle bands that put the flat edges back at
        // full extent. Only the corner arcs end up pulled in. Written as plain
        // geometry rather than `item`, which would override x/y/width/height.

        Region {
            id: barBlurRegion

            // Each module contributes its pill and, in pop-up mode, the
            // detached panel below it. The per-corner erosion that keeps a
            // blurred backing from peeking out around a curve lives in
            // ModuleRegion, which is where the comment explaining it went too.

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
