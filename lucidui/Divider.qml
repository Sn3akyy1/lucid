import QtQuick
import qs

Rectangle {
    property bool vertical: false

    implicitWidth: vertical ? 1 : Theme.dp(100)
    implicitHeight: vertical ? Theme.dp(100) : 1
    color: Theme.divider
}
