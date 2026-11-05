import QtQuick
import qs
import qs.lucidicons

// an app's icon as the dock draws it: its tile in lucid's icons, else the theme's
Item {
    id: appIcon

    property var app: null
    property string source: ""
    property real size: Theme.dp(24)
    property bool hovered: false
    readonly property string lucidSlot: !appIcon.app || Prefs.envLegacyIcons ? "" : LucidIcons.slotFor(appIcon.app.appId, appIcon.app.icon, appIcon.app.name)

    width: appIcon.size
    height: appIcon.size

    // never off the main thread: an icon theme source loaded
    // asynchronously takes the whole shell down
    Image {
        anchors.fill: parent
        visible: appIcon.lucidSlot === ""
        sourceSize.width: appIcon.size * 2
        sourceSize.height: appIcon.size * 2
        source: appIcon.lucidSlot === "" ? appIcon.source : ""
        smooth: true
    }

    Loader {
        anchors.centerIn: parent
        active: appIcon.lucidSlot !== ""

        sourceComponent: TonalIcon {
            size: appIcon.size
            slot: appIcon.lucidSlot
            hovered: appIcon.hovered
        }

    }

}
