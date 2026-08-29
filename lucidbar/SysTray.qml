import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

BarPill {
    id: root

    readonly property var hiddenKeywords: ["blueman"]
    readonly property var trayItems: {
        const raw = SystemTray.items ? SystemTray.items.values : [];
        const visible = raw.filter((i) => {
            const key = ((i.id || "") + " " + (i.title || "")).toLowerCase();
            return !root.hiddenKeywords.some((kw) => {
                return key.indexOf(kw) !== -1;
            });
        });
        const nameOf = (i) => {
            return (i.title || i.tooltipTitle || i.id || "").toLowerCase();
        };
        return visible.slice().sort((a, b) => {
            const aAttn = a.status === Status.NeedsAttention ? 0 : 1;
            const bAttn = b.status === Status.NeedsAttention ? 0 : 1;
            if (aAttn !== bAttn)
                return aAttn - bAttn;

            return nameOf(a).localeCompare(nameOf(b));
        });
    }
    readonly property int trayCount: root.trayItems.length
    readonly property int attentionCount: root.trayItems.filter((i) => {
        return i.status === Status.NeedsAttention;
    }).length
    property var menuItem: null
    property real menuX: 0
    property real menuY: 0
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

    readonly property int horizontalPadding: 10
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(380, Math.max(180, root.screenH - 40))

    shown: Prefs.showTray && root.trayCount > 0
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(300, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, expandedColumn.implicitHeight + 28)
    expandedRadius: Theme.radiusLg
    compactCollapseScale: 0.94

    onTrayCountChanged: {
        if (root.trayCount === 0)
            root.expanded = false;

    }
    onExpandedChanged: {
        if (!root.expanded)
            root.menuItem = null;

    }

    compactContent: [
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
                            path: "M3 13h8V3H3v10Zm0 8h8v-6H3v6Zm10 0h8V11h-8v10Zm0-18v6h8V3h-8Z"
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
                    text: root.trayCount > 9 ? "9+" : String(root.trayCount)
                    color: Theme.bgOpaque
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.barDurShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barDurShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.barDurShort
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
                    text: root.attentionCount > 0 ? root.attentionCount + " needs attention" : (root.trayCount === 1 ? "1 running" : root.trayCount + " running")
                    color: root.attentionCount > 0 ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barDurShort
                        }

                    }

                }

            }

            ListView {
                id: trayList

                width: parent.width
                clip: true
                spacing: 0
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
                    onRequestMenu: (it, wx, wy) => {
                        const p = menuLayer.mapFromItem(null, wx, wy);
                        root.menuItem = it;
                        root.menuX = p.x;
                        root.menuY = p.y;
                    }
                }

                add: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.barDurShort
                    }

                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Theme.barDurQuick
                    }

                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Theme.barDurMedium
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

            }

        }
    ]

    overlayOpen: root.menuItem !== null && entryRep.count > 0
    overlayItem: menuSheet

    overlayContent: [
        Item {
            id: menuLayer

            anchors.fill: parent
            visible: root.menuItem !== null && entryRep.count > 0

            QsMenuOpener {
                id: menuOpener

                menu: root.menuItem ? root.menuItem.menu : null
            }

            Rectangle {
                id: menuSheet

                readonly property real wanted: entryCol.implicitHeight + 12

                width: 196
                height: Math.min(menuSheet.wanted, root.screenH - 80)
                x: root.menuX
                y: root.menuY
                radius: Theme.radiusSm
                color: Theme.bgOpaque
                clip: true
                opacity: root.menuItem !== null ? 1 : 0
                scale: root.menuItem !== null ? 1 : 0.94
                transformOrigin: Item.TopLeft

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barDurShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.barDurShort
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.easeEmphasizedDecel
                    }

                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onWheel: (wheel) => {
                        wheel.accepted = true;
                    }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: width
                    contentHeight: entryCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height

                    Column {
                        id: entryCol

                        width: parent.width

                        Repeater {
                            id: entryRep

                            model: menuOpener.children

                            delegate: Item {
                                id: entryRow

                                required property var modelData

                                readonly property var entry: entryRow.modelData
                                readonly property bool isSep: entryRow.entry.isSeparator || entryRow.entry.text === ""

                                width: entryCol.width
                                height: entryRow.isSep ? 7 : 28

                                Rectangle {
                                    visible: entryRow.isSep
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    height: 1
                                    color: Theme.outline
                                }

                                Rectangle {
                                    visible: !entryRow.isSep
                                    anchors.fill: parent
                                    radius: Theme.radiusXs
                                    color: Theme.text
                                    opacity: (entryArea.containsMouse && entryRow.entry.enabled) ? Theme.stateHover : 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.barDurQuick
                                        }

                                    }

                                }

                                Rectangle {
                                    id: tick

                                    visible: !entryRow.isSep && entryRow.entry.checkState !== Qt.Unchecked
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5
                                    height: 5
                                    radius: 999
                                    color: Theme.accent
                                }

                                Text {
                                    visible: !entryRow.isSep
                                    anchors.left: parent.left
                                    anchors.leftMargin: tick.visible ? 19 : 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: entryRow.entry.text
                                    color: entryRow.entry.enabled ? Theme.text : Theme.subtextDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fs(11)
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: entryArea

                                    anchors.fill: parent
                                    enabled: !entryRow.isSep && entryRow.entry.enabled
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        entryRow.entry.triggered();
                                        root.menuItem = null;
                                    }
                                }

                            }

                        }

                    }

                }

            }

        }
    ]


    component TrayCard: Rectangle {
        id: card

        required property var modelData
        required property int index

        signal requestMenu(var it, real wx, real wy)

        readonly property var item: card.modelData
        readonly property bool needsAttention: card.item.status === Status.NeedsAttention
        readonly property string displayName: card.item.title || card.item.tooltipTitle || card.item.id || "Unknown"
        readonly property string supporting: {
            const desc = (card.item.tooltipDescription || "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
            if (desc.length > 0)
                return desc;

            const tip = (card.item.tooltipTitle || "").trim();
            if (tip.length > 0 && tip !== card.displayName)
                return tip;

            switch (card.item.category) {
            case Category.Hardware:
                return "Hardware";
            case Category.SystemServices:
                return "System service";
            case Category.Communications:
                return "Communications";
            default:
                return "";
            }
        }
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

        width: ListView.view.width
        height: card.supporting !== "" ? 54 : 44
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radiusXs
            color: Theme.text
            opacity: cardArea.pressed ? Theme.statePressed : (cardArea.containsMouse ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barDurQuick
                    easing.type: Easing.OutCubic
                }

            }

        }

        Rectangle {
            visible: card.index < card.ListView.view.count - 1
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 48
            height: 1
            color: Theme.outline
        }

        MouseArea {
            id: cardArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    const p = cardArea.mapToItem(null, mouse.x, mouse.y);
                    card.requestMenu(card.item, p.x, p.y);
                } else if (mouse.button === Qt.MiddleButton) {
                    card.item.secondaryActivate();
                } else {
                    card.item.activate();
                }
            }
            onWheel: (wheel) => {
                card.item.scroll(wheel.angleDelta.y, false);
                wheel.accepted = true;
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 12

            Item {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    id: cardIconImage

                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: card.resolvedIcon
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Rectangle {
                    visible: !cardIconImage.visible
                    anchors.fill: parent
                    radius: 999
                    color: Theme.withBlur(Theme.bgHigh)

                    Text {
                        anchors.centerIn: parent
                        text: card.displayName.charAt(0).toUpperCase()
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(11)
                    }

                }

                Rectangle {
                    visible: card.needsAttention
                    anchors.right: parent.right
                    anchors.top: parent.top
                    width: 8
                    height: 8
                    radius: 999
                    color: Theme.accent
                    border.width: 2
                    border.color: Theme.bgOpaque
                }

            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 - parent.spacing
                spacing: 1

                Text {
                    width: parent.width
                    text: card.displayName
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(12)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: card.supporting !== ""
                    text: card.supporting
                    color: card.needsAttention ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    elide: Text.ElideRight
                }

            }

        }

    }

}


