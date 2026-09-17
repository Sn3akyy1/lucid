import QtQuick
import Quickshell.Services.Notifications
import qs

// one notification, rendered the same way in the shade and in a popup
Item {
    id: card

    property var notification: null
    property bool showClose: true
    property bool showApp: true
    // inside an expanded group the heading already says who sent it
    property bool showAppName: true
    property bool showAvatar: true
    // a group puts its count and collapse control where the close button sits
    property alias trailingContent: trailingHolder.data
    readonly property bool hasTrailing: trailingHolder.children.length > 0
    property int bodyLines: 0
    property bool interactive: true

    // mirrored, because the notification object dies the moment it is dismissed
    property string appName: ""
    property string summary: ""
    property string body: ""
    property int urgency: NotificationUrgency.Normal
    property var actionList: []
    property real progress: -1
    property bool replyOpen: false

    readonly property bool critical: card.urgency === NotificationUrgency.Critical
    readonly property color tint: card.critical ? Theme.error : Theme.accent
    readonly property int textLeft: (Prefs.notifShowIcons && card.showAvatar) ? 38 : 0

    signal replyToggled(bool open)
    signal activated()

    function sync() {
        const n = card.notification;
        if (!n)
            return ;

        card.appName = n.appName || "Unknown";
        card.summary = n.summary;
        card.body = n.body;
        card.urgency = n.urgency;
        card.progress = Notifs.hasProgress(n) ? Notifs.progressOf(n) : -1;
        var out = [];
        for (var i = 0; i < n.actions.length; i++) {
            const a = n.actions[i];
            // the default action is the card's own click target, not a chip
            if (!a || a.identifier === "default")
                continue;

            out.push({
                "text": a.text,
                "invoke": () => {
                    return Notifs.invokeAction(a);
                }
            });
        }
        card.actionList = out;
    }

    onNotificationChanged: card.sync()
    Component.onCompleted: card.sync()
    implicitHeight: column.implicitHeight

    Connections {
        function onSummaryChanged() {
            card.sync();
        }

        function onBodyChanged() {
            card.sync();
        }

        function onAppNameChanged() {
            card.sync();
        }

        function onAppIconChanged() {
            card.sync();
        }

        function onImageChanged() {
            card.sync();
        }

        function onUrgencyChanged() {
            card.sync();
        }

        function onActionsChanged() {
            card.sync();
        }

        function onHintsChanged() {
            card.sync();
        }

        target: card.notification
    }

    HoverHandler {
        id: hover
    }

    Column {
        id: column

        width: parent.width
        spacing: 3

        Item {
            width: parent.width
            height: Math.max(headText.visible ? headText.implicitHeight : 0, avatarItem.visible ? 28 : 16)

            NotifAvatar {
                id: avatarItem

                anchors.left: parent.left
                anchors.top: parent.top
                visible: Prefs.notifShowIcons && card.showAvatar
                size: 28
                notification: card.notification
            }

            // app name, a middot, and how long it has been sitting there
            Text {
                id: headText

                anchors.left: parent.left
                anchors.leftMargin: card.textLeft
                anchors.right: card.hasTrailing ? trailingHolder.left : (closeButton.visible ? closeButton.left : parent.right)
                anchors.rightMargin: 6
                anchors.verticalCenter: avatarItem.visible ? avatarItem.verticalCenter : undefined
                visible: card.showApp && text !== ""
                text: {
                    const age = (Prefs.notifTimestamps && card.notification) ? Notifs.relLabel(card.notification.id) : "";
                    if (!card.showAppName)
                        return age;

                    return age ? card.appName + " · " + age : card.appName;
                }
                color: card.critical ? Theme.error : Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.letterSpacing: 0.3
                elide: Text.ElideRight
            }

            Item {
                id: trailingHolder

                anchors.right: parent.right
                anchors.top: parent.top
                implicitWidth: childrenRect.width
                implicitHeight: childrenRect.height
                width: implicitWidth
                height: implicitHeight
            }

            Item {
                id: closeButton

                anchors.right: parent.right
                anchors.top: parent.top
                width: 22
                height: 22
                visible: card.showClose && card.interactive && !card.hasTrailing

                NotifIcon {
                    anchors.centerIn: parent
                    size: 15
                    path: Notifs.icons.close
                    color: closeArea.containsMouse ? Theme.text : Theme.subtextDim
                    opacity: hover.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.ms(140)
                        }

                    }

                }

                MouseArea {
                    id: closeArea

                    anchors.fill: parent
                    anchors.margins: -3
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.dismiss(card.notification)
                }

            }

        }

        Text {
            width: parent.width - card.textLeft
            x: card.textLeft
            visible: card.summary !== ""
            text: card.summary
            color: Theme.text
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fs(12)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Text {
            width: parent.width - card.textLeft
            x: card.textLeft
            visible: card.body !== "" && Prefs.toastShowBody
            text: card.body
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(11)
            lineHeight: 1.15
            wrapMode: Text.WordWrap
            maximumLineCount: card.bodyLines > 0 ? card.bodyLines : 99
            elide: Text.ElideRight
            textFormat: Text.StyledText
            linkColor: card.tint
        }

        Item {
            width: parent.width
            height: 4
            visible: card.progress >= 0
        }

        NotifProgress {
            width: parent.width - card.textLeft
            x: card.textLeft
            visible: card.progress >= 0
            value: card.progress
            color: card.tint
        }

        Item {
            width: parent.width
            height: 6
            visible: actionRow.hasAny
        }

        NotifActions {
            id: actionRow

            width: parent.width - card.textLeft
            x: card.textLeft
            visible: Prefs.toastShowActions && card.interactive
            notification: card.notification
            actionList: card.actionList
            onReplyToggled: (open) => {
                card.replyOpen = open;
                card.replyToggled(open);
            }
        }

    }

}
