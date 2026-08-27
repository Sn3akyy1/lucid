import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

// The system tray. Pill shell, morph/pop-up geometry and hover affordance all
// come from BarPill now - what is left here is the tray itself.
BarPill {
    id: root

    readonly property var hiddenKeywords: ["blueman"]
    readonly property var trayItems: {
        const raw = SystemTray.items ? SystemTray.items.values : [];
        return raw.filter((i) => {
            const key = ((i.id || "") + " " + (i.title || "")).toLowerCase();
            return !root.hiddenKeywords.some((kw) => {
                return key.indexOf(kw) !== -1;
            });
        });
    }
    readonly property int trayCount: root.trayItems.length
    readonly property int horizontalPadding: 10
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(320, Math.max(160, root.screenH - 40))

    function resolveIconSource(raw) {
        if (!raw)
            return "";

        const qIdx = raw.indexOf("?path=");
        if (qIdx === -1)
            return raw;

        const name = raw.substring(0, qIdx);
        const dir = raw.substring(qIdx + 6);
        const fileName = name.substring(name.lastIndexOf("/") + 1);
        return "file://" + dir + "/" + fileName;
    }

    // An empty tray now takes the module out through the same fade every
    // other hidden module uses, rather than zeroing its own width - the pill
    // shrinks away instead of being cut.
    shown: Prefs.showTray && root.trayCount > 0
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(260, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, expandedColumn.implicitHeight + 28)
    expandedRadius: 20
    compactCollapseScale: 0.94

    onTrayCountChanged: {
        if (root.trayCount === 0)
            root.expanded = false;

    }

    compactContent: [
        // One glyph and a count, not a row of app logos. Every other
        // thing in the bar is a flat Theme.text shape with the accent
        // reserved for live state, so a handful of full-colour icons at
        // 16px were the one foreign element in it - and tinting them did
        // not help, because colorization keeps each icon's own luminance
        // and dense logos just became blobs of uneven brightness. The
        // icons themselves are worth seeing when you are picking one out,
        // so they live in the expanded card list instead, at full colour.
        //
        // Deliberately built like the notification bell next to it: same
        // 16px glyph, same 4px gap, same accent pill for the count.
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 4

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                Shape {
                    width: 24
                    height: 24
                    scale: 16 / 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: Theme.text
                        strokeWidth: 0

                        PathSvg {
                            path: "M4 4h16v6H4V4Zm0 10h16v6H4v-6Zm2-8v2h2V6H6Zm0 10v2h2v-2H6Z"
                        }

                    }

                }

            }

            Rectangle {
                id: countBadge

                anchors.verticalCenter: parent.verticalCenter
                height: 16
                width: root.trayCount > 0 ? Math.max(16, countText.implicitWidth + 8) : 0
                radius: 999
                color: Theme.accent
                opacity: root.trayCount > 0 ? 1 : 0
                scale: root.trayCount > 0 ? 1 : 0.4
                clip: true

                Text {
                    id: countText

                    anchors.centerIn: parent
                    // past 9 it just reads 9+, so the pill never has to
                    // grow to three digits
                    text: root.trayCount > 9 ? "9+" : String(root.trayCount)
                    color: Theme.bgOpaque
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.barMs(200)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(200)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.barMs(200)
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }
    ]

    panelContent: [
        Column {
            id: expandedColumn

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // header
            Item {
                width: parent.width
                height: 28

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.outline
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Tray"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.trayCount === 1 ? "1 running" : root.trayCount + " running"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                }

            }

            ListView {
                id: trayList

                width: parent.width
                clip: true
                spacing: 6
                model: root.trayItems
                height: Math.min(contentHeight, root.maxPanelHeight - 60)
                flickDeceleration: 6000
                maximumFlickVelocity: 6000

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        const maxY = Math.max(0, trayList.contentHeight - trayList.height);
                        trayList.contentY = Math.max(0, Math.min(maxY, trayList.contentY - (wheel.angleDelta.y / 120) * 90));
                        wheel.accepted = true;
                    }
                }

                delegate: TrayCard {
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.barMs(160)
                    }

                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Theme.barMs(120)
                    }

                }

            }

        }
    ]

    component TrayCard: Rectangle {
        id: card

        required property var modelData
        readonly property var item: modelData
        readonly property bool isHovered: cardHover.hovered
        // title is the real SNI field, but some apps (Chromium/Vesktop
        // included) leave it blank and only set a tooltip title, with id
        // left as a meaningless generated string - see closeApp() below
        readonly property string displayName: card.item.title || card.item.tooltipTitle || card.item.id || "Unknown"
        // see the matching resolveIconSource() on root - inline components
        // can't reach outer scope, so this is duplicated rather than shared
        readonly property string resolvedIcon: {
            const raw = card.item.icon;
            if (!raw)
                return "";

            const qIdx = raw.indexOf("?path=");
            if (qIdx === -1)
                return raw;

            const name = raw.substring(0, qIdx);
            const dir = raw.substring(qIdx + 6);
            const fileName = name.substring(name.lastIndexOf("/") + 1);
            return "file://" + dir + "/" + fileName;
        }

        function closeApp() {
            // best-effort match: Quickshell's tray API doesn't expose a pid
            // for the item, so this is a substring match of displayName
            // against the full command line rather than a precise kill of
            // one exact process
            const target = card.displayName.trim();
            if (target.length >= 3 && target !== "Unknown")
                killProc.exec(["pkill", "-9", "-if", target]);

        }

        width: ListView.view.width
        height: 44
        radius: 14
        color: card.isHovered ? Theme.withBlur(Theme.bgActive) : Theme.withBlur(Theme.bgHover)
        clip: true

        HoverHandler {
            id: cardHover
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.barMs(150)
                easing.type: Easing.OutCubic
            }

        }

        Process {
            id: killProc
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.item.activate()
        }

        Row {
            id: cardRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            spacing: 10

            Item {
                id: cardIconSlot

                width: 20
                height: 20
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: cardIconImage

                    anchors.fill: parent
                    source: card.resolvedIcon
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    visible: !cardIconImage.visible
                    anchors.fill: parent
                    radius: 999
                    color: Theme.bgTrack

                    Text {
                        anchors.centerIn: parent
                        text: card.displayName.charAt(0).toUpperCase()
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(9)
                    }

                }

            }

            Text {
                // capped so one very long app name can't blow the card out,
                // not stretched to fill the row - that's what left the ✕
                // stranded right after a short name instead of at the end
                width: Math.min(implicitWidth, 150)
                anchors.verticalCenter: parent.verticalCenter
                text: card.displayName
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fs(12)
                elide: Text.ElideRight
            }

        }

        // pinned to the card's own right edge, independent of the row above,
        // so it always sits at the end instead of trailing right after a
        // short name
        Item {
            id: closeBtn

            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 12

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeArea.containsMouse ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                opacity: card.isHovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(140)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(120)
                    }

                }

            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.closeApp()
            }

        }

    }

}
