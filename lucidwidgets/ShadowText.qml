import QtQuick
import qs

Item {
    id: st

    property string text: ""
    property color color: Theme.text
    property int pixelSize: Theme.dp(16)
    property bool bold: false
    property real weight: st.bold ? 640 : 420
    property real rounded: 0
    property real letterSpacing: 0
    property bool shadow: false
    property int horizontalAlignment: Text.AlignLeft
    property int elide: Text.ElideNone

    // an eliding label reports its elided width, so measure the full run instead
    implicitWidth: st.elide === Text.ElideNone ? label.implicitWidth : Math.ceil(full.advanceWidth)
    implicitHeight: label.implicitHeight

    Text {
        anchors.fill: parent
        anchors.topMargin: 1.5
        anchors.leftMargin: 0.5
        text: st.text
        color: Qt.rgba(0, 0, 0, 0.45)
        font.family: Theme.fontFamily
        font.pixelSize: st.pixelSize
        font.variableAxes: Theme.axes(st.pixelSize, st.weight, st.rounded)
        font.bold: st.bold
        font.letterSpacing: st.letterSpacing
        horizontalAlignment: st.horizontalAlignment
        elide: st.elide
        visible: st.shadow
    }

    TextMetrics {
        id: full

        font: label.font
        text: st.text
    }

    Text {
        id: label

        anchors.fill: parent
        text: st.text
        color: st.color
        font.family: Theme.fontFamily
        font.pixelSize: st.pixelSize
        font.variableAxes: Theme.axes(st.pixelSize, st.weight, st.rounded)
        font.bold: st.bold
        font.letterSpacing: st.letterSpacing
        horizontalAlignment: st.horizontalAlignment
        elide: st.elide
    }

}
