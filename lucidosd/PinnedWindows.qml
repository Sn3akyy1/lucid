import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs

// what marks a pinned window, past the border modules/settings.lua gives it:
// a pin badge on one of its corners that unpins it when clicked, and a ring
// that ripples out from the window the moment it is pinned.
//
// Hyprland says when a window is pinned but not when one moves, so while
// anything is pinned the clients are read every 120 ms, straight off
// Hyprland's socket; a badge whose window is moving steps away and comes back
// once it settles, rather than trailing it across the screen.
Scope {
    id: root

    readonly property bool badgeOn: Prefs.pinBadge !== "off"
    readonly property bool active: root.badgeOn || Prefs.pinPulse
    readonly property bool cornerRight: Prefs.pinBadge.indexOf("right") !== -1
    readonly property bool cornerBottom: Prefs.pinBadge.indexOf("bottom") !== -1
    // the badge, and the ring, in the border's colour; tertiary when the border is off
    readonly property color pinColour: HyprConfig.pinColours.length > 0 ? HyprConfig.pinColours[0] : Theme.cTertiary
    readonly property color pinInk: Prefs.pinBorder === "accent" ? Theme.cOnPrimary : Theme.cOnTertiary
    readonly property int rounding: Math.round(HyprConfig.num("decoration.rounding", 10))
    readonly property int borderSize: HyprConfig.pinColours.length > 0 ? HyprConfig.pinBorderSize : Math.round(HyprConfig.num("general.border_size", 2))
    // pinned windows as Hyprland last reported them, address -> { x, y, w, h,
    // monitor, fullscreen, settled }; the badges are made per address, so a
    // new reading moves them rather than making them again
    property var windows: ({})
    property var addresses: []
    // address -> "x y w h" at the last reading, and how many readings it has held still
    property var lastGeometry: ({})
    property var stillFor: ({})
    // addresses that were pinned just now, waiting for their ring
    property var pulses: []
    // monitor name -> the special workspace open on it, if any
    property var specials: ({})
    readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
    property string reply: ""
    property bool queryAgain: false

    function bare(address) {
        return String(address || "").replace(/^0x/, "");
    }

    function query() {
        if (!root.active)
            return ;

        if (sock.connected) {
            root.queryAgain = true;
            return ;
        }
        root.reply = "";
        sock.connected = true;
    }

    function take(text) {
        let clients;
        try {
            clients = JSON.parse(text);
        } catch (e) {
            return ;
        }
        if (!Array.isArray(clients))
            return ;

        const out = {};
        const geo = {};
        const still = {};
        for (const c of clients) {
            if (!c || !c.pinned || c.mapped === false || c.hidden)
                continue;

            const a = root.bare(c.address);
            const w = {
                "x": c.at[0],
                "y": c.at[1],
                "w": c.size[0],
                "h": c.size[1],
                "monitor": c.monitor,
                "fullscreen": (c.fullscreen || 0) > 0
            };
            geo[a] = [w.x, w.y, w.w, w.h].join(" ");
            still[a] = root.lastGeometry[a] === geo[a] ? (root.stillFor[a] || 0) + 1 : (root.lastGeometry[a] === undefined ? 2 : 0);
            w.settled = still[a] >= 2;
            out[a] = w;
        }
        root.lastGeometry = geo;
        root.stillFor = still;
        root.windows = out;
        const list = Object.keys(out).sort();
        if (list.join(" ") !== root.addresses.join(" "))
            root.addresses = list;
    }

    function unpin(address) {
        Hyprland.dispatch("hl.dsp.window.pin({ action = \"off\", window = \"address:0x" + root.bare(address) + "\" })");
        root.query();
    }

    function monitorName(id) {
        const m = Hyprland.monitors.values.find((x) => {
            return x.id === id;
        });
        return m ? m.name : "";
    }

    function pulseDone(address) {
        root.pulses = root.pulses.filter((a) => {
            return a !== address;
        });
    }

    // the monitors' open special workspaces, which cover the pinned windows
    function readSpecials() {
        const out = {};
        for (const m of Hyprland.monitors.values) {
            const s = m.lastIpcObject && m.lastIpcObject.specialWorkspace;
            out[m.name] = s && s.name ? s.name : "";
        }
        root.specials = out;
    }

    onActiveChanged: {
        if (root.active)
            root.query();
        else
            root.windows = {};
    }
    Component.onCompleted: {
        root.readSpecials();
        root.query();
    }

    Socket {
        id: sock

        path: root.socketPath
        onConnectedChanged: {
            if (sock.connected) {
                sock.write("j/clients");
                sock.flush();
                return ;
            }
            root.take(root.reply);
            root.reply = "";
            if (root.queryAgain) {
                root.queryAgain = false;
                root.query();
            }
        }

        parser: SplitParser {
            splitMarker: ""
            onRead: (data) => {
                root.reply += data;
                // hang up as soon as the whole list is in: Hyprland closing
                // first is logged as a socket error, on every reading
                if (/\]\s*$/.test(root.reply)) {
                    try {
                        JSON.parse(root.reply);
                        sock.connected = false;
                    } catch (e) {
                    }
                }
            }
        }

    }

    // a window pinned and let go before it was ever read leaves its ring behind
    Timer {
        id: stalePulses

        interval: 2500
        onTriggered: root.pulses = []
    }

    // only while something is pinned: nothing else says it moved
    Timer {
        interval: 120
        repeat: true
        running: root.active && root.addresses.length > 0
        onTriggered: root.query()
    }

    Connections {
        function onRawEvent(event) {
            const n = event.name;
            if (n === "pin") {
                const parts = String(event.data).split(",");
                if (parts[1] === "1" && Prefs.pinPulse) {
                    root.pulses = root.pulses.concat([root.bare(parts[0])]);
                    stalePulses.restart();
                }

                root.query();
            } else if (n === "activespecial" || n === "activespecialv2") {
                const parts = String(event.data).split(",");
                const next = Object.assign({}, root.specials);
                next[parts[parts.length - 1]] = n === "activespecial" ? parts[0] : parts[1];
                root.specials = next;
            } else if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2", "monitoraddedv2", "monitorremovedv2"].indexOf(n) !== -1) {
                root.query();
            }
        }

        target: Hyprland
    }

    Variants {
        model: root.active ? root.addresses : []

        delegate: Scope {
            id: pin

            required property string modelData
            readonly property string address: pin.modelData
            readonly property var win: root.windows[pin.address] || ({
                "x": 0,
                "y": 0,
                "w": 0,
                "h": 0,
                "monitor": -1,
                "fullscreen": false,
                "settled": false
            })
            // false until the first frame, so a new badge pops in rather than just being there
            property bool appeared: false
            readonly property string monitor: root.monitorName(pin.win.monitor)
            readonly property var screen: Quickshell.screens.find((s) => {
                return s.name === pin.monitor;
            }) || null
            readonly property bool settled: pin.win.settled
            readonly property bool covered: pin.win.fullscreen || (root.specials[pin.monitor] || "") !== ""
            readonly property real localX: pin.win.x - (pin.screen ? pin.screen.x : 0)
            readonly property real localY: pin.win.y - (pin.screen ? pin.screen.y : 0)
            readonly property bool pulsing: root.pulses.indexOf(pin.address) !== -1

            Component.onCompleted: Qt.callLater(() => {
                pin.appeared = true;
            })

            PanelWindow {
                id: badgeWindow

                readonly property int size: Theme.dp(28)
                readonly property int wide: 104
                // the tab reaches under the border, so the two read as one piece
                readonly property int bs: root.borderSize

                visible: root.badgeOn && !!pin.screen
                screen: pin.screen
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "lucid-pin"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                implicitWidth: badgeWindow.wide + badgeWindow.bs
                implicitHeight: badgeWindow.size + badgeWindow.bs
                anchors.top: true
                anchors.left: true
                // flush in the window's corner, out to the edge of its border
                margins.left: Math.max(0, Math.min((pin.screen ? pin.screen.width : 1920) - badgeWindow.implicitWidth, root.cornerRight ? pin.localX + pin.win.w + badgeWindow.bs - badgeWindow.implicitWidth : pin.localX - badgeWindow.bs))
                margins.top: Math.max(0, Math.min((pin.screen ? pin.screen.height : 1080) - badgeWindow.implicitHeight, root.cornerBottom ? pin.localY + pin.win.h + badgeWindow.bs - badgeWindow.implicitHeight : pin.localY - badgeWindow.bs))

                // the tab, given as numbers: Region { item } did not follow the
                // tab and left it deaf to the pointer
                mask: Region {
                    x: badge.x
                    y: badge.y
                    width: badge.width
                    height: badge.height
                }

                // a tab in the corner, in the border's colour: the outer corner
                // follows the window's own curve, the opposite one is rounded,
                // and the two along the edges are square so it sits on the border
                Rectangle {
                    id: badge

                    readonly property bool shown: pin.appeared && pin.settled && !pin.covered
                    readonly property bool open: hover.hovered
                    readonly property real outer: root.rounding + badgeWindow.bs
                    readonly property real inner: Theme.pill(height)
                    readonly property bool r: root.cornerRight
                    readonly property bool b: root.cornerBottom

                    x: badge.r ? parent.width - badge.width : 0
                    y: 0
                    // where the glyph and the label centre: the part inside the window
                    readonly property real faceY: (badge.b ? 0 : badgeWindow.bs) + badgeWindow.size / 2
                    readonly property real faceX: badge.r ? badge.width - badgeWindow.bs - badgeWindow.size / 2 : badgeWindow.bs + badgeWindow.size / 2

                    height: badgeWindow.size + badgeWindow.bs
                    width: (badge.open ? Math.max(badgeWindow.size, unpinLabel.implicitWidth + badgeWindow.size + Theme.dp(6)) : badgeWindow.size) + badgeWindow.bs
                    topLeftRadius: !badge.r && !badge.b ? badge.outer : (badge.r && badge.b ? badge.inner : 0)
                    topRightRadius: badge.r && !badge.b ? badge.outer : (!badge.r && badge.b ? badge.inner : 0)
                    bottomLeftRadius: !badge.r && badge.b ? badge.outer : (badge.r && !badge.b ? badge.inner : 0)
                    bottomRightRadius: badge.r && badge.b ? badge.outer : (!badge.r && !badge.b ? badge.inner : 0)
                    color: root.pinColour
                    opacity: badge.shown ? 1 : 0
                    scale: badge.shown ? 1 : 0.4
                    transformOrigin: badge.r ? (badge.b ? Item.BottomRight : Item.TopRight) : (badge.b ? Item.BottomLeft : Item.TopLeft)

                    Shape {
                        id: glyph

                        width: Theme.dp(24)
                        height: Theme.dp(24)
                        scale: 15 / 24
                        x: badge.faceX - Theme.dp(12)
                        y: badge.faceY - Theme.dp(12)
                        rotation: badge.open ? 0 : 35
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: root.pinInk
                            strokeWidth: 0

                            PathSvg {
                                path: "M16 9V4h1a1 1 0 0 0 0-2H7a1 1 0 0 0 0 2h1v5a3 3 0 0 1-3 3v2h5.97v7l1 1 1-1v-7H19v-2a3 3 0 0 1-3-3Z"
                            }

                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                    Text {
                        id: unpinLabel

                        y: badge.faceY - implicitHeight / 2
                        x: root.cornerRight ? Theme.dp(10) : badgeWindow.bs + badgeWindow.size - Theme.dp(2)
                        text: "Unpin"
                        color: root.pinInk
                        opacity: badge.open ? 1 : 0
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
                        enabled: badge.shown
                        onTapped: root.unpin(pin.address)
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durShort
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: badge.shown ? Theme.durShort : Theme.durQuick
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: badge.shown ? Theme.durMedium : Theme.durQuick
                            easing.type: badge.shown ? Theme.easeEmphasized : Theme.easeStandard
                            easing.overshoot: 2.2
                        }

                    }

                }

            }

            // the ripple when the window is pinned, out from its edge and gone
            PanelWindow {
                id: ringWindow

                readonly property int reach: 26

                visible: pin.pulsing && !!pin.screen && !pin.covered
                screen: pin.screen
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "lucid-pin"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                implicitWidth: pin.win.w + ringWindow.reach * 2
                implicitHeight: pin.win.h + ringWindow.reach * 2
                anchors.top: true
                anchors.left: true
                margins.left: pin.localX - ringWindow.reach
                margins.top: pin.localY - ringWindow.reach
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
                    model: 2

                    Rectangle {
                        id: ring

                        required property int index
                        property real grow: 0

                        anchors.centerIn: parent
                        width: pin.win.w + root.borderSize + ring.grow * 2
                        height: pin.win.h + root.borderSize + ring.grow * 2
                        radius: root.rounding + ring.grow
                        color: "transparent"
                        border.width: 3 - ring.index
                        border.color: root.pinColour
                        opacity: 0

                        SequentialAnimation {
                            running: ripple.running

                            PauseAnimation {
                                duration: ring.index * 140
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

                    interval: 820
                    onTriggered: root.pulseDone(pin.address)
                }

            }

        }

    }

}
