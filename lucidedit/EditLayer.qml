import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

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

        screen: win.modelData
        visible: Monitors.surfacesUp && (toolbar.shown || sheet.shown)
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

        // only the two of them take input; everything else falls through
        mask: Region {
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

        BackgroundEffect.blurRegion: Theme.blurAmount > 0 && (toolbar.settled || sheet.settled) ? glass : null

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

                hosted: Edit.active && Edit.sheet !== "" && win.name === Edit.sheetScreen
                y: Math.round(Prefs.barBottom && win.overlap ? toolbar.y + toolbar.height + Theme.dp(12) : win.topClear + Theme.dp(12))
                height: Math.max(Theme.dp(200), (win.overlap && !Prefs.barBottom ? toolbar.y - Theme.dp(12) : win.height - (Prefs.barBottom ? win.bottomClear : 0) - Theme.dp(12)) - sheet.y)
            }

        }

    }

}
