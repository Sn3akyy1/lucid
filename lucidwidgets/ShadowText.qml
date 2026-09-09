import QtQuick
import qs

Item {
    id: st

    property string text: ""
    property color color: Theme.text
    property int pixelSize: 16
    property bool bold: false
    property real letterSpacing: 0
    property bool shadow: false
    property int horizontalAlignment: Text.AlignLeft

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        anchors.fill: parent
        anchors.topMargin: 1.5
        anchors.leftMargin: 0.5
        text: st.text
        color: Qt.rgba(0, 0, 0, 0.45)
        font.family: Theme.fontFamily
        font.pixelSize: st.pixelSize
        font.bold: st.bold
        font.letterSpacing: st.letterSpacing
        horizontalAlignment: st.horizontalAlignment
        visible: st.shadow
    }

    Text {
        id: label

        anchors.fill: parent
        text: st.text
        color: st.color
        font.family: Theme.fontFamily
        font.pixelSize: st.pixelSize
        font.bold: st.bold
        font.letterSpacing: st.letterSpacing
        horizontalAlignment: st.horizontalAlignment
    }

}
