import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs

Item {
    id: strip

    property var model: null
    property int itemW: 280
    property int itemH: 175
    property alias currentIndex: view.currentIndex
    // settled height so the row doesn't re-center every frame while resizing
    property real stableHeight: height
    readonly property real rowHeight: itemH + 30

    // ---- preview debouncing ----
    // A matugen/pywal color-generation run reliably takes longer than a
    // short throttle window - so firing on a fixed cadence *during* a hold
    // (as a throttle does) still launches overlapping generation processes
    // that fight each other for CPU. That overlap, not the UI, is what was
    // actually causing the lag.
    //
    // This is a pure debounce instead: nothing fires while the selection is
    // still moving. Only once the scrub goes quiet for `previewInterval` ms
    // does a single generation run kick off, for whichever wallpaper the
    // strip is on at that moment. Visual scrubbing below is completely
    // unaffected - only the expensive backend call is gated.
    property int previewInterval: 300
    property string _pendingPreviewPath: ""

    signal chosen(string path)
    signal previewed(string path)

    function activateCurrent() {
        if (view.currentIndex < 0 || !strip.model)
            return ;

        var item = strip.model.get(view.currentIndex);
        if (item)
            strip.chosen(item.path);

    }

    function setIndexImmediate(i) {
        view.highlightMoveDuration = 0;
        view.currentIndex = i;
        view.positionViewAtIndex(i, ListView.Center);
        restoreAnim.restart();
    }

    function _emitPreview() {
        if (strip._pendingPreviewPath === "")
            return ;

        strip.previewed(strip._pendingPreviewPath);
        strip._pendingPreviewPath = "";
    }

    Timer {
        id: restoreAnim

        interval: 60
        onTriggered: view.highlightMoveDuration = 220
    }

    // fires once, `previewInterval` ms after the LAST index change - every
    // new step during a hold restarts it, so it never fires mid-scrub, only
    // after things go quiet
    Timer {
        id: previewThrottle

        interval: strip.previewInterval
        onTriggered: strip._emitPreview()
    }

    ListView {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - strip.rowHeight) / 2)
        height: strip.rowHeight
        orientation: ListView.Horizontal
        spacing: 16
        clip: true
        interactive: true
        boundsBehavior: Flickable.StopAtBounds
        model: strip.model
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - strip.itemW) / 2
        preferredHighlightEnd: (width + strip.itemW) / 2
        highlightMoveDuration: 220
        flickDeceleration: 3000
        visible: count > 0
        // adding or removing a wallpaper re-runs the whole scan, which is the
        // other way the cached positions go stale
        onCountChanged: view.forceLayout()
        // The delegate's width depends on isCurrent (the centred card is
        // wider), and ListView caches item positions - so when the selection
        // moves, the neighbours keep the positions computed for the previous
        // widths and the cards visibly overlap. forceLayout is the documented
        // answer for a delegate that changes size after creation.
        //
        // The visual step here (forceLayout + highlight slide) always runs
        // immediately, every time - that's what keeps arrow-key scrubbing
        // feeling instant. Only the expensive `previewed` emission below is
        // throttled.
        onCurrentIndexChanged: {
            view.forceLayout();
            if (currentIndex < 0 || !strip.model)
                return ;

            var item = strip.model.get(currentIndex);
            if (!item)
                return ;

            // every step - fast or slow - just restarts the quiet-period
            // timer. A single deliberate tap ends up with a ~300ms delay
            // before colors update; a long hold generates colors exactly
            // once, for the wallpaper you land on, with zero overlap.
            strip._pendingPreviewPath = item.path;
            previewThrottle.restart();
        }

        add: Transition {
            NumberAnimation {
                properties: "scale"
                from: 0.6
                duration: Theme.ms(260)
                easing.type: Easing.OutBack
                easing.overshoot: 1.8
            }

            NumberAnimation {
                properties: "opacity"
                from: 0
                duration: Theme.ms(200)
            }

        }

        delegate: Item {
            id: wallCard

            required property string path
            required property string name
            required property int index
            property bool isCurrent: view.currentIndex === index
            // shrink the actual layout width (not just scale) so neighbors
            // sit closer to center instead of landing past the viewport edge
            readonly property real cardW: isCurrent ? strip.itemW : strip.itemW * 0.78
            readonly property real cardH: isCurrent ? strip.itemH : strip.itemH * 0.78

            width: cardW
            height: view.height
            opacity: isCurrent ? 1 : 0.4
            // This card's width is animated (see Behavior on width below), and
            // ListView positions its items from the widths it reads at layout
            // time without re-reading them as they animate. Left alone, the
            // neighbours end up placed for a width the current card no longer
            // has, and the cards overlap - permanently, once the animation
            // settles. Re-laying out on every frame of the animation is what
            // keeps the row honest; the list is short enough for that to cost
            // nothing.
            onWidthChanged: view.forceLayout()

            Column {
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    // the animation lives here rather than on the delegate:
                    // this is a visual size inside a slot whose own width is
                    // now instant, so ListView never has to lay out against a
                    // moving target
                    width: wallCard.cardW
                    height: wallCard.cardH
                    radius: 20

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.ms(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.ms(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    color: Theme.dockItem
                    clip: true
                    border.color: wallCard.isCurrent ? Theme.accent : "transparent"
                    border.width: 3

                    Image {
                        anchors.fill: parent
                        anchors.margins: 3
                        source: "file://" + wallCard.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: strip.itemW * 2
                        layer.enabled: true

                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: cardMask
                        }

                    }

                    Item {
                        id: cardMask

                        anchors.fill: parent
                        anchors.margins: 3
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: 17
                        }

                    }

                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: wallCard.cardW
                    text: wallCard.name
                    color: wallCard.isCurrent ? Theme.text : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    font.bold: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

            }

            TapHandler {
                onTapped: {
                    if (wallCard.isCurrent)
                        strip.chosen(wallCard.path);
                    else
                        view.currentIndex = wallCard.index;
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(200)
                }

            }

        }

    }

    Column {
        id: emptyWallpaperState

        anchors.top: parent.top
        anchors.topMargin: Math.max(0, (strip.stableHeight - emptyWallpaperState.implicitHeight) / 2)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        visible: !strip.model || strip.model.count === 0

        Shape {
            width: 34
            height: 34
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.5
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Theme.subtext
                strokeWidth: 0

                PathSvg {
                    path: "M21 5v6.59l-3-3.01-4 4.01-4-4-4 4-3-3.01V5c0-1.1.9-2 2-2h14c1.1 0 2 .9 2 2zm-3 6.42l3 3.01V19c0 1.1-.9 2-2 2H5c-1.1 0-2-.9-2-2v-6.58l3 2.99 4-4 4 4 4-3.99z"
                }

            }

            transform: Scale {
                xScale: 34 / 24
                yScale: 34 / 24
            }

        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No wallpapers here"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(11)
            font.bold: true
        }

    }

}
