import "../luciddocks"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs

// Space on an icon: the file, large, grown out of the icon it came from and
// shrunk back into it. Pictures show whole, text shows its first page, the
// rest show their icon with what there is to know. The arrow keys walk the
// desktop, Enter opens, Space or Escape or a click outside puts it away
Item {
    id: ql

    readonly property var item: DesktopIcons.byKey[DesktopIcons.lookKey] || null
    // held through the closing animation, so the card shrinks back with its content
    property var shown: null
    readonly property var spot: ql.shown ? (DesktopIcons.placed[ql.shown.key] || null) : null
    // 0 = folded into its icon, 1 = open
    property real t: 0
    readonly property bool isImage: ql.shown !== null && (ql.shown.thumb !== "" || ql.shown.mime.indexOf("image/") === 0)
    readonly property bool isText: ql.shown !== null && !ql.isImage && ql.shown.size < 2000000 && (ql.shown.mime.indexOf("text/") === 0 || /json|xml|javascript|x-shellscript|toml|yaml|x-desktop/.test(ql.shown.mime))
    property string body: ""

    // where the icon is, and where the card goes
    readonly property rect from: ql.spot ? Qt.rect(DesktopIcons.tileX(ql.spot.c) + (DesktopIcons.tileW - DesktopIcons.iconPx) / 2, DesktopIcons.tileY(ql.spot.r) + 8, DesktopIcons.iconPx, DesktopIcons.iconPx) : Qt.rect(ql.width / 2, ql.height / 2, 0, 0)
    readonly property real cardW: Math.round(Math.min(ql.width * 0.6, 980))
    readonly property real cardH: Math.round(Math.min(ql.height * 0.74, 760))
    readonly property rect to: Qt.rect(Math.round((ql.width - ql.cardW) / 2), Math.round((ql.height - ql.cardH) / 2), ql.cardW, ql.cardH)

    function lerp(a, b) {
        return a + (b - a) * ql.t;
    }

    function human(n) {
        var u = ["B", "KB", "MB", "GB", "TB"];
        var i = 0;
        var v = n;
        while (v >= 1024 && i < u.length - 1) {
            v /= 1024;
            i++;
        }
        return (i === 0 ? v : v.toFixed(v < 10 ? 1 : 0)) + " " + u[i];
    }

    function when(secs) {
        if (!secs)
            return "";

        return Qt.formatDateTime(new Date(secs * 1000), "d MMM yyyy, hh:mm");
    }

    anchors.fill: parent
    visible: ql.t > 0.001
    onItemChanged: {
        if (ql.item) {
            ql.shown = ql.item;
            ql.body = "";
            if (ql.isText) {
                reader.command = ["head", "-c", "24000", "--", ql.item.path];
                reader.running = true;
            }
            closing.stop();
            if (ql.t < 1)
                opening.restart();

        } else {
            opening.stop();
            closing.restart();
        }
    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: ql.body = text
        }
    }

    NumberAnimation {
        id: opening

        target: ql
        property: "t"
        to: 1
        duration: Theme.durMedium + 80
        easing.type: Easing.OutBack
        easing.overshoot: 0.9
    }

    NumberAnimation {
        id: closing

        target: ql
        property: "t"
        to: 0
        duration: Theme.durMedium
        easing.type: Easing.InOutCubic
        onFinished: ql.shown = null
    }

    // the desktop dims behind it; a click there puts it away
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5 * ql.t)

        MouseArea {
            anchors.fill: parent
            enabled: DesktopIcons.lookKey !== ""
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: DesktopIcons.closeLook()
        }

    }

    Rectangle {
        id: card

        x: ql.lerp(ql.from.x, ql.to.x)
        y: ql.lerp(ql.from.y, ql.to.y)
        width: ql.lerp(ql.from.width, ql.to.width)
        height: ql.lerp(ql.from.height, ql.to.height)
        radius: Theme.radiusXl
        color: Theme.bgHigh
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowColor: Qt.rgba(0, 0, 0, 0.6)
            shadowVerticalOffset: Theme.dp(10)
        }

        // clicks on the card stay on the card
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onDoubleClicked: {
                DesktopIcons.openSelection();
                DesktopIcons.closeLook();
            }
        }

        Item {
            id: stage

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: Theme.dp(14)
            opacity: Math.max(0, (ql.t - 0.35) / 0.65)

            Image {
                anchors.fill: parent
                visible: ql.isImage
                source: ql.isImage && ql.shown ? (ql.shown.mime.indexOf("image/") === 0 ? ql.shown.uri : "file://" + ql.shown.thumb) : ""
                sourceSize.width: ql.cardW * 1.5
                sourceSize.height: ql.cardH * 1.5
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Flickable {
                anchors.fill: parent
                visible: ql.isText
                contentHeight: page.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: page

                    width: parent.width
                    text: ql.body
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }

            }

            Image {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.42
                height: width
                visible: !ql.isImage && !ql.isText
                source: {
                    void IconTheme.generation;
                    if (!ql.shown)
                        return "";

                    var names = ql.shown.icons;
                    for (var i = 0; i < names.length; i++) {
                        var p = IconTheme.resolve(names[i]);
                        if (p !== "")
                            return p;

                    }
                    return "";
                }
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

        }

        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Theme.dp(58)
            opacity: stage.opacity

            Column {
                anchors.left: parent.left
                anchors.right: hint.left
                anchors.leftMargin: Theme.dp(20)
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                Text {
                    width: parent.width
                    text: ql.shown ? ql.shown.label : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: ql.shown ? [ql.shown.kind === "dir" ? "Folder" : ql.human(ql.shown.size), ql.shown.mime, ql.when(ql.shown.mtime)].filter((x) => {
                        return x;
                    }).join("  ·  ") : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    elide: Text.ElideRight
                }

            }

            Text {
                id: hint

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                text: "←  →   ·   Enter opens   ·   Space closes"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
            }

        }

    }

}
