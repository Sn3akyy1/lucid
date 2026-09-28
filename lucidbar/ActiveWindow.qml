import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// the window in focus, by its app's icon and its title; open, what can be done
// to it and the other windows on the same workspace
BarPill {
    id: root

    readonly property var focusedWs: Hyprland.focusedWorkspace
    // quickshell learns the active window from Hyprland's focus events only, so
    // one focused before the shell started goes unseen until the focus moves:
    // until then, the window Hyprland lists as focused last stands in
    property bool heardFocus: false
    readonly property var startFocus: root.heardFocus ? null : (Hyprland.toplevels.values.find((t) => {
        return t && t.lastIpcObject && t.lastIpcObject.focusHistoryID === 0;
    }) || null)
    // Hyprland keeps the last window as active on an empty workspace, so the
    // one shown has to be on the workspace in view, or in a special one open
    // over it
    readonly property var active: {
        const t = Hyprland.activeToplevel || root.startFocus;
        if (!t || !t.workspace || !root.focusedWs)
            return null;

        if (t.workspace === root.focusedWs)
            return t;

        return String(t.workspace.name || "").indexOf("special:") === 0 ? t : null;
    }
    readonly property var info: root.active && root.active.lastIpcObject ? root.active.lastIpcObject : ({})
    readonly property string title: root.active ? String(root.active.title || "") : ""
    readonly property string appLabel: root.appName(root.active)
    readonly property string faceText: {
        const mode = Prefs.windowModuleText;
        if (mode === "app" || root.title === "")
            return root.appLabel;

        if (mode === "both" && root.appLabel !== "" && root.appLabel !== root.title)
            return root.appLabel + "  ·  " + root.title;

        return root.title;
    }
    readonly property int horizontalPadding: 11
    // the looks, from its card on the Bar page
    readonly property bool chipFace: Prefs.windowModuleStyle === "chip"
    readonly property bool iconOnly: Prefs.windowModuleText === "icon"
    // every window on the workspace in view, in Hyprland's order
    readonly property var here: root.active && root.active.workspace && root.active.workspace.toplevels ? root.active.workspace.toplevels.values.filter((t) => {
        return !!t;
    }) : []
    readonly property var others: root.here.filter((t) => {
        return t !== root.active;
    })
    readonly property int currentWs: root.focusedWs ? root.focusedWs.id : 0

    function classOf(t) {
        if (!t)
            return "";

        const o = t.lastIpcObject || {};
        return String((t.wayland && t.wayland.appId) || o.class || "");
    }

    function entryOf(t) {
        const c = root.classOf(t);
        return c !== "" ? DesktopEntries.heuristicLookup(c) : null;
    }

    function iconOf(t) {
        const e = root.entryOf(t);
        return e && e.icon ? Quickshell.iconPath(e.icon, "application-x-executable") : Quickshell.iconPath("application-x-executable", true);
    }

    function appName(t) {
        if (!t)
            return "";

        const e = root.entryOf(t);
        return e && e.name ? e.name : root.classOf(t);
    }

    function address(t) {
        const a = t ? String(t.address || "") : "";
        return a === "" ? "" : (a.indexOf("0x") === 0 ? a : "0x" + a);
    }

    // a dispatcher aimed at one window, whatever has the focus by then
    function act(t, dispatcher, args) {
        const a = root.address(t);
        if (a === "")
            return ;

        const fields = ["window = \"address:" + a + "\""].concat(args || []);
        Hyprland.dispatch(dispatcher + "({ " + fields.join(", ") + " })");
        refresh.restart();
    }

    function focusWindow(t) {
        const a = root.address(t);
        if (a === "")
            return ;

        focusLater.address = a;
        focusLater.restart();
    }

    // the wheel walks the windows here, one notch at a time
    function cycle(step) {
        if (root.here.length < 2)
            return ;

        const i = root.here.indexOf(root.active);
        const next = root.here[((i < 0 ? 0 : i) + step + root.here.length) % root.here.length];
        root.focusWindow(next);
    }

    // on the press, not the click: a press on a panel opened by hover pins it,
    // and the focus grab that comes with that cancels the click
    component PillGestures: MouseArea {
        acceptedButtons: Qt.MiddleButton
        onPressed: {
            if (Prefs.windowModuleMiddleClose)
                root.act(root.active, "hl.dsp.window.close", []);

        }
        onWheel: (wheel) => {
            if (!Prefs.windowModuleScroll) {
                wheel.accepted = false;
                return ;
            }
            root.cycle(wheel.angleDelta.y < 0 ? 1 : -1);
        }
    }

    shown: Prefs.showWindow && root.active !== null && root.faceText !== ""
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: 400
    panelHeight: panelColumn.implicitHeight + 36
    expandedRadius: Theme.shapeXl
    onShownChanged: {
        if (!root.shown)
            root.expanded = false;

    }
    onExpandedChanged: {
        if (root.expanded)
            Hyprland.refreshToplevels();

    }

    Connections {
        function onActiveToplevelChanged() {
            if (Hyprland.activeToplevel)
                root.heardFocus = true;

        }

        target: Hyprland
    }

    // after quickshell's own first read, not racing it
    Timer {
        running: !root.heardFocus
        interval: 1000
        onTriggered: Hyprland.refreshToplevels()
    }

    // the panel's focus grab hands the focus back as it lets go, so a switch
    // waits for that to be over, the way the launcher's does
    Timer {
        id: focusLater

        property string address: ""

        interval: 80
        onTriggered: Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + focusLater.address + "\" })")
    }

    // the same for a move: made while the grab still holds, the focus it hands
    // back as it lets go lands on the moved window and takes the view along
    Timer {
        id: moveLater

        property var window: null
        property int ws: 0

        interval: 80
        onTriggered: root.act(moveLater.window, "hl.dsp.window.move", ["workspace = " + moveLater.ws, "follow = false"])
    }

    Timer {
        id: refresh

        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    component ActionButton: Rectangle {
        id: button

        property string label: ""
        property bool on: false
        property bool danger: false

        signal clicked()

        width: buttonLabel.implicitWidth + 28
        height: 36
        radius: 18
        color: {
            if (button.danger)
                return buttonArea.containsMouse ? Theme.error : Theme.errorContainer;

            if (button.on)
                return buttonArea.containsMouse ? Theme.accentHover : Theme.accent;

            return buttonArea.containsMouse ? Theme.alpha(Theme.secondaryContainer, 0.8) : Theme.secondaryContainer;
        }

        Text {
            id: buttonLabel

            anchors.centerIn: parent
            text: button.label
            color: button.danger ? (buttonArea.containsMouse ? Theme.fgError : Theme.fgErrorContainer) : (button.on ? Theme.fgAccent : Theme.fgSecondaryContainer)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
        }

        MouseArea {
            id: buttonArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    component SectionLabel: Text {
        topPadding: 4
        color: Theme.accent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLabelLg
        font.weight: Font.DemiBold
    }

    compactContent: [
        // the chip face: the window on a tinted chip
        Rectangle {
            visible: root.chipFace
            anchors.centerIn: compactRow
            width: compactRow.width + (root.iconOnly ? 12 : 18)
            height: Math.min(26, parent.height - 6)
            radius: height / 2
            color: Theme.accentContainer
        },
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 8

            Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17
                sourceSize.width: 34
                sourceSize.height: 34
                source: root.iconOf(root.active)
                asynchronous: true
                smooth: true
            }

            Text {
                visible: !root.iconOnly
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, Prefs.windowModuleWidth)
                text: root.faceText
                color: root.chipFace ? Theme.fgAccentContainer : Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

        },
        // over the pill's own click area: the wheel and the middle button only,
        // so a left or right click still reaches the pill
        PillGestures {
            anchors.fill: parent
        }
    ]

    panelContent: [
        Column {
            id: panelColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 12

            Row {
                id: headerRow

                width: parent.width
                spacing: 14

                Rectangle {
                    id: badge

                    width: 48
                    height: 48
                    radius: Theme.radiusMd
                    color: Theme.accentContainer

                    Image {
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        sourceSize.width: 60
                        sourceSize.height: 60
                        source: root.iconOf(root.active)
                        asynchronous: true
                        smooth: true
                    }

                }

                Column {
                    width: parent.width - badge.width - 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.appLabel
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitleSm
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: root.title
                        visible: text !== "" && text !== root.appLabel
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelLg
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                }

            }

            Flow {
                width: parent.width
                spacing: 6

                ActionButton {
                    label: root.info.floating ? "Floating" : "Float"
                    on: root.info.floating === true
                    onClicked: root.act(root.active, "hl.dsp.window.float", ["action = \"toggle\""])
                }

                ActionButton {
                    visible: root.info.floating === true
                    label: "Center"
                    onClicked: root.act(root.active, "hl.dsp.window.center", [])
                }

                ActionButton {
                    visible: root.info.floating === true
                    label: root.info.pinned ? "Pinned" : "Pin"
                    on: root.info.pinned === true
                    onClicked: root.act(root.active, "hl.dsp.window.pin", [])
                }

                ActionButton {
                    label: "Fullscreen"
                    on: (root.info.fullscreen || 0) > 0
                    onClicked: {
                        root.expanded = false;
                        root.act(root.active, "hl.dsp.window.fullscreen", ["mode = \"fullscreen\""]);
                    }
                }

                ActionButton {
                    label: "Close"
                    danger: true
                    onClicked: {
                        root.expanded = false;
                        root.act(root.active, "hl.dsp.window.close", []);
                    }
                }

            }

            SectionLabel {
                text: "Move to workspace"
            }

            Grid {
                id: wsGrid

                width: parent.width
                columns: 5
                spacing: 6

                Repeater {
                    model: 10

                    Rectangle {
                        id: wsChip

                        required property int index
                        readonly property int ws: wsChip.index + 1
                        readonly property bool current: wsChip.ws === root.currentWs

                        width: (wsGrid.width - wsGrid.spacing * 4) / 5
                        height: 34
                        radius: 17
                        color: wsChip.current ? Theme.accent : (wsArea.containsMouse ? Theme.withBlur(Theme.bgHover) : Theme.withBlur(Theme.bgActive))

                        Text {
                            anchors.centerIn: parent
                            text: String(wsChip.ws)
                            color: wsChip.current ? Theme.fgAccent : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.weight: wsChip.current ? Font.DemiBold : Font.Medium
                        }

                        MouseArea {
                            id: wsArea

                            anchors.fill: parent
                            enabled: !wsChip.current
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                moveLater.window = root.active;
                                moveLater.ws = wsChip.ws;
                                root.expanded = false;
                                moveLater.restart();
                            }
                        }

                    }

                }

            }

            SectionLabel {
                visible: root.others.length > 0
                text: "Also on this workspace"
            }

            Repeater {
                model: root.others

                Rectangle {
                    id: otherRow

                    required property var modelData

                    width: panelColumn.width
                    height: 44
                    radius: Theme.radiusMd
                    color: otherArea.containsMouse ? Theme.withBlur(Theme.bgHover) : Theme.withBlur(Theme.bgActive)

                    Image {
                        id: otherIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        sourceSize.width: 40
                        sourceSize.height: 40
                        source: root.iconOf(otherRow.modelData)
                        asynchronous: true
                        smooth: true
                    }

                    Text {
                        anchors.left: otherIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(otherRow.modelData.title || root.appName(otherRow.modelData))
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyMd
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: otherArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const t = otherRow.modelData;
                            root.expanded = false;
                            root.focusWindow(t);
                        }
                    }

                }

            }

        },
        // the strip where the pill sat, header included, answers the wheel and
        // the middle button as the pill does: opened by hover, the panel is
        // already over the pill when they come
        PillGestures {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: panelColumn.anchors.margins + headerRow.height
        }
    ]
}
