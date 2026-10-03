import QtQuick
import Qt5Compat.GraphicalEffects

// a face cut to the lock's cookie, or the initials on its fill when there is
// no face worth showing
Item {
    id: av

    property string source: ""
    property string initials: "?"
    property real spin: 0
    property int textSize: Math.round(av.width * 0.34)
    // sddm hands every account without a picture its stock silhouette
    readonly property bool stock: av.source === "" || (/\/\.face\.icon$/.test(av.source) && av.source.indexOf("/sddm/faces/") >= 0)
    readonly property bool ready: !av.stock && face.status === Image.Ready

    Cookie {
        anchors.fill: parent
        spin: av.spin
        color: Theme.accentContainer
        visible: !av.ready

        Text {
            anchors.centerIn: parent
            text: av.initials
            color: Theme.fgAccentContainer
            font.family: Theme.fontFamily
            font.pixelSize: av.textSize
            font.variableAxes: Theme.axes(av.textSize, 560, 100)
            font.weight: Font.DemiBold
        }

    }

    Image {
        id: face

        anchors.fill: parent
        source: av.stock ? "" : av.source
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Math.round(av.width * 2)
        sourceSize.height: Math.round(av.height * 2)
        asynchronous: true
        cache: false
        visible: false
    }

    Cookie {
        id: mask

        anchors.fill: parent
        spin: av.spin
        color: "black"
        visible: false
    }

    OpacityMask {
        anchors.fill: parent
        visible: av.ready
        source: face
        maskSource: mask
    }

}
