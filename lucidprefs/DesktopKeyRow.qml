import QtQuick
import qs

// one of the desktop icons' keys: its keycaps, and a change recorded in place. while it
// records hyprland sits in the capture submap, so a combo it binds itself still arrives here
SettingRow {
    id: dk

    required property var action
    // the page's one recording row, so only one listens at a time
    property string recordingId: ""
    readonly property bool recording: dk.recordingId === dk.action.id
    readonly property string keys: DesktopIcons.keysFor(dk.action.id)
    readonly property string clash: DesktopIcons.clashOf(dk.action.id)
    readonly property bool changed: DesktopIcons.keyOverrides[dk.action.id] !== undefined
    // a combo is in: wait for the keys to come up before hyprland gets them back
    property bool awaitingRelease: false

    signal startRecording(string id)
    signal stopRecording()

    function finish() {
        releaseGuard.stop();
        dk.awaitingRelease = false;
        dk.stopRecording();
    }

    title: dk.action.label
    description: dk.recording ? I18n.tr("Press the keys you want. Esc cancels, Backspace leaves it without a key.") : (dk.keys === "" ? I18n.tr("No key") : "")
    warning: dk.clash !== "" ? I18n.tr("Same keys as %1: the one higher in this list wins.", dk.clash) : ""
    onRecordingChanged: {
        if (dk.recording) {
            dk.awaitingRelease = false;
            sink.forceActiveFocus();
        }
    }

    Timer {
        id: releaseGuard

        interval: 900
        onTriggered: dk.finish()
    }

    Row {
        spacing: Theme.dp(8)

        // every key comes here while this row records
        Item {
            id: sink

            width: 1
            height: 1
            Keys.onPressed: (e) => {
                e.accepted = true;
                if (!dk.recording || dk.awaitingRelease)
                    return ;

                if (e.modifiers === Qt.NoModifier && e.key === Qt.Key_Escape) {
                    dk.finish();
                    return ;
                }
                if (e.modifiers === Qt.NoModifier && e.key === Qt.Key_Backspace) {
                    DesktopIcons.setKeys(dk.action.id, "");
                    dk.finish();
                    return ;
                }
                var combo = Keybinds.comboFromEvent(e);
                if (combo === "")
                    return ;

                DesktopIcons.setKeys(dk.action.id, combo);
                dk.awaitingRelease = true;
                releaseGuard.restart();
            }
            Keys.onReleased: (e) => {
                e.accepted = true;
                if (dk.awaitingRelease && !e.isAutoRepeat && (e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier | Qt.MetaModifier)) === 0)
                    dk.finish();

            }
        }

        KeyCombo {
            anchors.verticalCenter: parent.verticalCenter
            visible: dk.keys !== "" && !dk.recording
            keys: dk.keys
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: dk.recording
            width: listening.implicitWidth + Theme.dp(20)
            height: Theme.dp(28)
            radius: Theme.dp(7)
            color: Theme.alpha(Theme.accent, 0.12)
            border.width: 2
            border.color: Theme.accent

            Text {
                id: listening

                anchors.centerIn: parent
                text: I18n.tr("Press keys…")
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.DemiBold
            }

        }

        M3Button {
            anchors.verticalCenter: parent.verticalCenter
            text: dk.recording ? I18n.tr("Cancel") : I18n.tr("Change")
            variant: dk.recording ? "filled" : "tonal"
            onClicked: dk.recording ? dk.finish() : dk.startRecording(dk.action.id)
        }

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: dk.changed && !dk.recording
            size: Theme.dp(36)
            iconPath: "restart_alt"
            onClicked: DesktopIcons.resetKeys(dk.action.id)
        }

    }

}
