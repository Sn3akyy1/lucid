import QtQuick
import QtQuick.Controls.Basic
import Quickshell.Io
import qs

Item {
    id: picker

    readonly property int wheelStep: 190
    property bool shown: false
    property var zones: []
    property string filter: ""
    readonly property var matches: {
        var q = picker.filter.trim().toLowerCase().replace(/ /g, "_");
        if (q === "")
            return picker.zones;

        var out = [];
        for (var i = 0; i < picker.zones.length; i++) {
            if (picker.zones[i].toLowerCase().indexOf(q) !== -1)
                out.push(picker.zones[i]);

        }
        return out;
    }

    function open() {
        picker.filter = "";
        picker.shown = true;
        searchInput.text = "";
        searchInput.forceActiveFocus();
        if (picker.zones.length === 0)
            zoneScan.running = true;
        else
            picker.scrollToCurrent();
    }

    function scrollToCurrent() {
        var idx = picker.matches.indexOf(Loc.zone);
        list.positionViewAtIndex(idx < 0 ? 0 : idx, ListView.Center);
    }

    function dismiss() {
        picker.shown = false;
    }

    function choose(zone) {
        Loc.setZone(zone);
        picker.dismiss();
    }

    anchors.fill: parent
    visible: picker.shown || picker.opacity > 0.01
    opacity: picker.shown ? 1 : 0

    Process {
        id: zoneScan

        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null || find /usr/share/zoneinfo -type f -printf '%P\\n' | grep -E '^[A-Z][A-Za-z_]+/' | sort"]

        stdout: StdioCollector {
            onStreamFinished: {
                picker.zones = this.text.trim().split("\n").filter((z) => {
                    return z !== "";
                });
                if (picker.shown)
                    picker.scrollToCurrent();

            }
        }

    }

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
            anchors.top: parent.top
            anchors.margins: 22
            text: "Time zone"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontHeadlineSm
            font.weight: Font.Medium
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
                        picker.choose(picker.matches[0]);

                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: picker.zones.length > 0 ? "Search " + picker.zones.length + " zones" : "Reading the zone database…"
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyLg
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
                id: zoneRow

                required property string modelData
                readonly property bool current: zoneRow.modelData === Loc.zone

                width: list.width - 14
                height: 48
                radius: Theme.pill(height)
                color: zoneRow.current ? Theme.accentContainer : (rowArea.containsMouse ? Theme.bgHover : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: zoneRow.modelData.replace(/_/g, " ")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyLg
                    color: zoneRow.current ? Theme.text : Theme.subtext
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.choose(zoneRow.modelData)
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
