import "lucidprefs"
import "lucidupdate"
import "support/installer"
import QtQuick
import Quickshell
import qs
import qs.lucidui

// the graphical installer: ./install.sh --gui opens this from the source tree.
// the choices below become install.sh's own flags, and the run itself is the
// updater's (lucidupdate/updater.py --src), so the window asks exactly what
// the terminal would and nothing is installed twice over
//
//   qs -p ./installer.qml
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property bool running: Updates.flow !== ""
    readonly property var choices: [{
        "flag": "--no-hypr",
        "icon": "keyboard",
        "label": "Hyprland config",
        "sub": "Binds, window rules, blur and autostart"
    }, {
        "flag": "--no-theming",
        "icon": "palette",
        "label": "Colours from your wallpaper",
        "sub": "Palettes, and the hook that recolours it all"
    }, {
        "flag": "--no-look",
        "icon": "terminal",
        "label": "The Lucid look",
        "sub": "kitty, starship, fastfetch, VSCode and GTK"
    }, {
        "flag": "--no-apps",
        "icon": "dock",
        "label": "Dock apps",
        "sub": "Zen, VSCodium, Spotify, Steam… several GB"
    }, {
        "flag": "--no-wallpapers",
        "icon": "wallpaper",
        "label": "Wallpapers",
        "sub": "Copied to ~/Pictures/wallpapers"
    }, {
        "flag": "--no-plugins",
        "icon": "mouse",
        "label": "Tilting cursor",
        "sub": "Builds hypr-dynamic-cursors, about a minute",
        "needs": "--no-hypr"
    }]
    // the flags of whatever was switched off
    property var off: []

    // shown, so a new picture fades the accent over rather than snapping
    property color seed: tour.seed

    function toggle(flag) {
        root.off = root.off.indexOf(flag) === -1 ? root.off.concat([flag]) : root.off.filter((f) => {
            return f !== flag;
        });
    }

    function isOn(c) {
        return root.off.indexOf(c.flag) === -1 && (!c.needs || root.off.indexOf(c.needs) === -1);
    }

    function install() {
        Updates.installHere(root.choices.filter((c) => {
            return !root.isOn(c);
        }).map((c) => {
            return c.flag;
        }));
    }

    // hyprctl reload puts the new binds and rules live; the shell comes up
    // through its launcher, as it would at login
    function leave(start) {
        if (start) {
            if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== "" && root.off.indexOf("--no-hypr") === -1)
                Quickshell.execDetached(["hyprctl", "reload"]);

            Updates.restartNow(root.home + "/.config/quickshell");
        }
        Qt.quit();
    }

    Binding {
        target: Theme
        property: "seed"
        value: root.seed
    }

    FloatingWindow {
        id: win

        title: "Install Lucid"
        implicitWidth: Theme.dp(1100)
        implicitHeight: Theme.dp(660)
        color: Theme.alpha(Theme.bg, 1)
        onClosed: Qt.quit()

        Tour {
            id: tour

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: side.left
            anchors.margins: Theme.dp(16)
            anchors.leftMargin: Theme.dp(28)
            anchors.rightMargin: Theme.dp(4)
        }

        Item {
            id: side

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.dp(460)
            focus: true
            Keys.onEscapePressed: {
                if (root.running)
                    card.dismiss();
                else
                    Qt.quit();
            }

            // the choices, until Install
            Column {
                id: welcome

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.dp(32)
                spacing: Theme.dp(6)
                opacity: root.running ? 0 : 1
                visible: opacity > 0
                enabled: !root.running

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

                Image {
                    width: Theme.dp(52)
                    height: Theme.dp(52)
                    source: Qt.resolvedUrl("assets/logo-mark.svg")
                    sourceSize: Qt.size(width * 2, height * 2)
                }

                Item {
                    width: 1
                    height: Theme.dp(10)
                }

                Text {
                    text: "Welcome to Lucid"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadlineLg
                    font.variableAxes: Theme.axes(Theme.fontHeadlineLg, 560, 0)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    text: (Updates.current !== "" ? "v" + Updates.current + " · " : "") + "Pick what comes with it. The installer asks before anything big, and all of it can be changed later in Settings."
                    color: Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    font.variableAxes: Theme.axes(Theme.fontBodyMd, 420, 0)
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: 1
                    height: Theme.dp(12)
                }

                Repeater {
                    model: root.choices

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool locked: !!modelData.needs && root.off.indexOf(modelData.needs) !== -1

                        width: parent.width
                        height: Theme.dp(62)
                        radius: index === 0 ? Theme.dp(20) : index === root.choices.length - 1 ? Theme.dp(20) : Theme.dp(6)
                        color: rowArea.containsMouse && !row.locked ? Theme.bgHigh : Theme.bgTile
                        opacity: row.locked ? 0.5 : 1

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!row.locked)
                                    root.toggle(row.modelData.flag);

                            }
                        }

                        Icon {
                            id: rowIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(18)
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            size: Theme.dp(20)
                            color: root.isOn(row.modelData) ? Theme.accent : Theme.subtextDim
                        }

                        Column {
                            anchors.left: rowIcon.right
                            anchors.leftMargin: Theme.dp(14)
                            anchors.right: sw.left
                            anchors.rightMargin: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(2)

                            Text {
                                text: row.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodyLg
                                font.variableAxes: Theme.axes(Theme.fontBodyLg, 480, 0)
                            }

                            Text {
                                width: parent.width
                                text: row.locked ? "Comes with the Hyprland config" : row.modelData.sub
                                color: Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodySm
                                font.variableAxes: Theme.axes(Theme.fontBodySm, 420, 0)
                                elide: Text.ElideRight
                            }

                        }

                        Switch {
                            id: sw

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(16)
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.isOn(row.modelData)
                            disabled: row.locked
                            onToggled: root.toggle(row.modelData.flag)
                        }

                    }

                }

            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.dp(32)
                spacing: Theme.dp(8)
                opacity: welcome.opacity
                visible: welcome.visible

                M3Button {
                    text: "Quit"
                    variant: "text"
                    onClicked: Qt.quit()
                }

                M3Button {
                    text: "Install"
                    variant: "filled"
                    iconPath: "download"
                    onClicked: root.install()
                }

            }

            // from the password on: the updater's own card
            UpdateCard {
                id: card

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.dp(4)
                color: "transparent"
                shown: root.running
                visible: opacity > 0.01
                onLeave: (start) => {
                    return root.leave(start);
                }
            }

        }

    }

    Behavior on seed {
        ColorAnimation {
            duration: 1200
            easing.type: Easing.InOutQuad
        }

    }

}
