import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs
import qs.lucidui

// space on an icon: the file, large, grown out of the icon it came from and
// shrunk back into it. pictures whole, text its first page, a folder what it
// holds, anything else its icon and what there is to know
Item {
    id: ql

    readonly property var item: DesktopIcons.byKey[DesktopIcons.lookKey] || null
    // held through the closing animation, so the card shrinks back with its content
    property var shown: null
    readonly property var spot: ql.shown ? (DesktopIcons.placed[ql.shown.key] || null) : null
    // 0 folded into its icon, 1 open
    property real t: 0
    readonly property bool isDir: ql.shown !== null && ql.shown.kind === "dir"
    readonly property bool isPicture: ql.shown !== null && ql.shown.mime.indexOf("image/") === 0
    readonly property bool isImage: ql.shown !== null && ((ql.isPicture && ql.shown.size < 60000000) || ql.shown.thumb !== "")
    readonly property bool isText: ql.shown !== null && !ql.isImage && !ql.isDir && ql.shown.size < 2000000 && (ql.shown.mime.indexOf("text/") === 0 || /json|xml|javascript|x-shellscript|toml|yaml|x-desktop|x-python|x-sql/.test(ql.shown.mime))
    readonly property bool isVideo: ql.shown !== null && ql.shown.mime.indexOf("video/") === 0
    readonly property bool isMedia: ql.isVideo || (ql.shown !== null && ql.shown.mime.indexOf("audio/") === 0)
    // playing, and its first frame is up
    readonly property bool framed: mediaLoader.item !== null && mediaLoader.item.ready
    readonly property var peek: ql.isDir ? DesktopIcons.peeks[ql.shown.path] : undefined
    property string body: ""
    // where the icon is, and where the card goes
    readonly property rect from: ql.spot ? Qt.rect(DesktopIcons.tileX(ql.spot.c) + (DesktopIcons.tileW - DesktopIcons.iconPx) / 2, DesktopIcons.tileY(ql.spot.r) + DesktopIcons.iconTop, DesktopIcons.iconPx, DesktopIcons.iconPx) : Qt.rect(ql.width / 2, ql.height / 2, 0, 0)
    readonly property real cardW: Math.round(Math.min(ql.width * 0.62, Theme.dp(1000)))
    readonly property real cardH: Math.round(Math.min(ql.height * 0.76, Theme.dp(780)))
    readonly property rect to: Qt.rect(Math.round((ql.width - ql.cardW) / 2), Math.round((ql.height - ql.cardH) / 2), ql.cardW, ql.cardH)
    readonly property string detail: {
        var s = ql.shown;
        if (!s)
            return "";

        var parts = [];
        if (ql.isDir)
            parts.push(ql.peek ? (ql.peek.count === 1 ? I18n.tr("1 item") : I18n.tr("%1 items", ql.peek.count)) : I18n.tr("Folder"));
        else
            parts.push(s.desc, DesktopIcons.human(s.size));
        if (s.mtime)
            parts.push(DesktopIcons.when(s.mtime));

        return parts.filter((x) => {
            return x;
        }).join("  ·  ");
    }

    // shrunk all the way back: the loader can let go
    signal closed()

    function lerp(a, b) {
        return a + (b - a) * ql.t;
    }

    function take() {
        if (ql.item) {
            ql.shown = ql.item;
            ql.body = "";
            if (ql.isText) {
                reader.running = false;
                reader.command = ["head", "-c", "24000", "--", ql.item.path];
                reader.running = true;
            }
            if (ql.isDir)
                DesktopIcons.peek(ql.item.path);

            closing.stop();
            if (ql.t < 1)
                opening.restart();

        } else {
            opening.stop();
            closing.restart();
        }
    }

    anchors.fill: parent
    visible: ql.t > 0.001
    onItemChanged: ql.take()
    Component.onCompleted: ql.take()

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
        duration: Theme.durEnter + 60
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedDecel
    }

    NumberAnimation {
        id: closing

        target: ql
        property: "t"
        to: 0
        duration: Theme.durExit + 40
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.easeEmphasizedAccel
        onFinished: {
            ql.shown = null;
            ql.closed();
        }
    }

    // the desktop dims behind it; a click there puts it away
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.5 * ql.t)

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
        radius: ql.lerp(Theme.radiusSm, Theme.radiusXl)
        color: Theme.surfaceHigh
        clip: true
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 1
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowVerticalOffset: Theme.dp(8)
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
            id: header

            width: card.width
            height: Theme.dp(68)
            opacity: Math.max(0, (ql.t - 0.4) / 0.6)

            Image {
                id: headIcon

                x: Theme.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(32)
                height: Theme.dp(32)
                source: ql.shown && ql.shown.icon ? "file://" + ql.shown.icon : ""
                sourceSize.width: Math.round(width * DesktopIcons.dpr)
                sourceSize.height: Math.round(height * DesktopIcons.dpr)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Column {
                anchors.left: headIcon.right
                anchors.right: buttons.left
                anchors.leftMargin: Theme.dp(14)
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(1)

                Text {
                    width: parent.width
                    text: ql.shown ? ql.shown.label : ""
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.weight: Font.DemiBold
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: ql.detail
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelMd
                    elide: Text.ElideRight
                }

            }

            Row {
                id: buttons

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(6)

                Button {
                    anchors.verticalCenter: parent.verticalCenter
                    variant: "tonal"
                    text: I18n.tr("Open")
                    icon: "open_in_new"
                    onClicked: {
                        DesktopIcons.openSelection();
                        DesktopIcons.closeLook();
                    }
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "close"
                    onClicked: DesktopIcons.closeLook()
                }

            }

        }

        Item {
            id: stage

            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.leftMargin: Theme.dp(16)
            anchors.rightMargin: Theme.dp(16)
            opacity: Math.max(0, (ql.t - 0.35) / 0.65)

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusLg
                color: ql.isVideo && mediaLoader.active ? "#000000" : Theme.surfaceHighest
                visible: !ql.isImage || (ql.isVideo && mediaLoader.active)
            }

            Image {
                id: picture

                anchors.fill: parent
                visible: ql.isImage && !ql.framed
                source: !ql.shown || !ql.isImage ? "" : (ql.isPicture && ql.shown.size < 60000000 ? ql.shown.uri : "file://" + ql.shown.thumb)
                sourceSize.width: Math.round(ql.cardW * DesktopIcons.dpr)
                sourceSize.height: Math.round(ql.cardH * DesktopIcons.dpr)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                mipmap: true
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.dp(18)
                visible: ql.isText
                contentHeight: page.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    id: page

                    width: parent.width
                    text: ql.body
                    color: Theme.text
                    font.family: Prefs.envMonoFont !== "" ? Prefs.envMonoFont : "monospace"
                    font.pixelSize: Theme.fontBodyMd
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }

            }

            // a folder: what it holds, the way a file manager would show it
            Grid {
                id: contents

                readonly property real cell: Theme.dp(108)

                anchors.centerIn: parent
                visible: ql.isDir && ql.peek && ql.peek.items.length > 0
                columns: Math.max(1, Math.min(4, Math.floor((stage.width - Theme.dp(32)) / contents.cell)))
                spacing: Theme.dp(8)

                Repeater {
                    model: ql.isDir && ql.peek ? ql.peek.items : []

                    Column {
                        required property var modelData

                        width: contents.cell
                        spacing: Theme.dp(6)

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Theme.dp(48)
                            height: Theme.dp(48)
                            source: parent.modelData.thumb ? "file://" + parent.modelData.thumb : (parent.modelData.icon ? "file://" + parent.modelData.icon : "")
                            sourceSize.width: Math.round(width * DesktopIcons.dpr)
                            sourceSize.height: Math.round(height * DesktopIcons.dpr)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }

                        Text {
                            width: parent.width
                            text: parent.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelMd
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                    }

                }

            }

            Column {
                anchors.centerIn: parent
                visible: !ql.isImage && !ql.isText && !contents.visible && !ql.framed
                spacing: Theme.dp(14)

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(Math.min(stage.width, stage.height) * 0.36)
                    height: width
                    source: ql.shown && ql.shown.icon ? "file://" + ql.shown.icon : ""
                    sourceSize.width: Math.round(width * DesktopIcons.dpr)
                    sourceSize.height: Math.round(height * DesktopIcons.dpr)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: ql.isDir
                    text: ql.peek && ql.peek.count === 0 ? I18n.tr("This folder is empty") : ""
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                }

            }

            // a video or a song plays; gone the moment quick look starts closing, so the sound stops with it
            Loader {
                id: mediaLoader

                anchors.fill: parent
                active: ql.isMedia && ql.shown !== null && DesktopIcons.lookKey === ql.shown.key
                source: mediaLoader.active ? Qt.resolvedUrl("QuickLookMedia.qml") : ""
                onLoaded: {
                    mediaLoader.item.video = ql.isVideo;
                    mediaLoader.item.source = ql.shown.uri;
                }
            }

        }

        // the keys that work here
        Row {
            id: footer

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: Theme.dp(46)
            spacing: Theme.dp(18)
            opacity: stage.opacity

            Repeater {
                model: [{
                    "icons": ["chevron_left", "chevron_right"],
                    "text": I18n.tr("Browse")
                }, {
                    "icons": [],
                    "key": I18n.tr("Enter"),
                    "text": I18n.tr("Open")
                }, {
                    "icons": [],
                    "key": I18n.tr("Space"),
                    "text": I18n.tr("Close")
                }]

                Row {
                    id: hintRow

                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(6)

                    Repeater {
                        model: hintRow.modelData.icons

                        Rectangle {
                            required property string modelData

                            width: Theme.dp(22)
                            height: Theme.dp(22)
                            radius: Theme.dp(6)
                            color: Theme.surfaceHighest

                            Icon {
                                anchors.centerIn: parent
                                size: Theme.dp(16)
                                name: parent.modelData
                                color: Theme.subtext
                            }

                        }

                    }

                    Rectangle {
                        visible: hintRow.modelData.key !== undefined
                        width: keyText.implicitWidth + Theme.dp(12)
                        height: Theme.dp(22)
                        radius: Theme.dp(6)
                        color: Theme.surfaceHighest

                        Text {
                            id: keyText

                            anchors.centerIn: parent
                            text: hintRow.modelData.key || ""
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelSm
                            font.weight: Font.Medium
                        }

                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hintRow.modelData.text
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelMd
                    }

                }

            }

        }

    }

}
