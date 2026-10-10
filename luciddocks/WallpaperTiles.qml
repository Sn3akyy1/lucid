import QtQuick
import Quickshell.Widgets
import qs

// The wallpaper picker as a grid of rounded tiles: two rows that scroll sideways,
// every wallpaper a rounded tile whose corners open up under the pointer. Same interface as
// WallpaperStrip, so the launcher can load either.
Item {
    id: strip

    property var model: null
    property int heroW: 340
    property int heroH: 211
    // the tiers of the strip style; a grid has none, but the launcher sets them
    property int midW: 238
    property int midH: 148
    property int smallW: 150
    property int smallH: 93
    property int tinyW: 100
    property int tinyH: 62
    property int itemGap: Theme.dp(10)
    property int hoveredIndex: -1
    property alias currentIndex: view.currentIndex
    property string appliedPath: ""
    property real stableHeight: height
    property int previewInterval: 300
    property string pendingPreviewPath: ""
    property bool syncing: false
    property real originX: -1
    property real originY: -1
    // Settings -> Theme -> Tiles: how many rows (two to five), and square or 16:9 tiles
    readonly property int rows: Math.max(2, Math.min(5, Math.round(Prefs.wallpaperTilesRows) || 2))
    readonly property bool wide: Prefs.wallpaperTilesAspect === "wide"
    readonly property real rowHeight: strip.heroH + Theme.dp(62)
    readonly property int tile: Math.floor(view.height / strip.rows)
    readonly property int cellW: strip.wide ? Math.round(strip.tile * 16 / 9) : strip.tile

    signal chosen(string path)
    signal previewed(string path)

    function noteOrigin(card) {
        if (!card || strip.Window.width <= 0 || strip.Window.height <= 0) {
            strip.originX = -1;
            strip.originY = -1;
            return;
        }
        var p = card.mapToItem(null, card.width / 2, card.height / 2);
        strip.originX = p.x / strip.Window.width;
        strip.originY = p.y / strip.Window.height;
    }

    // left and right move a column over, up and down a row inside the column
    function step(d) {
        if (strip.model)
            view.currentIndex = Math.max(0, Math.min(strip.model.count - 1, view.currentIndex + d * strip.rows));
    }

    function stepVertical(d) {
        if (!strip.model)
            return;

        var next = view.currentIndex + d;
        if (next < 0 || next >= strip.model.count || Math.floor(next / strip.rows) !== Math.floor(view.currentIndex / strip.rows))
            return;

        view.currentIndex = next;
    }

    function activateCurrent() {
        if (view.currentIndex < 0 || !strip.model)
            return;

        var item = strip.model.get(view.currentIndex);
        if (item) {
            strip.noteOrigin(view.currentItem);
            strip.chosen(item.path);
        }
    }

    function setIndexImmediate(i) {
        strip.syncing = true;
        previewThrottle.stop();
        strip.pendingPreviewPath = "";
        view.currentIndex = i;
        Qt.callLater(strip.centerCurrent);
        restoreAnim.restart();
    }

    function centerCurrent() {
        if (view.currentIndex >= 0)
            view.positionViewAtIndex(view.currentIndex, GridView.Center);
    }

    function emitPreview() {
        if (strip.pendingPreviewPath === "")
            return;

        // the transition can grow from the card being previewed
        strip.noteOrigin(view.currentItem);
        strip.previewed(strip.pendingPreviewPath);
        strip.pendingPreviewPath = "";
    }

    Timer {
        id: restoreAnim

        interval: 120
        onTriggered: strip.syncing = false
    }

    Timer {
        id: previewThrottle

        interval: strip.previewInterval
        onTriggered: strip.emitPreview()
    }

    GridView {
        id: view

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.dp(6)
        // as wide as its columns, so a few wallpapers sit in the middle instead of
        // piling up on the left, and no wider than the panel
        width: Math.min(strip.width - Theme.dp(24), strip.cellW * Math.ceil(view.count / strip.rows))
        // the panel is cut to the grid (Dock.wallTilesChrome is what it keeps around
        // it), so the rows get what is left and the tiles stay at their size
        height: Math.max(strip.rows * 40, strip.stableHeight - Theme.dp(56))
        flow: GridView.FlowTopToBottom
        cellWidth: strip.cellW
        cellHeight: strip.tile
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: strip.model
        visible: count > 0
        highlightFollowsCurrentItem: false
        cacheBuffer: strip.cellW * 8

        onCurrentIndexChanged: {
            if (view.currentIndex >= 0)
                view.positionViewAtIndex(view.currentIndex, GridView.Contain);

            if (strip.syncing || view.currentIndex < 0 || !strip.model)
                return;

            var item = strip.model.get(view.currentIndex);
            if (!item)
                return;

            strip.pendingPreviewPath = item.path;
            previewThrottle.restart();
        }

        add: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0.6
                duration: Theme.durEnter
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }

            NumberAnimation {
                properties: "opacity"
                from: 0
                duration: Theme.ms(200)
            }

        }

        // a mouse wheel scrolls the row sideways
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var max = Math.max(0, view.contentWidth - view.width);
                view.contentX = Math.max(0, Math.min(max, view.contentX - (event.angleDelta.y + event.angleDelta.x) / 2));
            }
        }

        delegate: Item {
            id: slot

            required property string path
            required property string name
            required property int index

            readonly property bool isCurrent: view.currentIndex === slot.index
            readonly property bool isApplied: strip.appliedPath !== "" && strip.appliedPath === slot.path
            readonly property bool hovered: tileHover.hovered
            readonly property bool pressed: tileTap.pressed && slot.hovered

            width: view.cellWidth
            height: view.cellHeight

            onHoveredChanged: {
                if (slot.hovered)
                    strip.hoveredIndex = slot.index;
                else if (strip.hoveredIndex === slot.index)
                    strip.hoveredIndex = -1;

            }

            ClippingRectangle {
                id: card

                anchors.centerIn: parent
                width: slot.width - strip.itemGap
                height: slot.height - strip.itemGap
                // the shell's rounding, which opens up under the pointer or on the pick, kept
                // in proportion on the small tiles of a many-row grid
                radius: Math.min((slot.hovered || slot.isCurrent) ? Theme.radiusXl : Theme.radiusMd, Math.round(Math.min(card.width, card.height) * ((slot.hovered || slot.isCurrent) ? 0.34 : 0.26)))
                color: Theme.bgTile
                scale: slot.pressed ? 1 - 4 / card.width : ((slot.hovered || slot.isCurrent) ? 1 + 6 / card.width : 1)
                opacity: (slot.isCurrent || slot.hovered) ? 1 : 0.78

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(300)
                    }

                }

                Image {
                    anchors.fill: parent
                    source: "file://" + slot.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: strip.cellW * 2
                }

                Rectangle {
                    anchors.fill: parent
                    radius: card.radius
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: slot.isCurrent ? 3 : 0
                    visible: slot.isCurrent
                }

            }

            Rectangle {
                anchors.right: card.right
                anchors.top: card.top
                width: Theme.dp(22)
                height: Theme.dp(22)
                radius: Theme.pill(22)
                color: Theme.accent
                opacity: slot.isApplied ? 1 : 0
                visible: opacity > 0.01

                DockGlyph {
                    anchors.centerIn: parent
                    width: Theme.dp(14)
                    height: Theme.dp(14)
                    pathData: DockIcons.check
                    glyphColor: Theme.fgAccent
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            HoverHandler {
                id: tileHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: tileTap

                onTapped: {
                    if (slot.isCurrent) {
                        strip.noteOrigin(card);
                        strip.chosen(slot.path);
                    } else {
                        view.currentIndex = slot.index;
                    }
                }
            }

        }

    }

    Item {
        id: caption

        anchors.top: view.bottom
        anchors.topMargin: Theme.dp(12)
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.dp(26)
        visible: view.visible

        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (!strip.model)
                        return "";

                    var i = strip.hoveredIndex >= 0 ? strip.hoveredIndex : view.currentIndex;
                    if (i < 0 || i >= strip.model.count)
                        return "";

                    var item = strip.model.get(i);
                    return item ? item.name : "";
                }
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, strip.width - Theme.dp(200))
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: strip.model && strip.model.count > 0 ? ((strip.hoveredIndex >= 0 ? strip.hoveredIndex : view.currentIndex) + 1) + " / " + strip.model.count : ""
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

        }

    }

    Column {
        id: emptyState

        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - emptyState.implicitHeight) / 2)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(10)
        visible: !strip.model || strip.model.count === 0

        DockGlyph {
            width: Theme.dp(32)
            height: Theme.dp(32)
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.5
            pathData: DockIcons.brokenImage
            glyphColor: Theme.subtext
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No wallpapers in this folder"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
        }

    }

}
