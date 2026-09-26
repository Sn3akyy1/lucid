import QtQuick
import qs

// a small stand-in for a bar module in one of its styles, drawn with the
// bar's own fonts and colours, for the style tiles on the module's card.
// a module's samples are keyed "<id>/<style>", its panel's "<id>/panel/<style>"
Item {
    id: sample

    property string moduleId: ""
    property string styleKey: ""
    property bool panel: false

    readonly property string sampleKey: sample.moduleId + "/" + (sample.panel ? "panel/" : "") + sample.styleKey
    readonly property var samples: ({
    })

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    Loader {
        id: loader

        anchors.centerIn: parent
        width: sample.panel ? parent.width : implicitWidth
        height: sample.panel ? parent.height : implicitHeight
        sourceComponent: sample.samples[sample.sampleKey] || fallback
    }

    Component {
        id: fallback

        Text {
            text: sample.styleKey
            color: Theme.text
            font.family: Theme.fontFamily
            font.bold: true
            font.pixelSize: Theme.fs(13)
        }

    }

    // a bit of bar text, as the modules set it
    component BarText: Text {
        color: Theme.text
        font.family: Theme.fontFamily
        font.bold: true
        font.pixelSize: Theme.fs(13)
    }

}
