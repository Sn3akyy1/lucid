import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs
import qs.lucidlumen
import qs.lucidui

// the details beside the picture: what it is, where it lives, how it was taken,
// how its tones fall, and the colours it is made of
Rectangle {
    id: panel

    required property var win
    required property var app
    readonly property var cur: panel.win.current
    readonly property var info: panel.win.info
    readonly property var kept: panel.win.kept
    readonly property var ex: panel.info && panel.info.exif ? panel.info.exif : ({})
    readonly property real fullW: Theme.dp(308)

    function row(label, value) {
        return value ? {
            "label": label,
            "value": value
        } : null;
    }

    readonly property var fileRows: {
        var c = panel.cur, i = panel.info;
        if (!c)
            return [];

        if (i && i.video)
            return panel.videoRows(c, i);

        var mp = i && i.w ? (i.w * i.h / 1e+06) : 0;
        return [panel.row("Kind", (c.desc || c.mime || "Picture") + (i && i.frames > 1 ? ", " + i.frames + " frames" : "")), panel.row("Size", i && i.w ? i.w + " × " + i.h + " pixels" + (mp >= 0.1 ? " (" + (mp >= 10 ? Math.round(mp) : mp.toFixed(1)) + " MP)" : "") : ""), panel.row("File", panel.app.sizeText(c.size || 0)), panel.row("Modified", panel.app.dateText(c.mtime)), panel.row("Colour", i ? [i.depth && i.depth !== 8 ? i.depth + "-bit" : "", i.alpha ? "see-through" : "", i.profile || ""].filter(function(s) {
            return s !== "";
        }).join(", ") : "")].filter(function(r) {
            return r !== null;
        });
    }
    function videoRows(c, i) {
        var picture = [i.vcodec, i.fps ? Math.round(i.fps * 100) / 100 + " fps" : "", i.depth > 8 ? i.depth + "-bit" : "", i.hdr ? "HDR" : ""].filter(function(s) {
            return s;
        }).join(", ");
        var sound = !i.acodec ? "None" : [i.acodec, i.channels === 1 ? "mono" : i.channels === 2 ? "stereo" : i.channels ? i.channels + " channels" : "", i.arate ? i.arate / 1000 + " kHz" : ""].filter(function(s) {
            return s;
        }).join(", ");
        var rate = i.bitrate >= 1e+06 ? (i.bitrate / 1e+06).toFixed(1) + " Mb/s" : i.bitrate > 0 ? Math.round(i.bitrate / 1000) + " kb/s" : "";
        return [panel.row("Kind", c.desc || c.mime || "Video"), panel.row("Size", i.w ? i.w + " × " + i.h + " pixels" : ""), panel.row("Length", i.duration > 0 ? panel.app.timeText(i.duration * 1000) : ""), panel.row("Picture", picture), panel.row("Sound", sound), panel.row("Bit rate", rate), panel.row("File", panel.app.sizeText(c.size || 0)), panel.row("Modified", panel.app.dateText(c.mtime))].filter(function(r) {
            return r !== null;
        });
    }

    readonly property var cameraRows: {
        var e = panel.ex;
        var shot = [e.aperture, e.shutter, e.iso, e.bias].filter(function(s) {
            return s;
        }).join("  ·  ");
        return [panel.row("Taken", e.taken ? panel.app.takenText(e.taken) : ""), panel.row("Camera", e.camera), panel.row("Lens", e.lens), panel.row("Exposure", shot), panel.row("Focal length", e.focal), panel.row("Flash", e.flash), panel.row("Software", e.software), panel.row("By", e.artist), panel.row("Caption", e.caption), panel.row("Copyright", e.copyright)].filter(function(r) {
            return r !== null;
        });
    }

    color: Theme.withBlur(Theme.bgSunken)
    radius: Theme.shapeXl
    clip: true

    Flickable {
        id: flick

        // the sheet keeps its width while the panel opens, and slides in
        x: panel.width - panel.fullW
        width: panel.fullW
        height: parent.height
        contentHeight: body.implicitHeight + Theme.dp(40)
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: body

            x: Theme.dp(20)
            y: Theme.dp(20)
            width: flick.width - Theme.dp(40)
            spacing: Theme.dp(18)

            Column {
                width: parent.width
                spacing: Theme.dp(4)

                LText {
                    width: parent.width
                    role: "titleLarge"
                    text: panel.cur ? panel.cur.name : ""
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                // the folder it lives in; a click opens it in lumen
                Row {
                    spacing: Theme.dp(6)
                    visible: panel.cur !== null && !panel.win.pasted

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "folder_open"
                        size: Theme.dp(16)
                        color: folderArea.containsMouse ? Theme.accent : Theme.subtext
                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, body.width - Theme.dp(24))
                        role: "bodyMedium"
                        text: panel.cur ? panel.app.placeOf(panel.app.parentOf(panel.cur.path)) : ""
                        color: folderArea.containsMouse ? Theme.accent : Theme.subtext
                        elide: Text.ElideMiddle

                        MouseArea {
                            id: folderArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: panel.win.reveal(panel.cur.path)
                        }

                    }

                }

            }

            // the picture as it was before lens first saved over it: held, it
            // stands in on the stage; it can be put back, or let go
            Column {
                width: parent.width
                spacing: Theme.dp(10)
                visible: panel.kept !== null

                LText {
                    role: "labelLarge"
                    color: Theme.accent
                    text: "Original"
                }

                Rectangle {
                    width: parent.width
                    height: Theme.dp(76)
                    radius: Theme.radiusMd
                    color: Theme.surfaceHigh

                    MouseArea {
                        id: keptArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: panel.win.holdingOriginal = true
                        onReleased: panel.win.holdingOriginal = false
                        onCanceled: panel.win.holdingOriginal = false
                    }

                    HoverLayer {
                        area: keptArea
                    }

                    Tip {
                        text: "Hold to compare"
                    }

                    ClippingRectangle {
                        id: keptThumb

                        x: Theme.dp(10)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(56)
                        height: Theme.dp(56)
                        radius: Theme.radiusSm
                        color: Theme.surfaceHighest

                        Image {
                            anchors.fill: parent
                            source: panel.kept && panel.kept.thumb ? "file://" + panel.kept.thumb : ""
                            sourceSize: Qt.size(Theme.dp(112), Theme.dp(112))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                        }

                    }

                    Column {
                        anchors.left: keptThumb.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.right: dropBtn.left
                        anchors.rightMargin: Theme.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        LText {
                            width: parent.width
                            role: "titleSmall"
                            text: "Before your edits"
                            elide: Text.ElideRight
                        }

                        LText {
                            width: parent.width
                            role: "bodySmall"
                            color: Theme.subtext
                            text: panel.kept ? "Kept " + panel.app.whenText(panel.kept.at) : ""
                            elide: Text.ElideRight
                        }

                        LText {
                            width: parent.width
                            role: "bodySmall"
                            color: Theme.subtext
                            tabular: true
                            text: !panel.kept ? "" : (panel.kept.w ? panel.kept.w + " × " + panel.kept.h + "  ·  " : "") + panel.app.sizeText(panel.kept.size || 0)
                            elide: Text.ElideRight
                        }

                    }

                    IconButton {
                        id: dropBtn

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "delete"
                        tooltip: "Delete the original"

                        Tip {
                        }

                        onClicked: panel.win.dropOriginal()
                    }

                }

                Button {
                    variant: "tonal"
                    icon: "history"
                    text: "Revert to original"
                    disabled: panel.win.busy
                    onClicked: panel.win.revertOriginal()
                }

            }

            // how the tones fall, red, green and blue over one another
            Rectangle {
                width: parent.width
                height: Theme.dp(96)
                radius: Theme.radiusMd
                color: Theme.surfaceHigh
                visible: panel.info !== null && panel.info.histogram !== undefined

                Shape {
                    id: histo

                    readonly property var h: panel.info && panel.info.histogram ? panel.info.histogram : null

                    function path(bins) {
                        if (!bins)
                            return "";

                        var w = histo.width, hh = histo.height, n = bins.length;
                        var d = "M 0 " + hh;
                        for (var i = 0; i < n; i++) {
                            var x = i / (n - 1) * w;
                            d += " L " + x.toFixed(1) + " " + (hh - Math.min(1, bins[i]) * hh * 0.94).toFixed(1);
                        }
                        return d + " L " + w + " " + hh + " Z";
                    }

                    anchors.fill: parent
                    anchors.margins: Theme.dp(10)
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(1, 0.33, 0.33, 0.42)

                        PathSvg {
                            path: histo.h ? histo.path(histo.h.r) : ""
                        }

                    }

                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(0.35, 0.9, 0.4, 0.38)

                        PathSvg {
                            path: histo.h ? histo.path(histo.h.g) : ""
                        }

                    }

                    ShapePath {
                        strokeWidth: 0
                        strokeColor: "transparent"
                        fillColor: Qt.rgba(0.35, 0.55, 1, 0.42)

                        PathSvg {
                            path: histo.h ? histo.path(histo.h.b) : ""
                        }

                    }

                    ShapePath {
                        strokeWidth: Theme.dp(1.5)
                        strokeColor: Theme.alpha(Theme.text, 0.75)
                        fillColor: "transparent"
                        joinStyle: ShapePath.RoundJoin

                        PathSvg {
                            path: histo.h ? histo.path(histo.h.l) : ""
                        }

                    }

                }

            }

            Section {
                title: "File"
                rows: panel.fileRows
            }

            Section {
                title: "Camera"
                rows: panel.cameraRows
                visible: panel.cameraRows.length > 0
            }

            // where it was taken, and a map of it
            Column {
                width: parent.width
                spacing: Theme.dp(8)
                visible: panel.ex.gps !== undefined

                LText {
                    role: "labelLarge"
                    color: Theme.accent
                    text: "Place"
                }

                Rectangle {
                    width: parent.width
                    height: Theme.dp(52)
                    radius: Theme.radiusMd
                    color: Theme.surfaceHigh

                    Icon {
                        id: pin

                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.dp(14)
                        name: "location_on"
                        size: Theme.dp(22)
                        color: Theme.accent
                    }

                    LText {
                        anchors.left: pin.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.dp(12)
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyMedium"
                        tabular: true
                        text: panel.ex.gps ? panel.ex.gps.lat.toFixed(5) + ", " + panel.ex.gps.lon.toFixed(5) + (panel.ex.gps.alt !== null ? "  ·  " + panel.ex.gps.alt + " m" : "") : ""
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: mapArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://www.openstreetmap.org/?mlat=" + panel.ex.gps.lat + "&mlon=" + panel.ex.gps.lon + "#map=15/" + panel.ex.gps.lat + "/" + panel.ex.gps.lon)
                    }

                    HoverLayer {
                        area: mapArea
                    }

                }

            }

            // the colours it is made of, most first; a click copies one
            Column {
                width: parent.width
                spacing: Theme.dp(10)
                visible: panel.info !== null && (panel.info.palette || []).length > 0

                LText {
                    role: "labelLarge"
                    color: Theme.accent
                    text: "Colours"
                }

                Flow {
                    width: parent.width
                    spacing: Theme.dp(8)

                    Repeater {
                        model: panel.info ? panel.info.palette || [] : []

                        delegate: Item {
                            id: sw

                            required property var modelData

                            width: (body.width - Theme.dp(8)) / 2
                            height: Theme.dp(44)

                            Rectangle {
                                id: dot

                                anchors.verticalCenter: parent.verticalCenter
                                width: Theme.dp(36)
                                height: width
                                radius: width / 2
                                color: sw.modelData.hex
                                border.width: 1
                                border.color: Theme.alpha(Theme.text, 0.12)
                                scale: swArea.pressed ? 0.9 : swArea.containsMouse ? 1.08 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.durFastSpatial
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveFastSpatial
                                    }

                                }

                            }

                            LText {
                                anchors.left: dot.right
                                anchors.leftMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter
                                role: "labelMedium"
                                tabular: true
                                text: sw.modelData.hex.toUpperCase()
                                color: swArea.containsMouse ? Theme.text : Theme.subtext
                            }

                            MouseArea {
                                id: swArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", sw.modelData.hex]);
                                    panel.win.say("Copied " + sw.modelData.hex.toUpperCase());
                                }
                            }

                        }

                    }

                }

            }

            Flow {
                width: parent.width
                spacing: Theme.dp(8)

                Button {
                    variant: "tonal"
                    icon: "wallpaper"
                    text: "Set as wallpaper"
                    visible: panel.app.caps.wallpaper === true && panel.cur !== null && (!panel.cur.video || panel.app.liveKind(panel.cur.path))
                    onClicked: panel.win.setWallpaper()
                }

                Button {
                    variant: "outlined"
                    icon: "folder_open"
                    text: "Show in Lumen"
                    visible: (panel.app.caps.lumen || "") !== "" && !panel.win.pasted
                    onClicked: panel.win.reveal(panel.cur.path)
                }

            }

        }

    }

    component Section: Column {
        id: sec

        property string title: ""
        property var rows: []

        width: parent ? parent.width : 0
        spacing: Theme.dp(10)

        LText {
            role: "labelLarge"
            color: Theme.accent
            text: sec.title
        }

        Repeater {
            model: sec.rows

            delegate: Row {
                required property var modelData

                width: sec.width
                spacing: Theme.dp(12)

                LText {
                    width: Theme.dp(92)
                    role: "bodyMedium"
                    text: modelData.label
                    color: Theme.subtext
                }

                LText {
                    width: parent.width - Theme.dp(104)
                    role: "bodyMedium"
                    text: modelData.value
                    color: Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

            }

        }

    }

}
