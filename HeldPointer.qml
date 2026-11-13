import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// fill whatever takes the press of a drag with it, over it. while `held`, the window draws
// the pointer itself, in the same frame as what follows it, and the compositor's
// goes, wherever nothing could cover the one drawn: the compositor shows its own a
// frame or two before a window catches up, so whatever a drag moves trails it
Item {
    id: hp

    property bool held: false
    // the shape the pointer has meanwhile, as for cursorShape
    property int cursor: Qt.ArrowCursor
    // the surface, for what could cover the pointer: a WlrLayer, or -1 for an app's
    // own window. a panel window counts as over the windows unless it says
    // otherwise with a pointerSurface of its own
    property int surface: {
        const w = hp.QsWindow.window;
        if (!w)
            return -1;

        if (w.pointerSurface !== undefined)
            return w.pointerSurface;

        return w.aboveWindows === undefined ? -1 : (w.aboveWindows ? WlrLayer.Top : WlrLayer.Bottom);
    }
    // an item on an overlay surface to draw the pointer on instead, for a window
    // under the others that keeps the drag: seen everywhere then. it has to cover
    // the same part of the screen as this window
    property Item stage: null

    anchors.fill: parent
    // above what takes the press, which it sees first and lets through
    z: 1000
    onHeldChanged: {
        if (!hp.held)
            return ;

        PointerPictures.refresh();
    }

    // watches the press and never takes it from what it moves
    PointHandler {
        id: follow

        acceptedButtons: Qt.AllButtons
    }

    // over everything else in the window
    Item {
        id: cover

        readonly property bool on: hp.held && follow.active
        readonly property point at: follow.point.scenePosition
        readonly property bool open: cover.on && cover.at.x >= 0 && cover.at.y >= 0 && cover.at.x < cover.width && cover.at.y < cover.height && (hp.stage !== null || PointerPictures.openAt(hp.QsWindow.window ? hp.QsWindow.window.screen : null, cover.at.x, cover.at.y, hp.surface))

        parent: hp.Window.contentItem
        anchors.fill: parent
        z: 999999

        DrawnPointer {
            id: drawn

            parent: hp.stage !== null ? hp.stage : cover
            cursor: hp.cursor
            active: cover.on
            px: cover.at.x
            py: cover.at.y
            visible: cover.open && drawn.ready
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: drawn.onScreen ? Qt.BlankCursor : undefined
        }

    }

}
