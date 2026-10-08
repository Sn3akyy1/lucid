import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.lucidui
import qs.lucidprefs as LP

// what this release brings, from Notes.qml. Settings → About opens it, and it
// opens by itself once, on the first start of a version it speaks for
PanelWindow {
    id: sheet

    property bool open: false
    readonly property var badges: ["cookie9", "sunny", "clover4", "gem", "pentagon", "puffy", "arch", "flower"]
    readonly property int pad: Theme.dp(28)
    // the settings panes' step, so a notch moves as far here as there
    readonly property int wheelStep: 190
    readonly property bool placeholders: notes.placeholders

    function show() {
        body.contentY = 0;
        sheet.open = true;
        mark.play();
        focusTimer.restart();
        if (notes.version === Updates.current)
            Updates.markSeen();

    }

    function hide() {
        sheet.open = false;
    }

    // a version's first start: once the session is unlocked and has settled
    function maybeAnnounce() {
        if (Updates.current === "" || notes.version !== Updates.current || Updates.seen === Updates.current || sheet.open)
            return ;

        if (Lockscreen.locked)
            return ;

        sheet.show();
    }

    color: "transparent"
    visible: sheet.open || card.opacity > 0.01
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: sheet.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucidwhatsnew"
    Component.onCompleted: firstStart.start()

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Notes {
        id: notes
    }

    FontMetrics {
        id: bodyMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.typeSize("bodyMedium")
    }

    Timer {
        id: firstStart

        interval: 4000
        onTriggered: sheet.maybeAnnounce()
    }

    Connections {
        function onLockedChanged() {
            if (!Lockscreen.locked)
                firstStart.restart();

        }

        target: Lockscreen
    }

    IpcHandler {
        target: "whatsnew"

        function open(): void {
            sheet.show();
        }

        function close(): void {
            sheet.hide();
        }

        // why it did or did not open by itself
        function status(): string {
            return "notes v" + notes.version + ", shell v" + Updates.current + ", seen v" + (Updates.seen || "none") + (Lockscreen.locked ? ", locked" : "") + (sheet.open ? ", open" : "");
        }

    }

    Connections {
        function onWhatsNewRequested() {
            sheet.show();
        }

        target: Updates
    }

    // the layer only takes the keyboard once it is mapped
    Timer {
        id: focusTimer

        interval: 40
        onTriggered: keys.forceActiveFocus()
    }

    Item {
        id: keys

        focus: true
        Keys.onEscapePressed: sheet.hide()
        Keys.onReturnPressed: sheet.hide()
        Keys.onUpPressed: body.flick(0, Theme.dp(1600))
        Keys.onDownPressed: body.flick(0, -Theme.dp(1600))
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.5)
        opacity: sheet.open ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.hide()
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(Theme.dp(720), sheet.width - Theme.dp(64))
        height: Math.min(Theme.dp(860), sheet.height - Theme.dp(64))
        radius: Theme.shapeXl
        color: Theme.bgOpaque
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.5)
        opacity: sheet.open ? 1 : 0
        scale: sheet.open ? 1 : 0.94
        clip: true

        // clicks on the card must not reach the dimmer
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            x: sheet.pad
            y: Theme.dp(24)
            width: parent.width - sheet.pad * 2
            height: Theme.dp(64)

            LP.LucidaMark {
                id: mark

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(52)
                height: Theme.dp(52)
                strokeWidth: 2.6
            }

            Column {
                anchors.left: mark.right
                anchors.leftMargin: Theme.dp(16)
                anchors.right: closeButton.left
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                LText {
                    role: "labelLarge"
                    color: Theme.accent
                    text: "What's new"
                }

                LText {
                    width: parent.width
                    role: "headlineSmall"
                    text: "Lucid v" + notes.version + (notes.name !== "" ? " · " + notes.name : "")
                    elide: Text.ElideRight
                }

                LText {
                    role: "bodyMedium"
                    color: Theme.subtext
                    text: notes.date
                }

            }

            IconButton {
                id: closeButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tooltip: "Close"
                onClicked: sheet.hide()
            }

        }

        Flickable {
            id: body

            anchors.top: header.bottom
            anchors.topMargin: Theme.dp(18)
            anchors.bottom: footer.top
            anchors.bottomMargin: Theme.dp(8)
            anchors.left: parent.left
            anchors.right: parent.right
            contentWidth: width
            contentHeight: content.implicitHeight + Theme.dp(12)
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000
            maximumFlickVelocity: 9000
            clip: true

            // a bare flickable moves 72px a notch; this eases the panes' 190
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    event.accepted = true;
                    var maxY = Math.max(0, body.contentHeight - body.height);
                    var base = bodyScroll.running ? bodyScroll.to : body.contentY;
                    var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * sheet.wheelStep));
                    if (target === base)
                        return ;

                    bodyScroll.stop();
                    bodyScroll.from = body.contentY;
                    bodyScroll.to = target;
                    bodyScroll.start();
                }
            }

            NumberAnimation {
                id: bodyScroll

                target: body
                property: "contentY"
                duration: Theme.ms(170)
                easing.type: Easing.OutCubic
            }

            // only while there is more than fits, the settings panes' handle
            QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: bodyBar

                // pinned to the list's right edge rather than left where the attachment puts it
                parent: body.parent
                anchors.top: body.top
                anchors.bottom: body.bottom
                anchors.right: body.right
                policy: body.contentHeight > body.height ? QQC.ScrollBar.AlwaysOn : QQC.ScrollBar.AlwaysOff
                // clear of the card's edge, the handle's own 5 to 8 inside it
                width: Theme.dp(16)
                rightPadding: Theme.dp(6)

                contentItem: Rectangle {
                    implicitWidth: bodyBar.hovered || bodyBar.pressed ? Theme.dp(8) : Theme.dp(5)
                    radius: width / 2
                    color: bodyBar.pressed ? Theme.accent : (bodyBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Theme.durQuick
                            easing.type: Theme.easeStandard
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                background: Rectangle {
                    color: "transparent"
                }

            }

            Column {
                id: content

                x: sheet.pad
                width: body.width - sheet.pad * 2
                spacing: Theme.dp(20)

                Rich {
                    width: parent.width
                    visible: notes.intro !== ""
                    size: Theme.typeSize("bodyLarge")
                    markup: notes.intro
                }

                // the pictures under the intro of the changelog's section
                Repeater {
                    model: notes.heroes

                    Shot {
                        required property var modelData

                        width: content.width
                        path: modelData.src
                        alt: modelData.alt
                    }

                }

                Repeater {
                    model: notes.sections

                    Column {
                        id: section

                        required property var modelData
                        required property int index
                        readonly property bool major: section.modelData.level === 1

                        width: content.width
                        topPadding: section.major ? Theme.dp(12) : Theme.dp(2)
                        spacing: Theme.dp(12)

                        // a ### heading: a badge and the title
                        Row {
                            visible: section.major
                            spacing: Theme.dp(14)

                            MaterialShape {
                                width: Theme.dp(42)
                                height: Theme.dp(42)
                                shape: sheet.badges[section.index % sheet.badges.length]
                                color: Theme.accentContainer

                                Icon {
                                    anchors.centerIn: parent
                                    name: section.modelData.icon
                                    size: Theme.dp(20)
                                    fill: 1
                                    color: Theme.fgAccentContainer
                                }

                            }

                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                role: "titleLarge"
                                text: section.modelData.title
                            }

                        }

                        // a #### heading: the title alone, in the accent
                        LText {
                            visible: !section.major
                            role: "titleMedium"
                            color: Theme.accent
                            text: section.modelData.title
                        }

                        Rich {
                            width: parent.width
                            visible: section.modelData.intro !== ""
                            markup: section.modelData.intro
                        }

                        Repeater {
                            model: section.modelData.images

                            Shot {
                                required property var modelData

                                width: section.width
                                path: modelData.src
                                alt: modelData.alt
                            }

                        }

                        Repeater {
                            model: section.modelData.items

                            Item {
                                id: entry

                                required property var modelData
                                readonly property bool isCode: entry.modelData.code !== ""

                                width: section.width
                                height: entry.isCode ? codeBox.height : entryText.implicitHeight

                                // the changelog's bullet, on the first line
                                Rectangle {
                                    visible: !entry.isCode
                                    x: Theme.dp(4)
                                    y: Math.round((bodyMetrics.height - height) / 2)
                                    width: Theme.dp(5)
                                    height: Theme.dp(5)
                                    radius: height / 2
                                    color: Theme.accent
                                }

                                Rich {
                                    id: entryText

                                    visible: !entry.isCode
                                    x: Theme.dp(18)
                                    width: parent.width - Theme.dp(18)
                                    markup: entry.modelData.text
                                }

                                Rectangle {
                                    id: codeBox

                                    // a fenced block sits flush, as it does in the changelog
                                    visible: entry.isCode
                                    width: parent.width
                                    height: codeText.implicitHeight + Theme.dp(24)
                                    radius: Theme.radiusMd
                                    color: Theme.surfaceHigh

                                    Text {
                                        id: codeText

                                        x: Theme.dp(16)
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: entry.modelData.code
                                        color: Theme.text
                                        font.family: "monospace"
                                        font.pixelSize: Theme.typeSize("bodyMedium")
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        // where the list fades out under the footer
        Rectangle {
            anchors.bottom: footer.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.dp(24)

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.bgOpaque, 0)
                }

                GradientStop {
                    position: 1
                    color: Theme.bgOpaque
                }

            }

        }

        Item {
            id: footer

            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.dp(20)
            x: sheet.pad
            width: parent.width - sheet.pad * 2
            height: Theme.dp(40)

            Button {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                icon: "open_in_new"
                text: "Every change"
                onClicked: {
                    Qt.openUrlExternally(notes.fullUrl);
                    sheet.hide();
                }
            }

            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "filled"
                text: "Got it"
                onClicked: sheet.hide()
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: sheet.open ? Theme.durEnter : Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: sheet.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: sheet.open ? Theme.durEnter : Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: sheet.open ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel
            }

        }

    }

    // a paragraph of the changelog: its bold, italics, code and links as rich
    // text. a plain Text, since LText's set weight axis would flatten the bold
    component Rich: Text {
        id: rich

        property string markup: ""
        property int size: Theme.typeSize("bodyMedium")

        // a theme colour as css; rich text takes no qml colour
        function css(c: color): string {
            return "#" + [c.r, c.g, c.b].map((v) => {
                return ("0" + Math.round(v * 255).toString(16)).slice(-2);
            }).join("");
        }

        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: size
        wrapMode: Text.WordWrap
        textFormat: Text.RichText
        // code spans as github draws them: monospace on a tint, a little smaller
        text: rich.markup.replace(/<code>/g, "<span style=\"background-color:" + css(Theme.surfaceHighest) + "\">&#8201;<span style=\"font-family:monospace;font-size:" + Math.round(rich.size * 0.9) + "px\">").replace(/<\/code>/g, "</span>&#8201;</span>").replace(/<a href=/g, "<a style=\"color:" + css(Theme.accent) + ";text-decoration:none\" href=")
        onLinkActivated: (link) => {
            return Qt.openUrlExternally(link);
        }

        HoverHandler {
            cursorShape: parent.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

    }

    // a picture: the file when it is there, its place kept while notes ask for that
    component Shot: Item {
        id: shot

        property string path: ""
        property string alt: ""
        readonly property bool ready: img.status === Image.Ready

        visible: shot.path !== "" && (shot.ready || sheet.placeholders)
        // the picture's own shape once it is in, a screen's until then
        height: !shot.visible ? 0 : (shot.ready && img.implicitWidth > 0 ? Math.round(shot.width * img.implicitHeight / img.implicitWidth) : Math.round(shot.width * 9 / 16))

        ClippingRectangle {
            anchors.fill: parent
            radius: Theme.radiusLg
            color: Theme.surfaceHigh

            Image {
                id: img

                anchors.fill: parent
                // only while the sheet is up, at one size, so a missing file is looked for once
                source: shot.path !== "" && sheet.visible ? "file://" + Quickshell.shellDir + "/" + shot.path : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Theme.dp(1280)
            }

            Column {
                visible: !shot.ready
                anchors.centerIn: parent
                width: parent.width - Theme.dp(48)
                spacing: Theme.dp(6)

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "photo"
                    size: Theme.dp(30)
                    color: Theme.subtext
                }

                LText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "labelLarge"
                    color: Theme.subtext
                    text: "A picture goes here"
                }

                LText {
                    visible: shot.alt !== ""
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "bodyMedium"
                    color: Theme.subtext
                    wrapMode: Text.WordWrap
                    text: shot.alt
                }

                LText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "bodySmall"
                    color: Theme.subtextDim
                    elide: Text.ElideMiddle
                    text: shot.path
                }

            }

        }

    }

}
