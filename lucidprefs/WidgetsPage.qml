import QtQuick
import qs

Column {
    id: page

    property string filter: "all"

    readonly property var shownTypes: page.filter === "all" ? Widgets.catalogue : Widgets.catalogue.filter((t) => {
        return t.id === page.filter;
    })

    spacing: 26
    // the header switch turns the whole layer off, so the page has nothing left to set
    enabled: Prefs.widgetsEnabled
    opacity: Prefs.widgetsEnabled ? 1 : 0.38

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    WidgetsMap {
        width: parent.width
    }

    SettingCard {
        title: "ADD A WIDGET"

        SettingRow {
            title: "Pick a look"
            description: Widgets.full ? "The desktop holds " + Widgets.capacity + " widgets, and it is full. Take one off below to make room." : "Every tile below is the real widget, drawn live. Click one and it lands on the desktop, where you can drag it anywhere and pin it in place."
            showDivider: false
            stacked: true

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [{
                        "id": "all",
                        "name": "All"
                    }].concat(Widgets.catalogue.map((t) => {
                        return ({
                            "id": t.id,
                            "name": t.name
                        });
                    }))

                    Rectangle {
                        id: chip

                        required property var modelData

                        readonly property bool selected: page.filter === chip.modelData.id

                        width: chipLabel.implicitWidth + 26
                        height: 32
                        radius: 16
                        color: chip.selected ? Theme.accentContainer : (chipArea.containsMouse ? Theme.bgHover : Theme.bgSunken)

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Text {
                            id: chipLabel

                            anchors.centerIn: parent
                            text: chip.modelData.name
                            color: chip.selected ? Theme.fgAccentContainer : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: chip.selected
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.filter = chip.modelData.id
                        }

                    }

                }

            }

        }

    }

    Repeater {
        model: page.shownTypes

        SettingCard {
            id: group

            required property var modelData

            title: group.modelData.name.toUpperCase()

            SettingRow {
                title: group.modelData.blurb
                description: group.modelData.variants.length + (group.modelData.variants.length === 1 ? " style" : " styles") + (Widgets.countOfType(group.modelData.id) > 0 ? " · " + Widgets.countOfType(group.modelData.id) + " on the desktop" : "")
                showDivider: false
                stacked: true

                Flow {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: group.modelData.variants

                        WidgetTile {
                            required property var modelData

                            wtype: group.modelData.id
                            variant: modelData
                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "BEHAVIOUR"

        SettingRow {
            title: "Snap while dragging"
            resetKey: "widgetSnap"
            description: "Widgets catch on the screen's edges and centre lines, and line up with each other, so a hand-placed arrangement still looks deliberate."

            M3Switch {
                checked: Prefs.widgetSnap
                onToggled: (v) => {
                    return Prefs.widgetSnap = v;
                }
            }

        }

        SettingRow {
            title: "Pin everything"
            resetKey: "widgetLockAll"
            description: "Locks every widget where it stands, including the ones that are not individually pinned. Useful once the layout is settled."

            M3Switch {
                checked: Prefs.widgetLockAll
                onToggled: (v) => {
                    return Prefs.widgetLockAll = v;
                }
            }

        }

        SettingRow {
            title: "Keep above windows"
            resetKey: "widgetOnTop"
            description: "Off, widgets live on the desktop and windows cover them. On, they float over everything - handy for a clock or a timer you always want in sight."

            M3Switch {
                checked: Prefs.widgetOnTop
                onToggled: (v) => {
                    return Prefs.widgetOnTop = v;
                }
            }

        }

        SettingRow {
            title: "Hide for fullscreen windows"
            resetKey: "widgetHideFullscreen"
            description: "Widgets step out of the way while something is running fullscreen, and come back when it is not."
            showDivider: false

            M3Switch {
                checked: Prefs.widgetHideFullscreen
                onToggled: (v) => {
                    return Prefs.widgetHideFullscreen = v;
                }
            }

        }

    }

}
