import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// every picture in the folder at once, to jump to one: it rises over the stage
// from the strip below. typing narrows it by name; enter goes to the first
Item {
    id: ov

    required property var win
    required property var app
    required property var model
    readonly property bool shown: ov.win.overview
    readonly property string query: field.text.trim().toLowerCase()
    property var hits: []
    property int cursor: 0
    // scrolled as lumen's folders are: a touchpad's pace, padSpeed in px per ms, smoothed
    readonly property real padGain: 2.4
    property real padSpeed: 0
    property real padAt: 0

    // fingers off the touchpad: the grid glides on at their speed, slowing at a
    // steady rate
    function coastOn() {
        var speed = ov.padSpeed;
        if (Theme.motionScale <= 0 || Date.now() - ov.padAt > 90 || Math.abs(speed) < 0.12)
            return ;

        var maxY = Math.max(0, grid.contentHeight - grid.height);
        var slow = 0.0025;
        var to = Math.max(0, Math.min(maxY, grid.contentY - speed * Math.abs(speed) / (2 * slow)));
        if (Math.abs(to - grid.contentY) < 1)
            return ;

        // an ease-out quad starts at twice its mean pace: that is the fingers' speed
        coast.from = grid.contentY;
        coast.to = to;
        coast.duration = Math.max(120, 2 * Math.abs(to - grid.contentY) / Math.abs(speed));
        coast.restart();
    }

    function refilter() {
        coast.stop();
        glide.stop();
        var out = [];
        for (var i = 0; i < ov.model.count; i++) {
            if (ov.query === "" || ov.model.get(i).name.toLowerCase().indexOf(ov.query) >= 0)
                out.push(i);

        }
        ov.hits = out;
        ov.cursor = Math.max(0, out.indexOf(ov.win.index));
    }

    function open(i) {
        if (i < 0 || i >= ov.hits.length)
            return ;

        ov.win.jump(ov.hits[i]);
        ov.win.overview = false;
    }

    onQueryChanged: ov.refilter()
    onShownChanged: {
        if (ov.shown) {
            field.text = "";
            ov.refilter();
            Qt.callLater(function() {
                grid.positionViewAtIndex(ov.cursor, GridView.Center);
                field.input.forceActiveFocus();
            });
        } else {
            ov.win.keysBack();
        }
    }
    visible: sheet.y < ov.height - 1

    Connections {
        function onCountChanged() {
            if (ov.shown)
                ov.refilter();

        }

        target: ov.model
    }

    Rectangle {
        id: sheet

        width: ov.width
        height: ov.height
        y: ov.shown ? 0 : ov.height
        color: Theme.withBlur(Theme.bgSunken)

        // the grid can't be clicked through to the stage under it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => {
                wheel.accepted = true;
            }
        }

        Row {
            id: head

            x: Theme.dp(20)
            y: Theme.dp(16)
            width: parent.width - Theme.dp(40)
            spacing: Theme.dp(12)

            TextField {
                id: field

                width: Math.min(Theme.dp(420), head.width - count.implicitWidth - Theme.dp(12))
                height: Theme.dp(48)
                variant: "search"
                placeholder: "Find a picture in " + ov.app.titleOf(ov.win.folder)
                onAccepted: ov.open(ov.cursor)
                onEscaped: ov.win.overview = false
                input.Keys.onPressed: (event) => {
                    var cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
                    var step = event.key === Qt.Key_Right ? 1 : event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Down ? cols : event.key === Qt.Key_Up ? -cols : 0;
                    if (step === 0 || (field.text !== "" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)))
                        return ;

                    ov.cursor = Math.max(0, Math.min(ov.hits.length - 1, ov.cursor + step));
                    grid.positionViewAtIndex(ov.cursor, GridView.Contain);
                    event.accepted = true;
                }
            }

            LText {
                id: count

                anchors.verticalCenter: parent.verticalCenter
                role: "bodyMedium"
                color: Theme.subtext
                text: ov.query === "" ? ov.hits.length + (ov.hits.length === 1 ? " picture" : " pictures") : ov.hits.length + " of " + ov.model.count
            }

        }

        GridView {
            id: grid

            readonly property real want: Theme.dp(168)
            readonly property int cols: Math.max(2, Math.floor(width / want))

            anchors.top: head.bottom
            anchors.topMargin: Theme.dp(12)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.dp(14)
            anchors.rightMargin: Theme.dp(14)
            cellWidth: Math.floor(width / cols)
            cellHeight: cellWidth
            model: ov.hits
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: Theme.dp(800)

            // a wheel notch moves two and a half rows; a touchpad follows the fingers
            // straight away, then coasts when they lift. only a touchpad's scroll has
            // phases: on wayland a wheel notch carries pixel deltas too (15 a notch)
            WheelHandler {
                target: null
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    var maxY = Math.max(0, grid.contentHeight - grid.height);
                    grid.cancelFlick();
                    if (event.phase !== Qt.NoScrollPhase) {
                        glide.stop();
                        coast.stop();
                        var d = event.pixelDelta.y * ov.padGain;
                        if (d !== 0) {
                            var now = Date.now();
                            var dt = Math.max(1, now - ov.padAt);
                            // a pause since the last event starts the speed afresh
                            ov.padSpeed = dt > 90 ? d / dt : ov.padSpeed * 0.6 + d / dt * 0.4;
                            ov.padAt = now;
                            grid.contentY = Math.max(0, Math.min(maxY, grid.contentY - d));
                        }
                        if (event.phase === Qt.ScrollEnd)
                            ov.coastOn();

                        return ;
                    }
                    coast.stop();
                    var step = Math.max(Theme.dp(320), grid.cellHeight * 2.5);
                    glide.to = Math.max(0, Math.min(maxY, (glide.running ? glide.to : grid.contentY) - event.angleDelta.y / 120 * step));
                    glide.restart();
                }
            }

            NumberAnimation {
                id: coast

                target: grid
                property: "contentY"
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                id: glide

                target: grid
                property: "contentY"
                duration: Theme.durShort
                easing.type: Easing.OutCubic
            }

            delegate: Item {
                id: cell

                required property int index
                required property int modelData
                readonly property var row: cell.modelData < ov.model.count ? ov.model.get(cell.modelData) : null
                readonly property bool on: cell.modelData === ov.win.index
                readonly property bool hot: cell.index === ov.cursor

                width: grid.cellWidth
                height: grid.cellHeight

                ClippingRectangle {
                    id: tile

                    anchors.fill: parent
                    anchors.margins: Theme.dp(5)
                    radius: cell.on ? Theme.radiusXl : Theme.radiusMd
                    color: Theme.surfaceHigh
                    scale: area.pressed ? 0.95 : 1

                    Image {
                        anchors.fill: parent
                        source: cell.row && cell.row.thumb !== "" ? "file://" + cell.row.thumb + "?r=" + cell.row.rev : ""
                        sourceSize: Qt.size(Math.round(grid.cellWidth * 1.5), Math.round(grid.cellWidth * 1.5))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !cell.row || cell.row.thumb === ""
                        name: cell.row && cell.row.failed ? "broken_image" : (cell.row && cell.row.video ? "movie" : "image")
                        size: Theme.dp(28)
                        color: Theme.subtext
                    }

                    // a video, marked as one
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.dp(8)
                        width: Theme.dp(26)
                        height: width
                        radius: width / 2
                        color: Qt.rgba(0, 0, 0, 0.55)
                        visible: cell.row !== null && cell.row.video === true && cell.row.thumb !== ""

                        Icon {
                            anchors.centerIn: parent
                            name: "play_arrow"
                            size: Theme.dp(18)
                            fill: 1
                            color: "#ffffff"
                        }

                    }

                    // the name, over a shade at the foot, while the pointer is on it
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Theme.dp(34)
                        opacity: area.containsMouse || cell.hot && ov.query !== "" ? 1 : 0
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }

                            GradientStop {
                                position: 1
                                color: Qt.rgba(0, 0, 0, 0.62)
                            }

                        }

                        LText {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Theme.dp(8)
                            role: "labelMedium"
                            color: "white"
                            text: cell.row ? cell.row.name : ""
                            elide: Text.ElideMiddle
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                    Behavior on radius {
                        NumberAnimation {
                            duration: Theme.durFastSpatial
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

                }

                Rectangle {
                    anchors.fill: tile
                    anchors.margins: -Theme.dp(3)
                    radius: tile.radius + Theme.dp(3)
                    color: "transparent"
                    border.width: Theme.dp(2)
                    border.color: cell.on ? Theme.accent : Theme.alpha(Theme.text, 0.5)
                    visible: cell.on || (cell.hot && ov.query !== "")
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: coast.stop()
                    onClicked: ov.open(cell.index)
                }

            }

        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

    }

}
