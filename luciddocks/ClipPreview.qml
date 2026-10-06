import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidui

// right-hand pane of the clipboard mode: the selected entry at full size
Item {
    id: preview

    // cliphist id of the selected row, or ""
    property string entryId: ""
    property bool clearArmed: false

    readonly property var entry: {
        void Clip.entries;
        return preview.entryId !== "" ? Clip.entry(preview.entryId) : null;
    }
    readonly property string kind: preview.entry ? preview.entry.kind : ""
    readonly property bool isTextual: preview.kind === "text" || preview.kind === "url" || preview.kind === "email"
    readonly property bool textReady: preview.entry !== null && Clip.textId === preview.entry.id && Clip.textReady
    readonly property string shownText: preview.textReady ? Clip.textBody : (preview.entry ? preview.entry.preview : "")
    readonly property string imageUrl: preview.kind === "image" ? (Clip.fulls[preview.entry.id] || "") : ""
    property string shownId: ""
    readonly property string metaLine: {
        const e = preview.entry;
        if (!e)
            return "";

        if (e.kind === "image")
            return e.meta;

        if (e.kind === "binary")
            return "Binary data · " + e.meta;

        if (e.kind === "color")
            return "Colour · " + e.preview.trim();

        const what = e.kind === "url" ? "Link" : (e.kind === "email" ? "Email address" : "Text");
        if (!preview.textReady)
            return what;

        const t = Clip.textBody;
        const lines = t.replace(/\n$/, "").split("\n").length;
        const more = Clip.textTruncated ? "+" : "";
        return what + " · " + lines + more + (lines === 1 && more === "" ? " line · " : " lines · ") + t.length + more + " characters";
    }

    onEntryChanged: {
        const e = preview.entry;
        if (!e) {
            preview.shownId = "";
            return ;
        }
        if (e.id !== preview.shownId) {
            preview.shownId = e.id;
            textScroll.contentY = 0;
        }
        // e.kind, not the derived properties: this handler can run before their bindings catch up
        if (e.kind === "image")
            Clip.requestFull(e.id);
        else if (e.kind === "text" || e.kind === "url" || e.kind === "email")
            Clip.loadText(e.id);
    }

    Rectangle {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.dp(10)
        radius: Theme.shapeXl
        color: Theme.withBlur(Theme.surfaceHigh)
        clip: true

        Item {
            id: frame

            // never blow a small image up past 2x
            readonly property real fit: preview.kind === "image" && preview.entry.width > 0 ? Math.min(frame.width / preview.entry.width, frame.height / preview.entry.height, 2) : 1

            anchors.fill: parent
            anchors.margins: Theme.dp(12)
            visible: preview.kind === "image"

            ClippingRectangle {
                anchors.centerIn: parent
                width: preview.kind === "image" ? Math.max(1, Math.round(preview.entry.width * frame.fit)) : 0
                height: preview.kind === "image" ? Math.max(1, Math.round(preview.entry.height * frame.fit)) : 0
                radius: Theme.shapeMd
                color: Theme.bgActive

                Image {
                    id: fullImage

                    anchors.fill: parent
                    source: preview.imageUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    // one decode size for every panel width, so the resize animation never reloads it
                    sourceSize.width: Theme.dp(720)
                    sourceSize.height: Theme.dp(720)
                    opacity: fullImage.status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

        Flickable {
            id: textScroll

            anchors.fill: parent
            anchors.margins: Theme.dp(14)
            visible: preview.isTextual
            clip: true
            contentWidth: textScroll.width
            contentHeight: bodyText.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: textScroll.contentHeight > textScroll.height

            Text {
                id: bodyText

                width: textScroll.width
                text: preview.shownText
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: preview.kind === "text" ? Theme.text : Theme.accent
                font.family: "monospace"
                font.pixelSize: Theme.typeSize("bodyMedium")
                lineHeight: 1.25
                opacity: preview.textReady ? 1 : 0.6
            }

        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.dp(12)
            visible: preview.kind === "color"
            radius: Theme.shapeLg
            color: preview.kind === "color" ? preview.entry.color : "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.12)

            Text {
                anchors.centerIn: parent
                text: preview.kind === "color" ? preview.entry.preview.trim() : ""
                color: preview.kind === "color" && preview.entry.darkColor ? "#ffffff" : "#000000"
                font.family: "monospace"
                font.pixelSize: Theme.typeSize("headlineSmall")
                font.weight: Font.DemiBold
            }

        }

        Column {
            id: holder

            readonly property bool imageBroken: preview.kind === "image" && (fullImage.status === Image.Error || Clip.fulls[preview.entry.id] === "")

            anchors.centerIn: parent
            spacing: Theme.dp(12)
            visible: preview.entry === null || preview.kind === "binary" || (preview.kind === "image" && fullImage.status !== Image.Ready)

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.dp(52)
                height: Theme.dp(52)
                radius: Theme.shapeLg
                color: Theme.withBlur(Theme.surfaceHighest)

                Icon {
                    anchors.centerIn: parent
                    name: preview.kind === "image" ? (holder.imageBroken ? "broken_image" : "wallpaper") : "content_paste"
                    size: Theme.dp(25)
                    color: Theme.primary
                }

            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "bodyMedium"
                text: preview.kind === "image" ? (holder.imageBroken ? "Couldn't load image" : "Loading image…") : (preview.kind === "binary" ? "No preview for binary data" : "Nothing selected")
                color: Theme.subtext
            }

        }

    }

    Column {
        id: footer

        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(4)
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(4)
        anchors.bottom: parent.bottom
        spacing: Theme.dp(7)

        LText {
            width: parent.width
            elide: Text.ElideRight
            role: "labelMedium"
            text: preview.metaLine
            color: Theme.subtext
        }

        LText {
            width: parent.width
            elide: Text.ElideRight
            role: "labelSmall"
            text: "Press Ctrl+Shift+Del again to clear everything"
            color: Theme.error
            visible: preview.clearArmed
        }

        Flow {
            width: parent.width
            spacing: Theme.dp(10)
            visible: !preview.clearArmed

            Repeater {
                // a key with a symbol of its own draws it in place of a legend
                model: [{
                    "symbol": "keyboard_return",
                    "key": "",
                    "label": "Copy"
                }, {
                    "key": "Del",
                    "label": "Delete"
                }, {
                    "key": "Ctrl+Shift+Del",
                    "label": "Clear"
                }]

                Row {
                    id: keyHint

                    required property var modelData

                    spacing: Theme.dp(5)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(Theme.dp(20), cap.implicitWidth + Theme.dp(10))
                        height: Theme.dp(20)
                        radius: Theme.shapeSm
                        color: Theme.alpha(Theme.text, 0.09)

                        LText {
                            id: cap

                            anchors.centerIn: parent
                            role: "labelSmall"
                            text: keyHint.modelData.key
                            color: Theme.subtext
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: !!keyHint.modelData.symbol
                            name: keyHint.modelData.symbol || ""
                            size: Theme.dp(14)
                            color: Theme.subtext
                        }

                    }

                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "labelSmall"
                        text: keyHint.modelData.label
                        color: Theme.subtextDim
                    }

                }

            }

        }

    }

}
