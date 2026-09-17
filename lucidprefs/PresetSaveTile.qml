import "../lucidwidgets"
import QtQuick
import qs

// the desktop as it is now, one name away from being a preset of your own
Item {
    id: tile

    property string wallpaper: ""
    property bool naming: false
    property string draft: ""

    readonly property bool empty: Widgets.desktopLayout.length === 0
    readonly property var clash: tile.naming ? Widgets.userPresetNamed(tile.draft) : null

    // the first free "Layout n", so enter alone is enough to save
    function suggestion() {
        for (var n = Widgets.userPresets.length + 1; n < 1000; n++) {
            if (Widgets.userPresetNamed("Layout " + n) === null)
                return "Layout " + n;

        }
        return "Layout";
    }

    function begin() {
        if (tile.empty)
            return ;

        tile.draft = tile.suggestion();
        // a cleared field first, or text typed last time would outlive the suggestion
        field.clear();
        field.text = tile.draft;
        tile.naming = true;
        field.focusInput();
    }

    function commit() {
        if (tile.draft.trim() === "")
            return ;

        Widgets.savePreset(tile.draft);
        tile.naming = false;
    }

    implicitWidth: 240
    implicitHeight: thumb.height + 88
    opacity: tile.empty ? 0.5 : 1
    onEmptyChanged: {
        if (tile.empty)
            tile.naming = false;

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    Rectangle {
        id: shell

        anchors.fill: parent
        radius: Theme.radiusLg
        color: (area.containsMouse || tile.naming) && !tile.empty ? Theme.bgHover : Theme.bgSunken
        scale: area.pressed ? 0.97 : 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Theme.easeStandard
            }

        }

        PresetThumb {
            id: thumb

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            height: thumb.implicitHeight
            cards: Widgets.desktopLayout
            wallpaper: tile.wallpaper
        }

        Rectangle {
            anchors.centerIn: thumb
            width: 34
            height: 34
            radius: Theme.rad(17)
            color: Theme.accent
            opacity: area.containsMouse && !tile.naming && !tile.empty ? 1 : 0
            scale: area.containsMouse && !tile.naming && !tile.empty ? 1 : 0.7
            visible: opacity > 0.01

            WidgetGlyph {
                anchors.centerIn: parent
                name: "add"
                size: 20
                color: Theme.fgAccent
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durEnter
                    easing.type: Theme.easeStandard
                }

            }

        }

        // what enter will do, said on the preview while you type
        Rectangle {
            anchors.horizontalCenter: thumb.horizontalCenter
            anchors.bottom: thumb.bottom
            anchors.bottomMargin: 8
            width: hint.implicitWidth + 20
            height: 24
            radius: Theme.rad(12)
            color: Theme.bgOpaque
            opacity: tile.naming ? 1 : 0
            visible: opacity > 0.01

            Text {
                id: hint

                anchors.centerIn: parent
                text: tile.clash !== null ? "Updates “" + tile.clash.name + "”" : "Enter to save · Esc to cancel"
                color: tile.clash !== null ? Theme.accent : Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fs(10)
                font.bold: tile.clash !== null
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Text {
            id: name

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: thumb.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            text: "Save this layout"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBody
            font.bold: true
            elide: Text.ElideRight
            visible: !tile.naming
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: name.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 3
            height: 30
            text: tile.empty ? "Place a widget or two first, then keep the arrangement here." : "Keep what is on your desktop now as a preset of your own."
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: !tile.naming
        }

    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        enabled: !tile.naming
        cursorShape: tile.empty ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: tile.begin()
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 6
        visible: tile.naming

        M3TextField {
            id: field

            width: parent.width - save.width - parent.spacing
            height: 42
            placeholder: "Name it"
            commitOnBlur: false
            onEdited: (v) => {
                return tile.draft = v;
            }
            onAccepted: (v) => {
                tile.draft = v;
                tile.commit();
            }
            onCancelled: tile.naming = false
        }

        M3IconButton {
            id: save

            anchors.verticalCenter: field.verticalCenter
            size: 42
            variant: "filled"
            enabled: tile.draft.trim() !== ""
            iconPath: "M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17Z"
            onClicked: tile.commit()
        }

    }

}
