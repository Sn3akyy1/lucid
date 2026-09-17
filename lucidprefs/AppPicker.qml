import QtQuick
import QtQuick.Controls.Basic
import qs

// every installed app, for the workspaces page to put one in a special workspace
Item {
    id: picker

    readonly property int wheelStep: 190
    property bool shown: false
    property string workspace: ""
    property string heading: ""
    property var items: []
    property string filter: ""
    readonly property var matches: {
        var q = picker.filter.trim().toLowerCase();
        if (q === "")
            return picker.items;

        var out = [];
        for (var i = 0; i < picker.items.length; i++) {
            var a = picker.items[i];
            if (a.name.toLowerCase().indexOf(q) !== -1 || a.id.toLowerCase().indexOf(q) !== -1 || a.note.toLowerCase().indexOf(q) !== -1)
                out.push(a);

        }
        return out;
    }

    signal chosen(string workspace, string entryId)

    function open(ws) {
        picker.workspace = ws;
        picker.heading = "Add an app to " + Specials.label(ws);
        picker.items = Specials.installedApps(ws);
        picker.filter = "";
        searchInput.text = "";
        picker.shown = true;
        searchInput.forceActiveFocus();
        list.positionViewAtBeginning();
    }

    function dismiss() {
        picker.shown = false;
    }

    function choose(entryId) {
        picker.chosen(picker.workspace, entryId);
        picker.dismiss();
    }

    anchors.fill: parent
    visible: picker.shown || picker.opacity > 0.01
    opacity: picker.shown ? 1 : 0

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.dismiss()
        }

        // the pane behind is still scrollable, so the dimmer has to eat these
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                return event.accepted = true;
            }
        }

    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(460, picker.width - 80)
        height: Math.min(520, picker.height - 80)
        radius: Theme.radiusXl
        color: Theme.bgHigh
        clip: true
        scale: picker.shown ? 1 : 0.92

        MouseArea {
            anchors.fill: parent
        }

        Text {
            id: cardTitle

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            text: picker.heading
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHeadlineSm
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cardTitle.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 14
            height: 46
            radius: Theme.shapeLg
            color: Theme.bgSunken
            border.width: searchInput.activeFocus ? 2 : 1
            border.color: searchInput.activeFocus ? Theme.accent : Theme.outlineStrong

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.fgAccent
                clip: true
                onTextChanged: picker.filter = searchInput.text
                Keys.onEscapePressed: picker.dismiss()
                Keys.onReturnPressed: {
                    if (picker.matches.length > 0)
                        picker.choose(picker.matches[0].id);

                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Search " + picker.items.length + " installed apps"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
                visible: searchInput.text === ""
            }

        }

        Text {
            anchors.centerIn: parent
            width: card.width - 60
            text: picker.items.length === 0 ? "Nothing left to add" : "No apps match “" + picker.filter + "”"
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyLg
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: picker.matches.length === 0
        }

        ListView {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchBox.bottom
            anchors.bottom: parent.bottom
            anchors.margins: 12
            anchors.topMargin: 10
            clip: true
            model: picker.matches
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 6000
            maximumFlickVelocity: 9000
            cacheBuffer: 400

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    event.accepted = true;
                    var maxY = Math.max(0, list.contentHeight - list.height);
                    var base = listScroll.running ? listScroll.to : list.contentY;
                    var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * picker.wheelStep));
                    if (target === base)
                        return ;

                    listScroll.stop();
                    listScroll.from = list.contentY;
                    listScroll.to = target;
                    listScroll.start();
                }
            }

            NumberAnimation {
                id: listScroll

                target: list
                property: "contentY"
                duration: Theme.ms(170)
                easing.type: Easing.OutCubic
            }

            ScrollBar.vertical: ScrollBar {
                id: listBar

                policy: ScrollBar.AlwaysOn
                width: 10

                contentItem: Rectangle {
                    implicitWidth: listBar.hovered || listBar.pressed ? 8 : 5
                    radius: width / 2
                    color: listBar.pressed ? Theme.accent : (listBar.hovered ? Theme.alpha(Theme.text, 0.4) : Theme.alpha(Theme.text, 0.2))

                    Behavior on implicitWidth {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                background: Rectangle {
                    color: "transparent"
                }

            }

            delegate: Rectangle {
                id: appRow

                required property var modelData

                width: list.width - 14
                height: 54
                radius: Theme.shapeLg
                color: rowArea.containsMouse ? Theme.bgHover : "transparent"

                Image {
                    id: appIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    visible: appRow.modelData.icon !== ""
                    source: appRow.modelData.icon
                    sourceSize.width: 56
                    sourceSize.height: 56
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }

                Column {
                    anchors.left: appIcon.visible ? appIcon.right : parent.left
                    anchors.leftMargin: appIcon.visible ? 12 : 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: appRow.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        color: Theme.text
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: appRow.modelData.note
                        visible: appRow.modelData.note !== ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelSm
                        color: Theme.subtextDim
                        elide: Text.ElideRight
                    }

                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.choose(appRow.modelData.id)
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

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

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

}
