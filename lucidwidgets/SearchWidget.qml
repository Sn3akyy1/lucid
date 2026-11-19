import QtQuick
import Quickshell
import qs
import qs.lucidui
import qs.lucidprefs as LP

// the launcher's search on the desktop, with its modes a tap away
WidgetBody {
    id: w

    readonly property var modes: [{
        "key": "web",
        "icon": "public",
        "label": I18n.tr("Web"),
        "shape": "cookie4"
    }, {
        "key": "emoji",
        "icon": "mood",
        "label": I18n.tr("Emoji"),
        "shape": "clover4"
    }, {
        "key": "clipboard",
        "icon": "content_paste",
        "label": I18n.tr("Clipboard"),
        "shape": "sunny"
    }, {
        "key": "wallpaper",
        "icon": "wallpaper",
        "label": I18n.tr("Wallpapers"),
        "shape": "pentagon"
    }, {
        "key": "command",
        "icon": "terminal",
        "label": I18n.tr("Commands"),
        "shape": "gem"
    }]

    // qs ipc call launcher open | search ? | emoji | clipboard | wallpaper | command
    function open(mode) {
        if (!w.live)
            return ;

        const call = mode === "" ? ["open"] : (mode === "web" ? ["search", "?"] : [mode]);
        Quickshell.execDetached(["qs", "ipc", "call", "launcher"].concat(call));
    }

    pill: w.variant === "pill"

    // pill: a search bar like a phone's, emoji and the clipboard at its end
    Item {
        visible: w.variant === "pill"
        anchors.fill: parent

        WidgetTap {
            id: pillTap

            anchors.fill: parent
            widget: w
            onTapped: w.open("")
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: w.ink
            opacity: pillTap.pressed ? 0.1 : (pillTap.containsMouse ? 0.05 : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        LP.LucidaMark {
            x: Theme.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(30)
            height: Theme.dp(30)
            strokeWidth: 2.4
            ringColor: w.inkAccent
            starColor: w.ink
        }

        LText {
            x: Theme.dp(64)
            anchors.verticalCenter: parent.verticalCenter
            role: "titleMedium"
            color: w.inkDim
            text: I18n.tr("Search")
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(13)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(6)

            Repeater {
                model: w.variant === "pill" ? [w.modes[1], w.modes[2]] : []

                Item {
                    id: quick

                    required property var modelData

                    width: Theme.dp(46)
                    height: Theme.dp(46)

                    MaterialShape {
                        anchors.fill: parent
                        shape: "circle"
                        to: quick.modelData.shape
                        morph: quickTap.containsMouse ? 1 : 0
                        color: Theme.alpha(w.inkAccent, quickTap.containsMouse ? 0.22 : 0.12)
                        rotation: quickTap.containsMouse ? 20 : 0
                        scale: quickTap.pressed ? 0.9 : 1

                        Behavior on morph {
                            NumberAnimation {
                                duration: Theme.durDefaultSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveStandard
                            }

                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durSlowSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveSlowSpatial
                            }

                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: parent
                        name: quick.modelData.icon
                        size: Theme.dp(22)
                        fill: quickTap.containsMouse ? 1 : 0
                        color: w.inkAccent
                    }

                    WidgetTap {
                        id: quickTap

                        anchors.fill: parent
                        widget: w
                        onTapped: w.open(quick.modelData.key)
                    }

                }

            }

        }

    }

    // bar: the search field over the launcher's modes, each on a shape of its own
    Item {
        id: barFace

        visible: w.variant === "bar"
        anchors.fill: parent

        Rectangle {
            id: field

            x: Theme.dp(14)
            y: Theme.dp(14)
            width: parent.width - Theme.dp(28)
            height: Theme.dp(56)
            radius: height / 2
            color: Theme.alpha(w.ink, fieldTap.pressed ? 0.14 : (fieldTap.containsMouse ? 0.11 : 0.08))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

            LP.LucidaMark {
                x: Theme.dp(16)
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.dp(28)
                height: Theme.dp(28)
                strokeWidth: 2.4
                ringColor: w.inkAccent
                starColor: w.ink
            }

            LText {
                x: Theme.dp(56)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - Theme.dp(20)
                elide: Text.ElideRight
                role: "titleMedium"
                color: w.inkDim
                text: I18n.tr("Search apps, files and the web")
            }

            WidgetTap {
                id: fieldTap

                anchors.fill: parent
                widget: w
                onTapped: w.open("")
            }

        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: field.bottom
            anchors.topMargin: Theme.dp(12)

            Repeater {
                model: w.variant === "bar" ? w.modes : []

                Item {
                    id: mode

                    required property var modelData

                    width: Math.floor((barFace.width - Theme.dp(28)) / w.modes.length)
                    height: Theme.dp(80)

                    MaterialShape {
                        id: modeShape

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Theme.dp(52)
                        height: Theme.dp(52)
                        shape: mode.modelData.shape
                        color: modeTap.containsMouse ? w.inkAccent : Theme.alpha(w.inkAccent, 0.16)
                        rotation: modeTap.containsMouse ? 30 : 0
                        scale: modeTap.pressed ? 0.9 : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durShort
                            }

                        }

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.durSlowSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveSlowSpatial
                            }

                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durFastSpatial
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveFastSpatial
                            }

                        }

                    }

                    Icon {
                        anchors.centerIn: modeShape
                        name: mode.modelData.icon
                        size: Theme.dp(22)
                        fill: modeTap.containsMouse ? 1 : 0
                        color: modeTap.containsMouse ? w.fgInkAccent : w.inkAccent
                    }

                    LText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: modeShape.bottom
                        anchors.topMargin: Theme.dp(6)
                        role: "labelMedium"
                        color: w.inkDim
                        text: mode.modelData.label
                    }

                    WidgetTap {
                        id: modeTap

                        anchors.fill: parent
                        widget: w
                        onTapped: w.open(mode.modelData.key)
                    }

                }

            }

        }

    }

}
