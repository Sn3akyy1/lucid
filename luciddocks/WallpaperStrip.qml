import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

Item {
    id: strip

    property var model: null
    property int heroW: Theme.dp(340)
    property int heroH: Theme.dp(211)
    property int midW: Theme.dp(238)
    property int midH: Theme.dp(148)
    property int smallW: Theme.dp(150)
    property int smallH: Theme.dp(93)
    property int itemGap: Theme.dp(10)
    property int hoveredIndex: -1
    readonly property int hoverGrow: Theme.dp(6)
    property alias currentIndex: view.currentIndex
    // the wallpaper actually in use
    property string appliedPath: ""
    property real stableHeight: height
    readonly property real rowHeight: strip.heroH + Theme.dp(62)
    // the hero card at the screen's own density: every tier is drawn from it
    readonly property size decodeSize: Qt.size(Math.ceil(strip.heroW * Math.max(1, Screen.devicePixelRatio)), Math.ceil(strip.heroH * Math.max(1, Screen.devicePixelRatio)))

    property int previewInterval: 300
    property string pendingPreviewPath: ""
    property bool syncing: false
    property int pendingCenterIndex: -1

    signal chosen(string path)
    signal previewed(string path)

    function activateCurrent() {
        if (view.currentIndex < 0 || !strip.model)
            return;

        var item = strip.model.get(view.currentIndex);
        if (item)
            strip.chosen(item.path);

    }

    function setIndexImmediate(i) {
        strip.syncing = true;
        previewThrottle.stop();
        strip.pendingPreviewPath = "";
        view.highlightMoveDuration = 0;
        view.currentIndex = i;
        strip.pendingCenterIndex = i;
        Qt.callLater(strip.centerPending);
        restoreAnim.restart();
    }

    // deferred — straight from a delegate handler this crashes mid-incubation
    function relayout() {
        view.forceLayout();
    }

    function centerPending() {
        if (strip.pendingCenterIndex < 0)
            return;

        view.positionViewAtIndex(strip.pendingCenterIndex, ListView.Center);
        strip.pendingCenterIndex = -1;
    }

    function emitPreview() {
        if (strip.pendingPreviewPath === "")
            return;

        strip.previewed(strip.pendingPreviewPath);
        strip.pendingPreviewPath = "";
    }

    Timer {
        id: restoreAnim

        interval: 120
        onTriggered: {
            view.highlightMoveDuration = Theme.ms(260);
            strip.syncing = false;
        }
    }

    Timer {
        id: previewThrottle

        interval: strip.previewInterval
        onTriggered: strip.emitPreview()
    }

    ListView {
        id: view


        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - strip.rowHeight) / 2)
        height: strip.heroH + Theme.dp(24)
        orientation: ListView.Horizontal
        spacing: strip.itemGap
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        model: strip.model
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (view.width - strip.heroW) / 2
        preferredHighlightEnd: (view.width + strip.heroW) / 2
        highlightMoveDuration: Theme.ms(260)
        flickDeceleration: 3000
        visible: count > 0
        cacheBuffer: strip.heroW * 6

        onCurrentIndexChanged: {
            Qt.callLater(strip.relayout);
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

        delegate: Item {
            id: slot

            required property string path
            required property string name
            required property string thumb
            required property int index

            readonly property bool isCurrent: view.currentIndex === slot.index
            readonly property bool isApplied: strip.appliedPath !== "" && strip.appliedPath === slot.path
            readonly property bool hovered: cardHover.hovered && stripHover.hovered
            readonly property bool pressed: cardTap.pressed && slot.hovered

            onHoveredChanged: {
                if (slot.hovered)
                    strip.hoveredIndex = slot.index;
                else if (strip.hoveredIndex === slot.index)
                    strip.hoveredIndex = -1;

            }
            readonly property int tier: Math.min(2, Math.abs(slot.index - view.currentIndex))
            readonly property int targetW: slot.tier === 0 ? strip.heroW : (slot.tier === 1 ? strip.midW : strip.smallW)
            readonly property int targetH: slot.tier === 0 ? strip.heroH : (slot.tier === 1 ? strip.midH : strip.smallH)

            width: slot.targetW
            height: view.height

            onWidthChanged: Qt.callLater(strip.relayout)

            Behavior on width {
                NumberAnimation {
                    duration: Theme.ms(300)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.easeEmphasizedDecel
                }

            }

            ClippingRectangle {
                id: card

                anchors.centerIn: parent
                anchors.verticalCenterOffset: slot.hovered ? -Theme.dp(4) : 0
                scale: slot.pressed ? 1 - 4 / card.width : (slot.hovered ? 1 + strip.hoverGrow / card.width : 1)
                width: parent.width
                height: slot.targetH

                Behavior on anchors.verticalCenterOffset {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }
                radius: slot.tier === 0 ? Theme.shapeXlInc : (slot.tier === 1 ? Theme.shapeLgInc : Theme.shapeMd)
                color: Theme.bgTile
                opacity: (slot.tier === 0 || slot.hovered) ? 1 : (slot.tier === 1 ? 0.78 : 0.5)

                Behavior on height {
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


                // the small copy decodes in a millisecond, so it is read in step and
                // is up on the card's first frame; an original still waiting for
                // one stays off the gui thread
                Image {
                    anchors.fill: parent
                    source: "file://" + (slot.thumb !== "" ? slot.thumb : slot.path)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: slot.thumb === ""
                    cache: true
                    sourceSize: strip.decodeSize
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

            }

            Rectangle {
                anchors.right: card.right
                anchors.top: card.top
                anchors.margins: Theme.dp(10)
                width: Theme.dp(26)
                height: Theme.dp(26)
                radius: width / 2
                color: Theme.accent
                scale: slot.isApplied ? 1 : 0.4

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durFastSpatial
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveDefaultSpatial
                    }

                }
                opacity: slot.isApplied ? 1 : 0
                visible: opacity > 0.01

                DockGlyph {
                    anchors.centerIn: parent
                    width: Theme.dp(15)
                    height: Theme.dp(15)
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
                id: cardHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                id: cardTap

                onTapped: {
                    if (slot.isCurrent)
                        strip.chosen(slot.path);
                    else
                        view.currentIndex = slot.index;
                }
            }

        }

    }

    HoverHandler {
        id: stripHover
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
            id: capRow

            readonly property int at: strip.hoveredIndex >= 0 ? strip.hoveredIndex : view.currentIndex
            readonly property var entry: strip.model && capRow.at >= 0 && capRow.at < strip.model.count ? strip.model.get(capRow.at) : null

            anchors.centerIn: parent
            spacing: Theme.dp(10)

            LText {
                id: capName

                anchors.verticalCenter: parent.verticalCenter
                role: "titleSmall"
                text: capRow.entry ? capRow.entry.name : ""
                color: Theme.text
                elide: Text.ElideRight
                width: Math.min(capMetrics.width + Theme.dp(2), Math.max(0, strip.width - Theme.dp(220)))

                TextMetrics {
                    id: capMetrics

                    font: capName.font
                    text: capName.text
                }

            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: appliedLabel.implicitWidth + Theme.dp(16)
                height: Theme.dp(22)
                radius: Theme.shapeFull
                color: Theme.accent
                visible: capRow.entry !== null && strip.appliedPath !== "" && strip.appliedPath === capRow.entry.path

                LText {
                    id: appliedLabel

                    anchors.centerIn: parent
                    role: "labelSmall"
                    text: "On the desktop"
                    color: Theme.fgAccent
                }

            }

            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "labelMedium"
                tabular: true
                text: strip.model && strip.model.count > 0 ? (capRow.at + 1) + " / " + strip.model.count : ""
                color: Theme.subtextDim
            }

        }

    }

    Column {
        id: emptyState

        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - emptyState.implicitHeight) / 2)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.dp(12)
        visible: !strip.model || strip.model.count === 0

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.dp(58)
            height: Theme.dp(58)
            radius: Theme.shapeXl
            color: Theme.withBlur(Theme.surfaceHigh)

            Icon {
                anchors.centerIn: parent
                name: "wallpaper"
                size: Theme.dp(28)
                color: Theme.primary
            }

        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "titleMedium"
            text: "No wallpapers in this folder"
            color: Theme.text
        }

        LText {
            anchors.horizontalCenter: parent.horizontalCenter
            role: "bodyMedium"
            text: "Drop images into the theme's wallpaper folder and they show up here."
            color: Theme.subtextDim
        }

    }

}
