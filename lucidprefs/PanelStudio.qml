import QtQuick
import qs

// the control centre's studio (Edit.studio === "system"): over one display, the
// panel lifted off the bar to the middle, the library to its left and the
// inspector to its right, never over each other. it rises out of where the
// panel was and goes back into it on the way out
Item {
    id: stage

    property bool hosted: false
    // the free band of the display, between edit mode's toolbar and the bar
    property rect area: Qt.rect(0, 0, stage.width, stage.height)
    // how far in it has come, driven from hosted below
    property real t: 0
    readonly property bool shown: stage.t > 0.001
    // for the layer's blur, once the panes have arrived
    readonly property bool settled: stage.hosted && stage.t > 0.998 && !!loader.item
    readonly property rect libRect: loader.item ? loader.item.libRect : Qt.rect(0, 0, 0, 0)
    readonly property rect canvasRect: loader.item ? loader.item.canvasRect : Qt.rect(0, 0, 0, 0)
    readonly property rect inspRect: loader.item ? loader.item.inspRect : Qt.rect(0, 0, 0, 0)

    // in as the shell's surfaces open, decelerating; out quicker, accelerating
    // into the bar. set before it starts, so each way runs on its own curve
    function travel() {
        enter.stop();
        enter.to = stage.hosted ? 1 : 0;
        enter.duration = stage.hosted ? Theme.durLong : Theme.durMedium;
        enter.easing.bezierCurve = stage.hosted ? Theme.easeEmphasizedDecel : Theme.easeEmphasizedAccel;
        enter.start();
    }

    // shown while it warms up too: every pane is clear at the start, but drawn,
    // so its first frame is paid for before it moves
    visible: stage.shown || warm.running
    // from closed it is built first, and set off once that and its first frame
    // are behind it, or the cost eats the start of the way in
    onHostedChanged: {
        if (stage.hosted && stage.t === 0)
            warm.restart();
        else
            stage.travel();
        if (stage.hosted)
            Qt.callLater(() => {
            if (loader.item)
                loader.item.forceActiveFocus();

        });

    }
    Component.onCompleted: {
        if (stage.hosted)
            warm.restart();

    }

    // a press on the shaded display around the panes lets go of the block
    MouseArea {
        anchors.fill: parent
        onPressed: {
            if (loader.item) {
                loader.item.selected = "";
                loader.item.menu = null;
                loader.item.forceActiveFocus();
            }
        }
    }

    // a fresh one each time, so it starts with nothing picked and its own undo
    Loader {
        id: loader

        anchors.fill: parent
        active: stage.hosted || stage.shown

        sourceComponent: PanelBuilder {
            width: stage.width
            height: stage.height
            studio: true
            area: stage.area
            enterT: stage.t
            from: Edit.studioFrom
            readings: Edit.studioHost
            // a tile of your own is edited in its fields, on the module's sheet
            onEditOwnTile: (key) => {
                Edit.studioOwnsEdit = false;
                Edit.closeStudio();
                Prefs.openBarModule("system", "owntiles");
            }
        }

    }

    Timer {
        id: warm

        interval: 50
        onTriggered: {
            if (stage.hosted)
                stage.travel();

        }
    }

    NumberAnimation {
        id: enter

        target: stage
        property: "t"
        easing.type: Easing.Bezier
    }

}
