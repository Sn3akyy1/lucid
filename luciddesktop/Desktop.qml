import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Variants {
    id: variants

    model: Quickshell.screens

    Scope {
        id: unit

        required property var modelData

        function run(id) {
            if (id === "addWidget")
                Prefs.settingsRequested("widgets");
            else if (id === "settings")
                Prefs.settingsRequested("");
            else if (id === "keyboard")
                Prefs.keyboardRequested();
            else if (id === "hideWidgets" || id === "showWidgets")
                Prefs.widgetsEnabled = !Prefs.widgetsEnabled;
            else
                Prefs.desktopActionRequested(id);
        }

        PanelWindow {
            id: layer

            screen: unit.modelData
            visible: Prefs.loaded && (Prefs.desktopSelection || Prefs.desktopMenu)
            color: "transparent"
            // reserves nothing and refuses to be shrunk into the bar and dock's
            // strips, so the box can be dragged edge to edge
            exclusionMode: ExclusionMode.Ignore
            // the bottom-most layer, so a press only reaches here when nothing —
            // no window, no widget, no panel — is sitting over that pixel
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                id: field

                // press origin and the live corner, both in layer coordinates
                property real ax: 0
                property real ay: 0
                property real bx: 0
                property real by: 0
                property bool dragging: false
                // only a left press arms the box; a right press opens the menu
                property bool armed: false
                // a plain click should not flash a box, so wait for real travel
                readonly property int threshold: 4

                function begin() {
                    field.dragging = true;
                    fade.stop();
                    box.opacity = 1;
                }

                function finish() {
                    if (field.dragging)
                        fade.restart();

                    field.dragging = false;
                    field.armed = false;
                }

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (m) => {
                    if (m.button === Qt.RightButton) {
                        field.armed = false;
                        if (Prefs.desktopMenu)
                            menu.openAt(m.x, m.y);

                        return ;
                    }
                    field.armed = Prefs.desktopSelection;
                    field.ax = m.x;
                    field.ay = m.y;
                    field.bx = m.x;
                    field.by = m.y;
                    field.dragging = false;
                }
                // the pointer keeps reporting past the edges once grabbed, so pin the
                // corner to the screen instead of letting the box run off it
                onPositionChanged: (m) => {
                    if (!field.armed)
                        return ;

                    field.bx = Math.max(0, Math.min(field.width, m.x));
                    field.by = Math.max(0, Math.min(field.height, m.y));
                    if (!field.dragging && (Math.abs(field.bx - field.ax) > field.threshold || Math.abs(field.by - field.ay) > field.threshold))
                        field.begin();

                }
                onReleased: field.finish()
                onCanceled: field.finish()

                Rectangle {
                    id: box

                    x: Math.min(field.ax, field.bx)
                    y: Math.min(field.ay, field.by)
                    width: Math.abs(field.bx - field.ax)
                    height: Math.abs(field.by - field.ay)
                    radius: Math.min(4, box.width / 2, box.height / 2)
                    color: Theme.alpha(Theme.accent, 0.16)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.8)
                    antialiasing: true
                    // set outright on drag start and only ever animated back down,
                    // so the box tracks the cursor from the first frame
                    opacity: 0
                    visible: box.opacity > 0.01

                    NumberAnimation {
                        id: fade

                        target: box
                        property: "opacity"
                        to: 0
                        duration: Theme.durExit
                        easing.type: Easing.OutCubic
                    }

                }

            }

        }

        // the menu cannot live on the background layer or windows would cover it,
        // so it gets its own overlay that only exists while it is open
        PanelWindow {
            id: menuLayer

            screen: unit.modelData
            // up the moment the menu opens, so the fade-in plays inside a mapped
            // surface, and stays up until the fade-out finishes
            visible: menu.open || menu.visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: menu.open = false

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: menu.open = false
                }

                DesktopMenu {
                    id: menu

                    fieldW: menuLayer.width
                    fieldH: menuLayer.height
                    onChosen: (id) => {
                        return unit.run(id);
                    }
                }

            }

            // no input once the menu starts closing, so the fade-out is never a
            // dead region over the desktop
            mask: Region {
                width: menu.open ? menuLayer.width : 0
                height: menu.open ? menuLayer.height : 0
            }

        }

    }

}
