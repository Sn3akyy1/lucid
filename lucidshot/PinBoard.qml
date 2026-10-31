import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// captures pinned to the screen, over the windows: one transparent layer per
// display, letting the pointer through everywhere but the pins themselves
Scope {
    id: board

    property var engine: null
    property int serial: 0
    // bumped whenever the set changes, for the input regions to look again
    property int rev: 0
    readonly property int count: pins.count

    function fileUrl(path) {
        return board.engine ? board.engine.fileUrl(path) : "file://" + path;
    }

    // x, y, w and h are in the display's own logical pixels
    function add(file, screenName, x, y, w, h) {
        if (!file || w < 1 || h < 1)
            return ;

        // the oldest goes once there are more than a display's worth
        if (pins.count >= 8)
            pins.remove(0);

        board.serial++;
        pins.append({
            "pid": board.serial,
            "file": file,
            "screen": screenName || (Monitors.focusedScreen ? Monitors.focusedScreen.name : ""),
            "px": x,
            "py": y,
            "pw": w,
            "ph": h
        });
        board.rev++;
    }

    function remove(pid) {
        for (let i = 0; i < pins.count; i++) {
            if (pins.get(i).pid === pid) {
                pins.remove(i);
                break;
            }
        }
        board.rev++;
    }

    function clear() {
        pins.clear();
        board.rev++;
    }

    function copy(file) {
        if (board.engine)
            board.engine.copyImage(file);

    }

    ListModel {
        id: pins
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pinWin

            required property var modelData
            readonly property int mine: {
                void board.rev;
                let n = 0;
                for (let i = 0; i < pins.count; i++) {
                    if (pins.get(i).screen === pinWin.modelData.name)
                        n++;

                }
                return n;
            }

            // the i-th pin's input area, while it is on this display
            function slot(i) {
                void board.rev;
                void rep.count;
                const it = rep.itemAt(i);
                return it && it.shown ? it : null;
            }

            screen: pinWin.modelData
            visible: pinWin.mine > 0 && Monitors.surfacesUp
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "lucid-shot-pin"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Repeater {
                id: rep

                model: pins

                PinItem {
                    host: board
                    shown: screen === pinWin.modelData.name
                }

            }

            mask: Region {
                Region {
                    item: pinWin.slot(0)
                }

                Region {
                    item: pinWin.slot(1)
                }

                Region {
                    item: pinWin.slot(2)
                }

                Region {
                    item: pinWin.slot(3)
                }

                Region {
                    item: pinWin.slot(4)
                }

                Region {
                    item: pinWin.slot(5)
                }

                Region {
                    item: pinWin.slot(6)
                }

                Region {
                    item: pinWin.slot(7)
                }

            }

        }

    }

}
