import QtQuick

// a line of the user's own, such as who to call if the machine is found
WidgetBase {
    id: msg

    readonly property string text: String(msg.opts.text || "").trim()
    readonly property string icon: msg.opts.icon || "info"
    readonly property bool boxed: msg.opts.style === "card" && !msg.carded
    readonly property real pad: msg.boxed ? msg.kp(16) : 0
    readonly property real maxW: Math.min(msg.avail, msg.kp(460))
    readonly property real iconBox: msg.icon === "none" ? 0 : msg.kp(msg.boxed ? 36 : 22)

    hasContent: msg.text !== "" || msg.editing
    implicitWidth: Math.min(msg.maxW, row.implicitWidth + msg.pad * 2)
    implicitHeight: Math.max(row.implicitHeight, 1) + msg.pad * 2

    Item {
        width: msg.implicitWidth
        height: msg.implicitHeight
        x: msg.xFor(width, msg.width)

        Rectangle {
            anchors.fill: parent
            radius: msg.theme.shapeLg
            color: msg.onCard ? msg.theme.cardHigh : msg.theme.card
            visible: msg.boxed
        }

        Row {
            id: row

            x: msg.pad
            y: msg.pad
            spacing: msg.kp(12)
            layoutDirection: msg.align === Qt.AlignRight && !msg.boxed ? Qt.RightToLeft : Qt.LeftToRight

            Rectangle {
                width: msg.iconBox
                height: width
                radius: width / 2
                color: msg.boxed ? msg.theme.accentContainer : "transparent"
                visible: msg.icon !== "none"
                anchors.verticalCenter: parent.verticalCenter

                Glyph {
                    anchors.centerIn: parent
                    name: msg.icon
                    size: msg.kp(msg.boxed ? 19 : 20)
                    color: msg.boxed ? msg.theme.fgAccentContainer : (msg.tonal ? msg.theme.fgAccentContainer : msg.theme.accent)
                }

            }

            Text {
                width: Math.min(implicitWidth, msg.maxW - msg.pad * 2 - (msg.icon !== "none" ? msg.iconBox + row.spacing : 0))
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                horizontalAlignment: msg.boxed ? Text.AlignLeft : msg.hAlign
                text: msg.text !== "" ? msg.text : (msg.lock ? msg.lock.tr("Your message") : "")
                opacity: msg.text !== "" ? 1 : 0.55
                color: msg.tonal ? msg.theme.fgAccentContainer : (msg.boxed ? msg.theme.text : msg.theme.subtext)
                font.family: msg.theme.fontFamily
                font.pixelSize: Math.round(msg.theme.fontBodyLg * msg.k)
                font.variableAxes: msg.theme.axes(Math.round(msg.theme.fontBodyLg * msg.k), 450, 0)
            }

        }

    }

}
