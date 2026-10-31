import QtQuick
import QtQuick.Window
import qs
import qs.lucidui

// the original lens kept of an edited picture, held up in its place while
// compare is held, fitted as the stage fits a picture: never past 100%
Item {
    id: peek

    required property var win
    required property var stage
    readonly property var kept: peek.win.kept
    readonly property bool shown: peek.win.peeking && img.status === Image.Ready

    visible: opacity > 0
    opacity: peek.shown ? 1 : 0

    // decoded once the details say there is one, so a press shows it at once
    Image {
        id: img

        readonly property real natW: peek.kept && peek.kept.w ? peek.kept.w : img.implicitWidth
        readonly property real natH: peek.kept && peek.kept.h ? peek.kept.h : img.implicitHeight
        readonly property real fit: img.natW > 0 && img.natH > 0 ? Math.min(1, (peek.width - 2 * peek.stage.pad) / img.natW, (peek.height - 2 * peek.stage.pad) / img.natH) : 1

        x: Math.round((peek.width - width) / 2)
        y: Math.round((peek.height - height) / 2)
        width: Math.round(img.natW * img.fit)
        height: Math.round(img.natH * img.fit)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        autoTransform: true
        cache: false
        smooth: true
        mipmap: true
        source: peek.kept && !peek.win.isVideo ? peek.win.app.uriOf(peek.kept.file) : ""
        sourceSize: Qt.size(Math.max(1920, Screen.width), Math.max(1080, Screen.height))
    }

    // which of the two is on show
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dp(16)
        width: label.implicitWidth + Theme.dp(28)
        height: Theme.dp(36)
        radius: height / 2
        color: Theme.alpha(Theme.surfaceHigh, 0.86)

        LText {
            id: label

            anchors.centerIn: parent
            role: "labelLarge"
            text: "Original"
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

}
