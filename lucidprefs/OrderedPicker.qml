import QtQuick
import qs

// a list to pick from and put in order, as the power module's actions are:
// the ones switched on first, in their order, with arrows to move them, then
// the rest. value is the comma list the pref keeps
Column {
    id: picker

    // [{ "id", "label", "note" (optional) }]
    property var catalogue: []
    property string value: ""
    // how many must stay switched on
    property int minimum: 0
    readonly property var chosen: String(picker.value || "").split(",").filter((id, i, all) => {
        return all.indexOf(id) === i && picker.catalogue.some((a) => {
            return a.id === id;
        });
    })
    readonly property var rows: picker.chosen.concat(picker.catalogue.map((a) => {
        return a.id;
    }).filter((id) => {
        return picker.chosen.indexOf(id) === -1;
    }))

    signal picked(string value)

    spacing: Theme.dp(6)

    Repeater {
        model: picker.rows

        Rectangle {
            id: row

            required property string modelData
            readonly property var entry: picker.catalogue.find((a) => {
                return a.id === row.modelData;
            })
            readonly property int at: picker.chosen.indexOf(row.modelData)
            readonly property bool isOn: row.at !== -1

            function move(by) {
                const l = picker.chosen.slice();
                l.splice(row.at, 1);
                l.splice(row.at + by, 0, row.modelData);
                picker.picked(l.join(","));
            }

            width: picker.width
            height: Theme.dp(52)
            radius: Theme.radiusMd
            color: Theme.bgSunken

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.dp(16)
                anchors.right: tools.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: row.entry ? row.entry.label : row.modelData
                    color: row.isOn ? Theme.text : Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    elide: Text.ElideRight
                }

                Text {
                    visible: !!(row.entry && row.entry.note)
                    width: parent.width
                    text: row.entry && row.entry.note ? row.entry.note : ""
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    elide: Text.ElideRight
                }

            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(2)

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(34)
                    enabled: row.isOn && row.at > 0
                    iconPath: "arrow_upward"
                    onClicked: row.move(-1)
                }

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Theme.dp(34)
                    enabled: row.isOn && row.at < picker.chosen.length - 1
                    iconPath: "arrow_downward"
                    onClicked: row.move(1)
                }

                M3Switch {
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: !row.isOn || picker.chosen.length > picker.minimum
                    checked: row.isOn
                    onToggled: (v) => {
                        const l = picker.chosen.filter((id) => {
                            return id !== row.modelData;
                        });
                        if (v)
                            l.push(row.modelData);

                        picker.picked(l.join(","));
                    }
                }

            }

        }

    }

}
