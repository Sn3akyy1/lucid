import QtQuick
import QtQuick.Shapes
import qs

// Meteocons line art (MIT, Bas Milius) drawn in its native 512 space and
// scaled down. Every condition carries its own motion: the sun spins, the
// moon rocks, clouds drift, rain falls, snow tumbles, fog slides, bolts flash.
Item {
    id: icon

    // clear, clear-night, partly, partly-night, cloud, rain, snow, storm, fog
    property string kind: "clear"
    property real size: 48
    property color tint: Theme.accent
    property color cloudColor: Theme.subtext
    property bool animate: true

    // the bar passes "sunny"/"cloudy"; everything else already matches
    readonly property string k: icon.kind === "sunny" ? "clear" : (icon.kind === "cloudy" ? "cloud" : icon.kind)
    readonly property bool bigSun: icon.k === "clear"
    readonly property bool bigMoon: icon.k === "clear-night"
    readonly property bool smallSun: icon.k === "partly"
    readonly property bool smallMoon: icon.k === "partly-night"
    readonly property bool hasCloud: icon.k !== "clear" && icon.k !== "clear-night"
    // meteocons draws at 15 units; hold that to ~1.35px however far we scale down
    readonly property real weight: Math.max(1, (512 * 1.35 / Math.max(1, icon.size)) / 15)
    // meteocons sizes each viewBox to fit a 15-unit stroke exactly, so a thicker
    // one overhangs and Shape clips it; grow every Shape and shift its paint back
    readonly property real pad: 40

    implicitWidth: icon.size
    implicitHeight: icon.size

    component Stroked: Shape {
        id: st

        property string d: ""
        property color stroke: icon.cloudColor
        property real units: 15

        anchors.fill: parent
        anchors.margins: -icon.pad
        preferredRendererType: Shape.CurveRenderer

        transform: Translate {
            x: icon.pad
            y: icon.pad
        }

        ShapePath {
            strokeColor: st.stroke
            strokeWidth: st.units * icon.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: st.d
            }

        }

    }

    component Filled: Shape {
        id: fl

        property string d: ""
        property color fill: icon.tint

        anchors.fill: parent
        anchors.margins: -icon.pad
        preferredRendererType: Shape.CurveRenderer

        transform: Translate {
            x: icon.pad
            y: icon.pad
        }

        ShapePath {
            fillColor: fl.fill
            strokeWidth: 0

            PathSvg {
                path: fl.d
            }

        }

    }

    // one condition layer; crossfades as the forecast changes
    component Layer: Item {
        property bool on: false

        opacity: on ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.ms(260)
                easing.type: Theme.easeStandard
            }

        }

    }

    Item {
        id: art

        width: 512
        height: 512
        transformOrigin: Item.TopLeft
        scale: icon.size / 512

        Layer {
            x: 68.5
            y: 68.5
            width: 375
            height: 375
            on: icon.bigSun

            Stroked {
                d: "M103.5 187.5a84 84 0 1 0 168 0a84 84 0 1 0-168 0"
                stroke: icon.tint
            }

            Item {
                anchors.fill: parent

                Stroked {
                    d: "M187.5 57.2V7.5m0 360v-49.7m92.2-222.5l35-35M60.3 314.7l35.1-35.1m0-184.4l-35-35m254.5 254.5l-35.1-35.1M57.2 187.5H7.5m360 0h-49.7"
                    stroke: icon.tint
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 45
                    duration: Theme.ms(6000)
                    loops: Animation.Infinite
                    running: icon.animate && icon.bigSun
                }

            }

        }

        Layer {
            x: 116.5
            y: 116.5
            width: 279
            height: 279
            on: icon.bigMoon

            Stroked {
                d: "M256.8 173.1A133.3 133.3 0 0 1 122.4 40.7A130.5 130.5 0 0 1 127 7.5A133 133 0 0 0 7.5 139.1c0 73.1 60 132.4 134.2 132.4c62.5 0 114.8-42.2 129.8-99.2a135.6 135.6 0 0 1-14.8.8Z"
                stroke: icon.tint
            }

            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: icon.animate && icon.bigMoon

                NumberAnimation {
                    from: -15
                    to: 9
                    duration: Theme.ms(3000)
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 9
                    to: -15
                    duration: Theme.ms(3000)
                    easing.type: Easing.InOutSine
                }

            }

        }

        Layer {
            x: 24
            y: 66
            width: 193
            height: 193
            on: icon.smallSun

            Stroked {
                d: "M56.5 96.5a40 40 0 1 0 80 0a40 40 0 1 0-80 0"
                stroke: icon.tint
                units: 9
            }

            Item {
                anchors.fill: parent

                Stroked {
                    d: "M96.5 29.9V4.5m0 184v-25.4m47.1-113.7l18-18M31.4 161.6l18-18m0-94.2l-18-18m130.2 130.2l-18-18M4.5 96.5h25.4m158.6 0h-25.4"
                    stroke: icon.tint
                    units: 9
                }

                RotationAnimation on rotation {
                    from: 0
                    to: 45
                    duration: Theme.ms(6000)
                    loops: Animation.Infinite
                    running: icon.animate && icon.smallSun
                }

            }

        }

        Layer {
            x: 6
            y: 44
            width: 178
            height: 178
            // the moon fills far more of its box than the sun does, so it needs
            // shrinking to tuck behind the cloud instead of colliding with it
            scale: 0.72
            transformOrigin: Item.TopLeft
            on: icon.smallMoon

            Stroked {
                d: "M163.6 110.4a84.8 84.8 0 0 1-85.4-84.3A83.3 83.3 0 0 1 81 5A84.7 84.7 0 0 0 5 88.7A84.8 84.8 0 0 0 90.4 173a85.2 85.2 0 0 0 82.6-63.1a88 88 0 0 1-9.4.5Z"
                stroke: icon.tint
                units: 14
            }

            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: icon.animate && icon.smallMoon

                NumberAnimation {
                    from: -15
                    to: 9
                    duration: Theme.ms(3000)
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    from: 9
                    to: -15
                    duration: Theme.ms(3000)
                    easing.type: Easing.InOutSine
                }

            }

        }

        // the second, smaller bank only shows for a fully overcast sky
        Layer {
            id: backCloud

            x: 272
            y: 165
            width: 214.3
            height: 140.1
            on: icon.k === "cloud"

            Item {
                width: parent.width
                height: parent.height

                Stroked {
                    d: "M7.5 100.2a32.4 32.4 0 0 0 32.4 32.4h129.8v-.1l2.3.1a34.8 34.8 0 0 0 6.5-68.9a32.4 32.4 0 0 0-48.5-33a48.6 48.6 0 0 0-88.6 37.1h-1.5a32.4 32.4 0 0 0-32.4 32.4Z"
                    stroke: Theme.alpha(icon.cloudColor, 0.55)
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: icon.animate && icon.k === "cloud"

                    NumberAnimation {
                        from: -9
                        to: 9
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: 9
                        to: -9
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                }

            }

        }

        Layer {
            id: frontCloud

            x: 76.5
            y: 140.5
            width: 359
            height: 231
            on: icon.hasCloud

            Item {
                width: parent.width
                height: parent.height

                Stroked {
                    d: "M295.5 223.5a56 56 0 0 0 0-112l-2.5.1a83.9 83.9 0 0 0-153-64.2a56 56 0 0 0-84.6 48.1a56.6 56.6 0 0 0 .8 9a60 60 0 0 0 11.2 119Z"
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: icon.animate && icon.k === "cloud"

                    NumberAnimation {
                        from: -18
                        to: 18
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: 18
                        to: -18
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                }

            }

        }

        Layer {
            x: 192
            y: 344
            width: 128
            height: 56
            on: icon.k === "rain"

            Repeater {
                model: 3

                Item {
                    id: drop

                    required property int index

                    x: drop.index * 56
                    width: 16
                    height: 56
                    opacity: 0

                    Filled {
                        d: "M8 56a8 8 0 0 1-8-8V8a8 8 0 0 1 16 0v40a8 8 0 0 1-8 8Z"
                    }

                    SequentialAnimation {
                        running: icon.animate && icon.k === "rain"

                        PauseAnimation {
                            duration: Theme.ms(drop.index * 333)
                        }

                        SequentialAnimation {
                            loops: Animation.Infinite

                            ParallelAnimation {
                                NumberAnimation {
                                    target: drop
                                    property: "y"
                                    from: -60
                                    to: 60
                                    duration: Theme.ms(670)
                                }

                                SequentialAnimation {
                                    NumberAnimation {
                                        target: drop
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: Theme.ms(168)
                                    }

                                    NumberAnimation {
                                        target: drop
                                        property: "opacity"
                                        from: 1
                                        to: 0
                                        duration: Theme.ms(502)
                                    }

                                }

                            }

                            PauseAnimation {
                                duration: Theme.ms(330)
                            }

                        }

                    }

                }

            }

        }

        Layer {
            x: 178.4
            y: 338
            width: 155.2
            height: 48
            on: icon.k === "snow"

            Repeater {
                model: 3

                Item {
                    id: flake

                    required property int index

                    x: flake.index * 56
                    width: 48
                    height: 48
                    opacity: 0

                    Filled {
                        d: "m41.2 30.5l-5.8-3.3a13.7 13.7 0 0 0 0-6.4l5.8-3.3a4 4 0 0 0 1.5-5.5a4 4 0 0 0-5.6-1.5l-5.8 3.3a13.6 13.6 0 0 0-2.6-2a13.8 13.8 0 0 0-3-1.2V4a4 4 0 0 0-8.1 0v6.6a14.3 14.3 0 0 0-5.7 3.2l-5.8-3.3A4 4 0 0 0 .5 12A4 4 0 0 0 2 17.5l5.8 3.3a13.7 13.7 0 0 0 0 6.4L2 30.5A4 4 0 0 0 .5 36a4 4 0 0 0 3.6 2a4 4 0 0 0 2-.5l5.8-3.3a13.6 13.6 0 0 0 2.6 2a13.8 13.8 0 0 0 3 1.2V44a4 4 0 0 0 8 0v-6.6a14.2 14.2 0 0 0 5.8-3.2l5.8 3.3a4 4 0 0 0 2 .5a4 4 0 0 0 3.5-2a4 4 0 0 0-1.4-5.5Zm-22.6-1.3a6 6 0 0 1-2.3-8.2a6.1 6.1 0 0 1 5.3-3a6.2 6.2 0 0 1 3 .8A6 6 0 0 1 27 27a6.1 6.1 0 0 1-8.3 2.2Z"
                    }

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Theme.ms(6000)
                        loops: Animation.Infinite
                        running: icon.animate && icon.k === "snow"
                    }

                    SequentialAnimation {
                        running: icon.animate && icon.k === "snow"

                        PauseAnimation {
                            duration: Theme.ms(flake.index * 667)
                        }

                        SequentialAnimation {
                            loops: Animation.Infinite

                            ParallelAnimation {
                                NumberAnimation {
                                    target: flake
                                    property: "y"
                                    from: -36
                                    to: 92
                                    duration: Theme.ms(2000)
                                }

                                SequentialAnimation {
                                    NumberAnimation {
                                        target: flake
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: Theme.ms(340)
                                    }

                                    PauseAnimation {
                                        duration: Theme.ms(1320)
                                    }

                                    NumberAnimation {
                                        target: flake
                                        property: "opacity"
                                        from: 1
                                        to: 0
                                        duration: Theme.ms(340)
                                    }

                                }

                            }

                        }

                    }

                }

            }

        }

        Layer {
            x: 127
            y: 405
            width: 258
            height: 66
            on: icon.k === "fog"

            Item {
                width: parent.width
                height: parent.height

                Stroked {
                    d: "M9 57h240"
                    units: 18
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: icon.animate && icon.k === "fog"

                    NumberAnimation {
                        from: -24
                        to: 24
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: 24
                        to: -24
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                }

            }

            Item {
                width: parent.width
                height: parent.height

                Stroked {
                    d: "M9 9h240"
                    units: 18
                }

                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: icon.animate && icon.k === "fog"

                    NumberAnimation {
                        from: 24
                        to: -24
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        from: -24
                        to: 24
                        duration: Theme.ms(3000)
                        easing.type: Easing.InOutSine
                    }

                }

            }

        }

        Layer {
            id: bolt

            x: 208
            y: 293
            width: 96
            height: 176
            on: icon.k === "storm"

            Item {
                id: boltFlash

                anchors.fill: parent

                Filled {
                    d: "M32 0L0 96h32l-16 80L96 64H48L80 0H32z"
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: icon.animate && icon.k === "storm"

                    PauseAnimation {
                        duration: Theme.ms(500)
                    }

                    NumberAnimation {
                        to: 0
                        duration: Theme.ms(60)
                    }

                    NumberAnimation {
                        to: 1
                        duration: Theme.ms(60)
                    }

                    NumberAnimation {
                        to: 0
                        duration: Theme.ms(60)
                    }

                    NumberAnimation {
                        to: 1
                        duration: Theme.ms(60)
                    }

                    PauseAnimation {
                        duration: Theme.ms(1400)
                    }

                }

            }

        }

    }

}
