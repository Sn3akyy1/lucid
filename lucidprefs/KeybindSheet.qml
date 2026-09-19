import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs

// every keybind at a glance, over whatever is on screen. ipc target "keybinds";
// Hyprland reaches it through the "keybinds-sheet" entry in keybinds.json
PanelWindow {
    id: sheet

    property bool open: false
    property string query: ""
    readonly property int gutter: 16
    readonly property int minColumn: 380
    readonly property var shownBinds: {
        var q = sheet.query.trim().toLowerCase();
        return Keybinds.binds.filter((b) => {
            return b.enabled !== false && Keybinds.matches(b, q);
        });
    }
    readonly property int columnCount: Math.max(1, Math.min(4, Math.floor((body.width + sheet.gutter) / (sheet.minColumn + sheet.gutter))))
    // categories dealt out in file order, each to whichever column is shortest
    readonly property var columns: {
        var cols = [];
        var heights = [];
        for (var i = 0; i < sheet.columnCount; i++) {
            cols.push([]);
            heights.push(0);
        }
        var cats = Keybinds.categories;
        for (var c = 0; c < cats.length; c++) {
            var n = sheet.shownBinds.filter((b) => {
                return Keybinds.categoryOf(b) === cats[c];
            }).length;
            if (n === 0)
                continue;

            var best = 0;
            for (var j = 1; j < heights.length; j++) {
                if (heights[j] < heights[best])
                    best = j;

            }
            cols[best].push(cats[c]);
            heights[best] += n + 2.5;
        }
        return cols;
    }
    readonly property string problem: {
        if (Keybinds.parseError !== "")
            return "keybinds.json does not parse: " + Keybinds.parseError;

        if (Keybinds.emergency)
            return "Emergency binds active — " + (Keybinds.status.error || "keybinds.json could not be used");

        var n = Object.keys(Keybinds.failed).length;
        return n > 0 ? n + (n === 1 ? " keybind" : " keybinds") + " did not apply — shown in red" : "";
    }

    function show() {
        searchInput.text = "";
        sheet.query = "";
        body.contentY = 0;
        sheet.open = true;
        focusTimer.restart();
    }

    function hide() {
        sheet.open = false;
    }

    function edit() {
        sheet.hide();
        Prefs.settingsRequested("keybinds");
    }

    function editBind(id) {
        sheet.edit();
        Keybinds.editRequested(id);
    }

    color: "transparent"
    visible: sheet.open || card.opacity > 0.01
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: sheet.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "lucidkeybinds"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // the layer only takes the keyboard once it is mapped
    Timer {
        id: focusTimer

        interval: 40
        onTriggered: searchInput.forceActiveFocus()
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            if (sheet.open)
                sheet.hide();
            else
                sheet.show();
        }

        function open(): void {
            sheet.show();
        }

        function close(): void {
            sheet.hide();
        }

        // straight to Settings -> Keybinds
        function edit(): void {
            sheet.edit();
        }

        // the same, with one bind's editor already open
        function editBind(id: string): void {
            sheet.editBind(id);
        }

    }

    Connections {
        function onSheetRequested() {
            sheet.show();
        }

        target: Keybinds
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.5)
        opacity: sheet.open ? 1 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.hide()
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(1360, sheet.width - 96)
        height: Math.min(940, sheet.height - 96)
        radius: Theme.shapeXl
        color: Theme.bgOpaque
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.5)
        opacity: sheet.open ? 1 : 0
        scale: sheet.open ? 1 : 0.96

        // clicks on the card must not reach the dimmer
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: header

            x: 30
            y: 22
            width: parent.width - 60
            height: 60

            Column {
                anchors.left: parent.left
                anchors.right: tools.left
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: "Keybinds"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadlineSm
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: sheet.problem !== "" ? sheet.problem : sheet.shownBinds.length + (sheet.shownBinds.length === 1 ? " keybind" : " keybinds") + " · click one to change it · " + (Keybinds.sheetKeys !== "" ? Keybinds.sheetKeys + " or " : "") + "Esc to close"
                    color: sheet.problem !== "" ? Theme.error : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    elide: Text.ElideRight
                }

            }

            Row {
                id: tools

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(320, Math.max(180, card.width * 0.26))
                    height: 44
                    radius: height / 2
                    color: Theme.bgSunken
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.outline

                    Shape {
                        id: searchIcon

                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeWidth: 0
                            fillColor: Theme.subtext

                            PathSvg {
                                path: "M15.5 14h-.79l-.28-.27A6.47 6.47 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5Zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14Z"
                            }

                        }

                        transform: Scale {
                            xScale: 20 / 24
                            yScale: 20 / 24
                        }

                    }

                    TextInput {
                        id: searchInput

                        anchors.left: searchIcon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.fgAccent
                        clip: true
                        onTextChanged: sheet.query = searchInput.text
                        Keys.onEscapePressed: {
                            if (searchInput.text !== "")
                                searchInput.text = "";
                            else
                                sheet.hide();
                        }
                    }

                    Text {
                        anchors.left: searchInput.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Type to search"
                        color: Theme.subtextDim
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                    }

                }

                M3Button {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Edit keybinds"
                    variant: "filled"
                    iconPath: "M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25ZM20.71 7.04a1 1 0 0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83Z"
                    onClicked: sheet.edit()
                }

                M3IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    iconSize: 21
                    iconPath: "M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41Z"
                    onClicked: sheet.hide()
                }

            }

        }

        Flickable {
            id: body

            anchors.top: header.bottom
            anchors.topMargin: 18
            anchors.left: parent.left
            anchors.leftMargin: 30
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            contentWidth: width
            contentHeight: columnsRow.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: columnsRow

                width: body.width
                spacing: sheet.gutter

                Repeater {
                    model: sheet.columns

                    Column {
                        id: column

                        required property var modelData

                        width: (columnsRow.width - (sheet.columnCount - 1) * sheet.gutter) / sheet.columnCount
                        spacing: sheet.gutter

                        Repeater {
                            model: column.modelData

                            Rectangle {
                                id: group

                                required property string modelData
                                readonly property var items: sheet.shownBinds.filter((b) => {
                                    return Keybinds.categoryOf(b) === group.modelData;
                                })

                                width: column.width
                                height: groupCol.implicitHeight + 30
                                radius: Theme.shapeLg
                                color: Theme.bgTile

                                Column {
                                    id: groupCol

                                    x: 18
                                    y: 14
                                    width: parent.width - 36

                                    Text {
                                        text: group.modelData
                                        color: Theme.accent
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontTitleSm
                                        font.weight: Font.DemiBold
                                        bottomPadding: 8
                                    }

                                    Repeater {
                                        model: group.items

                                        Item {
                                            id: line

                                            required property var modelData
                                            readonly property bool broken: Keybinds.failed[line.modelData.id] !== undefined

                                            width: groupCol.width
                                            height: 34

                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.leftMargin: -8
                                                anchors.rightMargin: -8
                                                radius: Theme.shapeSm
                                                color: Theme.text
                                                opacity: lineArea.containsMouse ? Theme.stateHover : 0
                                            }

                                            MouseArea {
                                                id: lineArea

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sheet.editBind(line.modelData.id)
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.right: lineKeys.left
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Keybinds.displayDesc(line.modelData)
                                                color: line.broken ? Theme.error : Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontBodyMd
                                                elide: Text.ElideRight
                                            }

                                            KeyCombo {
                                                id: lineKeys

                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                keys: line.modelData.keys
                                                capHeight: 25
                                                fontSize: Theme.fontLabelMd
                                            }

                                        }

                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        Text {
            anchors.centerIn: body
            visible: sheet.shownBinds.length === 0
            text: Keybinds.binds.length === 0 ? "No keybinds yet — add some in Settings" : "Nothing matches “" + sheet.query.trim() + "”"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Theme.easeStandard
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

    }

}
