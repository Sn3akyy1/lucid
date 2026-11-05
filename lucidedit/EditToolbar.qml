import QtQuick
import qs
import qs.lucidui

// edit mode's floating toolbar: what is going on and how, the sheets for the bar and
// the dock, the widget panel and the wallpapers, and the two ways out
Item {
    id: toolbar

    property bool hosted: false
    property string screenName: ""
    // eases 0..1 as it rises into place
    property real reveal: toolbar.hosted ? 1 : 0
    readonly property bool shown: toolbar.reveal > 0.01
    // the glass cannot fade, so it comes on once the toolbar is in place
    readonly property bool settled: toolbar.hosted && toolbar.reveal > 0.97

    implicitWidth: row.implicitWidth + Theme.dp(10) * 2
    implicitHeight: Theme.dp(60)
    width: toolbar.implicitWidth
    height: toolbar.implicitHeight
    opacity: toolbar.reveal
    visible: toolbar.shown

    // it rises from the bottom edge, or drops from the top one over a bottom bar
    transform: Translate {
        y: (1 - toolbar.reveal) * Theme.dp(Prefs.barBottom ? -28 : 28)
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
    }

    Row {
        id: row

        x: Theme.dp(10)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(4)

        Item {
            width: lead.implicitWidth + Theme.dp(18)
            height: Theme.dp(44)

            Row {
                id: lead

                x: Theme.dp(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.dp(12)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dp(38)
                    height: Theme.dp(38)
                    radius: height / 2
                    color: Theme.alpha(Theme.accent, 0.16)

                    Icon {
                        anchors.centerIn: parent
                        name: "edit"
                        size: Theme.dp(20)
                        fill: 1
                        color: Theme.accent
                    }

                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.dp(1)

                    Text {
                        text: "Edit mode"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitleSm
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Drag to move · right-click for options"
                        color: Theme.subtext
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelMd
                    }

                }

            }

        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.dp(28)
            color: Theme.outline
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "toolbar"
            text: "Bar"
            selected: Edit.sheet === "bar" || Edit.sheet === "module"
            onClicked: Edit.toggleSheet("bar", toolbar.screenName)
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "dock_to_bottom"
            text: "Dock"
            selected: Edit.sheet === "dock"
            onClicked: Edit.toggleSheet("dock", toolbar.screenName)
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "widgets"
            text: "Widgets"
            onClicked: {
                Edit.closeSheet();
                Widgets.openPanel(toolbar.screenName);
            }
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "wallpaper"
            text: "Wallpaper"
            onClicked: {
                Edit.closeSheet();
                Prefs.desktopActionRequested("wallpaper");
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: Theme.dp(28)
            color: Theme.outline
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "undo"
            text: "Undo"
            disabled: !Edit.canUndo
            onClicked: Edit.undo()
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "history"
            text: "Revert"
            disabled: !Edit.changed
            onClicked: Edit.revert()
        }

        EditTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "check"
            text: "Done"
            filled: true
            onClicked: Edit.exit()
        }

    }

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutCubic
        }

    }

}
