import QtQuick
import QtQuick.Effects
import Quickshell
import qs

// a corner of the screen with three tiled windows, drawn from the options in
// force so gaps, borders, corners, shadow and dimming read at their real size
Rectangle {
    id: preview

    readonly property var shown: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    readonly property real screenW: preview.shown ? preview.shown.width : 1920
    readonly property real screenH: preview.shown ? preview.shown.height : 1080
    readonly property real reserved: Prefs.barEnabled ? Prefs.barHeight : 0
    // the left three fifths of the screen, so a 2 px border still shows
    readonly property real zoom: screen.width / (preview.screenW * 0.6)
    readonly property real gapsIn: HyprConfig.num("general.gaps_in", 5)
    readonly property real gapsOut: HyprConfig.num("general.gaps_out", 20)
    readonly property real border: HyprConfig.num("general.border_size", 2)
    readonly property real rounding: HyprConfig.num("decoration.rounding", 10)
    readonly property bool shadowOn: HyprConfig.bool("decoration.shadow.enabled", false)
    readonly property real shadowRange: HyprConfig.num("decoration.shadow.range", 20)
    readonly property bool dimOn: HyprConfig.bool("decoration.dim_inactive", false)
    readonly property real dimStrength: HyprConfig.num("decoration.dim_strength", 0.5)
    readonly property var activeColours: HyprConfig.coloursOf(HyprConfig.value("general.col.active_border"))
    readonly property var inactiveColours: HyprConfig.coloursOf(HyprConfig.value("general.col.inactive_border"))
    // the work area and the three windows in it, in screen pixels
    readonly property real areaX: preview.gapsOut
    readonly property real areaY: preview.reserved + preview.gapsOut
    readonly property real areaW: preview.screenW - 2 * preview.gapsOut
    readonly property real areaH: preview.screenH - preview.reserved - 2 * preview.gapsOut
    readonly property var boxes: [{
        "x": preview.areaX,
        "y": preview.areaY,
        "w": preview.areaW / 2 - preview.gapsIn,
        "h": preview.areaH,
        "active": true
    }, {
        "x": preview.areaX + preview.areaW / 2 + preview.gapsIn,
        "y": preview.areaY,
        "w": preview.areaW / 2 - preview.gapsIn,
        "h": preview.areaH / 2 - preview.gapsIn,
        "active": false
    }, {
        "x": preview.areaX + preview.areaW / 2 + preview.gapsIn,
        "y": preview.areaY + preview.areaH / 2 + preview.gapsIn,
        "w": preview.areaW / 2 - preview.gapsIn,
        "h": preview.areaH / 2 - preview.gapsIn,
        "active": false
    }]

    radius: Theme.radiusMd
    color: Theme.bgTile
    implicitHeight: 230

    Rectangle {
        id: screen

        anchors.fill: parent
        anchors.margins: 14
        radius: Theme.radiusXs
        color: Theme.bgSunken
        clip: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.alpha(Theme.accent, 0.16)
                }

                GradientStop {
                    position: 1
                    color: Theme.alpha(Theme.accent, 0.03)
                }

            }

        }

        // the bar's reserved strip
        Rectangle {
            width: parent.width
            height: preview.reserved * preview.zoom
            color: Theme.bgTile
        }

        Repeater {
            model: preview.boxes

            Item {
                id: win

                required property var modelData
                readonly property var colours: win.modelData.active ? preview.activeColours : preview.inactiveColours
                readonly property real b: preview.border * preview.zoom
                readonly property real r: preview.rounding * preview.zoom

                x: win.modelData.x * preview.zoom
                y: win.modelData.y * preview.zoom
                width: win.modelData.w * preview.zoom
                height: win.modelData.h * preview.zoom
                layer.enabled: preview.shadowOn
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.6
                    blurMax: 48
                    shadowBlur: Math.min(1, preview.shadowRange * preview.zoom / 48)
                }

                // the border, drawn under the window so its corners follow the rounding
                Rectangle {
                    anchors.fill: parent
                    radius: win.r + win.b
                    visible: win.b > 0

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop {
                            position: 0
                            color: win.colours[0]
                        }

                        GradientStop {
                            position: 0.5
                            color: win.colours[Math.min(1, win.colours.length - 1)]
                        }

                        GradientStop {
                            position: 1
                            color: win.colours[win.colours.length - 1]
                        }

                    }

                }

                Rectangle {
                    x: win.b
                    y: win.b
                    width: parent.width - 2 * win.b
                    height: parent.height - 2 * win.b
                    radius: win.r
                    color: Theme.bgActive
                    clip: true

                    Column {
                        x: 14
                        y: 14
                        spacing: 8

                        Repeater {
                            model: [0.55, 0.8, 0.4, 0.7]

                            Rectangle {
                                required property real modelData

                                width: (win.width - 28) * modelData
                                height: 6
                                radius: 3
                                color: Theme.alpha(Theme.text, 0.16)
                            }

                        }

                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: win.r
                        color: "#000000"
                        opacity: preview.dimOn && !win.modelData.active ? preview.dimStrength : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durShort
                            }

                        }

                    }

                }

            }

        }

    }

}
