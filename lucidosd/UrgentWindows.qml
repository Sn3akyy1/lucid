import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

// what marks a window asking for attention (a message come in, a download
// done, a terminal's bell) once it is on screen: a tab on one of its corners
// in the colour the workspaces use for it, with a bell that rings now and
// then and takes you to the window when clicked, and a few rings rippling out
// from it the moment it is first seen. A window asking from another workspace
// already lights that workspace up in the bar; this is for when you get there.
//
// Hyprland says when a window asks, and the window stops asking once it is
// focused. The list is kept here, off those events: the toplevels' own
// urgent flag is cleared by every refresh of them, and the refreshes are
// what say where a window is, read again every 250 ms while anything is
// asking, since nothing says a window moved.
Scope {
    id: root

    readonly property bool badgeOn: Prefs.urgentBadge !== "off"
    readonly property bool active: root.badgeOn || Prefs.urgentPulse
    readonly property bool cornerRight: Prefs.urgentBadge.indexOf("right") !== -1
    readonly property bool cornerBottom: Prefs.urgentBadge.indexOf("bottom") !== -1
    readonly property color tint: Theme.error
    readonly property color ink: Theme.fgError
    readonly property int rounding: Math.round(HyprConfig.num("decoration.rounding", 10))
    readonly property int borderSize: Math.round(HyprConfig.num("general.border_size", 2))
    // addresses (bare, as the events give them) of the windows asking
    property var urgent: []
    readonly property var asking: root.active && root.urgent.length > 0 ? Hyprland.toplevels.values.filter((t) => {
        return root.urgent.indexOf(root.bare(t.address)) !== -1;
    }) : []
    // monitor name -> the special workspace open on it, if any
    property var specials: ({})
    // workspace id -> whether a window is fullscreen on it, from the last reading
    property var fullscreenOn: ({})

    function bare(address) {
        return String(address || "").replace(/^0x/, "");
    }

    function answered(address) {
        const a = root.bare(address);
        if (root.urgent.indexOf(a) !== -1)
            root.urgent = root.urgent.filter((x) => {
                return x !== a;
            });

    }

    function monitorOf(id) {
        return Hyprland.monitors.values.find((m) => {
            return m.id === id;
        }) || null;
    }

    function readSpecials() {
        const out = {};
        for (const m of Hyprland.monitors.values) {
            const s = m.lastIpcObject && m.lastIpcObject.specialWorkspace;
            out[m.name] = s && s.name ? s.name : "";
        }
        root.specials = out;
    }

    function readFullscreen() {
        const out = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (o && o.workspace && (o.fullscreen || 0) > 0)
                out[o.workspace.id] = t.address;

        }
        root.fullscreenOn = out;
    }

    // "" when the window is on screen to be marked, otherwise why it is not:
    // its workspace is not the one showing, something special is open over
    // it, another window is fullscreen on top of it
    function why(t) {
        const o = t.lastIpcObject || {};
        if (!o.size || o.size[0] <= 0 || o.mapped === false || o.hidden)
            return "unmapped";

        const m = root.monitorOf(o.monitor === undefined ? -1 : o.monitor);
        if (!m)
            return "no monitor";

        if (!m.activeWorkspace || !o.workspace || m.activeWorkspace.id !== o.workspace.id)
            return "workspace";

        if ((root.specials[m.name] || "") !== "")
            return "special";

        const fs = root.fullscreenOn[o.workspace.id];
        if (fs !== undefined && fs !== t.address)
            return "fullscreen";

        return "";
    }

    function show(address) {
        Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + root.bare(address) + "\" })");
    }

    Component.onCompleted: root.readSpecials()

    IpcHandler {
        target: "urgent"

        // qs ipc call urgent list - the windows asking, and why any is not marked
        function list(): string {
            return JSON.stringify(root.asking.map((t) => {
                return {
                    "address": t.address,
                    "title": t.title,
                    "shown": root.why(t) === "" ? "yes" : root.why(t)
                };
            }));
        }

    }

    // whether a window asking sits on a workspace that is showing; one asking
    // from elsewhere needs no reading until you go there
    readonly property bool askingInSight: root.asking.some((t) => {
        return t.workspace && t.workspace.active;
    })

    // only while something asks in sight: nothing else says where it went
    Timer {
        interval: 250
        repeat: true
        triggeredOnStart: true
        running: root.askingInSight
        onTriggered: {
            Hyprland.refreshToplevels();
            root.readFullscreen();
        }
    }

    Connections {
        function onRawEvent(event) {
            const n = event.name;
            if (n === "activespecial" || n === "activespecialv2") {
                const parts = String(event.data).split(",");
                const next = Object.assign({}, root.specials);
                next[parts[parts.length - 1]] = n === "activespecial" ? parts[0] : parts[1];
                root.specials = next;
            } else if (n === "urgent") {
                const a = root.bare(event.data);
                // the focused window asking is already answered
                const focused = Hyprland.activeToplevel;
                if (focused && root.bare(focused.address) === a)
                    return ;

                if (root.urgent.indexOf(a) === -1)
                    root.urgent = root.urgent.concat([a]);

                Hyprland.refreshToplevels();
            } else if (n === "activewindowv2" || n === "closewindow") {
                root.answered(String(event.data).split(",")[0]);
            }
        }

        target: Hyprland
    }

    Variants {
        model: root.asking

        delegate: Scope {
            id: win

            required property var modelData
            readonly property var ipc: win.modelData.lastIpcObject || ({})
            readonly property var at: win.ipc.at || [0, 0]
            readonly property var size: win.ipc.size || [0, 0]
            readonly property var mon: root.monitorOf(win.ipc.monitor === undefined ? -1 : win.ipc.monitor)
            readonly property var screen: win.mon ? (Quickshell.screens.find((s) => {
                return s.name === win.mon.name;
            }) || null) : null
            readonly property int wsId: win.ipc.workspace ? win.ipc.workspace.id : -999
            // on screen, as why() has it. Not "onScreen": next to `screen`, QML
            // takes that for the screen's change handler and drops the binding
            readonly property bool inView: !!win.screen && root.why(win.modelData) === ""
            readonly property real localX: win.at[0] - (win.screen ? win.screen.x : 0)
            readonly property real localY: win.at[1] - (win.screen ? win.screen.y : 0)
            // the first time it is seen asking, it ripples; after that the tab
            // carries it on its own
            property bool rippled: false
            property bool rippling: false
            property bool appeared: false

            function seen() {
                if (win.inView && !win.rippled && Prefs.urgentPulse) {
                    win.rippled = true;
                    win.rippling = true;
                }
            }

            onInViewChanged: win.seen()
            Component.onCompleted: {
                Qt.callLater(() => {
                    win.appeared = true;
                });
                win.seen();
            }

            PanelWindow {
                id: tabWindow

                readonly property int size: Theme.dp(28)
                readonly property int wide: 96
                readonly property int bs: root.borderSize

                visible: root.badgeOn && !!win.screen
                screen: win.screen
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "lucid-urgent"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                implicitWidth: tabWindow.wide + tabWindow.bs
                implicitHeight: tabWindow.size + tabWindow.bs
                anchors.top: true
                anchors.left: true
                margins.left: Math.max(0, Math.min((win.screen ? win.screen.width : 1920) - tabWindow.implicitWidth, root.cornerRight ? win.localX + win.size[0] + tabWindow.bs - tabWindow.implicitWidth : win.localX - tabWindow.bs))
                margins.top: Math.max(0, Math.min((win.screen ? win.screen.height : 1080) - tabWindow.implicitHeight, root.cornerBottom ? win.localY + win.size[1] + tabWindow.bs - tabWindow.implicitHeight : win.localY - tabWindow.bs))

                // given as numbers: Region { item } does not follow the tab
                mask: Region {
                    x: tab.x
                    y: tab.y
                    width: tab.width
                    height: tab.height
                }

                // the pin badge's shape: the outer corner on the window's own
                // curve, the opposite one round, the two along the edges square
                Rectangle {
                    id: tab

                    readonly property bool shown: win.appeared && win.inView
                    readonly property bool open: hover.hovered
                    readonly property real outer: root.rounding + tabWindow.bs
                    readonly property real inner: Theme.pill(height)
                    readonly property bool r: root.cornerRight
                    readonly property bool b: root.cornerBottom
                    readonly property real faceY: (tab.b ? 0 : tabWindow.bs) + tabWindow.size / 2
                    readonly property real faceX: tab.r ? tab.width - tabWindow.bs - tabWindow.size / 2 : tabWindow.bs + tabWindow.size / 2

                    x: tab.r ? parent.width - tab.width : 0
                    y: 0
                    height: tabWindow.size + tabWindow.bs
                    width: (tab.open ? Math.max(tabWindow.size, showLabel.implicitWidth + tabWindow.size + Theme.dp(8)) : tabWindow.size) + tabWindow.bs
                    topLeftRadius: !tab.r && !tab.b ? tab.outer : (tab.r && tab.b ? tab.inner : 0)
                    topRightRadius: tab.r && !tab.b ? tab.outer : (!tab.r && tab.b ? tab.inner : 0)
                    bottomLeftRadius: !tab.r && tab.b ? tab.outer : (tab.r && !tab.b ? tab.inner : 0)
                    bottomRightRadius: tab.r && tab.b ? tab.outer : (!tab.r && !tab.b ? tab.inner : 0)
                    color: root.tint
                    opacity: tab.shown ? 1 : 0
                    scale: tab.shown ? 1 : 0.4
                    transformOrigin: tab.r ? (tab.b ? Item.BottomRight : Item.TopRight) : (tab.b ? Item.BottomLeft : Item.TopLeft)

                    Shape {
                        id: bell

                        width: Theme.dp(24)
                        height: Theme.dp(24)
                        scale: 15 / 24
                        x: tab.faceX - Theme.dp(12)
                        y: tab.faceY - Theme.dp(12)
                        transformOrigin: Item.Top
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: root.ink
                            strokeWidth: 0

                            PathSvg {
                                path: "M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2Zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2Z"
                            }

                        }

                        // a ring now and then, the way a bell would
                        SequentialAnimation on rotation {
                            running: tab.shown && !tab.open
                            loops: Animation.Infinite
                            alwaysRunToEnd: true

                            NumberAnimation {
                                to: -16
                                duration: 90
                                easing.type: Easing.OutQuad
                            }

                            NumberAnimation {
                                to: 14
                                duration: 150
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: -10
                                duration: 130
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: 6
                                duration: 110
                                easing.type: Easing.InOutQuad
                            }

                            NumberAnimation {
                                to: 0
                                duration: 90
                                easing.type: Easing.OutQuad
                            }

                            PauseAnimation {
                                duration: 2400
                            }

                        }

                    }

                    Text {
                        id: showLabel

                        y: tab.faceY - implicitHeight / 2
                        x: root.cornerRight ? Theme.dp(10) : tabWindow.bs + tabWindow.size - Theme.dp(2)
                        text: "Show"
                        color: root.ink
                        opacity: tab.open ? 1 : 0
                        visible: opacity > 0
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabel
                        font.weight: Font.DemiBold

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                            }

                        }

                    }

                    HoverHandler {
                        id: hover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: tab.shown
                        onTapped: root.show(win.modelData.address)
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: tab.shown ? Theme.durShort : Theme.durQuick
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: tab.shown ? Theme.durMedium : Theme.durQuick
                            easing.type: tab.shown ? Theme.easeEmphasized : Theme.easeStandard
                            easing.overshoot: 2.2
                        }

                    }

                }

            }

            // three rings out from its edge the first time it is seen asking
            PanelWindow {
                id: ringWindow

                readonly property int reach: 26

                visible: win.rippling && win.inView
                screen: win.screen
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "lucid-urgent"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                implicitWidth: win.size[0] + ringWindow.reach * 2
                implicitHeight: win.size[1] + ringWindow.reach * 2
                anchors.top: true
                anchors.left: true
                margins.left: win.localX - ringWindow.reach
                margins.top: win.localY - ringWindow.reach
                onVisibleChanged: {
                    if (ringWindow.visible)
                        ripple.restart();

                }
                Component.onCompleted: {
                    if (ringWindow.visible)
                        ripple.restart();

                }

                mask: Region {
                }

                Repeater {
                    model: 3

                    Rectangle {
                        id: ring

                        required property int index
                        property real grow: 0

                        anchors.centerIn: parent
                        width: win.size[0] + root.borderSize + ring.grow * 2
                        height: win.size[1] + root.borderSize + ring.grow * 2
                        radius: root.rounding + ring.grow
                        color: "transparent"
                        border.width: 3
                        border.color: root.tint
                        opacity: 0

                        SequentialAnimation {
                            running: ripple.running

                            PauseAnimation {
                                duration: ring.index * 380
                            }

                            ParallelAnimation {
                                NumberAnimation {
                                    target: ring
                                    property: "grow"
                                    from: 0
                                    to: ringWindow.reach - 4
                                    duration: 620
                                    easing.type: Easing.OutCubic
                                }

                                NumberAnimation {
                                    target: ring
                                    property: "opacity"
                                    from: 0.95
                                    to: 0
                                    duration: 620
                                    easing.type: Easing.InQuad
                                }

                            }

                        }

                    }

                }

                Timer {
                    id: ripple

                    interval: 2 * 380 + 700
                    onTriggered: win.rippling = false
                }

            }

        }

    }

}
