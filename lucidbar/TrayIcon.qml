import QtQuick
import QtQuick.Effects
import qs
import qs.lucidicons

// a tray app's icon: lucid's own for it, else the one the app sends, in the
// shell's colours when the module's card asks. it keeps the last face it had,
// so an app that quits fades out still looking like itself
Item {
    id: ti

    property var item: null
    property real size: Theme.dp(24)
    property bool hovered: false
    // the card's colour choice is for the apps' own icons only
    property bool tinted: true

    readonly property real px: Math.round(ti.size)
    readonly property string slot: ti.item ? Tray.slotOf(ti.item) : ti.keptSlot
    readonly property string source: ti.item ? Tray.iconSource(ti.item.icon) : ti.keptSource
    readonly property string letter: ti.item ? Tray.nameOf(ti.item).charAt(0).toUpperCase() : ti.keptLetter
    property string keptSlot: ""
    property string keptSource: ""
    property string keptLetter: ""
    readonly property bool drawn: ti.slot === "" && art.status === Image.Ready
    // a symbolic icon is one shape meant to take the text's colour, as gtk paints
    // it; drawn as sent, a dark theme's white one vanishes on a light bar
    readonly property bool symbolic: ti.source.indexOf("-symbolic") !== -1
    readonly property bool recoloured: ti.tinted && Prefs.trayIconColor !== "original"

    onSlotChanged: {
        if (ti.item)
            ti.keptSlot = ti.slot;

    }
    onSourceChanged: {
        if (ti.item)
            ti.keptSource = ti.source;

    }
    onLetterChanged: {
        if (ti.item)
            ti.keptLetter = ti.letter;

    }
    Component.onCompleted: {
        ti.keptSlot = ti.slot;
        ti.keptSource = ti.source;
        ti.keptLetter = ti.letter;
    }
    width: ti.px
    height: ti.px

    // never off the main thread: an icon theme source loaded asynchronously
    // takes the whole shell down
    Image {
        id: art

        anchors.fill: parent
        visible: ti.drawn
        source: ti.slot === "" ? ti.source : ""
        // drawn at twice the size and brought down, so a small icon keeps its edges
        sourceSize.width: ti.px * 2
        sourceSize.height: ti.px * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
        layer.enabled: ti.recoloured || ti.symbolic

        // its light and shade kept, the hue taken from the text (grey) or one of the
        // palette's colours, lifted first so a mid-tone icon reads like the bar's text.
        // a symbolic one left as sent still takes the text's colour, all of it
        layer.effect: MultiEffect {
            readonly property color role: Prefs.trayIconColor === "accent" ? Theme.cPrimary : (Prefs.trayIconColor === "tertiary" ? Theme.cTertiary : Theme.cSecondary)

            brightness: ti.recoloured ? 0.4 : 1
            colorization: 1
            colorizationColor: !ti.recoloured || Prefs.trayIconColor === "grey" ? Theme.text : Theme.atTone(role, Theme.isLight ? 40 : 80)
        }

    }

    Loader {
        anchors.centerIn: parent
        active: ti.slot !== ""

        sourceComponent: TonalIcon {
            size: ti.px
            slot: ti.slot
            hovered: ti.hovered
        }

    }

    // nothing to draw: the app's initial on a soft disc
    Rectangle {
        visible: ti.slot === "" && !ti.drawn
        anchors.fill: parent
        radius: width / 2
        color: Theme.alpha(Theme.text, 0.12)

        Text {
            anchors.centerIn: parent
            text: ti.letter !== "" ? ti.letter : "?"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(8, Math.round(ti.px * 0.5))
            font.variableAxes: Theme.axes(Math.max(8, Math.round(ti.px * 0.5)), 640, 0)
        }

    }

}
