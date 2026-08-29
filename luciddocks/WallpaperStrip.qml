import QtQuick
import Quickshell.Widgets
import qs

Item {
    id: strip

    property var model: null
    property int heroW: 340
    property int heroH: 211
    property int midW: 238
    property int midH: 148
    property int smallW: 150
    property int smallH: 93
    property int itemGap: 10
    property int hoveredIndex: -1
    readonly property int hoverGrow: 6
    property alias currentIndex: view.currentIndex
    // the wallpaper actually in use
    property string appliedPath: ""
    property real stableHeight: height
    readonly property real rowHeight: strip.heroH + 62

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
        height: strip.heroH + 24
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
                anchors.verticalCenterOffset: slot.hovered ? -4 : 0
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
                radius: slot.tier === 0 ? Theme.radiusXl : (slot.tier === 1 ? Theme.radiusLg : Theme.radiusMd)
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


                Image {
                    anchors.fill: parent
                    source: "file://" + slot.path
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: strip.heroW * 2
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

                Rectangle {
                    anchors.fill: parent
                    radius: card.radius
                    color: "transparent"
                    border.color: Theme.alpha(Theme.text, 0.55)
                    border.width: 2
                    opacity: (slot.hovered && !slot.isCurrent) ? 1 : 0
                    visible: opacity > 0.01

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
                anchors.margins: 10
                width: 24
                height: 24
                radius: 12
                color: Theme.accent
                opacity: slot.isApplied ? 1 : 0
                visible: opacity > 0.01

                DockGlyph {
                    anchors.centerIn: parent
                    width: 15
                    height: 15
                    pathData: DockIcons.check
                    glyphColor: Theme.onAccent
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
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26
        visible: view.visible

        Row {
            anchors.centerIn: parent
            spacing: 10

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
                width: Math.min(implicitWidth, strip.width - 200)
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
        spacing: 10
        visible: !strip.model || strip.model.count === 0

        DockGlyph {
            width: 32
            height: 32
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.5
            pathData: DockIcons.brokenImage
            glyphColor: Theme.subtext
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No wallpapers in this theme's folder"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.weight: Font.Medium
        }

    }

}
