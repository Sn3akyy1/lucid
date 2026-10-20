import QtQuick
import qs
import qs.lucidui

// an icon-only tile with its name underneath
Item {
    id: st

    property string icon: ""
    property string label: ""
    property bool checked: false
    // a right click asks for more than the tap does
    property bool hasMore: false
    // round while off, and turning into this shape as it comes on, in
    // place of squaring off
    property string shape: ""

    signal toggled()
    signal more()

    // the gap beside it, which its name may spill into
    property real gutter: Theme.dp(8)

    height: st.width + Theme.dp(20)

    Rectangle {
        id: sq

        width: st.width
        height: st.width
        radius: st.checked && st.shape === "" ? Theme.shapeLg : width / 2
        color: st.shape !== "" ? "transparent" : (st.checked ? Theme.primary : Theme.withBlur(Theme.surfaceHighest))

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        MaterialShape {
            visible: st.shape !== ""
            anchors.fill: parent
            shape: "circle"
            to: st.shape
            morph: st.checked ? 1 : 0
            rotation: st.checked ? 0 : -60
            color: st.checked ? Theme.primary : Theme.withBlur(Theme.surfaceHighest)

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
                    duration: Theme.durDefaultEffects
                }

            }

        }

        StateLayer {
            radius: sq.radius
            tint: st.checked ? Theme.fgPrimary : Theme.text
            acceptedButtons: st.hasMore ? (Qt.LeftButton | Qt.RightButton) : Qt.LeftButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton)
                    st.more();
                else
                    st.toggled();
            }
        }

        Icon {
            anchors.centerIn: parent
            name: st.icon
            size: Theme.dp(22)
            fill: st.checked ? 1 : 0
            color: st.checked ? Theme.fgPrimary : Theme.text
        }

    }

    LText {
        anchors.top: sq.bottom
        anchors.topMargin: Theme.dp(4)
        anchors.horizontalCenter: parent.horizontalCenter
        // the gutter is the label's too; past that it shrinks a little before it elides
        width: st.width + st.gutter
        horizontalAlignment: Text.AlignHCenter
        role: "labelSmall"
        color: st.checked ? Theme.text : Theme.subtext
        text: st.label
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: Math.max(Theme.dp(8), size - Theme.dp(2))
        elide: Text.ElideRight
    }

}
