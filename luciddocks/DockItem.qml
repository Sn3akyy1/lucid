import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs

Item {
    id: dockItem

    property string iconName: ""
    property Component iconContent: null
    property string command: ""
    property string appId: ""
    property bool isToggle: false
    property bool toggleActive: false
    property string displayName: ""
    // handed down rather than re-read per item
    property var clients: []
    property int activeWorkspaceId: -1
    property string focusedAddress: ""
    property real magnifyBoost: 0
    property bool pointerInside: true

    property bool hovered: hoverHandler.hovered && dockItem.pointerInside
    property bool pressed: tapHandler.pressed && dockItem.hovered
    property bool tooltipReady: false

    signal requestToggle()
    signal requestStackPopup()
    signal requestContextMenu()
    signal launched()

    readonly property int slot: Prefs.dockIconSize
    readonly property real slotScale: dockItem.slot / 46

    function sc(v) {
        return Math.round(v * dockItem.slotScale);
    }

    readonly property var clientStats: {
        var stats = {
            "matching": null,
            "count": 0,
            "workspaces": ({}),
            "addresses": [],
            "focused": false
        };
        if (dockItem.appId === "")
            return stats;

        var want = dockItem.appId.toLowerCase();
        for (var i = 0; i < dockItem.clients.length; i++) {
            var c = dockItem.clients[i];
            if (!c.class || c.class.toLowerCase() !== want)
                continue;

            if (!stats.matching)
                stats.matching = c;

            stats.count++;
            if (c.workspace)
                stats.workspaces[c.workspace.id] = true;

            if (c.address) {
                stats.addresses.push(c.address);
                if (c.address === dockItem.focusedAddress)
                    stats.focused = true;
            }
        }
        return stats;
    }
    readonly property var matchingClient: dockItem.clientStats.matching
    readonly property int windowCount: dockItem.clientStats.count
    readonly property int distinctWorkspaceCount: Object.keys(dockItem.clientStats.workspaces).length
    readonly property bool active: dockItem.windowCount > 0
    readonly property bool focused: dockItem.clientStats.focused
    readonly property bool urgent: dockItem.appId !== "" && Hyprland.toplevels.values.some((t) => {
        return t.wayland && t.wayland.appId && t.wayland.appId.toLowerCase() === dockItem.appId.toLowerCase() && t.urgent;
    })

    function resolveIcon(name) {
        if (!name || name === "")
            return "";

        if (name.charAt(0) === "/")
            return "file://" + name;

        var tries = [name, name.toLowerCase()];
        var dot = name.lastIndexOf(".");
        if (dot > 0 && dot < name.length - 1) {
            var tail = name.substring(dot + 1);
            tries.push(tail, tail.toLowerCase());
        }
        for (var i = 0; i < tries.length; i++) {
            var p = Quickshell.iconPath(tries[i], true);
            if (p !== "")
                return p;
        }
        return "";
    }

    readonly property string iconSource: dockItem.resolveIcon(dockItem.iconName)
    readonly property string monogram: dockItem.displayName !== "" ? dockItem.displayName.charAt(0).toUpperCase() : "?"

    readonly property real hoverSwell: (dockItem.active ? 0.12 : 0.08) * Prefs.dockHoverEffect
    readonly property real hoverLift: (dockItem.active ? 9 : 6) * Prefs.dockHoverEffect

    width: dockItem.slot
    height: dockItem.slot
    scale: dockItem.pressed ? 0.94 : (dockItem.hovered ? 1 + dockItem.hoverSwell : 1 + dockItem.magnifyBoost)
    y: dockItem.pressed ? -2 : (dockItem.hovered ? -dockItem.hoverLift : 0)

    onHoveredChanged: {
        if (dockItem.hovered) {
            tooltipDelay.restart();
        } else {
            tooltipDelay.stop();
            dockItem.tooltipReady = false;
        }
    }

    Timer {
        id: tooltipDelay

        interval: 450
        onTriggered: dockItem.tooltipReady = true
    }

    Item {
        id: iconWrap

        anchors.fill: parent

        Rectangle {
            id: tile

            anchors.fill: parent
            radius: dockItem.sc(14)
            color: Theme.withBlur(Theme.bgTile)
            visible: Prefs.dockIconTiles
        }

        Rectangle {
            id: stateLayer

            anchors.fill: parent
            radius: dockItem.sc(14)
            color: Theme.text
            opacity: dockItem.pressed ? Theme.statePressed : (dockItem.hovered ? Theme.stateHover : (dockItem.toggleActive ? Theme.stateFocus : 0))

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

        IconImage {
            id: iconImg

            anchors.fill: parent
            anchors.margins: dockItem.sc(5)
            visible: dockItem.iconContent === null && dockItem.iconSource !== ""
            source: dockItem.iconSource
        }

        Rectangle {
            id: monogramTile

            anchors.fill: parent
            anchors.margins: dockItem.sc(5)
            radius: dockItem.sc(11)
            color: Theme.bgHigh
            visible: dockItem.iconContent === null && dockItem.iconSource === ""

            Text {
                anchors.centerIn: parent
                text: dockItem.monogram
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(dockItem.sc(19))
                font.weight: Font.DemiBold
            }

        }

        Loader {
            id: iconLoader

            anchors.fill: parent
            anchors.margins: dockItem.sc(5)
            active: dockItem.iconContent !== null
            sourceComponent: dockItem.iconContent
        }

    }

    Rectangle {
        id: countBadge

        visible: dockItem.windowCount > 3
        width: dockItem.sc(16)
        height: dockItem.sc(16)
        radius: width / 2
        color: Theme.accent
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -dockItem.sc(3)
        anchors.topMargin: -dockItem.sc(3)
        z: 20
        scale: dockItem.windowCount > 3 ? 1 : 0

        Text {
            anchors.centerIn: parent
            text: dockItem.windowCount
            color: Theme.onAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(9)
            font.weight: Font.DemiBold
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }

        }

    }

    Row {
        id: indicator

        readonly property int segments: Math.max(1, Math.min(3, dockItem.windowCount))
        readonly property real segW: dockItem.focused ? (indicator.segments === 1 ? dockItem.sc(16) : dockItem.sc(9)) : dockItem.sc(5)

        anchors.horizontalCenter: parent.horizontalCenter
        y: dockItem.height + dockItem.sc(3) + (dockItem.hovered ? 3 : 0)
        spacing: dockItem.sc(3)
        opacity: (dockItem.active && Prefs.dockShowIndicators) ? 1 : 0
        visible: indicator.opacity > 0

        Repeater {
            model: indicator.segments

            Rectangle {
                width: indicator.segW
                height: dockItem.sc(3)
                radius: height / 2
                color: dockItem.urgent ? Theme.error : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

        }

        SequentialAnimation on opacity {
            running: dockItem.urgent && dockItem.active
            loops: Animation.Infinite

            NumberAnimation {
                to: 0.35
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: Theme.ms(500)
                easing.type: Easing.InOutSine
            }

        }

        Behavior on opacity {
            enabled: !dockItem.urgent

            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

        }

    }

    DockTooltip {
        id: tooltip

        label: dockItem.displayName
        detail: dockItem.windowCount > 1 ? dockItem.windowCount + " windows" : (dockItem.windowCount === 1 ? "1 window" : "")
        open: Prefs.dockShowTooltips && dockItem.tooltipReady && dockItem.displayName !== ""
        lift: dockItem.hovered ? 4 : 0
    }

    Item {
        id: hitArea

        readonly property real lift: -Math.min(0, dockItem.y)

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height + hitArea.lift

        HoverHandler {
            id: hoverHandler
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: dockItem.windowCount > 1
            onWheel: (event) => {
                event.accepted = true;
                dockItem.cycleWindows(event.angleDelta.y > 0 ? -1 : 1);
            }
        }

    }

    property int cycleAnchor: -1

    function cycleWindows(delta) {
        var addrs = dockItem.clientStats.addresses;
        if (addrs.length < 2)
            return;

        var from = dockItem.cycleAnchor;
        if (from < 0 || from >= addrs.length)
            from = addrs.indexOf(dockItem.focusedAddress);

        var next = ((from + delta) % addrs.length + addrs.length) % addrs.length;
        dockItem.cycleAnchor = next;
        Hyprland.dispatch("hl.dsp.focus({window='address:" + addrs[next] + "'})");
    }

    function launch() {
        if (dockItem.command === "")
            return;

        Quickshell.execDetached(["sh", "-c", dockItem.command]);
        dockItem.launched();
    }

    onFocusedAddressChanged: dockItem.cycleAnchor = -1

    TapHandler {
        id: tapHandler

        onTapped: {
            if (dockItem.isToggle) {
                dockItem.requestToggle();
                return;
            }
            if (dockItem.active && dockItem.matchingClient) {
                var winWs = dockItem.matchingClient.workspace ? dockItem.matchingClient.workspace.id : -1;
                if (dockItem.distinctWorkspaceCount >= 2 || dockItem.windowCount >= 2 || winWs !== dockItem.activeWorkspaceId) {
                    dockItem.requestStackPopup();
                    return;
                }
            }
            dockItem.launch();
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        enabled: !dockItem.isToggle && dockItem.command !== ""
        onTapped: dockItem.launch()
    }

    TapHandler {
        id: contextTapHandler

        acceptedButtons: Qt.RightButton
        enabled: !dockItem.isToggle && dockItem.appId !== ""
        onTapped: dockItem.requestContextMenu()
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: dockItem.active && dockItem.hovered ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.6
        }

    }

    Behavior on y {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: dockItem.active && dockItem.hovered ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.6
        }

    }

}
