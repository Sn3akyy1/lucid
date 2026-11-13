import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import qs.lucidui as UI
import "../lucidprefs"

// the start button: the launcher, from the bar. a click opens it or puts it
// away; the right click is the module's card, as on every module
BarPill {
    id: root

    property var dockMod: null
    readonly property bool launcherOpen: !!root.dockMod && root.dockMod.menuOpen
    // linked, it is the first icon of one row with the Apps module and lights as
    // they do, a square of its own, not as a module
    readonly property bool linked: !!root.hostWindow && root.hostWindow.startJoinsApps === true
    lookPref: Prefs.startModuleStyle
    readonly property bool gridFace: root.look === "grid"
    // the distribution's logo, the account picture, or a word; the logo falls
    // back to Lucid's mark when the system names none or none is found
    property string osReleaseText: ""
    readonly property string osLogo: {
        const m = /^LOGO=["']?([^"'\n]*)/m.exec(root.osReleaseText);
        return m ? m[1].trim() : "";
    }
    readonly property string osLogoSource: {
        if (root.osLogo === "")
            return "";

        const themed = Quickshell.iconPath(root.osLogo, true);
        return themed !== "" ? themed : "file:///usr/share/pixmaps/" + root.osLogo + ".svg";
    }
    readonly property bool distroFace: root.look === "distro" && distroLogo.status !== Image.Error && root.osLogoSource !== ""
    readonly property bool avatarFace: root.look === "avatar"
    readonly property bool labelFace: root.look === "label"
    readonly property bool markFace: !root.gridFace && !root.distroFace && !root.avatarFace && !root.labelFace
    readonly property int glyph: Math.min(root.compactHeight - Theme.dp(8), Math.max(Theme.barDp(16), Math.min(Theme.barDp(22), root.compactHeight - Theme.dp(14))))
    // the icon faces sit in a circle, as wide as the bar is tall; the word's
    // chip is hugged as closely at its ends as at its top and bottom
    readonly property int chipWidth: Math.ceil(startLabel.implicitWidth) + Theme.barDp(20)
    readonly property int chipHeight: Math.min(Theme.barDp(24), root.compactHeight - Theme.dp(8))

    opensOnHover: false
    compactInteractive: false
    compactHovered: !root.linked && startArea.containsMouse
    shown: Prefs.showStart && root.dockMod !== null
    compactWidth: root.labelFace ? root.chipWidth + root.compactHeight - root.chipHeight : root.compactHeight

    FileView {
        id: osRelease

        path: "/etc/os-release"
        onLoaded: root.osReleaseText = osRelease.text()
    }

    compactContent: [
        // lit while the launcher is open; no hover or press tint of its own
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Theme.dp(8))
            height: Math.max(0, root.compactHeight - Theme.dp(8))
            radius: Theme.pill(height)
            color: root.launcherOpen ? Theme.alpha(Theme.accent, 0.2) : Theme.alpha(Theme.accent, 0)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        },
        // the Apps module's state layer, on its own icon's square
        Rectangle {
            visible: root.linked
            anchors.centerIn: parent
            width: root.compactHeight - Theme.dp(8)
            height: root.compactHeight - Theme.dp(8)
            radius: Theme.radiusMd
            color: Theme.text
            opacity: startArea.pressed ? Theme.statePressed + 0.04 : (startArea.containsMouse ? Theme.stateHover + 0.02 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        },
        // pressed, the face squashes and springs back as it is let go
        Item {
            anchors.fill: parent
            scale: startArea.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durMedium
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }

            }

            // Lucid's mark (assets/logo-mark.svg), as at the top of the launcher
            Shape {
                visible: root.markFace
                anchors.centerIn: parent
                width: root.glyph
                height: root.glyph
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 3
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap

                    PathSvg {
                        path: "M15.92,5.72 A7.4,7.4 0 1 0 18.95,14.53"
                    }

                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.text

                    PathSvg {
                        path: "M12,7.4 C12.598,10.62 13.38,11.402 16.6,12 C13.38,12.598 12.598,13.38 12,16.6 C11.402,13.38 10.62,12.598 7.4,12 C10.62,11.402 11.402,10.62 12,7.4 Z"
                    }

                }

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.accent

                    PathSvg {
                        path: "M20,9.4 A1,1 0 1 0 22,9.4 A1,1 0 1 0 20,9.4 Z"
                    }

                }

                transform: Scale {
                    xScale: root.glyph / 24
                    yScale: root.glyph / 24
                }

            }

            // or the dock's launcher button, lit as the dock lights it. its squares
            // span about half its box, which puts them at the bar's icon size
            UI.LauncherGrid {
                visible: root.gridFace
                anchors.centerIn: parent
                width: Math.round(root.glyph * 1.3)
                height: width
                lit: startArea.containsMouse || root.launcherOpen
            }

            // Distro: the logo /etc/os-release names, in the accent
            Image {
                id: distroLogo

                visible: false
                width: root.glyph
                height: root.glyph
                source: Prefs.startModuleStyle === "distro" ? root.osLogoSource : ""
                sourceSize.width: root.glyph * 2
                sourceSize.height: root.glyph * 2
                fillMode: Image.PreserveAspectFit
            }

            MultiEffect {
                visible: root.distroFace
                anchors.centerIn: parent
                width: root.glyph
                height: root.glyph
                source: distroLogo
                colorization: 1
                colorizationColor: Theme.accent
                brightness: 0.25
            }

            // Avatar: the account picture, round
            UserAvatar {
                visible: root.avatarFace
                anchors.centerIn: parent
                user: Users.me
                size: root.glyph + Theme.barDp(2)
            }

            // Label: the word, on a chip in the accent
            Rectangle {
                visible: root.labelFace
                anchors.centerIn: parent
                width: root.chipWidth
                height: root.chipHeight
                radius: Theme.pill(height)
                color: root.launcherOpen ? Theme.accentHover : Theme.accent

                Text {
                    id: startLabel

                    anchors.centerIn: parent
                    text: "Start"
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.bold: true
                    font.pixelSize: Theme.barFs(12)
                }

            }

        },
        MouseArea {
            id: startArea

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    if (root.hostWindow && root.hostWindow.editModule)
                        root.hostWindow.editModule("start");
                    else
                        Prefs.openBarModule("start");
                    return ;
                }
                if (root.launcherOpen)
                    root.dockMod.menuOpen = false;
                else
                    root.dockMod.openLauncher("");
            }
        }
    ]
}
