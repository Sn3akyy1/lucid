import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Hyprland._FocusGrab
import qs
import "../lucidnotif"

// the bar's entry point into the notification centre. the state lives in the
// Notifs singleton; popups are their own surface now, so this is the shade.
BarPill {
    id: root

    readonly property bool silenced: Notifs.silenced
    readonly property int notifCount: Notifs.count
    readonly property string badgeDisplayText: root.notifCount > 9 ? "9+" : String(root.notifCount)
    readonly property bool anyCritical: Notifs.criticalCount > 0
    readonly property color badgeColor: root.anyCritical ? Theme.error : Theme.accent
    readonly property color badgeTextColor: root.anyCritical ? Theme.fgError : Theme.fgAccent
    readonly property int horizontalPadding: 10
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(560, Math.max(220, root.screenH - 80))
    // measured, not guessed, so the list always gets the rest
    readonly property int chromeHeight: headerRow.height + countRow.height + footerRow.height + mainColumn.spacing * 3 + 28

    readonly property var popups: Notifs.popups
    readonly property var topPopup: root.popups.length > 0 ? root.popups[0] : null
    readonly property var restPopups: root.popups.length > 1 ? root.popups.slice(1) : []
    readonly property int popupOverflow: Math.max(0, Notifs.count - root.popups.length)

    shown: Prefs.showNotifications
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(380, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, mainColumn.implicitHeight + 28)
    expandedRadius: Theme.shapeXl
    // the module becomes the newest popup; the older ones stack under it
    altOpen: root.shown && root.topPopup !== null && !root.expanded
    altWidth: Math.min(344, root.screenW - 34)
    altHeight: Math.min(root.maxPanelHeight, topCard.implicitHeight)
    overlayOpen: root.altOpen && (root.restPopups.length > 0 || root.popupOverflow > 0)
    overlayItem: stackSheet

    property var shownPopup: null

    onTopPopupChanged: {
        if (!root.topPopup) {
            // keep the last one on screen while the pill collapses over it
            clearShownTimer.restart();
            return ;
        }
        clearShownTimer.stop();
        root.beginTransition();
        if (!root.shownPopup) {
            root.shownPopup = root.topPopup;
            return ;
        }
        if (root.shownPopup !== root.topPopup)
            popupSwap.restart();

    }
    onExpandedChanged: {
        Notifs.shadeOpen = root.expanded;
        if (root.expanded)
            shadeList.contentY = 0;

    }

    // the popup lives on a layer with no keyboard interactivity, so a reply
    // field in it needs its own grab the way the expanded panel gets one
    HyprlandFocusGrab {
        active: Notifs.replying && !root.expanded
        windows: root.hostWindow ? [root.hostWindow] : []
        onCleared: Notifs.replyingId = -1
    }

    Timer {
        id: clearShownTimer

        interval: Theme.barMs(420)
        onTriggered: root.shownPopup = null
    }

    // out, swap, in — so an expiring popup is seen to leave
    SequentialAnimation {
        id: popupSwap

        ParallelAnimation {
            NumberAnimation {
                target: topCard
                property: "opacity"
                to: 0
                duration: Theme.barMs(110)
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: topCard
                property: "swapOffset"
                to: -16
                duration: Theme.barMs(110)
                easing.type: Easing.InCubic
            }

        }

        ScriptAction {
            script: {
                root.shownPopup = root.topPopup;
                topCard.swapOffset = 14;
                root.beginTransition();
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: topCard
                property: "opacity"
                to: 1
                duration: Theme.barMs(210)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: topCard
                property: "swapOffset"
                to: 0
                duration: Theme.barMs(210)
                easing.type: Easing.OutCubic
            }

        }

    }

    Connections {
        function onShadeRequested() {
            root.expanded = true;
        }

        function onShadeCloseRequested() {
            root.expanded = false;
        }

        function onShadeToggleRequested() {
            root.expanded = !root.expanded;
        }

        target: Notifs
    }

    compactContent: [
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 5

            Item {
                width: 17
                height: 17
                anchors.verticalCenter: parent.verticalCenter

                NotifIcon {
                    anchors.centerIn: parent
                    size: 17
                    path: Notifs.icons.notifications
                    color: Theme.text
                    opacity: root.silenced ? 0 : 1
                    scale: root.silenced ? 0.55 : 1
                    rotation: root.silenced ? -30 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barMs(260)
                            easing.type: Easing.OutBack
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                NotifIcon {
                    anchors.centerIn: parent
                    size: 17
                    path: Notifs.icons.bedtime
                    color: Theme.accent
                    opacity: root.silenced ? 1 : 0
                    scale: root.silenced ? 1 : 0.55
                    rotation: root.silenced ? 0 : 30
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barMs(260)
                            easing.type: Easing.OutBack
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            Rectangle {
                id: badge

                anchors.verticalCenter: parent.verticalCenter
                height: 16
                width: root.notifCount > 0 ? Math.max(16, badgeText.implicitWidth + 8) : 0
                radius: Theme.radiusPill
                color: root.badgeColor
                opacity: root.notifCount > 0 ? 1 : 0
                scale: root.notifCount > 0 ? 1 : 0.4
                clip: true

                Text {
                    id: badgeText

                    property string displayedText: ""
                    property real morphOffset: 0

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: badgeText.morphOffset
                    text: badgeText.displayedText
                    color: root.badgeTextColor
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)
                    Component.onCompleted: badgeText.displayedText = root.badgeDisplayText
                }

                Connections {
                    function onBadgeDisplayTextChanged() {
                        badgeMorph.restart();
                    }

                    target: root
                }

                // the count rolls over rather than snapping
                SequentialAnimation {
                    id: badgeMorph

                    ParallelAnimation {
                        NumberAnimation {
                            target: badgeText
                            property: "opacity"
                            to: 0
                            duration: Theme.barMs(90)
                            easing.type: Easing.InCubic
                        }

                        NumberAnimation {
                            target: badgeText
                            property: "morphOffset"
                            to: -6
                            duration: Theme.barMs(90)
                            easing.type: Easing.InCubic
                        }

                    }

                    ScriptAction {
                        script: {
                            badgeText.displayedText = root.badgeDisplayText;
                            badgeText.morphOffset = 6;
                        }
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: badgeText
                            property: "opacity"
                            to: 1
                            duration: Theme.barMs(140)
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            target: badgeText
                            property: "morphOffset"
                            to: 0
                            duration: Theme.barMs(140)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

                // no bounce here, it fights the pop below
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.barMs(160)
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.barMs(220)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(180)
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.barMs(220)
                        easing.type: Easing.OutBack
                    }

                }

            }

        },
        // left click opens the shade through BarPill; this only wants the right
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: Notifs.toggleDnd()
        }
    ]

    altContent: [
        NotifPopupCard {
            id: topCard

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            notification: root.shownPopup
        }
    ]

    overlayContent: [
        Item {
            id: stackSheet

            // parked directly under whichever surface the pill is wearing
            readonly property real liveY: root.popupItem ? root.popupItem.y + root.popupItem.height + 8 : 0
            property real heldY: 0

            onLiveYChanged: {
                if (root.overlayOpen)
                    stackSheet.heldY = stackSheet.liveY;

            }
            // the pill is right-aligned in the bar, so its right edge is the one
            // fixed point: anchoring there keeps the sheet still while the pill
            // collapses and slides right underneath it
            x: root.width - stackSheet.width
            // frozen while fading, or it flies up after the shrinking pill
            y: root.overlayOpen ? stackSheet.liveY : stackSheet.heldY
            width: root.altWidth
            height: stackColumn.implicitHeight
            opacity: root.overlayOpen ? 1 : 0
            visible: opacity > 0.01

            HoverHandler {
                onHoveredChanged: Notifs.popupsPaused = hovered
            }

            Column {
                id: stackColumn

                width: parent.width
                spacing: 8

                ListView {
                    id: stackList

                    width: parent.width
                    height: contentHeight
                    interactive: false
                    spacing: 8
                    model: stackModel

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.barMs(260)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                    delegate: NotifPopupCard {
                        required property var modelData

                        width: stackList.width
                        notification: modelData
                        surfaceColor: Theme.withBlur(Theme.bg)
                    }

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.barMs(260)
                            easing.type: Easing.OutCubic
                        }

                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Theme.barMs(170)
                            easing.type: Easing.InCubic
                        }

                        NumberAnimation {
                            property: "scale"
                            to: 0.92
                            duration: Theme.barMs(170)
                            easing.type: Easing.InCubic
                        }

                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Theme.barMs(300)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                        NumberAnimation {
                            property: "opacity"
                            to: 1
                            duration: Theme.barMs(200)
                        }

                    }

                }

                // whatever the stack could not hold is still in the shade
                Item {
                    width: parent.width
                    height: root.popupOverflow > 0 ? 26 : 0
                    opacity: root.popupOverflow > 0 ? 1 : 0
                    visible: opacity > 0.01

                    Rectangle {
                        anchors.centerIn: parent
                        width: overflowRow.implicitWidth + 22
                        height: 26
                        radius: height / 2
                        color: overflowArea.containsMouse ? Theme.withBlur(Theme.bgActive) : Theme.withBlur(Theme.bg)

                        Row {
                            id: overflowRow

                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.popupOverflow + " more"
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: Theme.fs(10)
                            }

                            NotifIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 13
                                path: Notifs.icons.expand_more
                                color: Theme.subtext
                            }

                        }

                        MouseArea {
                            id: overflowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Notifs.popupClear();
                                root.expanded = true;
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.barMs(200)
                }

            }

        }
    ]

    panelContent: [
        Column {
            id: mainColumn

            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            Item {
                id: headerRow

                width: parent.width
                height: 30

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.fs(15)
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    NotifGhostButton {
                        iconPath: Notifs.icons.bedtime
                        active: Notifs.dnd
                        onClicked: Notifs.toggleDnd()
                    }

                    NotifGhostButton {
                        iconPath: Notifs.icons.settings
                        onClicked: {
                            root.expanded = false;
                            Notifs.settingsRequested();
                        }
                    }

                }

            }

            // what is actually going on right now, in one line
            Item {
                id: countRow

                width: parent.width
                height: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (Notifs.dnd)
                            return "Do Not Disturb · " + root.notifCount + " waiting";

                        if (Notifs.quietNow)
                            return "Quiet hours · " + root.notifCount + " waiting";

                        if (root.notifCount === 0)
                            return "Nothing waiting";

                        return root.notifCount === 1 ? "1 notification" : root.notifCount + " notifications";
                    }
                    color: (Notifs.dnd || Notifs.quietNow) ? Theme.accent : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                }

                NotifTextButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.rows.length > 0 && Prefs.notifGrouping
                    label: "Expand all"
                    labelColor: Theme.subtext
                    onClicked: Notifs.expandAll()
                }

            }

            // nothing to show: say so properly rather than with a bare line
            Item {
                width: parent.width
                height: root.notifCount === 0 ? 132 : 0
                opacity: root.notifCount === 0 ? 1 : 0
                visible: opacity > 0.01
                clip: true

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    NotifIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 34
                        path: Notifs.icons.done_all
                        color: Theme.subtextDim
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "You're all caught up"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.weight: Font.DemiBold
                        font.pixelSize: Theme.fs(12)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Notifs.dnd ? "Notifications are being held back" : "New notifications will show up here"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(10)
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.barMs(200)
                    }

                }

            }

            // a Flickable rather than a ListView: one row here is a whole app
            // group, and an expanded one is far taller than the viewport.
            // ListView virtualises from delegate bounds, so a single huge
            // delegate whose height is also animated leaves its bookkeeping
            // stale and shows empty space. there are only ever a few rows.
            Flickable {
                id: shadeList

                // the gutter the scrollbar lives in, taken out of the panel's
                // right margin so the cards keep even margins either side
                readonly property int gutter: 10
                readonly property bool scrollable: shadeList.contentHeight > shadeList.height + 1
                readonly property real maxScroll: Math.max(0, shadeList.contentHeight - shadeList.height)

                function clampScroll() {
                    const v = Math.max(0, Math.min(shadeList.maxScroll, shadeList.contentY));
                    // guarded, or the assignment re-enters through onContentYChanged
                    if (Math.abs(v - shadeList.contentY) > 0.01)
                        shadeList.contentY = v;

                }

                // interactive is false, so nothing rebounds contentY on its own
                onContentHeightChanged: Qt.callLater(shadeList.clampScroll)
                onHeightChanged: Qt.callLater(shadeList.clampScroll)
                onContentYChanged: Qt.callLater(shadeList.clampScroll)

                width: parent.width + shadeList.gutter
                visible: root.notifCount > 0
                clip: true
                // the cards swipe sideways, so the list must not fight them
                interactive: false
                contentWidth: shadeList.width
                contentHeight: rowColumn.implicitHeight
                height: Math.max(0, Math.min(contentHeight, root.maxPanelHeight - root.chromeHeight))

                Column {
                    id: rowColumn

                    width: shadeList.width - shadeList.gutter
                    spacing: 6

                    move: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: Theme.barMs(300)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.barMs(240)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Repeater {
                        model: shadeModel

                        Item {
                            id: shadeRow

                            required property var modelData

                            readonly property bool isHeader: shadeRow.modelData && shadeRow.modelData.kind === "header"

                            width: rowColumn.width
                            implicitHeight: shadeRow.isHeader ? 24 : groupItem.implicitHeight
                            height: shadeRow.implicitHeight

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                visible: shadeRow.isHeader
                                text: shadeRow.isHeader ? shadeRow.modelData.label : ""
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.weight: Font.DemiBold
                                font.pixelSize: Theme.fs(10)
                                font.letterSpacing: 0.6
                            }

                            NotifGroup {
                                id: groupItem

                                width: parent.width
                                visible: !shadeRow.isHeader
                                row: shadeRow.isHeader ? null : shadeRow.modelData
                            }

                        }

                    }

                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        shadeList.contentY = Math.max(0, Math.min(shadeList.maxScroll, shadeList.contentY - (wheel.angleDelta.y / 120) * 90));
                        wheel.accepted = true;
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: shadeList.scrollable ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: width / 2
                        color: Theme.accent
                        opacity: shadeList.scrollable ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.barMs(180)
                            }

                        }

                    }

                    background: Item {
                    }

                }

            }

            // m3 puts the shade's verbs on pills along the bottom
            Item {
                id: footerRow

                width: parent.width
                height: 34

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.5
                }

                NotifTextButton {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    label: "Clear all"
                    enabled: root.notifCount > 0
                    onClicked: Notifs.clearAll()
                }

            }

        }
    ]

    ScriptModel {
        id: shadeModel

        values: Notifs.rows
    }

    ScriptModel {
        id: stackModel

        values: root.restPopups
    }

}
