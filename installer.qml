import "lucidprefs"
import "lucidupdate"
import "support/installer"
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.lucidui

// the graphical installer: ./install.sh opens this from the source tree when
// it is run bare in a Wayland session, and --gui with options starts the
// switches from them (LUCID_INSTALL_ARGS). the choices become install.sh's own flags, and the run itself is the
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
        "needs": "--no-hypr",
        "needsText": "Comes with the Hyprland config"
    }, {
        "flag": "--no-sddm",
        "onFlag": "--login-screen",
        "icon": "login",
        "label": "Login screen",
        "sub": "The SDDM theme, from your next login",
        "needs": "--no-theming",
        "needsText": "Comes with the colours from your wallpaper"
    }]
    // what install.sh was given besides --gui
    readonly property var given: (Quickshell.env("LUCID_INSTALL_ARGS") || "").split(" ").filter((a) => {
        return a !== "";
    })
    // the flags of whatever was switched off, starting from the command line
    property var off: root.choices.filter((c) => {
        return root.given.indexOf(c.flag) !== -1;
    }).map((c) => {
        return c.flag;
    })
    // the login screen theme only goes where sddm is
    property bool sddmHere: false

    // shown, so a new picture fades the accent over rather than snapping
    property color seed: tour.seed

    function toggle(flag) {
        root.off = root.off.indexOf(flag) === -1 ? root.off.concat([flag]) : root.off.filter((f) => {
            return f !== flag;
        });
    }

    function locked(c) {
        return (!!c.needs && root.off.indexOf(c.needs) !== -1) || (c.flag === "--no-sddm" && !root.sddmHere);
    }

    function isOn(c) {
        return root.off.indexOf(c.flag) === -1 && !root.locked(c);
    }

    // each switch is its flag when off, or its onFlag when on; anything else
    // from the command line (-y, --skip-deps, --with-hypr) rides along
    function install() {
        var mine = [];
        root.choices.forEach((c) => {
            mine.push(c.flag);
            if (c.onFlag)
                mine.push(c.onFlag);

        });
        var args = root.given.filter((a) => {
            return mine.indexOf(a) === -1;
        });
        root.choices.forEach((c) => {
            if (!root.isOn(c))
                args.push(c.flag);
            else if (c.onFlag)
                args.push(c.onFlag);
        });
        Updates.installHere(args);
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

    Process {
        running: true
        command: ["test", "-d", "/usr/share/sddm/themes"]
        onExited: (code) => {
            return root.sddmHere = code === 0;
        }
    }

    Binding {
        target: Theme
        property: "seed"
        value: root.seed
    }

    FloatingWindow {
        id: win

        title: "Install Lucid"
        // as tall as the choices, and as wide as the screenshot needs to fill
        // that height, unless the screen is narrower
        implicitHeight: welcome.implicitHeight + Theme.dp(64)
        implicitWidth: Math.min(side.width + Theme.dp(44) + Math.round((win.implicitHeight - Theme.dp(32) - tour.footHeight) * 16 / 9), (win.screen ? win.screen.width : 1920) - Theme.dp(80))
        // one size: Hyprland floats a window that cannot be resized
        minimumSize: Qt.size(win.implicitWidth, win.implicitHeight)
        maximumSize: Qt.size(win.implicitWidth, win.implicitHeight)
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

                Row {
                    spacing: Theme.dp(14)

                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(44)
                        height: Theme.dp(44)
                        source: Qt.resolvedUrl("assets/logo-mark.svg")
                        sourceSize: Qt.size(width * 2, height * 2)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Welcome to Lucid"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadlineLg
                        font.variableAxes: Theme.axes(Theme.fontHeadlineLg, 560, 0)
                        font.weight: Font.DemiBold
                    }

                }

                Item {
                    width: 1
                    height: Theme.dp(4)
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
                        readonly property bool locked: root.locked(modelData)

                        width: parent.width
                        height: Theme.dp(54)
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
                                text: !row.locked ? row.modelData.sub : row.modelData.flag === "--no-sddm" && !root.sddmHere ? "SDDM is not installed" : row.modelData.needsText
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

                Item {
                    width: parent.width
                    height: Theme.dp(64)

                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: Theme.dp(8)

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
