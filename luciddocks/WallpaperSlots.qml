import QtQuick
import Quickshell.Widgets
import qs

// The picker styles built from slots: every wallpaper is one shape that glides
// between places as the selection moves, changing width, height and corner
// radius on the way. A style only says where the wallpaper `offset` places from
// the selected one goes (slotRect); this does the rest, and has the same
// interface as WallpaperStrip so the launcher can load any of them.
Item {
    id: strip

    property var model: null
    property int heroW: 340
    property int heroH: 211
    // the tiers of the strip style; slot styles lay themselves out, but the launcher sets them
    property int midW: 238
    property int midH: 148
    property int smallW: 150
    property int smallH: 93
    property int tinyW: 100
    property int tinyH: 62
    property int itemGap: Theme.dp(10)
    property int hoveredIndex: -1
    property int currentIndex: -1
    property string appliedPath: ""
    property real stableHeight: height
    property int previewInterval: 300
    property string pendingPreviewPath: ""
    property bool syncing: false
    property real originX: -1
    property real originY: -1
    readonly property int count: strip.model ? strip.model.count : 0
    readonly property real stageTop: Math.max(0, (strip.stableHeight - (strip.heroH + 62)) / 2)
    readonly property real stageH: strip.heroH + 24
    // slotRect(offset) -> { x, y, w, h, r, o }: where the wallpaper that many places
    // from the selected one sits in the stage, its corner radius and opacity (0 hides it)
    property var slotRect: function (offset) {
        return {
            "x": 0,
            "y": 0,
            "w": 0,
            "h": 0,
            "r": 0,
            "o": 0
        };
    }

    signal chosen(string path)
    signal previewed(string path)

    // x of a slim shape `offset` places from an open one in a row: the open one is
    // centred, the slim ones follow on both sides with a gap, `sides` of them each
    function rowX(offset, openW, slimW, gap, sides) {
        var ox = (strip.width - openW) / 2;
        var n = Math.abs(offset);
        if (offset === 0)
            return ox;

        if (n > sides)
            return offset > 0 ? strip.width : -slimW;

        return offset > 0 ? ox + openW + gap + (n - 1) * (slimW + gap) : ox - n * (slimW + gap);
    }

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

    function step(d) {
        if (strip.count > 0)
            strip.currentIndex = Math.max(0, Math.min(strip.count - 1, strip.currentIndex + d));
    }

    function stepVertical(d) {
    }

    function pathAt(i) {
        var item = (strip.model && i >= 0 && i < strip.count) ? strip.model.get(i) : null;
        return item ? item.path : "";
    }

    function activateCurrent() {
        var path = strip.pathAt(strip.currentIndex);
        if (path === "")
            return;

        strip.noteOrigin(slots.itemAt(strip.currentIndex));
        strip.chosen(path);
    }

    function setIndexImmediate(i) {
        strip.syncing = true;
        previewThrottle.stop();
        strip.pendingPreviewPath = "";
        strip.currentIndex = i;
        restoreAnim.restart();
    }

    function emitPreview() {
        if (strip.pendingPreviewPath === "")
            return;

        // the transition can grow from the card being previewed
        strip.noteOrigin(slots.itemAt(strip.currentIndex));
        strip.previewed(strip.pendingPreviewPath);
        strip.pendingPreviewPath = "";
    }

    // the model arrives after the picker does
    onCountChanged: {
        if (strip.count > 0 && strip.currentIndex < 0)
            strip.currentIndex = 0;

    }
    onCurrentIndexChanged: {
        if (strip.syncing || strip.currentIndex < 0 || strip.count === 0)
            return;

        var path = strip.pathAt(strip.currentIndex);
        if (path === "")
            return;

        strip.pendingPreviewPath = path;
        previewThrottle.restart();
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

    Item {
        id: stage

        y: strip.stageTop
        width: parent.width
        height: strip.stageH
        visible: strip.count > 0

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                strip.step(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1);
            }
        }

        Repeater {
            id: slots

            model: strip.count

            delegate: Item {
                id: slot

                required property int index

                readonly property int offset: slot.index - strip.currentIndex
                readonly property var rect: strip.slotRect(slot.offset)
                readonly property var entry: strip.model ? strip.model.get(slot.index) : null
                readonly property string path: slot.entry ? slot.entry.path : ""
                readonly property bool isCurrent: slot.offset === 0
                readonly property bool isApplied: strip.appliedPath !== "" && strip.appliedPath === slot.path
                readonly property bool hovered: slotHover.hovered
                readonly property bool pressed: slotTap.pressed && slot.hovered
                readonly property bool wide: slot.width >= Theme.dp(70)

                x: slot.rect.x
                y: slot.rect.y
                width: slot.rect.w
                height: slot.rect.h
                opacity: (slot.hovered && slot.rect.o > 0) ? 1 : slot.rect.o
                visible: slot.opacity > 0.01 && slot.width > 1
                scale: slot.pressed ? 0.97 : 1
                onHoveredChanged: {
                    if (slot.hovered)
                        strip.hoveredIndex = slot.index;
                    else if (strip.hoveredIndex === slot.index)
                        strip.hoveredIndex = -1;

                }

                Behavior on x {
                    enabled: !strip.syncing

                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Behavior on y {
                    enabled: !strip.syncing

                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Behavior on width {
                    enabled: !strip.syncing

                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Behavior on height {
                    enabled: !strip.syncing

                    NumberAnimation {
                        duration: Theme.ms(300)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.ms(300)
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                ClippingRectangle {
                    id: card

                    anchors.fill: parent
                    radius: slot.rect.r
                    color: Theme.bgTile

                    Behavior on radius {
                        enabled: !strip.syncing

                        NumberAnimation {
                            duration: Theme.ms(300)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                    // a narrow shape shows the middle of the picture, a wide one all of it
                    Image {
                        anchors.centerIn: parent
                        width: Math.max(parent.width, parent.height * 1.6)
                        height: parent.height
                        source: slot.path === "" ? "" : "file://" + slot.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: Theme.dp(640)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.text
                        opacity: slot.pressed ? Theme.statePressed : (slot.hovered ? Theme.stateHover : 0)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

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

                // applied: a check on a wide shape, a dot at the foot of a slim one
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.dp(10)
                    width: Theme.dp(24)
                    height: Theme.dp(24)
                    radius: Theme.pill(24)
                    color: Theme.accent
                    visible: slot.isApplied && slot.wide

                    DockGlyph {
                        anchors.centerIn: parent
                        width: Theme.dp(15)
                        height: Theme.dp(15)
                        pathData: DockIcons.check
                        glyphColor: Theme.fgAccent
                    }

                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.dp(8)
                    width: Theme.dp(8)
                    height: Theme.dp(8)
                    radius: Theme.pill(8)
                    color: Theme.accent
                    visible: slot.isApplied && !slot.wide
                }

                HoverHandler {
                    id: slotHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: slotTap

                    onTapped: {
                        if (slot.isCurrent) {
                            strip.noteOrigin(slot);
                            strip.chosen(slot.path);
                        } else {
                            strip.currentIndex = slot.index;
                        }
                    }
                }

            }

        }

    }

    Item {
        id: caption

        anchors.top: stage.bottom
        anchors.topMargin: Theme.dp(12)
        anchors.left: parent.left
        anchors.right: parent.right
        height: Theme.dp(26)
        visible: strip.count > 0

        Row {
            anchors.centerIn: parent
            spacing: Theme.dp(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    var i = strip.hoveredIndex >= 0 ? strip.hoveredIndex : strip.currentIndex;
                    var item = (strip.model && i >= 0 && i < strip.count) ? strip.model.get(i) : null;
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
                text: strip.count > 0 ? ((strip.hoveredIndex >= 0 ? strip.hoveredIndex : strip.currentIndex) + 1) + " / " + strip.count : ""
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
        visible: strip.count === 0

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
