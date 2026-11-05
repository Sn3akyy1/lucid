import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.lucidprefs as LP

// edit mode's own surface on every display, over everything: the toolbar on the one
// edit mode was started from, the sheet on the one it was asked for. only those two
// take the pointer; the bar, the dock and the desktop stay in reach around them
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        readonly property string name: win.modelData ? win.modelData.name : ""
        // the bar and the dock on this display, so the sheet and the toolbar keep clear of them
        readonly property bool barHere: Prefs.barEnabled && (Monitors.barEverywhere || (Monitors.barPlacement ? Monitors.barPlacement.name === win.name : win.modelData === Monitors.mainScreen))
        readonly property bool dockHere: {
            const s = Monitors.dockPlacement || Monitors.mainScreen;
            return Prefs.dockOn && !!s && s.name === win.name;
        }
        readonly property real barClear: win.barHere ? Prefs.effectiveBarTopMargin + Theme.dp(Prefs.barHeight) : 0
        readonly property real topClear: Prefs.barBottom ? 0 : win.barClear
        // the dock, its handle above it, and a gap; or a bar on the bottom edge
        readonly property real bottomClear: win.dockHere ? Theme.dp(Prefs.dockIconSize) + Theme.dp(20) + Prefs.effectiveDockBottomMargin + Theme.dp(30) : (Prefs.barBottom ? win.barClear : 0)
        readonly property bool overlap: sheet.x < toolbar.x + toolbar.width && sheet.x + sheet.width > toolbar.x
        // the band a studio has: clear of the bar and of the toolbar, on whichever edge it is
        readonly property bool toolbarLow: toolbar.y > win.height / 2
        readonly property real bandTop: win.toolbarLow ? win.topClear + Theme.dp(16) : toolbar.y + toolbar.height + Theme.dp(16)
        readonly property real bandBottom: win.toolbarLow ? toolbar.y - Theme.dp(16) : win.height - win.bottomClear - Theme.dp(16)

        screen: win.modelData
        visible: Monitors.surfacesUp && (toolbar.shown || sheet.shown || studio.shown)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: Edit.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // only a window that is up goes on the focus grabs' list
        function register(on) {
            const rest = Edit.windows.filter((w) => {
                return w !== win;
            });
            Edit.windows = on ? rest.concat([win]) : rest;
        }

        onVisibleChanged: win.register(win.visible)
        Component.onCompleted: win.register(win.visible)
        Component.onDestruction: win.register(false)

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // only the two of them take input, or a studio the whole display; everything
        // else falls through
        mask: Region {
            Region {
                width: studio.shown ? win.width : 0
                height: studio.shown ? win.height : 0
            }

            Region {
                x: toolbar.x
                y: toolbar.y
                width: toolbar.hosted ? toolbar.width : 0
                height: toolbar.hosted ? toolbar.height : 0
            }

            Region {
                x: sheet.x
                y: sheet.y
                width: sheet.hosted ? sheet.width : 0
                height: sheet.hosted ? sheet.height : 0
            }

        }

        BackgroundEffect.blurRegion: Theme.blurAmount > 0 && (toolbar.settled || sheet.settled || studio.settled) ? glass : null

        Region {
            id: glass

            Region {
                x: Math.ceil(toolbar.x)
                y: Math.ceil(toolbar.y)
                width: toolbar.settled ? Math.floor(toolbar.width) : 0
                height: toolbar.settled ? Math.floor(toolbar.height) : 0
                radius: Math.floor(toolbar.height / 2)
            }

            Region {
                x: Math.ceil(sheet.x)
                y: Math.ceil(sheet.y)
                width: sheet.settled ? Math.floor(sheet.width) : 0
                height: sheet.settled ? Math.floor(sheet.height) : 0
                radius: sheet.radius
            }

            Region {
                x: Math.ceil(studio.libRect.x)
                y: Math.ceil(studio.libRect.y)
                width: studio.settled ? Math.floor(studio.libRect.width) : 0
                height: studio.settled ? Math.floor(studio.libRect.height) : 0
                radius: Theme.shapeXl
            }

            Region {
                x: Math.ceil(studio.canvasRect.x)
                y: Math.ceil(studio.canvasRect.y)
                width: studio.settled ? Math.floor(studio.canvasRect.width) : 0
                height: studio.settled ? Math.floor(studio.canvasRect.height) : 0
                radius: Theme.shapeXl
            }

            Region {
                x: Math.ceil(studio.inspRect.x)
                y: Math.ceil(studio.inspRect.y)
                width: studio.settled ? Math.floor(studio.inspRect.width) : 0
                height: studio.settled ? Math.floor(studio.inspRect.height) : 0
                radius: Theme.shapeXl
            }

        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Edit.backOut()
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
                    Edit.undo();
                    event.accepted = true;
                }
            }

            LP.PanelStudio {
                id: studio

                anchors.fill: parent
                hosted: Edit.active && Edit.studio !== "" && win.name === Edit.studioScreen
                area: Qt.rect(Theme.dp(24), win.bandTop, win.width - Theme.dp(48), Math.max(0, win.bandBottom - win.bandTop))
            }

            EditToolbar {
                id: toolbar

                hosted: Edit.active && win.name === Edit.toolbarScreen && !Edit.dragging
                screenName: win.name
                x: Math.round((win.width - toolbar.width) / 2)
                // on the edge away from the bar, so the panels that open from it stay clear
                y: Prefs.barBottom ? Math.round(win.topClear + Theme.dp(20)) : Math.round(win.height - win.bottomClear - Theme.dp(20) - toolbar.height)
            }

            EditSheet {
                id: sheet

                hosted: Edit.active && Edit.sheet !== "" && win.name === Edit.sheetScreen && Edit.studio === ""
                y: Math.round(Prefs.barBottom && win.overlap ? toolbar.y + toolbar.height + Theme.dp(12) : win.topClear + Theme.dp(12))
                height: Math.max(Theme.dp(200), (win.overlap && !Prefs.barBottom ? toolbar.y - Theme.dp(12) : win.height - (Prefs.barBottom ? win.bottomClear : 0) - Theme.dp(12)) - sheet.y)
            }

        }

    }

}
