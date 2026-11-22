import QtQuick
import qs
import qs.lucidui
import "parts"

// previous, play and next for LockMedia: m3's filled play pill between two bare skips
Row {
    id: part

    property var media: null

    property real big: Theme.dp(40)

    spacing: 0

    LockIconButton {
        anchors.verticalCenter: parent.verticalCenter
        diameter: parent.big * 0.9
        glyphSize: parent.big * 0.48
        glyph: "prev"
        glyphColor: Theme.subtext
        actionable: !!media.player && media.player.canGoPrevious && !media.editing
        onClicked: media.player.previous()
    }

    // the one filled thing on the card: m3's play pill
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(parent.big * 1.3)
        height: parent.big
        radius: media.playing ? Theme.shapeMd : height / 2
        color: playHover.hovered ? Theme.accentHover : Theme.accent
        scale: playTap.pressed ? 0.92 : 1

        Behavior on radius {
            NumberAnimation {
                duration: Theme.ms(260)
                easing.type: Easing.OutCubic
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.ms(110)
                easing.type: Easing.OutCubic
            }

        }

        LockGlyph {
            anchors.centerIn: parent
            name: media.playing ? "pause" : "play"
            size: Math.round(parent.height * 0.5)
            color: Theme.fgAccent
        }

        HoverHandler {
            id: playHover

            enabled: parent.enabled && !media.editing
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: playTap

            enabled: !!media.player && media.player.canTogglePlaying && !media.editing
            onTapped: media.player.togglePlaying()
        }

    }

    LockIconButton {
        anchors.verticalCenter: parent.verticalCenter
        diameter: parent.big * 0.9
        glyphSize: parent.big * 0.48
        glyph: "next"
        glyphColor: Theme.subtext
        actionable: !!media.player && media.player.canGoNext && !media.editing
        onClicked: media.player.next()
    }

}
