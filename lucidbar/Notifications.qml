import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland._FocusGrab
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: root

    property var hostWindow: null
    property bool expanded: false
    // mirrors shell's own radius below - see the same note in Workspaces.qml
    readonly property int cornerRadius: (root.expanded || root.toastActive) ? 20 : 60
    property bool dnd: false
    property var toastNotification: null
    property bool panelTransitioning: false
    // delays toasts briefly so hot-reload replays don't fire one
    property bool ready: false
    readonly property int horizontalPadding: 10
    readonly property int maxPanelHeight: 420
    // fixed vertical chrome above the list: margins + header + toolbar + spacing
    readonly property int chromeHeight: 102
    readonly property int notifCount: notifServer.trackedNotifications ? notifServer.trackedNotifications.values.length : 0
    // anything past 9 just reads as "9+" so the badge never has to grow past two digits
    readonly property string badgeDisplayText: root.notifCount > 9 ? "9+" : String(root.notifCount)
    readonly property bool toastActive: root.toastNotification !== null && !root.expanded
    readonly property bool showCompact: !root.expanded && !root.toastActive
    property var sortedNotifications: []

    function refreshSorted() {
        root.sortedNotifications = notifServer.trackedNotifications.values.slice().sort((a, b) => {
            return b.id - a.id;
        });
    }

    function clearAll() {
        const list = notifServer.trackedNotifications.values.slice();
        for (const n of list) n.dismiss()
    }

    onExpandedChanged: {
        panelTransitionTimer.restart();
        if (expanded) {
            toastTimer.stop();
            root.toastNotification = null;
        }
    }
    onToastActiveChanged: panelTransitionTimer.restart()
    implicitWidth: expanded ? 320 : (toastActive ? 300 : (compactRow.implicitWidth + horizontalPadding * 2))
    implicitHeight: expanded ? Math.min(root.maxPanelHeight, mainColumn.implicitHeight + 28) : (toastActive ? (toastBody.implicitHeight + 20) : 35)
    clip: true

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

        interval: 4500
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

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        // toast uses the expanded panel's flatter radius, not the pill's
        radius: (root.expanded || root.toastActive) ? 20 : 60
        clip: true

        // COMPACT FACE
        Item {
            id: compactFace

            property bool hovered: false

            width: compactRow.implicitWidth + (root.horizontalPadding * 2)
            height: 35
            anchors.left: parent.left
            anchors.top: parent.top
            opacity: root.showCompact ? 1 : 0
            scale: root.showCompact ? 1 : 0.82
            visible: opacity > 0.01

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: compactFace.hovered = true
                onExited: compactFace.hovered = false
                onClicked: root.expanded = true
            }

            Row {
                id: compactRow

                anchors.centerIn: parent
                spacing: 4

                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Shape {
                        visible: !root.dnd
                        width: 24
                        height: 24
                        scale: 16 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: Theme.text
                            strokeWidth: 0

                            PathSvg {
                                path: "M12 22a2.5 2.5 0 0 0 2.45-2h-4.9A2.5 2.5 0 0 0 12 22Zm7-6v-5c0-3.07-1.63-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C8.64 5.36 7 7.92 7 11v5l-2 2v1h14v-1l-2-2Z"
                            }

                        }

                    }

                    Shape {
                        visible: root.dnd
                        width: 24
                        height: 24
                        scale: 16 / 24
                        anchors.centerIn: parent
                        preferredRendererType: Shape.CurveRenderer

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
                        font.pixelSize: 11

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
                                duration: 90
                                easing.type: Easing.InCubic
                            }

                            NumberAnimation {
                                target: badgeText
                                property: "morphOffset"
                                to: -6
                                duration: 90
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
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation {
                                target: badgeText
                                property: "morphOffset"
                                to: 0
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                    }

                    // no bounce here, or it fights the scale/opacity pop below
                    Behavior on width {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }

                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                        }

                    }

                }

            }

            Rectangle {
                anchors.fill: parent
                radius: parent.parent.radius
                color: Theme.text
                opacity: compactFace.hovered ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }

            }

        }

        // TOAST FACE
        Item {
            id: toastFace

            readonly property var notif: root.toastNotification
            readonly property string notifImage: notif ? notif.image : ""
            readonly property string themeIconName: notif ? (notif.appIcon || (notifImage.indexOf("image://icon/") === 0 ? notifImage.slice(13) : "")) : ""
            readonly property string directImage: notifImage.indexOf("image://icon/") === 0 ? "" : notifImage
            readonly property string iconSource: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
            readonly property bool hovered: toastHover.hovered

            anchors.left: parent.left
            anchors.top: parent.top
            width: 300
            height: toastBody.implicitHeight + 20
            opacity: root.toastActive ? 1 : 0
            scale: root.toastActive ? 1 : 0.94
            visible: opacity > 0.01
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
                    duration: 200
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    id: toastDismissAnim

                    target: toastContent
                    property: "y"
                    to: -(toastContent.height + 40)
                    duration: 180
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
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: toastFace.notif ? toastFace.notif.summary : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: 12
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
                    font.pixelSize: 11
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
                                color: Theme.bg
                                font.family: Theme.fontFamily
                                font.bold: true
                                font.pixelSize: 10
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
                                    duration: 120
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
                        font.pixelSize: 11
                        opacity: toastFace.hovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
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

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }

            }

        }

        // EXPANDED FACE
        Item {
            id: expandedFace

            anchors.fill: parent
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 1.04
            visible: opacity > 0.01

            HyprlandFocusGrab {
                active: root.expanded
                windows: root.hostWindow ? [root.hostWindow] : []
                onCleared: root.expanded = false
            }

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
                        font.pixelSize: 13
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
                            font.pixelSize: 11
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
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }

                                }

                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dnd = !root.dnd
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 200
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
                        font.pixelSize: 11
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
                        font.pixelSize: 11

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
                                duration: 120
                            }

                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
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
                        font.pixelSize: 12
                    }

                }

                ListView {
                    id: notifList

                    width: parent.width
                    visible: root.notifCount > 0
                    clip: true
                    spacing: 6
                    model: root.sortedNotifications
                    height: Math.min(contentHeight, root.maxPanelHeight - root.chromeHeight)
                    flickDeceleration: 6000
                    maximumFlickVelocity: 6000

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

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 160
                        }

                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 120
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

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            Behavior on scale {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.expanded ? 140 : 0
                    }

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: 380
                easing.type: Easing.OutCubic
            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }

    }

    Behavior on implicitHeight {
        enabled: root.panelTransitioning

        NumberAnimation {
            duration: 380
            easing.type: Easing.OutCubic
        }

    }

    // reusable notification card
    component NotifCard: Rectangle {
        id: card

        required property var modelData
        readonly property var notification: modelData
        readonly property string themeIconName: notification.appIcon || (notification.image.indexOf("image://icon/") === 0 ? notification.image.slice(13) : "")
        readonly property string directImage: notification.image.indexOf("image://icon/") === 0 ? "" : notification.image
        readonly property string iconSource: directImage || (themeIconName ? Quickshell.iconPath(themeIconName) : "")
        // urgency reads out as a thin accent bar instead of just another line of text
        readonly property color accentColor: notification.urgency === NotificationUrgency.Critical ? Theme.error : (notification.urgency === NotificationUrgency.Low ? Theme.subtextDim : Theme.accent)
        readonly property bool isHovered: cardHover.hovered

        // leave a small gutter on the right so the list's scrollbar floats
        // clear of the card instead of running flush against its edge
        width: ListView.view.width - 12
        height: cardColumn.implicitHeight + 20
        radius: 14
        color: Theme.withBlur(Theme.bgHover)
        clip: true

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
                        text: (card.notification.appName || "?").charAt(0).toUpperCase()
                        color: card.accentColor
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: 9
                    }

                }

                Column {
                    width: parent.width - 20 - 20 - 16
                    spacing: 1

                    Text {
                        width: parent.width
                        visible: card.notification.appName !== ""
                        text: card.notification.appName
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: card.notification.summary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.pixelSize: 12
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
                        font.pixelSize: 11
                        opacity: card.isHovered ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }

                        }

                    }

                    MouseArea {
                        id: dismissArea

                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.notification.dismiss()
                    }

                }

            }

            Text {
                width: parent.width
                leftPadding: 28
                visible: card.notification.body !== ""
                text: card.notification.body
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
            }

            Row {
                leftPadding: 28
                visible: card.notification.actions.length > 0
                spacing: 6

                Repeater {
                    model: card.notification.actions

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
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.pixelSize: 10
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
                                duration: 120
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
