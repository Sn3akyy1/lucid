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
    property real t: stage.hosted ? 1 : 0
    readonly property bool shown: stage.t > 0.001
    // for the layer's blur, once the panes have arrived
    readonly property bool settled: stage.hosted && stage.t > 0.99 && !!loader.item
    readonly property rect libRect: loader.item ? loader.item.libRect : Qt.rect(0, 0, 0, 0)
    readonly property rect canvasRect: loader.item ? loader.item.canvasRect : Qt.rect(0, 0, 0, 0)
    readonly property rect inspRect: loader.item ? loader.item.inspRect : Qt.rect(0, 0, 0, 0)

    visible: stage.shown
    onHostedChanged: {
        if (stage.hosted)
            Qt.callLater(() => {
            if (loader.item)
                loader.item.forceActiveFocus();

        });

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

    // one curve both ways, so going back retraces the way it came
    Behavior on t {
        NumberAnimation {
            duration: Theme.durLong
            easing.type: Easing.InOutCubic
        }

    }

}
