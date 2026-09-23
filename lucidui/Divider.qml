import QtQuick
import qs

Rectangle {
    property bool vertical: false

    implicitWidth: vertical ? 1 : 100
    implicitHeight: vertical ? 100 : 1
    color: Theme.divider
}
