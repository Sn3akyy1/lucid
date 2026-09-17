import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs

// the app's icon, its supplied image, or its initial as a last resort
Item {
    id: avatar

    property var notification: null
    property int size: 28
    readonly property string img: avatar.notification ? avatar.notification.image : ""
    readonly property string themeIconName: {
        if (!avatar.notification)
            return "";

        return avatar.notification.appIcon || (avatar.img.indexOf("image://icon/") === 0 ? avatar.img.slice(13) : "");
    }
    readonly property string directImage: avatar.img.indexOf("image://icon/") === 0 ? "" : avatar.img
    readonly property string source: avatar.directImage || (avatar.themeIconName ? Quickshell.iconPath(avatar.themeIconName, true) : "")
    property bool ready: false
    readonly property bool critical: avatar.notification && avatar.notification.urgency === NotificationUrgency.Critical
    readonly property color tint: avatar.critical ? Theme.error : Theme.accent

    implicitWidth: avatar.size
    implicitHeight: avatar.size
    Component.onCompleted: avatar.ready = true

    IconImage {
        id: img

        anchors.fill: parent
        source: avatar.ready ? avatar.source : ""
        asynchronous: true
        visible: avatar.ready && status === Image.Ready
    }

    // no icon: a flat tonal disc carrying the app's initial
    Rectangle {
        anchors.fill: parent
        visible: !img.visible
        radius: width / 2
        color: Theme.bgHigh

        NotifIcon {
            anchors.centerIn: parent
            visible: avatar.critical
            size: Math.round(avatar.size * 0.62)
            path: Notifs.icons.notifications_active
            color: avatar.tint
        }

        Text {
            anchors.centerIn: parent
            visible: !avatar.critical
            text: ((avatar.notification ? avatar.notification.appName : "") || "?").charAt(0).toUpperCase()
            color: avatar.tint
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Math.round(avatar.size * 0.45)
        }

    }

}
