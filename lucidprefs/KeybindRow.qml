import QtQuick
import qs

// one keybind inside a Settings -> Keybinds group: its keys, what it does, and
// whether it is on. click anywhere else on it to edit
Item {
    id: row

    readonly property bool isGroupItem: true
    // written by the enclosing SettingCard
    property bool groupFirst: true
    property bool groupLast: true
    property var bind: null
    readonly property string bindId: row.bind ? row.bind.id : ""
    readonly property bool on: !!row.bind && row.bind.enabled !== false
    readonly property string failure: Keybinds.failed[row.bindId] || ""
    readonly property string clashText: {
        var ids = Keybinds.conflicts[row.bindId] || [];
        if (!row.on || ids.length === 0)
            return "";

        return "Same keys as " + ids.map((id) => {
            var b = Keybinds.find(id);
            return b ? "“" + Keybinds.displayDesc(b) + "”" : id;
        }).join(", ") + " — both fire";
    }
    readonly property string problem: row.failure !== "" ? "Did not bind: " + row.failure : row.clashText
    readonly property int outerRadius: 26
    readonly property int innerRadius: 6
    readonly property int keysWidth: Math.min(280, Math.round(row.width * 0.32))

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(64, texts.implicitHeight + 26)

    Rectangle {
        anchors.fill: parent
        topLeftRadius: row.groupFirst ? row.outerRadius : row.innerRadius
        topRightRadius: row.groupFirst ? row.outerRadius : row.innerRadius
        bottomLeftRadius: row.groupLast ? row.outerRadius : row.innerRadius
        bottomRightRadius: row.groupLast ? row.outerRadius : row.innerRadius
        color: Theme.withBlur(Theme.bgTile)

        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Theme.text
            opacity: area.pressed ? Theme.statePressed * 0.6 : (area.containsMouse ? Theme.stateHover * 0.5 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

    }

    // under the controls, so the switch and buttons keep their own clicks
    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Keybinds.editRequested(row.bindId)
    }

    Item {
        id: keysBox

        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: row.keysWidth
        height: combo.height
        clip: true

        KeyCombo {
            id: combo

            keys: row.bind ? row.bind.keys : ""
            dim: !row.on
        }

    }

    Column {
        id: texts

        anchors.left: keysBox.right
        anchors.leftMargin: 18
        anchors.right: controls.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            text: Keybinds.displayDesc(row.bind)
            color: row.failure !== "" ? Theme.error : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            font.weight: Font.Medium
            opacity: row.on ? 1 : 0.5
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: Keybinds.summary(row.bind)
            visible: text !== "" && !!row.bind && !!row.bind.desc
            color: Theme.subtext
            font.family: "monospace"
            font.pixelSize: Theme.fontBodySm
            opacity: row.on ? 0.9 : 0.45
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: row.problem
            visible: row.problem !== ""
            color: Theme.error
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodySm
            wrapMode: Text.WordWrap
        }

    }

    Row {
        id: controls

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        M3Switch {
            anchors.verticalCenter: parent.verticalCenter
            checked: row.on
            enabled: Keybinds.parseError === ""
            onToggled: (v) => {
                return Keybinds.setEnabled(row.bindId, v);
            }
        }

        Item {
            width: 8
            height: 1
        }

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 38
            iconSize: 19
            iconPath: "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25ZM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z"
            onClicked: Keybinds.editRequested(row.bindId)
        }

        M3IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 38
            iconSize: 19
            destructive: true
            enabled: Keybinds.parseError === ""
            iconPath: "M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12ZM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4Z"
            onClicked: Prefs.askConfirm("Delete this keybind?", "“" + Keybinds.displayDesc(row.bind) + "” (" + Keybinds.tokens(row.bind.keys).join(" + ") + ") is removed from keybinds.json and Hyprland reloads without it.", "Delete", "keybind-delete:" + row.bindId)
        }

    }

}
