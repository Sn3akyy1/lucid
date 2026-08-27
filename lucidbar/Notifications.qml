import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs


// Notifications: the pill, its arrival toast, and the list.
//
// The toast is the same "second surface" the clock's reminder alert is, so it
// rides BarPill's alt face rather than each module hand-rolling a third state
// alongside compact and expanded.
BarPill {
    id: root

    readonly property bool dnd: Prefs.doNotDisturb
    property var toastNotification: null
    property bool ready: false
    readonly property int horizontalPadding: 10
    readonly property real screenW: root.hostWindow ? root.hostWindow.screen.width : 1600
    readonly property real screenH: root.hostWindow ? root.hostWindow.screen.height : 900
    readonly property int maxPanelHeight: Math.min(420, Math.max(200, root.screenH - 40))
    readonly property int chromeHeight: 102
    readonly property int notifCount: notifServer.trackedNotifications ? notifServer.trackedNotifications.values.length : 0
    readonly property string badgeDisplayText: root.notifCount > 9 ? "9+" : String(root.notifCount)
    property var sortedNotifications: []

    function refreshSorted() {
        const v = notifServer.trackedNotifications ? notifServer.trackedNotifications.values.slice() : [];
        v.sort((a, b) => b.id - a.id);
        root.sortedNotifications = v;
    }

    function clearAll() {
        for (const n of root.sortedNotifications.slice()) n.dismiss()
        root.refreshSorted();
    }

    // ids whose card has already been built once, so only a notification
    // nobody has seen plays the arrival animation
    property var shownIds: ({})
    property bool shownIdsSeeded: false

    function markShown(id) {
        if (!root.shownIdsSeeded) {
            for (const n of root.sortedNotifications) root.shownIds[n.id] = true
            root.shownIdsSeeded = true;
        }
        if (root.shownIds[id])
            return false;

        root.shownIds[id] = true;
        return true;
    }

    // ---------------- pill shell configuration ----------------
    shown: Prefs.showNotifications
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: Math.min(320, root.screenW - 34)
    panelHeight: Math.min(root.maxPanelHeight, mainColumn.implicitHeight + 28)
    // the arrival toast
    altOpen: root.shown && root.toastNotification !== null && !root.expanded
    altWidth: Math.min(300, root.screenW - 34)
    altHeight: Math.min(root.maxPanelHeight, toastBody.implicitHeight + 20)
    expandedRadius: 20

    onExpandedChanged: {
        if (expanded) {
            root.toastNotification = null;
            toastTimer.stop();
            root.refreshSorted();
        }
    }

    NotificationServer {
        id: notifServer

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false
        persistenceSupported: false
        Component.onCompleted: root.refreshSorted()
        onNotification: (notification) => {
            notification.tracked = true;
            if (!root.ready)
                return ;

            if (root.expanded)
                return ;

            if (root.dnd)
                return ;

            // a never-expiring toast (expireTimeout 0, eg. "recording hidden")
            // holds its spot until it's actually closed - newer notifications
            // still get tracked (visible in the notification list) but don't
            // silently bump it off screen
            if (root.toastNotification && root.toastNotification.expireTimeout === 0)
                return ;

            root.toastNotification = notification;
            if (notification.expireTimeout === 0)
                toastTimer.stop();
            else
                toastTimer.restart();
        }
    }

    // short delay before toasts are allowed, see root.ready above
    Timer {
        interval: 300
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: toastTimer

        interval: Prefs.toastTimeout * 1000
        onTriggered: root.toastNotification = null
    }

    Timer {
        id: panelTransitionTimer

        interval: 400
        onTriggered: root.panelTransitioning = false
        onRunningChanged: {
            if (running)
                root.panelTransitioning = true;

        }
    }

    Connections {
        function onClosed() {
            toastTimer.stop();
            root.toastNotification = null;
        }

        target: root.toastNotification
    }

    Connections {
        function onValuesChanged() {
            root.refreshSorted();
        }

        target: notifServer.trackedNotifications
    }

    // handing the ListView a plain JS array means every refresh reads as a
    // full model reset - every delegate torn down and rebuilt - so add/remove
    // transitions never fire and a notification arriving into the open panel
    // just blinks into existence. This diffs the sorted list into real
    // insert/remove signals so the view can actually animate the change.
    ScriptModel {
        id: notifModel

        values: root.sortedNotifications
    }




    // In pop-up mode this is the pill that stays in the bar, and the compact
    // face reparents into it. In morph mode it is unused - the rectangle
    // below is both pill and panel, exactly as before.

    compactContent: [
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 4

            Item {
                width: 16
                height: 16
                anchors.verticalCenter: parent.verticalCenter

                // Bell and moon cross-fade through each other rather than
                // swapping between frames: each one shrinks and turns away as
                // it leaves and unwinds back to true as it arrives, so the
                // toggle reads as one icon rotating into the other. The base
                // 16/24 is the glyph's own down-scale and stays factored in.
                Shape {
                    visible: opacity > 0.01
                    opacity: root.dnd ? 0 : 1
                    scale: (16 / 24) * (root.dnd ? 0.55 : 1)
                    rotation: root.dnd ? -35 : 0
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    ShapePath {
                        fillColor: Theme.text
                        strokeWidth: 0

                        PathSvg {
                            path: "M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6v-5c0-3.07-1.63-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C8.64 5.36 7 7.92 7 11v5l-2 2v1h14v-1l-2-2Z"
                        }

                    }

                }

                Shape {
                    visible: opacity > 0.01
                    opacity: root.dnd ? 1 : 0
                    scale: (16 / 24) * (root.dnd ? 1 : 0.55)
                    rotation: root.dnd ? 0 : 35
                    width: 24
                    height: 24
                    anchors.centerIn: parent
                    preferredRendererType: Shape.CurveRenderer

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.barMs(220)
                            easing.type: Easing.OutCubic
                        }

                    }

                    ShapePath {
                        fillColor: Theme.accent
                        strokeWidth: 0

                        PathSvg {
                            path: "M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79Z"
                        }

                    }

                }

            }

            Rectangle {
                id: badge

                anchors.verticalCenter: parent.verticalCenter
                height: 16
                width: root.notifCount > 0 ? Math.max(16, badgeText.implicitWidth + 8) : 0
                radius: 999
                color: Theme.accent
                opacity: root.notifCount > 0 ? 1 : 0
                scale: root.notifCount > 0 ? 1 : 0.4
                clip: true

                Text {
                    id: badgeText

                    // set from badgeMorph's ScriptAction, not a live binding,
                    // so the old digit holds through the fade-out half
                    property string displayedText: ""
                    property real morphOffset: 0

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: morphOffset
                    text: displayedText
                    color: Theme.bgOpaque
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)

                    Component.onCompleted: displayedText = root.badgeDisplayText
                }

                Connections {
                    function onBadgeDisplayTextChanged() {
                        badgeMorph.restart();
                    }

                    target: root
                }

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

                // no bounce here, or it fights the scale/opacity pop below
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.barMs(160)
                        easing.type: Easing.OutCubic
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

        }
    ]

    altContent: [
        Item {
            id: toastFace

        // Fills the alt surface BarPill sizes to altWidth/altHeight. Without
        // this the Item is 0x0, and toastContent's `width: parent.width`
        // collapses with it - which is why the toast drew as an empty box.
        anchors.fill: parent

        readonly property var notif: root.toastNotification
        readonly property string notifImage: notif ? notif.image : ""
        readonly property string themeIconName: notif ? (notif.appIcon || (notifImage.indexOf("image://icon/") === 0 ? notifImage.slice(13) : "")) : ""
        readonly property string directImage: notifImage.indexOf("image://icon/") === 0 ? "" : notifImage
        readonly property string iconSource: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
        readonly property bool hovered: toastHover.hovered

        clip: true
        // reset any leftover drag offset from a prior swipe-to-dismiss
        onNotifChanged: {
            if (notif)
                toastContent.y = 0;

        }

        HoverHandler {
            id: toastHover
        }

        // y is driven by the drag or one of the two anims below, never both
        Item {
            id: toastContent

            width: parent.width
            height: parent.height
            opacity: Math.max(0, 1 - (-y) / 120)

            MouseArea {
                id: toastDragArea

                property bool dragged: false

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                drag.target: toastContent
                drag.axis: Drag.YAxis
                drag.minimumY: -(toastContent.height + 40)
                drag.maximumY: 0
                onPressed: {
                    dragged = false;
                    toastTimer.stop();
                }
                onPositionChanged: {
                    if (Math.abs(toastContent.y) > 4)
                        dragged = true;
                }
                onReleased: {
                    if (-toastContent.y > 36) {
                        toastDismissAnim.start();
                    } else {
                        toastSnapAnim.start();
                        toastTimer.restart();
                    }
                }
                onClicked: {
                    if (!dragged)
                        root.expanded = true;
                }
            }

            NumberAnimation {
                id: toastSnapAnim

                target: toastContent
                property: "y"
                to: 0
                duration: Theme.barMs(200)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: toastDismissAnim

                target: toastContent
                property: "y"
                to: -(toastContent.height + 40)
                duration: Theme.barMs(180)
                easing.type: Easing.InCubic
                onFinished: root.toastNotification = null
            }

            Column {
                id: toastBody

                x: 14
                y: 10
                width: parent.width - 28
                spacing: 4

                Row {
                    width: parent.width
                    spacing: 8

                    Item {
                        width: 20
                        height: 20
                        anchors.top: parent.top

                        IconImage {
                            id: toastIcon

                            anchors.fill: parent
                            source: toastFace.iconSource
                            asynchronous: true
                            visible: status === Image.Ready
                        }

                        Shape {
                            visible: !toastIcon.visible
                            width: 24
                            height: 24
                            scale: 16 / 24
                            anchors.centerIn: parent
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                fillColor: Theme.subtextDim
                                strokeWidth: 0

                                PathSvg {
                                    path: "M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6v-5c0-3.07-1.63-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C8.64 5.36 7 7.92 7 11v5l-2 2v1h14v-1l-2-2Z"
                                }

                            }

                        }

                    }

                    Column {
                        width: parent.width - 20 - 8 - 24
                        spacing: 1

                        Text {
                            width: parent.width
                            visible: toastFace.notif && toastFace.notif.appName !== ""
                            text: toastFace.notif ? toastFace.notif.appName : ""
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fs(9)
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: toastFace.notif ? toastFace.notif.summary : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(12)
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }

                    }

                }

            Text {
                width: parent.width
                leftPadding: 28
                visible: toastFace.notif && toastFace.notif.body !== ""
                text: toastFace.notif ? toastFace.notif.body : ""
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Row {
                leftPadding: 28
                visible: toastFace.notif && toastFace.notif.actions.length > 0
                spacing: 6

                Repeater {
                    model: toastFace.notif ? toastFace.notif.actions : []

                    Rectangle {
                        id: toastActionChip

                        required property var modelData

                        height: 22
                        width: toastActionLabel.implicitWidth + 16
                        radius: 999
                        color: toastActionArea.containsMouse ? Theme.accentHover : Theme.accent

                        Text {
                            id: toastActionLabel

                            anchors.centerIn: parent
                            text: toastActionChip.modelData.text
                            // bgOpaque, not bg: this is a label sitting on
                            // the accent chip, so it has to stay solid -
                            // bg carries the >blur slider's alpha and made
                            // the text itself see-through
                            color: Theme.bgOpaque
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(10)
                        }

                        MouseArea {
                            id: toastActionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: toastActionChip.modelData.invoke()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                    }

                }

            }

            }

            Item {
                id: toastCloseButton

                width: 20
                height: 20
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 6

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: toastCloseArea.containsMouse ? Theme.text : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                    opacity: toastFace.hovered ? 1 : 0

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
                    id: toastCloseArea

                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        toastTimer.stop();
                        root.toastNotification = null;
                    }
                }

            }

        }
        }
    ]

    panelContent: [
        Column {
            id: mainColumn

            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            // header: title + dnd
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
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(13)
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Do Not Disturb"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(11)
                    }

                    Rectangle {
                        id: dndSwitch

                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 18
                        radius: 999
                        color: root.dnd ? Theme.accent : Theme.outlineStrong

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: Theme.bgOpaque
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.dnd ? parent.width - width - 2 : 2

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.barMs(200)
                                    easing.type: Easing.OutCubic
                                }

                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Prefs.doNotDisturb = !Prefs.doNotDisturb
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(200)
                            }

                        }

                    }

                }

            }

            // toolbar: count + clear all
            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.notifCount > 0
                    text: root.notifCount === 1 ? "1 notification" : root.notifCount + " notifications"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(11)
                }

                Text {
                    id: clearAllText

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clear all"
                    color: clearAllArea.containsMouse ? Theme.accentHover : Theme.accent
                    opacity: root.notifCount > 0 ? 1 : 0.35
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.fs(11)

                    MouseArea {
                        id: clearAllArea

                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.notifCount > 0
                        hoverEnabled: true
                        cursorShape: root.notifCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.clearAll()
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.barMs(120)
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.barMs(150)
                        }

                    }

                }

            }

            Item {
                width: parent.width
                height: 48
                visible: root.notifCount === 0

                Text {
                    anchors.centerIn: parent
                    text: "No notifications"
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(12)
                }

            }

            ListView {
                id: notifList

                // new cards land at index 0, so a scrolled-down list would
                // otherwise animate them in somewhere off screen
                property int prevCount: 0

                width: parent.width
                visible: root.notifCount > 0
                clip: true
                spacing: 6
                model: notifModel
                height: Math.min(contentHeight, root.maxPanelHeight - root.chromeHeight)
                flickDeceleration: 6000
                maximumFlickVelocity: 6000
                onCountChanged: {
                    if (count > prevCount && contentY > 0)
                        scrollToNewest.restart();

                    prevCount = count;
                }

                NumberAnimation {
                    id: scrollToNewest

                    target: notifList
                    property: "contentY"
                    to: 0
                    duration: Theme.barMs(320)
                    easing.type: Easing.OutCubic
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: (wheel) => {
                        const maxY = Math.max(0, notifList.contentHeight - notifList.height);
                        notifList.contentY = Math.max(0, Math.min(maxY, notifList.contentY - (wheel.angleDelta.y / 120) * 90));
                        wheel.accepted = true;
                    }
                }

                delegate: NotifCard {
                }

                // There is deliberately no add transition here - the
                // arrival animation lives on the card itself (see NotifCard
                // below). The view ignores geometry changes of an item that
                // is in a transition, so a card whose height animated from
                // an add transition would never push the cards under it
                // down: they would be placed once, from the height the
                // delegate happened to report before Qt had laid it out,
                // and stay there flush against the new card until the panel
                // was reopened. Animating the height from outside any view
                // transition keeps the view's own layout in charge, so the
                // spacing is right on every frame.
                // only for removals: closing the gap over a dismissed card
                // is safe to capture up front, since every card involved has
                // long since settled at its real height
                removeDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Theme.barMs(300)
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: Theme.barMs(200)
                    }

                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Theme.barMs(200)
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        property: "scale"
                        to: 0.85
                        duration: Theme.barMs(200)
                        easing.type: Easing.InCubic
                    }

                    NumberAnimation {
                        property: "x"
                        to: 26
                        duration: Theme.barMs(200)
                        easing.type: Easing.InCubic
                    }

                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Theme.accent
                        opacity: 0.55
                    }

                    background: Item {
                    }

                }

            }

        }
    ]

    component NotifCard: Rectangle {
        id: card

        required property var modelData
        readonly property var notification: modelData
        // Everything drawn below reads these mirrors rather than the
        // Notification itself: the remove transition keeps this delegate alive
        // for a moment after the card is dismissed, but the object behind it is
        // destroyed immediately, so direct bindings would re-evaluate against
        // nothing and log a TypeError per field on every dismissal. Mirrored
        // (not snapshotted once) because a notification can be updated in place
        // by the app that sent it; once the object is gone they simply freeze
        // at their last values, which is exactly what the card should fade out
        // showing.
        property string notifAppName: ""
        property string notifSummary: ""
        property string notifBody: ""
        property string notifImage: ""
        property string notifAppIcon: ""
        property int notifUrgency: NotificationUrgency.Normal
        // plain {text, invoke} objects, so a chip still renders its label while
        // the card animates away with its NotificationActions already freed
        property var notifActions: []
        readonly property string themeIconName: card.notifAppIcon || (card.notifImage.indexOf("image://icon/") === 0 ? card.notifImage.slice(13) : "")
        readonly property string directImage: card.notifImage.indexOf("image://icon/") === 0 ? "" : card.notifImage
        readonly property string iconSource: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
        // urgency reads out as a thin accent bar instead of just another line of text
        readonly property color accentColor: card.notifUrgency === NotificationUrgency.Critical ? Theme.error : (card.notifUrgency === NotificationUrgency.Low ? Theme.subtextDim : Theme.accent)
        readonly property bool isHovered: cardHover.hovered
        // 1 the moment the card lands, decayed back to 0 by the arrival
        // animation below - a temporary tint, never permanent chrome
        property real arrivalGlow: 0
        // 0 while the card is unfolding into the list, 1 once it has arrived -
        // the card's height, its slide and its fade all hang off it
        readonly property real fullHeight: cardColumn.implicitHeight + 20
        property real enterProgress: 0

        function syncNotification() {
            const n = card.notification;
            if (!n)
                return ;

            card.notifAppName = n.appName;
            card.notifSummary = n.summary;
            card.notifBody = n.body;
            card.notifImage = n.image;
            card.notifAppIcon = n.appIcon;
            card.notifUrgency = n.urgency;
            card.notifActions = n.actions.map((a) => {
                return {
                    "text": a.text,
                    "invoke": () => {
                        return a.invoke();
                    }
                };
            });
        }

        onNotificationChanged: card.syncNotification()
        Component.onCompleted: {
            card.syncNotification();
            // only a notification nobody has seen yet gets the arrival
            // animation; any other delegate the view builds just appears
            if (card.notification && root.markShown(card.notification.id))
                cardEnter.start();
            else
                card.enterProgress = 1;
        }
        // The view measures a delegate once per insert and caches that number,
        // so it has to be told when the number stops being true - which happens
        // twice here. Qt reports a text-sized delegate's height a layout pass
        // late (this card reads 20, then 122, then its real 130), and the unfold
        // below animates the height on purpose. Re-laying out on every change
        // covers both: it corrects the stale measurement before anything is
        // drawn - without it the cards below keep the stale spacing and sit
        // flush against the new one until the panel is reopened - and then it
        // walks them down in step with the unfold.
        onHeightChanged: {
            if (card.ListView.view)
                card.ListView.view.forceLayout();

        }
        // leave a small gutter on the right so the list's scrollbar floats
        // clear of the card instead of running flush against its edge
        width: ListView.view.width - 12
        height: card.fullHeight * card.enterProgress
        radius: 14
        color: Theme.withBlur(card.arrivalGlow > 0 ? Theme._mix(Theme.bgHover, card.accentColor, card.arrivalGlow * 0.32) : Theme.bgHover)
        clip: true
        // slides in from the right as it unfolds - a transform rather than an x
        // binding, so the view's layout never sees it move
        transform: Translate {
            x: (1 - card.enterProgress) * 22
        }

        // The arrival: the card unfolds from nothing to its full height while
        // sliding in from the right and fading up, with a wash of its urgency
        // accent that decays on its own - so it reads as new for a beat and
        // then looks like every other card. Deliberately animated here instead
        // of from the list's add transition, so the view keeps treating this as
        // an ordinary item and walks the cards below it down as the height
        // grows; see the note on the list.
        ParallelAnimation {
            id: cardEnter

            NumberAnimation {
                target: card
                property: "enterProgress"
                from: 0
                to: 1
                duration: Theme.barMs(400)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: card
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.barMs(300)
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: card
                property: "arrivalGlow"
                from: 1
                to: 0
                duration: Theme.barMs(900)
                easing.type: Easing.InCubic
            }

        }

        // an app can update a notification in place, so the mirrors above
        // track it for as long as it exists
        Connections {
            function onAppNameChanged() {
                card.syncNotification();
            }

            function onAppIconChanged() {
                card.syncNotification();
            }

            function onSummaryChanged() {
                card.syncNotification();
            }

            function onBodyChanged() {
                card.syncNotification();
            }

            function onImageChanged() {
                card.syncNotification();
            }

            function onUrgencyChanged() {
                card.syncNotification();
            }

            function onActionsChanged() {
                card.syncNotification();
            }

            target: card.notification
        }

        HoverHandler {
            id: cardHover
        }

        Column {
            id: cardColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 10
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    id: avatar

                    width: 20
                    height: 20
                    radius: 999
                    color: Theme.bgTrack
                    anchors.top: parent.top

                    IconImage {
                        id: iconImage

                        anchors.fill: parent
                        anchors.margins: 1
                        source: card.iconSource
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconImage.visible
                        text: (card.notifAppName || "?").charAt(0).toUpperCase()
                        color: card.accentColor
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(9)
                    }

                }

                Column {
                    // height is stated rather than derived: a nested positioner
                    // only reports its implicit height on the *next* layout
                    // pass, and the view measures this delegate before that
                    // lands (the card reads 122 tall, then 130). It positions
                    // the cards an arrival pushes down exactly once, from that
                    // stale number, which left them 8px too high - sitting
                    // flush against the new card until the panel was reopened.
                    // Text heights are known immediately, so summing them keeps
                    // the card honest from its first frame.
                    width: parent.width - 20 - 20 - 16
                    spacing: 1
                    height: (cardAppNameText.visible ? cardAppNameText.height + spacing : 0) + cardSummaryText.height

                    Text {
                        id: cardAppNameText

                        width: parent.width
                        visible: card.notifAppName !== ""
                        text: card.notifAppName
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fs(9)
                        elide: Text.ElideRight
                    }

                    Text {
                        id: cardSummaryText

                        width: parent.width
                        text: card.notifSummary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: Theme.fs(12)
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                }

                Item {
                    width: 20
                    height: 20
                    anchors.top: parent.top

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: dismissArea.containsMouse ? Theme.text : Theme.subtextDim
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
                        id: dismissArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (card.notification)
                                card.notification.dismiss();

                        }
                    }

                }

            }

            Text {
                width: parent.width
                leftPadding: 28
                visible: card.notifBody !== ""
                text: card.notifBody
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(11)
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Row {
                leftPadding: 28
                visible: card.notifActions.length > 0
                spacing: 6

                Repeater {
                    model: card.notifActions

                    Rectangle {
                        id: actionChip

                        required property var modelData

                        height: 22
                        width: actionLabel.implicitWidth + 16
                        radius: 999
                        color: card.accentColor
                        opacity: actionArea.containsMouse ? 0.85 : 1

                        Text {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionChip.modelData.text
                            // solid label on the accent chip, see toastActionLabel
                            color: Theme.bgOpaque
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: Theme.fs(10)
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: actionChip.modelData.invoke()
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.barMs(120)
                            }

                        }

                    }

                }

            }

            Item {
                width: parent.width
                height: 6
            }

        }

    }

}
