import QtQuick
import qs
import qs.lucidui

// a page's symbol in the rail; it fills in once the page is open
Item {
    id: glyph

    property string kind: "general"
    property color color: Theme.subtext
    property bool active: false

    implicitWidth: Theme.dp(22)
    implicitHeight: Theme.dp(22)

    Icon {
        anchors.centerIn: parent
        name: Prefs.settingsPage(glyph.kind) ? Prefs.settingsPage(glyph.kind).icon : "settings"
        size: Theme.dp(22)
        fill: glyph.active ? 1 : 0
        color: glyph.color
    }

}
