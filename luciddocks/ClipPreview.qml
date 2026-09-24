import QtQuick
import Quickshell.Widgets
import qs

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
        anchors.bottomMargin: 10
        radius: Theme.radiusLg
        color: Theme.withBlur(Theme.bgTile)
        clip: true

        Item {
            id: frame

            // never blow a small image up past 2x
            readonly property real fit: preview.kind === "image" && preview.entry.width > 0 ? Math.min(frame.width / preview.entry.width, frame.height / preview.entry.height, 2) : 1

            anchors.fill: parent
            anchors.margins: 12
            visible: preview.kind === "image"

            ClippingRectangle {
                anchors.centerIn: parent
                width: preview.kind === "image" ? Math.max(1, Math.round(preview.entry.width * frame.fit)) : 0
                height: preview.kind === "image" ? Math.max(1, Math.round(preview.entry.height * frame.fit)) : 0
                radius: Theme.radiusMd
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
                    sourceSize.width: 720
                    sourceSize.height: 720
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
            anchors.margins: 14
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
                font.pixelSize: Theme.fontBody
                lineHeight: 1.15
                opacity: preview.textReady ? 1 : 0.6
            }

        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            visible: preview.kind === "color"
            radius: Theme.radiusMd
            color: preview.kind === "color" ? preview.entry.color : "transparent"
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.12)

            Text {
                anchors.centerIn: parent
                text: preview.kind === "color" ? preview.entry.preview.trim() : ""
                color: preview.kind === "color" && preview.entry.darkColor ? "#ffffff" : "#000000"
                font.family: "monospace"
                font.pixelSize: Theme.fontTitleLg
                font.weight: Font.DemiBold
            }

        }

        Column {
            readonly property bool imageBroken: preview.kind === "image" && (fullImage.status === Image.Error || Clip.fulls[preview.entry.id] === "")

            anchors.centerIn: parent
            spacing: 10
            visible: preview.entry === null || preview.kind === "binary" || (preview.kind === "image" && fullImage.status !== Image.Ready)

            DockGlyph {
                width: 28
                height: 28
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: 0.5
                pathData: preview.kind === "image" ? (parent.imageBroken ? DockIcons.brokenImage : DockIcons.wallpaper) : DockIcons.clipboard
                glyphColor: Theme.subtext
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: preview.kind === "image" ? (parent.imageBroken ? "Couldn't load image" : "Loading image…") : (preview.kind === "binary" ? "No preview for binary data" : "Nothing selected")
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.weight: Font.Medium
            }

        }

    }

    Column {
        id: footer

        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        spacing: 3

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: preview.metaLine
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: preview.clearArmed ? "Press Ctrl+Shift+Del again to clear everything" : "↵ Copy   Del Delete   Ctrl⇧Del Clear all"
            color: preview.clearArmed ? Theme.error : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

}
