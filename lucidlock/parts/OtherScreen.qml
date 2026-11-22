import QtQuick

// every screen but the main one: the time in the middle and a word that the
// machine is locked, or nothing at all over the backdrop
Item {
    id: p

    property var stage: null
    readonly property var authHost: null
    readonly property bool blank: p.stage.layout && p.stage.layout.other === "blank"

    Column {
        anchors.centerIn: parent
        spacing: p.stage.dp(10)
        visible: !p.blank
        opacity: p.stage.rv(0.08)

        transform: Translate {
            y: (1 - p.stage.rv(0.08)) * 24
        }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
            theme: p.stage.theme
            lock: p.stage.lock
            align: Qt.AlignHCenter
            screenH: p.height
            // the main screen's clock face, a size up
            opts: {
                var o = Object.assign({}, p.stage.optsOf("clock"));
                o.size = "L";
                return o;
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: p.stage.dp(8)
            topPadding: p.stage.dp(18)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "lock"
                size: p.stage.dp(17)
                color: p.stage.theme.subtextDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: p.stage.lock && p.stage.lock.lockedWord ? p.stage.lock.lockedWord : "Locked" // i18n-skip
                color: p.stage.theme.subtextDim
                font.family: p.stage.theme.fontFamily
                font.pixelSize: p.stage.theme.fontBodyMd
                font.variableAxes: p.stage.theme.axes(p.stage.theme.fontBodyMd, 420, 0)
            }

        }

    }

}
