import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// the folder along the bottom, the one on show kept in the middle. a click goes
// to a picture; dragged out, a picture goes wherever it is dropped
Item {
    id: film

    required property var win
    required property var app
    required property var model
    readonly property real cell: Theme.dp(60)
    readonly property real gap: Theme.dp(6)

    // the one on show slides to the middle; a far jump just lands there
    function follow() {
        if (film.win.index < 0)
            return ;

        list.currentIndex = film.win.index;
    }

    Connections {
        function onIndexChanged() {
            film.follow();
        }

        function onItemsChanged() {
            Qt.callLater(film.follow);
        }

        target: film.win
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: Theme.dp(4)
        anchors.bottomMargin: Theme.dp(8)
        orientation: ListView.Horizontal
        spacing: film.gap
        model: film.model
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        highlightRangeMode: ListView.ApplyRange
        preferredHighlightBegin: (width - film.cell) / 2
        preferredHighlightEnd: (width + film.cell) / 2
        highlightMoveDuration: Theme.durMedium
        highlightFollowsCurrentItem: true
        cacheBuffer: Theme.dp(600)
        // a short folder sits in the middle rather than at the left
        leftMargin: Math.max(0, (width - contentWidth) / 2)
        reuseItems: false
        // narrowed by a panel opening beside it, it keeps the one on show in sight
        onWidthChanged: {
            if (film.win.index >= 0 && count > 0)
                positionViewAtIndex(film.win.index, ListView.Contain);

        }

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var d = event.phase !== Qt.NoScrollPhase ? (event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y) * 2 : event.angleDelta.y / 120 * film.cell * 3;
                var max = Math.max(0, list.contentWidth - list.width + list.leftMargin);
                list.contentX = Math.max(-list.leftMargin, Math.min(max - list.leftMargin, list.contentX - d));
            }
        }

        delegate: Item {
            id: cell

            required property int index
            required property string path
            required property string name
            required property string thumb
            // new each time the file is written again: same thumbnail path, new picture
            required property int rev
            required property bool video
            required property bool failed
            readonly property bool on: cell.index === film.win.index
            readonly property bool edited: film.win.pending[cell.path] !== undefined

            width: film.cell
            height: list.height

            ClippingRectangle {
                id: tile

                anchors.centerIn: parent
                width: film.cell
                height: film.cell
                radius: cell.on ? Theme.radiusMd : Theme.radiusSm
                color: Theme.surfaceHigh
                scale: area.pressed ? 0.94 : cell.on ? 1 : (area.containsMouse ? 0.97 : 0.9)
                opacity: cell.on || area.containsMouse ? 1 : 0.72
                clip: true

                Image {
                    anchors.fill: parent
                    source: cell.thumb !== "" ? "file://" + cell.thumb + "?r=" + cell.rev : ""
                    sourceSize: Qt.size(Math.round(film.cell * 2), Math.round(film.cell * 2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: cell.thumb === ""
                    name: cell.failed ? "broken_image" : (cell.video ? "movie" : "image")
                    size: Theme.dp(22)
                    color: Theme.subtext
                }

                // a video, marked as one
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.dp(4)
                    width: Theme.dp(18)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.55)
                    visible: cell.video && cell.thumb !== ""

                    Icon {
                        anchors.centerIn: parent
                        name: "play_arrow"
                        size: Theme.dp(13)
                        fill: 1
                        color: "#ffffff"
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

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // the ring round the one on show
            Rectangle {
                anchors.centerIn: tile
                width: tile.width * tile.scale + Theme.dp(6)
                height: tile.height * tile.scale + Theme.dp(6)
                radius: tile.radius + Theme.dp(3)
                color: "transparent"
                border.width: Theme.dp(2)
                border.color: Theme.accent
                opacity: cell.on ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // an edit not saved yet
            Rectangle {
                anchors.right: tile.right
                anchors.top: tile.top
                anchors.margins: Theme.dp(4)
                width: Theme.dp(10)
                height: width
                radius: width / 2
                color: Theme.accent
                border.width: Theme.dp(2)
                border.color: Theme.surfaceHigh
                visible: cell.edited
            }

            MouseArea {
                id: area

                property point at

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    area.at = Qt.point(mouse.x, mouse.y);
                }
                onPositionChanged: (mouse) => {
                    if (pressed && !dragOut.Drag.active && Math.abs(mouse.x - area.at.x) + Math.abs(mouse.y - area.at.y) > Theme.dp(10))
                        film.dragOut(cell.path, cell.thumb);

                }
                onClicked: film.win.jump(cell.index)
            }

            Tip {
                text: cell.name
            }

        }

    }

    // a picture carried out to another app: lumen, a browser, a chat. the drag
    // starts after the press handler returns, so its loop doesn't run inside it
    function dragOut(path, thumb) {
        dragOut.path = path;
        dragOut.Drag.imageSource = thumb !== "" ? "file://" + thumb : "";
        Qt.callLater(function() {
            dragOut.Drag.active = true;
        });
    }

    Item {
        id: dragOut

        property string path: ""

        width: 1
        height: 1
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({
            "text/uri-list": film.app.uriOf(dragOut.path) + "\r\n",
            "text/plain": dragOut.path
        })
        Drag.imageSourceSize: Qt.size(Theme.dp(72), Theme.dp(72))
        Drag.hotSpot: Qt.point(Theme.dp(36), Theme.dp(36))
        Drag.onActiveChanged: {
            if (!Drag.active)
                dragOut.Drag.imageSource = "";

        }
    }

}
