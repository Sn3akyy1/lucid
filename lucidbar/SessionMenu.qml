import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lucidnotif"

// lock, suspend, log out, restart or shut down from the bar. the last three
// take a second click, so a stray one does nothing
BarPill {
    id: root

    // material symbols, as NotifIcon draws them
    readonly property var icons: ({
        "power": "power_settings_new",
        "lock": "lock",
        "logout": "logout",
        "suspend": "bedtime",
        "hibernate": "mode_standby",
        "reboot": "restart_alt"
    })
    // hibernate only where logind says it can
    property bool canHibernate: false
    readonly property var catalogue: [{
        "id": "lock",
        "label": "Lock",
        "icon": "lock",
        "confirm": false
    }, {
        "id": "suspend",
        "label": "Suspend",
        "icon": "suspend",
        "confirm": false
    }, {
        "id": "hibernate",
        "label": "Hibernate",
        "icon": "hibernate",
        "confirm": false
    }, {
        "id": "logout",
        "label": "Log out",
        "icon": "logout",
        "confirm": true
    }, {
        "id": "reboot",
        "label": "Restart",
        "icon": "reboot",
        "confirm": true
    }, {
        "id": "shutdown",
        "label": "Shut down",
        "icon": "power",
        "confirm": true
    }]
    // the ones picked in Settings, in the order picked
    readonly property var actions: String(Prefs.powerModuleActions || "").split(",").map((id) => {
        return root.catalogue.find((a) => {
            return a.id === id;
        });
    }).filter((a) => {
        return !!a && (a.id !== "hibernate" || root.canHibernate);
    })
    // the action waiting for its second click
    property string armed: ""
    property string uptime: ""
    readonly property int horizontalPadding: 11

    function run(id) {
        const a = root.actions.find((x) => {
            return x.id === id;
        });
        if (!a)
            return ;

        if (a.confirm && Prefs.powerModuleConfirm && root.armed !== id) {
            root.armed = id;
            disarm.restart();
            return ;
        }
        root.armed = "";
        root.expanded = false;
        // the same actions as the session screen and the lock screen, from one place
        Power.run(id);
    }

    // the looks, from its card on the Bar page
    readonly property bool accentFace: Prefs.powerModuleStyle === "accent"
    readonly property bool gridPanel: Prefs.powerModulePanelStyle === "grid"

    shown: Prefs.showPower
    compactWidth: (root.accentFace ? 24 : 18) + root.horizontalPadding * 2
    panelWidth: root.gridPanel ? 300 : 260
    panelHeight: panelColumn.implicitHeight + 32
    expandedRadius: Theme.shapeXl
    onExpandedChanged: {
        root.armed = "";
        if (root.expanded)
            probe.running = true;

    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: root.armed = ""
    }

    // how long the machine has been up, and whether it can hibernate
    Process {
        id: probe

        command: ["sh", "-c", "cut -d. -f1 /proc/uptime; busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n");
                const s = parseInt(lines[0]);
                if (!isNaN(s)) {
                    const d = Math.floor(s / 86400);
                    const h = Math.floor(s % 86400 / 3600);
                    const m = Math.floor(s % 3600 / 60);
                    root.uptime = "Up " + (d > 0 ? d + (d === 1 ? " day " : " days ") : "") + (d > 0 || h > 0 ? h + " h " : "") + m + " min";
                }
                root.canHibernate = /"yes"/.test(lines[1] || "");
            }
        }

    }

    compactContent: [
        Rectangle {
            anchors.centerIn: parent
            width: 24
            height: 24
            radius: height / 2
            color: Theme.accent
            visible: root.accentFace
        },
        NotifIcon {
            anchors.centerIn: parent
            size: root.accentFace ? 15 : 17
            path: root.icons.power
            color: root.accentFace ? Theme.fgAccent : Theme.text
        }
    ]

    panelContent: [
        Column {
            id: panelColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 4

            Item {
                width: parent.width
                height: 34

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Power"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitleSm
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: Prefs.powerModuleUptime && root.uptime !== ""
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: uptimeLabel.implicitWidth + 20
                    height: 26
                    radius: 13
                    color: Theme.accentContainer

                    Text {
                        id: uptimeLabel

                        anchors.centerIn: parent
                        text: root.uptime
                        color: Theme.fgAccentContainer
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLabelMd
                        font.weight: Font.Medium
                    }

                }

            }

            // a list, or three to a row with the label under the icon
            Grid {
                columns: root.gridPanel ? 3 : 1
                spacing: root.gridPanel ? 8 : 4

                Repeater {
                    model: root.actions

                    Rectangle {
                        id: actionRow

                        required property var modelData
                        readonly property bool isArmed: root.armed === actionRow.modelData.id
                        readonly property bool danger: actionRow.modelData.id === "reboot" || actionRow.modelData.id === "shutdown"

                        width: root.gridPanel ? (panelColumn.width - 16) / 3 : panelColumn.width
                        height: root.gridPanel ? 84 : 48
                        radius: Theme.radiusMd
                        color: actionRow.isArmed ? Theme.alpha(Theme.error, 0.9) : (actionArea.containsMouse ? Theme.withBlur(Theme.bgHover) : "transparent")

                        Rectangle {
                            id: actionIcon

                            x: root.gridPanel ? (parent.width - width) / 2 : 8
                            y: root.gridPanel ? 12 : (parent.height - height) / 2
                            width: 34
                            height: 34
                            radius: 17
                            color: actionRow.isArmed ? Theme.alpha(Theme.fgError, 0.18) : (actionRow.danger ? Theme.errorContainer : Theme.accentContainer)

                            NotifIcon {
                                anchors.centerIn: parent
                                size: 18
                                path: root.icons[actionRow.modelData.icon]
                                color: actionRow.isArmed ? Theme.fgError : (actionRow.danger ? Theme.fgErrorContainer : Theme.fgAccentContainer)
                            }

                        }

                        Text {
                            x: root.gridPanel ? 6 : actionIcon.x + actionIcon.width + 12
                            y: root.gridPanel ? actionIcon.y + actionIcon.height + 8 : (parent.height - height) / 2
                            width: parent.width - x - (root.gridPanel ? 6 : 12)
                            horizontalAlignment: root.gridPanel ? Text.AlignHCenter : Text.AlignLeft
                            text: actionRow.isArmed ? actionRow.modelData.label + (root.gridPanel ? "?" : "? Click again") : actionRow.modelData.label
                            color: actionRow.isArmed ? Theme.fgError : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.run(actionRow.modelData.id)
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

        }
    ]
}
