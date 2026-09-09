import QtQuick
import qs

SettingCard {
    id: card

    required property var dev

    readonly property var sinks: card.dev.sinks || []

    title: "SOUND ON THE PHONE"

    Repeater {
        model: card.sinks

        SettingRow {
            id: sinkRow

            required property var modelData
            required property int index

            readonly property int maxVol: sinkRow.modelData.maxVolume > 0 ? sinkRow.modelData.maxVolume : 100

            title: sinkRow.modelData.description || sinkRow.modelData.name
            description: sinkRow.modelData.muted ? "Muted" : Math.round((sinkRow.modelData.volume / sinkRow.maxVol) * 100) + "%"
            stacked: true
            showDivider: sinkRow.index < card.sinks.length - 1

            Row {
                width: parent.width
                spacing: 14

                M3Slider {
                    width: parent.width - 110
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !sinkRow.modelData.muted
                    showReadout: false
                    from: 0
                    to: sinkRow.maxVol
                    value: sinkRow.modelData.volume
                    onMoved: (v) => {
                        return KdeConnect.sinkVolume(card.dev.id, sinkRow.modelData.name, Math.round(v));
                    }
                }

                CheckLine {
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Mute"
                    checked: !!sinkRow.modelData.muted
                    onToggled: KdeConnect.sinkMute(card.dev.id, sinkRow.modelData.name, !sinkRow.modelData.muted)
                }

            }

        }

    }

}
