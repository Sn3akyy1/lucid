import QtQuick
import QtQuick.Controls.Basic
import qs

Item {
    id: picker

    property bool shown: false
    readonly property var families: Qt.fontFamilies()
    property string filter: ""
    readonly property var matches: {
        var q = picker.filter.trim().toLowerCase();
        if (q === "")
            return picker.families;

        var out = [];
        for (var i = 0; i < picker.families.length; i++) {
            if (picker.families[i].toLowerCase().indexOf(q) !== -1)
                out.push(picker.families[i]);
        }
        return out;
    }

    function open() {
        picker.filter = "";
        picker.shown = true;
        searchInput.forceActiveFocus();
        var idx = picker.matches.indexOf(Theme.fontFamily);
        list.positionViewAtIndex(idx < 0 ? 0 : idx, ListView.Center);
    }

    function dismiss() {
        picker.shown = false;
    }

    function choose(family) {
        Prefs.fontFamily = family;
        picker.dismiss();
    }

    anchors.fill: parent
    visible: picker.shown || picker.opacity > 0.01
    opacity: picker.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
            easing.type: Theme.easeStandard
        }

    }

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.cShadow, 0.55)

        MouseArea {
            anchors.fill: parent
            onClicked: picker.dismiss()
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

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeEmphasized
                easing.overshoot: Theme.emphasizedOvershoot
            }

        }

        MouseArea {
            anchors.fill: parent
        }

        Text {
            id: cardTitle

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 22
            text: "Interface font"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(17)
            font.bold: true
        }

        Rectangle {
            id: searchBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cardTitle.bottom
            anchors.leftMargin: 22
            anchors.rightMargin: 22
            anchors.topMargin: 14
            height: 40
            radius: Theme.radiusSm
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
                font.pixelSize: Theme.fontBody
                selectByMouse: true
                selectionColor: Theme.accent
                selectedTextColor: Theme.onAccent
                clip: true
                onTextChanged: picker.filter = searchInput.text
                Keys.onEscapePressed: picker.dismiss()
                Keys.onReturnPressed: {
                    if (picker.matches.length > 0)
                        picker.choose(picker.matches[0]);

                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "Search " + picker.families.length + " installed fonts"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                visible: searchInput.text === ""
            }

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
            cacheBuffer: 400

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
                id: fontRow

                required property string modelData

                readonly property bool current: fontRow.modelData === Theme.fontFamily

                width: list.width - 14
                height: 44
                radius: Theme.radiusSm
                color: fontRow.current ? Theme.accentContainer : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: fontRow.modelData
                    font.family: fontRow.modelData
                    font.pixelSize: Theme.fontTitle
                    color: fontRow.current ? Theme.text : Theme.subtext
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.choose(fontRow.modelData)
                }

            }

        }

    }

}
