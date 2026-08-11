import QtQuick
import qs

Item {
    id: blurRow

    readonly property var steps: [0, 0.2, 0.5, 0.8, 1]
    readonly property var stepLabels: ["Off", "Light", "Balanced", "Heavy", "Full"]
    property real value: 0
    property bool dragging: false
    property real dragValue: 0
    readonly property real displayValue: dragging ? dragValue : value
    readonly property int activeStepIndex: blurRow.nearestStepIndex(blurRow.displayValue)
    // settled height once resize finishes, see WallpaperStrip.qml/PowerRow.qml
    property real stableHeight: height

    signal levelChosen(real level)

    function nearestStepIndex(v) {
        var idx = 0, best = 999;
        for (var i = 0; i < blurRow.steps.length; i++) {
            var d = Math.abs(blurRow.steps[i] - v);
            if (d < best) {
                best = d;
                idx = i;
            }
        }
        return idx;
    }

    function updateFromX(x) {
        blurRow.dragging = true;
        var pct = Math.max(0, Math.min(1, x / track.width));
        var newValue = blurRow.steps[blurRow.nearestStepIndex(pct)];
        if (newValue !== blurRow.dragValue) {
            blurRow.dragValue = newValue;
            // commit on every step change while dragging, not just on
            // release, so the actual opacity updates live as you drag
            blurRow.levelChosen(newValue);
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 300)
        height: blurRow.stableHeight
        spacing: 16

        Item {
            width: parent.width
            height: 22

            Text {
                anchors.centerIn: parent
                text: blurRow.stepLabels[blurRow.activeStepIndex]
                color: Theme.text
                font.family: Theme.fontFamily
                font.bold: true
                font.pixelSize: Theme.fontHeadline

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

        }

        Item {
            id: track

            readonly property bool hovering: dragArea.containsMouse || blurRow.dragging
            readonly property real thumbSize: blurRow.dragging ? 20 : (track.hovering ? 18 : 14)
            readonly property real haloSize: blurRow.dragging ? 34 : (track.hovering ? 28 : 0)
            readonly property real thumbX: Math.max(0, Math.min(track.width, track.width * blurRow.displayValue))

            width: parent.width
            height: 36

            // inactive rail - brightens slightly on hover so the whole
            // control reads as interactive before you even touch the thumb
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 3
                radius: 1.5
                color: track.hovering ? Theme.outlineStrong : Theme.outline

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                height: 3
                radius: 1.5
                color: Theme.accent
                width: Math.max(0, parent.width * blurRow.displayValue)

                Behavior on width {
                    enabled: !blurRow.dragging

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

            }

            // step dots - kept tiny so five of them read cleanly on a track
            // this narrow; contrast flips once the fill sweeps past them
            Repeater {
                model: blurRow.steps

                Rectangle {
                    id: tick

                    required property real modelData
                    required property int index

                    readonly property bool isActive: blurRow.activeStepIndex === tick.index
                    readonly property bool covered: tick.modelData <= blurRow.displayValue + 0.001

                    width: tick.isActive ? 6 : 4
                    height: tick.width
                    radius: tick.width / 2
                    color: tick.covered ? Theme.alpha(Theme.onAccent, 0.85) : Theme.outlineStrong
                    anchors.verticalCenter: parent.verticalCenter
                    x: tick.modelData * track.width - tick.width / 2

                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                        }

                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }

                    }

                }

            }

            // Material 3-style state layer - a soft accent halo that blooms
            // behind the thumb on hover and further on drag
            Rectangle {
                anchors.centerIn: thumb
                width: track.haloSize
                height: track.haloSize
                radius: width / 2
                color: Theme.accent
                opacity: blurRow.dragging ? Theme.stateDragged : (track.hovering ? Theme.stateHover : 0)

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // draggable thumb - grows and picks up the matugen accent's
            // hover/pressed variants so the slider feels touchable, not just decorative
            Rectangle {
                id: thumb

                width: track.thumbSize
                height: track.thumbSize
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                x: track.thumbX - width / 2
                color: blurRow.dragging ? Theme.accentPressed : (track.hovering ? Theme.accentHover : Theme.accent)

                Behavior on x {
                    enabled: !blurRow.dragging

                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                onPressed: (mouse) => {
                    return blurRow.updateFromX(mouse.x);
                }
                onPositionChanged: (mouse) => {
                    if (pressed)
                        blurRow.updateFromX(mouse.x);

                }
                onReleased: {
                    blurRow.dragging = false;
                }
            }

        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Adjusts the bar's translucency"
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Experimental - can look glitchy at some settings"
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel - 1
            }
        }

    }

}
