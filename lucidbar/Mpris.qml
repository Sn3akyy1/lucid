import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    property var hostWindow: null
    property bool expanded: false
    // mirrors shell's own radius below - see the same note in Workspaces.qml
    readonly property int cornerRadius: root.expanded ? 20 : 60
    readonly property var mprisPlayers: Mpris.players.values
    readonly property var spotifyPlayer: {
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            const p = root.mprisPlayers[i];
            if (p.identity && p.identity.toLowerCase().indexOf("spotify") !== -1)
                return p;

        }
        return null;
    }
    readonly property var player: root.spotifyPlayer || (root.mprisPlayers.length > 0 ? root.mprisPlayers[0] : null)
    readonly property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    readonly property string title: player ? (player.trackTitle || "Unknown") : "Nothing playing"
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string displayTitle: (player && artist) ? artist + "  -  " + title : title
    readonly property real posSec: player ? player.position : 0
    readonly property real lenSec: player ? player.length : 0
    // interpolated between ticks so the wave doesn't jump-then-freeze
    property real livePosSec: posSec
    property double posTimestamp: Date.now()
    readonly property real progress: lenSec > 0 ? Math.min(1, livePosSec / lenSec) : 0
    // cava visualizer
    property var bars: []

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    onPosSecChanged: {
        posTimestamp = Date.now();
        livePosSec = posSec;
    }
    implicitWidth: expanded ? 360 : (compactRow.implicitWidth + 20)
    implicitHeight: expanded ? 155 : 35

    HyprlandFocusGrab {
        id: focusGrab

        active: root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: root.expanded = false
    }

    // live position ticker (mpris doesn't auto-tick position for you)
    Timer {
        interval: 1000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.player)
                root.player.positionChanged();

        }
    }

    // smooths the ticks above so the wave creeps instead of snapping
    Timer {
        interval: 33
        running: root.isPlaying && !trackHitArea.dragging
        repeat: true
        onTriggered: {
            root.livePosSec = Math.min(root.lenSec, root.posSec + (Date.now() - root.posTimestamp) / 1000);
        }
    }

    Process {
        id: cavaProc

        running: true
        command: ["cava", "-p", Quickshell.env('HOME') + "/.config/cava/quickshell.conf"]

        stdout: SplitParser {
            onRead: (line) => {
                root.bars = line.trim().split(" ").map((n) => {
                    return parseInt(n) || 0;
                });
            }
        }

    }

    Rectangle {
        id: shell

        anchors.fill: parent
        color: Theme.bg
        clip: true
        radius: root.expanded ? 20 : 60

        // COMPACT FACE
        Item {
            id: compactFace

            property bool hovered: false

            anchors.fill: parent
            opacity: root.expanded ? 0 : 1
            scale: root.expanded ? 0.94 : 1
            visible: opacity > 0.01

            // catches clicks not eaten by a button's own MouseArea
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: compactFace.hovered = true
                onExited: compactFace.hovered = false
                onClicked: root.expanded = true
            }

            Row {
                id: compactRow

                anchors.centerIn: parent
                spacing: 6

                // note icon
                Rectangle {
                    width: 18
                    height: 18
                    radius: 999
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        width: 24
                        height: 24
                        scale: 12 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.onAccent
                            strokeWidth: 0

                            PathSvg {
                                path: "M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6Z"
                            }

                        }

                    }

                }

                Item {
                    id: titleContainer

                    readonly property real segmentWidth: titleMeasure.implicitWidth
                    readonly property bool overflowing: segmentWidth > width
                    // 10 = resting indent, 0 = loop start, -segmentWidth = loop wrap
                    property real currentX: 10

                    function updateScroll() {
                        if (root.isPlaying && titleContainer.overflowing) {
                            loopAnim.stop();
                            entryAnim.restart();
                        } else {
                            entryAnim.stop();
                            loopAnim.stop();
                            titleContainer.currentX = 10;
                        }
                    }

                    width: 120
                    height: 16
                    clip: true
                    anchors.verticalCenter: parent.verticalCenter
                    onOverflowingChanged: updateScroll()
                    Component.onCompleted: updateScroll()
                    layer.enabled: titleContainer.overflowing

                    Text {
                        id: titleMeasure

                        visible: false
                        text: root.displayTitle + " • "
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: 13
                    }

                    Connections {
                        function onIsPlayingChanged() {
                            titleContainer.updateScroll();
                        }

                        target: root
                    }

                    SequentialAnimation {
                        id: entryAnim

                        NumberAnimation {
                            target: titleContainer
                            property: "currentX"
                            to: 0
                            duration: 380
                            easing.type: Easing.OutCubic
                        }

                        ScriptAction {
                            script: loopAnim.start()
                        }

                    }

                    NumberAnimation {
                        id: loopAnim

                        target: titleContainer
                        property: "currentX"
                        from: 0
                        to: -titleContainer.segmentWidth
                        duration: Math.max(4000, titleContainer.segmentWidth * 35)
                        loops: Animation.Infinite
                        running: false
                    }

                    Row {
                        id: marqueeRow

                        spacing: 0
                        x: titleContainer.currentX
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: root.displayTitle + " • "
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: 13
                        }

                        Text {
                            text: root.displayTitle + " • "
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: 13
                            visible: titleContainer.overflowing
                        }

                    }

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: edgeFadeMask
                    }

                    Behavior on currentX {
                        enabled: !entryAnim.running && !loopAnim.running

                        NumberAnimation {
                            duration: 380
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // mask for the fade above, kept as a sibling since a
                // layer.effect can't reference an id inside itself
                Item {
                    id: edgeFadeMask

                    x: titleContainer.x
                    y: titleContainer.y
                    width: titleContainer.width
                    height: titleContainer.height
                    visible: false
                    layer.enabled: true

                    Row {
                        anchors.fill: parent

                        Rectangle {
                            width: 14
                            height: parent.height

                            gradient: Gradient {
                                orientation: Gradient.Horizontal

                                GradientStop {
                                    position: 0
                                    color: "transparent"
                                }

                                GradientStop {
                                    position: 1
                                    color: "white"
                                }

                            }

                        }

                        Rectangle {
                            width: parent.width - 28
                            height: parent.height
                            color: "white"
                        }

                        Rectangle {
                            width: 14
                            height: parent.height

                            gradient: Gradient {
                                orientation: Gradient.Horizontal

                                GradientStop {
                                    position: 0
                                    color: "white"
                                }

                                GradientStop {
                                    position: 1
                                    color: "transparent"
                                }

                            }

                        }

                    }

                }

                // transport controls, right inside the pill
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: 13
                        height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: compactPrevArea.containsMouse ? 0.8 : 1

                        Shape {
                            width: 24
                            height: 24
                            scale: 13 / 24
                            anchors.centerIn: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: Theme.text
                                strokeWidth: 0

                                PathSvg {
                                    path: "M6 6h2v12H6V6Zm3.5 6 8.5-6v12l-8.5-6Z"
                                }

                            }

                        }

                        MouseArea {
                            id: compactPrevArea

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoPrevious)
                                    root.player.previous();

                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }

                        }

                    }

                    Rectangle {
                        width: 21.5
                        height: 21.5
                        radius: 999
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        Item {
                            width: 13
                            height: 13
                            anchors.centerIn: parent

                            Shape {
                                width: 24
                                height: 24
                                scale: 13 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.onAccent
                                    strokeWidth: 0

                                    PathSvg {
                                        path: root.isPlaying ? "M8 6h3v12H8V6Zm5 0h3v12h-3V6Z" : "M8 5v14l11-7L8 5Z"
                                    }

                                }

                            }

                        }

                        MouseArea {
                            id: compactPlayArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying)
                                    root.player.togglePlaying();

                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }

                        }

                    }

                    Item {
                        width: 13
                        height: 13
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: compactNextArea.containsMouse ? 0.8 : 1

                        Shape {
                            width: 24
                            height: 24
                            scale: 13 / 24
                            anchors.centerIn: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: Theme.text
                                strokeWidth: 0

                                PathSvg {
                                    path: "M18 6h-2v12h2V6Zm-3.5 6L6 6v12l8.5-6Z"
                                }

                            }

                        }

                        MouseArea {
                            id: compactNextArea

                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoNext)
                                    root.player.next();

                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }

                        }

                    }

                }

            }

            Rectangle {
                anchors.fill: parent
                radius: parent.parent.radius
                color: Theme.text
                opacity: compactFace.hovered ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

        }

        // EXPANDED FACE
        Row {
            id: expandedRow

            anchors.fill: parent
            anchors.margins: 14
            spacing: 14
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 1.04
            visible: opacity > 0.01

            Rectangle {
                id: artwork

                property bool hovered: false

                width: 90
                height: 90
                radius: 14
                color: Theme.withBlur(Theme.bgActive)
                clip: true

                Image {
                    id: artImage

                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }

                // fallback shown whenever there's no usable artwork, instead
                // of just leaving a blank dark square
                Item {
                    anchors.centerIn: parent
                    visible: !artImage.visible
                    width: 28
                    height: 28

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.bgHigh
                            strokeWidth: 0

                            PathSvg {
                                path: "M12 3v10.55A4 4 0 1 0 14 17V7h4V3h-6Z"
                            }

                        }

                    }

                }

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: artwork.hovered ? 0.25 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: artwork.hovered = true
                    onExited: artwork.hovered = false
                    onClicked: root.expanded = false
                }

            }

            Column {
                width: parent.width - 90 - 14
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    width: parent.width
                    text: root.displayTitle
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }

                // cava bars
                Row {
                    width: parent.width
                    height: 18
                    spacing: 2

                    Repeater {
                        model: 16

                        Rectangle {
                            required property int index

                            width: (parent.width - 15 * 2) / 16
                            height: Math.max(2, ((root.bars[index] || 0) / 20) * 18)
                            anchors.bottom: parent.bottom
                            radius: 1
                            color: Theme.accent

                            Behavior on height {
                                NumberAnimation {
                                    duration: 80
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                    }

                }

                Column {
                    width: parent.width
                    spacing: 4

                    Item {
                        id: trackHitArea

                        property bool hovering: false
                        property bool dragging: false
                        property real dragProgress: root.progress
                        readonly property real displayProgress: dragging ? dragProgress : root.progress
                        // room for the handle dot so it doesn't clip at the edge
                        readonly property real trackInset: 8

                        width: parent.width - 24
                        height: 18
                        anchors.horizontalCenter: parent.horizontalCenter

                        Canvas {
                            id: waveCanvas

                            // played portion is a wavy squiggle, rest is a straight line
                            property real animatedProgress: trackHitArea.displayProgress
                            property real lineThickness: trackHitArea.hovering || trackHitArea.dragging ? 3 : 2.5
                            property real handleRadius: trackHitArea.hovering || trackHitArea.dragging ? 7 : 6
                            // wave gets a bit more lively on hover/drag, purely as feedback
                            property real amplitude: trackHitArea.hovering || trackHitArea.dragging ? 6 : 4.5
                            readonly property real wavelength: 26

                            function smoothstep(t) {
                                t = Math.max(0, Math.min(1, t));
                                return t * t * (3 - 2 * t);
                            }

                            function envelope(x, inset, rampLen, handleX) {
                                const fromStart = smoothstep((x - inset) / rampLen);
                                const fromEnd = smoothstep((handleX - x) / rampLen);
                                return Math.min(fromStart, fromEnd);
                            }

                            anchors.fill: parent
                            antialiasing: true
                            onAnimatedProgressChanged: requestPaint()
                            onLineThicknessChanged: requestPaint()
                            onHandleRadiusChanged: requestPaint()
                            onAmplitudeChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                console.log("[mpris-wave] w=" + width + " h=" + height + " progress=" + animatedProgress + " accent=" + Theme.accent + " outlineStrong=" + Theme.outlineStrong);
                                const midY = height / 2;
                                const inset = trackHitArea.trackInset;
                                const usableWidth = width - inset * 2;
                                const handleX = inset + Math.max(0, Math.min(usableWidth, usableWidth * animatedProgress));
                                // eases amplitude in/out so both ends blend smoothly
                                const rampLen = wavelength * 1.4;
                                // skip near-zero paths, they render as a clipped sliver
                                if (handleX - inset > lineThickness) {
                                    ctx.strokeStyle = Theme.accent;
                                    ctx.lineWidth = lineThickness;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    for (let x = inset; x <= handleX; x++) {
                                        const y = midY + Math.sin((x / wavelength) * Math.PI * 2) * amplitude * envelope(x, inset, rampLen, handleX);
                                        if (x === inset)
                                            ctx.moveTo(x, y);
                                        else
                                            ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();
                                }
                                ctx.strokeStyle = Theme.outlineStrong;
                                ctx.lineWidth = lineThickness * 0.7;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                ctx.moveTo(handleX, midY);
                                ctx.lineTo(width - inset, midY);
                                ctx.stroke();
                                ctx.fillStyle = Theme.accent;
                                ctx.beginPath();
                                ctx.arc(handleX, midY, handleRadius, 0, Math.PI * 2);
                                ctx.fill();
                            }

                            Connections {
                                function onAccentChanged() {
                                    waveCanvas.requestPaint();
                                }

                                function onOutlineStrongChanged() {
                                    waveCanvas.requestPaint();
                                }

                                target: Theme
                            }

                            Behavior on animatedProgress {
                                enabled: !trackHitArea.dragging

                                NumberAnimation {
                                    duration: 80
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on lineThickness {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on handleRadius {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                            Behavior on amplitude {
                                NumberAnimation {
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: trackHitArea.hovering = true
                            onExited: trackHitArea.hovering = false
                            onPressed: (mouse) => {
                                trackHitArea.dragging = true;
                                trackHitArea.dragProgress = Math.max(0, Math.min(1, (mouse.x - trackHitArea.trackInset) / (width - trackHitArea.trackInset * 2)));
                            }
                            onPositionChanged: (mouse) => {
                                if (trackHitArea.dragging)
                                    trackHitArea.dragProgress = Math.max(0, Math.min(1, (mouse.x - trackHitArea.trackInset) / (width - trackHitArea.trackInset * 2)));

                            }
                            onReleased: (mouse) => {
                                if (root.player && root.player.canSeek)
                                    root.player.position = trackHitArea.dragProgress * root.lenSec;

                                trackHitArea.dragging = false;
                            }
                        }

                    }

                    Item {
                        width: trackHitArea.width
                        height: posLabel.implicitHeight
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            id: posLabel

                            anchors.left: parent.left
                            anchors.leftMargin: trackHitArea.trackInset
                            text: root.fmt(root.livePosSec)
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: trackHitArea.trackInset
                            text: root.fmt(root.lenSec)
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                        }

                    }

                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    // previous
                    Item {
                        id: prevBtn

                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        // separate layer so it fades independently of the icon
                        Rectangle {
                            anchors.fill: parent
                            radius: 999
                            color: Theme.text
                            opacity: prevArea.containsMouse ? 0.14 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent
                            scale: prevArea.pressed ? 0.88 : 1

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.text
                                    strokeWidth: 0

                                    PathSvg {
                                        path: "M6 6h2v12H6V6Zm3.5 6 8.5-6v12l-8.5-6Z"
                                    }

                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            id: prevArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoPrevious)
                                    root.player.previous();

                            }
                        }

                    }

                    // play / pause (primary action, a little bigger)
                    Rectangle {
                        id: playBtn

                        width: 34
                        height: 34
                        radius: 999
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.accent
                        scale: playArea.pressed ? 0.92 : (playArea.containsMouse ? 1.08 : 1)

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.onAccent
                                    strokeWidth: 0

                                    PathSvg {
                                        path: root.isPlaying ? "M8 6h3v12H8V6Zm5 0h3v12h-3V6Z" : "M8 5v14l11-7L8 5Z"
                                    }

                                }

                            }

                        }

                        MouseArea {
                            id: playArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying)
                                    root.player.togglePlaying();

                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    // next
                    Item {
                        id: nextBtn

                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            anchors.fill: parent
                            radius: 999
                            color: Theme.text
                            opacity: nextArea.containsMouse ? 0.14 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        Item {
                            width: 17
                            height: 17
                            anchors.centerIn: parent
                            scale: nextArea.pressed ? 0.88 : 1

                            Shape {
                                width: 24
                                height: 24
                                scale: 17 / 24
                                anchors.centerIn: parent
                                preferredRendererType: Shape.CurveRenderer

                                ShapePath {
                                    fillColor: Theme.text
                                    strokeWidth: 0

                                    PathSvg {
                                        path: "M18 6h-2v12h2V6Zm-3.5 6L6 6v12l8.5-6Z"
                                    }

                                }

                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            id: nextArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player && root.player.canGoNext)
                                    root.player.next();

                            }
                        }

                    }

                }

            }

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }

    }

}
