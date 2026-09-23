import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.lucidui

// the way out: lock, sleep, log out, restart or shut down, each on its own
// expressive shape. the last three ask twice, so a stray key never costs work
PanelWindow {
    id: ses

    property bool open: false
    property var onScreen: null
    // the action waiting for its second press
    property string armed: ""
    property int focusIndex: 0
    // runs 1 to 0 while an action is armed
    property real armLeft: 0
    property real reveal: ses.open ? 1 : 0
    readonly property var actions: [{
        "id": "lock",
        "label": "Lock",
        "icon": "lock",
        "shape": "cookie4",
        "key": Qt.Key_L,
        "hint": "L"
    }, {
        "id": "suspend",
        "label": "Sleep",
        "icon": "bedtime",
        "shape": "clover4",
        "key": Qt.Key_S,
        "hint": "S"
    }, {
        "id": "logout",
        "label": "Log out",
        "icon": "logout",
        "shape": "pill",
        "key": Qt.Key_E,
        "hint": "E",
        "ask": "Log out and close everything?"
    }, {
        "id": "reboot",
        "label": "Restart",
        "icon": "restart_alt",
        "shape": "cookie9",
        "key": Qt.Key_R,
        "hint": "R",
        "ask": "Restart now?"
    }, {
        "id": "shutdown",
        "label": "Shut down",
        "icon": "power_settings_new",
        "shape": "sunny",
        "key": Qt.Key_P,
        "hint": "P",
        "ask": "Shut down now?"
    }]
    readonly property string who: Users.me ? Users.displayName(Users.me).split(" ")[0] : Quickshell.env("USER")

    function show() {
        ses.onScreen = Monitors.focusedScreen || Monitors.mainScreen;
        ses.armed = "";
        ses.focusIndex = 0;
        ses.open = true;
        Sys.hold("session", true, 5000);
    }

    function hide() {
        ses.open = false;
        ses.armed = "";
        Sys.hold("session", false);
    }

    function press(i) {
        var a = ses.actions[i];
        ses.focusIndex = i;
        if (a.ask && ses.armed !== a.id) {
            ses.armed = a.id;
            disarm.restart();
            armAnim.restart();
            return ;
        }
        ses.hide();
        // let the screen clear before the session goes
        runLater.pending = a.id;
        runLater.restart();
    }

    screen: ses.onScreen
    visible: ses.open || ses.reveal > 0.01
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ses.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucid-session"
    BackgroundEffect.blurRegion: Theme.blurAmount > 0 && ses.open ? whole : null

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Region {
        id: whole

        width: ses.width
        height: ses.height
    }

    Behavior on reveal {
        NumberAnimation {
            duration: ses.open ? Theme.durDefaultSpatial : Theme.durFastEffects
            easing.type: ses.open ? Easing.Bezier : Easing.InCubic
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    NumberAnimation {
        id: armAnim

        target: ses
        property: "armLeft"
        from: 1
        to: 0
        duration: disarm.interval
    }

    Timer {
        id: disarm

        interval: 4000
        onTriggered: ses.armed = ""
    }

    Timer {
        id: runLater

        property string pending: ""

        interval: 260
        onTriggered: Power.run(runLater.pending)
    }

    IpcHandler {
        // qs ipc call session toggle
        function toggle(): void {
            if (ses.open)
                ses.hide();
            else
                ses.show();
        }

        function open(): void {
            ses.show();
        }

        function close(): void {
            ses.hide();
        }

        target: "session"
    }

    Item {
        id: stage

        anchors.fill: parent
        focus: ses.open
        opacity: Math.min(1, ses.reveal * 1.4)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
                if (ses.armed !== "")
                    ses.armed = "";
                else
                    ses.hide();
            } else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && (e.modifiers & Qt.ShiftModifier))) {
                ses.focusIndex = (ses.focusIndex + ses.actions.length - 1) % ses.actions.length;
                ses.armed = "";
            } else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                ses.focusIndex = (ses.focusIndex + 1) % ses.actions.length;
                ses.armed = "";
            } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                ses.press(ses.focusIndex);
            } else {
                for (var i = 0; i < ses.actions.length; i++) {
                    if (ses.actions[i].key === e.key) {
                        ses.press(i);
                        break;
                    }
                }
            }
            e.accepted = true;
        }

        // the dim, and a click anywhere off the shapes backs out
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, Theme.blurAmount > 0 ? 0.42 : 0.72)

            MouseArea {
                anchors.fill: parent
                onClicked: ses.hide()
            }

        }

        Column {
            anchors.centerIn: parent
            spacing: 44

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                transform: Translate {
                    y: (1 - ses.reveal) * -24
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "displayMedium"
                    weight: 560
                    rounded: 100
                    color: "white"
                    text: ses.armed !== "" ? ses.actions.find((a) => {
                        return a.id === ses.armed;
                    }).ask : "See you soon, " + ses.who
                }

                LText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "titleMedium"
                    color: Qt.rgba(1, 1, 1, 0.72)
                    text: ses.armed !== "" ? "Press it again to go ahead, Esc to stay" : (Sys.uptime > 0 ? "Up for " + Sys.duration(Sys.uptime) : " ")
                }

            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                Repeater {
                    model: ses.actions

                    Item {
                        id: tile

                        required property var modelData
                        required property int index
                        readonly property bool focused: ses.focusIndex === tile.index
                        readonly property bool isArmed: ses.armed === tile.modelData.id
                        readonly property bool hot: tile.focused || tileTap.containsMouse
                        // each tile rises into place a beat after the one before
                        readonly property real enter: Math.max(0, Math.min(1, ses.reveal * 1.6 - tile.index * 0.12))

                        width: 136
                        height: 136 + 44
                        opacity: tile.enter
                        transform: Translate {
                            y: (1 - tile.enter) * 60
                        }

                        MaterialShape {
                            id: blob

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 136
                            height: 136
                            shape: tile.modelData.shape
                            to: "circle"
                            morph: tile.isArmed ? 0 : (tile.hot ? 0.0 : 0.55)
                            color: tile.isArmed ? Theme.error : (tile.hot ? Theme.primary : Theme.withBlur(Theme.surfaceHigh))
                            rotation: tile.isArmed ? 360 : (tile.hot ? 22 : 0)
                            scale: tileTap.pressed ? 0.92 : (tile.hot ? 1.06 : 1)

                            Behavior on morph {
                                NumberAnimation {
                                    duration: Theme.durDefaultSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: tile.isArmed ? 900 : Theme.durSlowSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveDefaultSpatial
                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.durFastSpatial
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.curveFastSpatial
                                }

                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durDefaultEffects
                                }

                            }

                        }

                        Icon {
                            anchors.centerIn: blob
                            name: tile.modelData.icon
                            size: 46
                            fill: tile.hot || tile.isArmed ? 1 : 0
                            color: tile.isArmed ? Theme.fgError : (tile.hot ? Theme.fgPrimary : Theme.text)
                        }

                        // the countdown before an armed action gives up
                        CircularProgress {
                            visible: tile.isArmed
                            anchors.centerIn: blob
                            width: 156
                            height: 156
                            thickness: 4
                            showTrack: false
                            animated: false
                            color: Theme.error
                            value: ses.armLeft
                        }

                        Column {
                            anchors.top: blob.bottom
                            anchors.topMargin: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2

                            LText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "titleMedium"
                                weight: tile.hot ? 640 : 500
                                color: "white"
                                text: tile.modelData.label
                            }

                            LText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "labelSmall"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                text: tile.modelData.hint
                            }

                        }

                        MouseArea {
                            id: tileTap

                            anchors.fill: blob
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (ses.focusIndex !== tile.index) {
                                    ses.focusIndex = tile.index;
                                    if (ses.armed !== tile.modelData.id)
                                        ses.armed = "";

                                }
                            }
                            onClicked: ses.press(tile.index)
                        }

                    }

                }

            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "labelLarge"
                color: Qt.rgba(1, 1, 1, 0.5)
                text: "← → to choose  ·  Enter to go  ·  Esc to stay"
            }

        }

    }

}
