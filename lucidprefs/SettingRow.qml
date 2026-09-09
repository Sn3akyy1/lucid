import QtQuick
import QtQuick.Shapes
import qs

// one item of an m3 grouped list: its own container, rounded large where the
// group ends and small where it meets a neighbour
Item {
    id: row

    readonly property bool isGroupItem: true
    // written by the enclosing SettingCard
    property bool groupFirst: true
    property bool groupLast: true
    property string title: ""
    property string description: ""
    property bool enabled: true
    property string disabledReason: ""
    property bool stacked: false
    property bool showDivider: true // kept for callers; gaps replace dividers now
    property bool monoTitle: false
    property string resetKey: ""
    property string resetAction: row.resetKey
    property bool resetVisible: row.resetKey !== "" && Prefs.isModified(row.resetKey)
    property string resetTitle: row.title
    property string warning: ""
    default property alias control: holder.data
    readonly property string activeDescription: (!row.enabled && row.disabledReason !== "") ? row.disabledReason : row.description
    readonly property int outerRadius: 26
    readonly property int innerRadius: 6
    readonly property int padH: 22
    readonly property int padV: 16
    // the SettingCard this row belongs to, if any
    readonly property var group: {
        for (var p = row.parent; p; p = p.parent) {
            if (p.isSettingGroup === true)
                return p;

        }
        return null;
    }

    implicitWidth: parent ? parent.width : 400
    implicitHeight: Math.max(60, (row.stacked ? labels.implicitHeight + holder.implicitHeight + 14 : Math.max(labels.implicitHeight, holder.implicitHeight)) + row.padV * 2)
    onVisibleChanged: {
        if (row.group)
            row.group.regroupLater();

    }

    Rectangle {
        id: container

        anchors.fill: parent
        topLeftRadius: row.groupFirst ? row.outerRadius : row.innerRadius
        topRightRadius: row.groupFirst ? row.outerRadius : row.innerRadius
        bottomLeftRadius: row.groupLast ? row.outerRadius : row.innerRadius
        bottomRightRadius: row.groupLast ? row.outerRadius : row.innerRadius
        color: Theme.withBlur(Theme.bgTile)

        // pointer feedback as a state layer, the way the rest of the app does it
        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Theme.text
            opacity: hover.hovered && row.enabled ? Theme.stateHover * 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

        }

        // pointer feedback only; must never swallow clicks meant for the control
        HoverHandler {
            id: hover
        }

        Behavior on topLeftRadius {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Theme.easeStandard
            }

        }

    }

    Column {
        id: labels

        anchors.left: parent.left
        anchors.leftMargin: row.padH
        anchors.right: row.stacked ? parent.right : holder.left
        anchors.rightMargin: row.stacked ? row.padH : 20
        anchors.top: parent.top
        anchors.topMargin: row.padV
        spacing: 4

        Item {
            width: parent.width
            height: Math.max(titleText.implicitHeight, resetBtn.height)

            Text {
                id: titleText

                anchors.left: parent.left
                anchors.right: resetBtn.left
                anchors.rightMargin: row.resetVisible ? 6 : 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.title
                color: Theme.text
                font.family: row.monoTitle ? "monospace" : Theme.fontFamily
                font.features: row.monoTitle ? ({
                    "liga": 0,
                    "calt": 0
                }) : ({
                })
                font.pixelSize: Theme.fontBodyLg
                font.weight: Font.Medium
                opacity: row.enabled ? 1 : 0.38
                elide: Text.ElideRight

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            M3IconButton {
                id: resetBtn

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                size: 30
                iconSize: 17
                width: row.resetVisible ? 30 : 0
                enabled: row.resetVisible
                opacity: row.resetVisible ? 1 : 0
                visible: opacity > 0.01
                iconPath: "M17.65 6.35A7.958 7.958 0 0 0 12 4a8 8 0 1 0 7.73 10h-2.08A6 6 0 1 1 12 6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35Z"
                onClicked: Prefs.askReset("Reset " + row.resetTitle.toLowerCase() + "?", "This puts \"" + row.resetTitle + "\" back to the value it ships with.", row.resetAction)

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Theme.easeStandard
                    }

                }

            }

        }

        Text {
            width: parent.width
            text: row.activeDescription
            color: !row.enabled && row.disabledReason !== "" ? Theme.accentMuted : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontBodyMd
            lineHeight: 1.28
            opacity: row.enabled ? 1 : 0.5
            wrapMode: Text.WordWrap
            visible: row.activeDescription !== ""

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

        }

        // a caution about the setting itself, beside a warning mark
        Item {
            width: parent.width
            height: warnText.implicitHeight
            visible: row.warning !== ""
            opacity: row.enabled ? 1 : 0.5

            Shape {
                id: warnMark

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.topMargin: 1
                width: 15
                height: 15
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 0
                    fillColor: Theme.error

                    PathSvg {
                        path: "M12 2 1 21h22L12 2Zm0 5 7.5 12.9h-15L12 7Zm-1 4v5h2v-5h-2Zm0 6v2h2v-2h-2Z"
                    }

                }

                transform: Scale {
                    xScale: 15 / 24
                    yScale: 15 / 24
                }

            }

            Text {
                id: warnText

                anchors.left: warnMark.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.top: parent.top
                text: row.warning
                color: Theme.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

        }

    }

    Item {
        id: holder

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        anchors.right: parent.right
        anchors.rightMargin: row.padH
        anchors.left: row.stacked ? parent.left : undefined
        anchors.leftMargin: row.padH
        anchors.top: row.stacked ? labels.bottom : undefined
        anchors.topMargin: row.stacked ? 12 : 0
        anchors.verticalCenter: row.stacked ? undefined : parent.verticalCenter
    }

}
