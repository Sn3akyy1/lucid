import QtQuick
import Quickshell.Widgets
import qs

// the README's screenshots, one after another while the installer works. each
// one hands its strongest colour to `seed`, so the window takes its accent from
// the picture on show the way the shell takes it from a wallpaper
Item {
    id: tour

    readonly property var slides: [{
        "file": "desktop",
        "title": "Your desktop",
        "blurb": "The bar along the top, widgets on the desktop and the dock below"
    }, {
        "file": "control-centre",
        "title": "Control centre",
        "blurb": "Sliders, toggles and what is playing, laid out the way you want"
    }, {
        "file": "launcher-wallpapers",
        "title": "Launcher",
        "blurb": "Apps, commands, emoji and wallpapers from one place"
    }, {
        "file": "widget-panel",
        "title": "Widgets",
        "blurb": "Clocks, weather, calendars and more, dropped onto the desktop"
    }, {
        "file": "clock-app",
        "title": "Clock",
        "blurb": "Alarms, timers and world clocks, beside the widgets"
    }, {
        "file": "lock-screen",
        "title": "Lock screen",
        "blurb": "The weather, a big clock, your music and notifications"
    }, {
        "file": "screenshot-toolbar",
        "title": "Screenshots",
        "blurb": "Photos, recordings, text and colours from any part of the screen"
    }, {
        "file": "settings-sound",
        "title": "Settings",
        "blurb": "Everything in one window, with a page for each part of the system"
    }, {
        "file": "light-mode",
        "title": "Light mode",
        "blurb": "Every colour follows your wallpaper, dark or light"
    }]
    property int index: 0
    // the caption and the gap above it: the window sizes the picture round it
    readonly property real footHeight: caption.implicitHeight + Theme.dp(20)
    // the default palette's primary until the first picture is read
    property color seed: "#a8c7fa"

    function source(i) {
        return Qt.resolvedUrl("../../assets/" + tour.slides[i].file + ".webp");
    }

    function go(i) {
        tour.index = (i + tour.slides.length) % tour.slides.length;
        advance.restart();
    }

    // the most colourful hue, weighted by how vivid each pixel is. near-greys
    // and near-blacks carry no accent, so they are left out of the vote
    function pick(d) {
        var bins = [];
        for (var b = 0; b < 36; b++) bins.push({
            "w": 0,
            "r": 0,
            "g": 0,
            "b": 0
        })
        for (var i = 0; i < d.length; i += 4) {
            var r = d[i] / 255, g = d[i + 1] / 255, bl = d[i + 2] / 255;
            var hi = Math.max(r, g, bl), lo = Math.min(r, g, bl);
            var s = hi > 0 ? (hi - lo) / hi : 0;
            if (hi < 0.2 || s < 0.25)
                continue;

            var h = hi === r ? ((g - bl) / (hi - lo) + 6) % 6 : hi === g ? (bl - r) / (hi - lo) + 2 : (r - g) / (hi - lo) + 4;
            var bin = bins[Math.floor(h * 6) % 36];
            var w = s * s * hi;
            bin.w += w;
            bin.r += r * w;
            bin.g += g * w;
            bin.b += bl * w;
        }
        // a hue and its neighbours vote together, so a gradient is not split three ways
        var best = -1, score = 0;
        for (var k = 0; k < 36; k++) {
            var v = bins[(k + 35) % 36].w + bins[k].w * 2 + bins[(k + 1) % 36].w;
            if (v > score) {
                score = v;
                best = k;
            }
        }
        if (best < 0 || bins[best].w <= 0)
            return null;

        var c = Qt.rgba(bins[best].r / bins[best].w, bins[best].g / bins[best].w, bins[best].b / bins[best].w, 1);
        // the tones come from Theme; only make sure there is a hue to carry
        return Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.6), 0.5, 1);
    }

    Timer {
        id: advance

        interval: 7000
        repeat: true
        running: tour.visible
        onTriggered: tour.index = (tour.index + 1) % tour.slides.length
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(20)

        // the screenshots are 16:9, so nothing of the shell is cropped away
        ClippingRectangle {
            width: parent.width
            height: Math.round(width * 9 / 16)
            radius: Theme.shapeXl
            color: Theme.bgSunken

            // reads the picture on show, small, behind the pictures themselves
            Canvas {
                id: probe

                readonly property url src: tour.source(tour.index)

                width: 48
                height: 27
                renderStrategy: Canvas.Immediate
                onSrcChanged: {
                    if (probe.isImageLoaded(probe.src))
                        probe.requestPaint();
                    else
                        probe.loadImage(probe.src);
                }
                onImageLoaded: probe.requestPaint()
                Component.onCompleted: probe.loadImage(probe.src)
                onPaint: {
                    if (!probe.isImageLoaded(probe.src))
                        return ;

                    var ctx = probe.getContext("2d");
                    ctx.drawImage(probe.src, 0, 0, probe.width, probe.height);
                    var c = tour.pick(ctx.getImageData(0, 0, probe.width, probe.height).data);
                    if (c !== null)
                        tour.seed = c;

                }
            }

            Repeater {
                model: tour.slides.length

                Image {
                    required property int index

                    anchors.fill: parent
                    source: tour.source(index)
                    sourceSize.width: 1280
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: tour.index === index && status === Image.Ready ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durLong
                            easing.type: Theme.easeStandard
                        }

                    }

                }

            }

        }

        Item {
            width: parent.width
            height: caption.implicitHeight

            Column {
                id: caption

                anchors.left: parent.left
                anchors.right: dots.left
                anchors.leftMargin: Theme.dp(8)
                anchors.rightMargin: Theme.dp(16)
                spacing: Theme.dp(4)

                Text {
                    text: tour.slides[tour.index].title
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleLg
                    font.variableAxes: Theme.axes(Theme.fontTitleLg, 560, 0)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: tour.slides[tour.index].blurb
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                    elide: Text.ElideRight
                }

            }

            Row {
                id: dots

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                Repeater {
                    model: tour.slides.length

                    Rectangle {
                        required property int index
                        readonly property bool on: tour.index === index

                        width: on ? Theme.dp(22) : Theme.dp(8)
                        height: Theme.dp(8)
                        radius: height / 2
                        color: on ? Theme.accent : dotArea.containsMouse ? Theme.subtext : Theme.outline

                        MouseArea {
                            id: dotArea

                            anchors.fill: parent
                            anchors.margins: -Theme.dp(4)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: tour.go(parent.index)
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durShort
                                easing.type: Theme.easeStandard
                            }

                        }

                    }

                }

            }

        }

    }

}
