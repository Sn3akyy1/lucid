import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs
import "../lucidprefs"

// the start button: the launcher, from the bar. a click opens it or puts it
// away; the right click is the module's card, as on every module
BarPill {
    id: root

    property var dockMod: null
    readonly property bool launcherOpen: !!root.dockMod && root.dockMod.menuOpen
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
    readonly property int glyph: Math.max(Theme.dp(16), Math.min(Theme.dp(22), root.compactHeight - Theme.dp(14)))
    // the icon faces sit in a circle, as wide as the bar is tall; the word's
    // chip is hugged as closely at its ends as at its top and bottom
    readonly property int chipWidth: Math.ceil(startLabel.implicitWidth) + Theme.dp(20)
    readonly property int chipHeight: Math.min(Theme.dp(24), root.compactHeight - Theme.dp(8))
    // the grid of nine, dots twice their gaps: as wide as the circle is odd or
    // even, so its edges land on whole pixels with the same clear all round
    readonly property int gridSize: {
        const s = Math.round(root.glyph * 0.78);
        return (root.compactHeight - s) % 2 === 0 ? s : s - 1;
    }

    opensOnHover: false
    compactInteractive: false
    compactHovered: startArea.containsMouse
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
        // Lucid's mark (assets/logo-mark.svg), as on the dock's launcher button
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

        },
        // or a grid of nine, across as much of the glyph as the mark is
        Grid {
            visible: root.gridFace
            anchors.centerIn: parent
            columns: 3
            spacing: root.gridSize / 8

            Repeater {
                model: 9

                Rectangle {
                    width: root.gridSize / 4
                    height: width
                    radius: Theme.pill(height)
                    color: index === 4 ? Theme.accent : Theme.text
                }

            }

        },
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
            asynchronous: true
        },
        MultiEffect {
            visible: root.distroFace
            anchors.centerIn: parent
            width: root.glyph
            height: root.glyph
            source: distroLogo
            colorization: 1
            colorizationColor: Theme.accent
            brightness: 0.25
        },
        // Avatar: the account picture, round
        UserAvatar {
            visible: root.avatarFace
            anchors.centerIn: parent
            user: Users.me
            size: root.glyph + Theme.dp(2)
        },
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
                font.pixelSize: Theme.fs(12)
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
