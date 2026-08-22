import QtQuick
import QtQuick.Shapes
import qs

// A single setting: label and explanation on the left, control on the right.
// Sliders get `stacked` instead, which drops the control onto its own
// full-width line underneath - a slider squeezed into the right-hand column
// is too short to aim at.
//
// `enabled` here is the real mechanism behind the greyed-out dependent
// settings (inline mode under pop-up mode): the row dims, its control stops
// accepting input, and a reason can be shown in place of the description.
Item {
    id: row

    property string title: ""
    property string description: ""
    property bool enabled: true
    // shown instead of `description` while disabled, to say *why* rather than
    // leaving a dead control with no explanation
    property string disabledReason: ""
    property bool stacked: false
    property bool showDivider: true
    // command lines are set in monospace with ligatures off - Google Sans
    // renders a literal "--" as an em dash, which is actively wrong when the
    // text is something the reader is meant to type
    property bool monoTitle: false
    // ---- reset affordance ----
    // Naming the settings key is enough: the row can read both the live value
    // and the shipped default off Prefs, so it knows on its own whether it has
    // anything to offer and what resetting would mean. `resetAction` only
    // needs setting for the handful of resets that are not a plain key (the
    // blur amount lives in Theme, not Prefs).
    property string resetKey: ""
    property string resetAction: row.resetKey
    property bool resetVisible: row.resetKey !== "" && Prefs.isModified(row.resetKey)
    property string resetTitle: row.title
    default property alias control: holder.data

    readonly property string activeDescription: (!row.enabled && row.disabledReason !== "") ? row.disabledReason : row.description

    implicitWidth: parent ? parent.width : 400
    implicitHeight: (row.stacked ? labels.implicitHeight + holder.implicitHeight + 12 : Math.max(labels.implicitHeight, holder.implicitHeight)) + 28

    Column {
        id: labels

        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.right: row.stacked ? parent.right : holder.left
        anchors.rightMargin: row.stacked ? 20 : 16
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 3

        Item {
            width: parent.width
            height: titleText.implicitHeight

            Text {
                id: titleText

                anchors.left: parent.left
                anchors.right: resetBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.title
                color: Theme.text
                font.family: row.monoTitle ? "monospace" : Theme.fontFamily
                font.features: row.monoTitle ? ({
                    "liga": 0,
                    "calt": 0
                }) : ({})
                font.pixelSize: Theme.fontTitle
                opacity: row.enabled ? 1 : 0.38
                elide: Text.ElideRight

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // only appears once the setting has actually been moved off its
            // default - a reset button on an already-default row is a control
            // that cannot do anything
            Rectangle {
                id: resetBtn

                width: row.resetVisible ? 26 : 0
                height: 26
                radius: 13
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: resetArea.containsMouse ? Theme.alpha(Theme.text, Theme.stateHover) : "transparent"
                opacity: row.resetVisible ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durQuick
                    }

                }

                Shape {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: 0
                        fillColor: resetArea.containsMouse ? Theme.text : Theme.subtext

                        PathSvg {
                            path: "M17.65 6.35A7.958 7.958 0 0 0 12 4a8 8 0 1 0 7.73 10h-2.08A6 6 0 1 1 12 6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35Z"
                        }

                    }

                    transform: Scale {
                        xScale: 16 / 24
                        yScale: 16 / 24
                    }

                }

                MouseArea {
                    id: resetArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.resetVisible
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Prefs.askReset("Reset " + row.resetTitle.toLowerCase() + "?", "This puts \"" + row.resetTitle + "\" back to the value it ships with.", row.resetAction)
                }

            }

        }

        Text {
            width: parent.width
            text: row.activeDescription
            color: !row.enabled && row.disabledReason !== "" ? Theme.accentMuted : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            opacity: row.enabled ? 1 : 0.5
            wrapMode: Text.WordWrap
            visible: row.activeDescription !== ""

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    Item {
        id: holder

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.left: row.stacked ? parent.left : undefined
        anchors.leftMargin: 20
        anchors.top: row.stacked ? labels.bottom : parent.top
        anchors.topMargin: row.stacked ? 10 : 14
        anchors.verticalCenter: row.stacked ? undefined : undefined
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.outline, 0.6)
        visible: row.showDivider
    }

}
