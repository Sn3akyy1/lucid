import QtQuick
import qs
import qs.lucidui

// how full one volume is, and once it has been scanned, what with
Item {
    id: ov

    readonly property bool isGroupItem: true
    property bool groupFirst: true
    property bool groupLast: true
    property var pal: null
    property var vol: null
    property var scan: null
    property var drive: null
    readonly property bool scanning: ov.vol !== null && Storage.scanMount === ov.vol.mount
    readonly property real capacity: ov.vol ? ov.vol.used + ov.vol.avail : 0
    readonly property real usedFrac: ov.capacity > 0 ? ov.vol.used / ov.capacity : 0
    readonly property int outerRadius: Theme.rad(26)
    readonly property int innerRadius: Theme.dp(6)
    // { key, label, color, size }, in a fixed order so colours never swap places
    readonly property var segments: {
        if (!ov.scan || !ov.scan.cats || !ov.pal)
            return [];

        var out = [];
        var cats = ov.pal.cats;
        for (var i = 0; i < cats.length; i++) {
            var c = cats[i];
            var s = c.key === "hidden" ? (ov.scan.root === ov.scan.mount ? Math.max(0, ov.scan.used - ov.scan.scanned) : 0) : (ov.scan.cats[c.key] || 0);
            if (s > 0)
                out.push({
                "key": c.key,
                "label": c.label,
                "color": c.color,
                "size": s
            });

        }
        return out;
    }
    readonly property real segTotal: ov.segments.reduce((a, s) => {
        return a + s.size;
    }, 0)
    readonly property var legend: ov.segments.slice().sort((a, b) => {
        return b.size - a.size;
    })
    readonly property string driveLine: {
        if (!ov.vol)
            return "";

        var bits = [Storage.size(ov.vol.avail) + " free"];
        if (ov.drive && ov.drive.model)
            bits.push(ov.drive.model);

        bits.push(ov.vol.fstype);
        if (ov.drive && ov.drive.temp > 0)
            bits.push(Math.round(ov.drive.temp) + " °C");

        return bits.join("  ·  ");
    }

    implicitWidth: parent ? parent.width : Theme.dp(400)
    implicitHeight: col.implicitHeight + Theme.dp(44)

    Rectangle {
        anchors.fill: parent
        topLeftRadius: ov.groupFirst ? ov.outerRadius : ov.innerRadius
        topRightRadius: ov.groupFirst ? ov.outerRadius : ov.innerRadius
        bottomLeftRadius: ov.groupLast ? ov.outerRadius : ov.innerRadius
        bottomRightRadius: ov.groupLast ? ov.outerRadius : ov.innerRadius
        color: Theme.withBlur(Theme.bgTile)
    }

    Column {
        id: col

        x: Theme.dp(22)
        y: Theme.dp(22)
        width: parent.width - Theme.dp(44)
        spacing: Theme.dp(16)

        Item {
            width: parent.width
            height: Math.max(numbers.implicitHeight, pct.implicitHeight)

            Column {
                id: numbers

                anchors.left: parent.left
                anchors.right: pct.left
                anchors.rightMargin: Theme.dp(12)
                spacing: Theme.dp(4)

                Row {
                    spacing: Theme.dp(8)

                    Text {
                        id: usedText

                        text: ov.vol ? Storage.size(ov.vol.used) : "—"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontDisplaySm
                        font.variableAxes: Theme.axes(Theme.fontDisplaySm, 600, 0)
                        font.weight: Font.DemiBold
                    }

                    Text {
                        anchors.baseline: usedText.baseline
                        text: ov.vol ? "of " + Storage.size(ov.capacity) : ""
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                    }

                }

                Text {
                    width: parent.width
                    text: ov.driveLine
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    elide: Text.ElideRight
                }

            }

            Text {
                id: pct

                anchors.right: parent.right
                anchors.top: parent.top
                text: Math.round(ov.usedFrac * 100) + "%"
                color: ov.pal && ov.pal.low(ov.vol) ? Theme.error : Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadlineLg
                font.variableAxes: Theme.axes(Theme.fontHeadlineLg, 650, 0)
                font.weight: Font.Bold
            }

        }

        // used space split by what it is; before a scan it is one block
        Item {
            id: bar

            width: parent.width
            height: Theme.dp(22)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.bgSunken
            }

            Row {
                id: segRow

                readonly property real usedW: bar.width * ov.usedFrac

                height: parent.height
                spacing: 0
                visible: ov.segments.length > 0

                Repeater {
                    model: ov.segments

                    Item {
                        id: seg

                        required property var modelData
                        required property int index

                        width: ov.segTotal > 0 ? segRow.usedW * seg.modelData.size / ov.segTotal : 0
                        height: segRow.height

                        Rectangle {
                            anchors.fill: parent
                            anchors.rightMargin: seg.width > Theme.dp(4) ? Theme.dp(2) : 0
                            topLeftRadius: seg.index === 0 ? height / 2 : Theme.dp(3)
                            bottomLeftRadius: topLeftRadius
                            topRightRadius: Theme.dp(3)
                            bottomRightRadius: Theme.dp(3)
                            color: seg.modelData.color
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durMedium
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Theme.curveStandard
                            }

                        }

                    }

                }

            }

            Rectangle {
                width: bar.width * ov.usedFrac
                height: parent.height
                radius: height / 2
                visible: ov.segments.length === 0
                color: ov.pal && ov.pal.low(ov.vol) ? Theme.error : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveStandard
                    }

                }

            }

        }

        Flow {
            width: parent.width
            spacing: Theme.dp(8)
            visible: ov.legend.length > 0

            Repeater {
                model: ov.legend

                Rectangle {
                    id: key

                    required property var modelData

                    width: chip.implicitWidth + Theme.dp(24)
                    height: Theme.dp(32)
                    radius: height / 2
                    color: Theme.bgSunken

                    Row {
                        id: chip

                        anchors.centerIn: parent
                        spacing: Theme.dp(7)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.dp(10)
                            height: Theme.dp(10)
                            radius: width / 2
                            color: key.modelData.color
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: key.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Storage.size(key.modelData.size)
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                        }

                    }

                }

            }

        }

        Item {
            width: parent.width
            height: Math.max(status.implicitHeight, statusBtn.height)

            Column {
                id: status

                anchors.left: parent.left
                anchors.right: statusBtn.left
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(8)

                LinearProgress {
                    width: parent.width
                    visible: ov.scanning
                    wavy: true
                    animated: ov.scanning
                    valueAnimated: true
                    value: ov.vol && ov.vol.used > 0 ? Math.min(0.98, Storage.scanBytes / ov.vol.used) : 0
                    color: Theme.accent
                    trackColor: Theme.bgSunken
                }

                Text {
                    width: parent.width
                    text: {
                        if (ov.scanning)
                            return Storage.scanFiles > 0 ? "Looking through " + Storage.scanFiles.toLocaleString(Qt.locale(), "f", 0) + " files, " + Storage.size(Storage.scanBytes) + " so far" : "Starting to look…";

                        if (Storage.scanError !== "" && !ov.scan)
                            return Storage.scanError;

                        if (!ov.scan)
                            return "Scan this drive to see what is filling it, folder by folder.";

                        var bits = ["Looked through " + ov.scan.files.toLocaleString(Qt.locale(), "f", 0) + " files " + (ov.pal ? ov.pal.ago(ov.scan.time) : "")];
                        if (ov.scan.root === ov.scan.mount && ov.scan.used > ov.scan.scanned)
                            bits.push(Storage.size(ov.scan.used - ov.scan.scanned) + " only the system can read");

                        return bits.join("  ·  ");
                    }
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodySm
                    wrapMode: Text.WordWrap
                }

            }

            M3Button {
                id: statusBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: ov.scanning ? "text" : (ov.scan ? "tonal" : "filled")
                text: ov.scanning ? "Stop" : (ov.scan ? "Scan again" : "Scan")
                iconPath: ov.scanning ? "close" : "refresh"
                enabled: ov.vol !== null && (ov.scanning || !Storage.scanning)
                onClicked: ov.scanning ? Storage.cancelScan() : Storage.scan(ov.vol.mount)
            }

        }

    }

}
