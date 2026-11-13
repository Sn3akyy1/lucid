import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

Variants {
    id: variants

    model: Quickshell.screens

    Scope {
        id: unit

        required property var modelData
        // the icons live on the main screen only
        readonly property bool icons: DesktopIcons.live && unit.modelData === DesktopIcons.screen
        // the board stays up, untouchable, while the icons put themselves away
        readonly property bool iconsUp: DesktopIcons.shown && unit.modelData === DesktopIcons.screen
        // surfaces on one layer stack in the order they were mapped, so a wallpaper
        // daemon that starts after the shell would cover the icons: remap over it
        property bool lifting: false

        function run(id) {
            if (DesktopIcons.owns(id)) {
                DesktopIcons.runAction(id);
            } else if (id === "editMode") {
                Edit.toggle(unit.modelData.name);
            } else if (id === "settings") {
                Prefs.settingsRequested("");
            } else if (id === "keyboard") {
                Prefs.keyboardRequested();
            } else if (id === "hideIcons" || id === "showIcons") {
                Prefs.desktopIconsShown = id === "showIcons";
            } else if (id === "hideWidgets" || id === "showWidgets") {
                Prefs.widgetsEnabled = !Prefs.widgetsEnabled;
            } else if (id.indexOf("menu:") !== 0) {
                Prefs.desktopActionRequested(id);
            }
        }

        Connections {
            function onRawEvent(event) {
                if (event.name === "openlayer" && /awww|swww|hyprpaper|swaybg|mpvpaper|wallpaper/i.test(event.data))
                    liftTimer.restart();

            }

            target: Hyprland
            enabled: unit.icons
        }

        // edit mode's shade has to sit over the wallpaper, and a video wallpaper is a
        // background surface of its own that can be over this one: put it back on top
        Connections {
            function onActiveChanged() {
                if (!Edit.active || !LiveWall.wanted)
                    return ;

                unit.lifting = true;
                Qt.callLater(() => {
                    unit.lifting = false;
                });
            }

            target: Edit
        }

        Timer {
            id: liftTimer

            interval: 400
            onTriggered: {
                unit.lifting = true;
                Qt.callLater(() => {
                    unit.lifting = false;
                });
            }
        }

        // the icons ask for their menu through here, so there is one menu
        Connections {
            function onMenuRequested(x, y, rows) {
                if (!unit.icons)
                    return ;

                menu.custom = rows;
                menu.openAt(x, y);
            }

            // a click hands the layer the keys only on the next pointer move; this takes them outright
            function onGrabTickChanged() {
                if (!unit.icons)
                    return ;

                layer.grabbing = true;
                grabEnd.restart();
            }

            target: DesktopIcons
        }

        Timer {
            id: grabEnd

            interval: 150
            onTriggered: layer.grabbing = false
        }

        PanelWindow {
            id: layer

            PointerPoke {
            }

            // up on the overlay from the press until the box has faded, see below
            readonly property bool lifted: field.lift && (field.armed || box.visible)
            // what can cover a pointer drawn here (HeldPointer)
            readonly property int pointerSurface: layer.lifted ? WlrLayer.Overlay : WlrLayer.Background
            // a moment of exclusive keys after a click on the icons, see DesktopIcons.arm
            property bool grabbing: false
            // quick look is a modal over everything, windows included
            readonly property bool looking: boardLoader.item !== null && boardLoader.item.looking

            screen: unit.modelData
            visible: Prefs.loaded && (Prefs.desktopSelection || Prefs.desktopMenu || unit.iconsUp || Edit.active || shade.opacity > 0.01) && !unit.lifting
            color: "transparent"
            // reserves nothing and refuses to be shrunk into the bar and dock's
            // strips, so the box can be dragged edge to edge
            exclusionMode: ExclusionMode.Ignore
            // the bottom-most layer, so a press only reaches here when nothing —
            // no window, no widget, no panel — is sitting over that pixel. with a
            // window focused hyprland keeps a held drag here, so the box stays under
            // the windows; with nothing focused it hands the drag to any surface it
            // crosses, so only then does a left press lift the layer over the bar,
            // the dock and the widgets
            WlrLayershell.layer: (layer.lifted || layer.looking) ? WlrLayer.Overlay : WlrLayer.Background
            // never on-demand at rest: hyprland gives an on-demand layer the keys
            // whenever the pointer crosses it, which would take them from a window
            WlrLayershell.keyboardFocus: !unit.icons ? (Edit.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None) : ((layer.grabbing || layer.looking) ? WlrKeyboardFocus.Exclusive : (DesktopIcons.armed || Edit.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None))
            // click-through while the box fades out up there
            mask: Region {
                width: (field.armed || !layer.lifted) ? layer.width : 0
                height: (field.armed || !layer.lifted) ? layer.height : 0
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // edit mode: the wallpaper shaded, under the icons, the widgets and the box
            Rectangle {
                id: shade

                anchors.fill: parent
                color: Theme.alpha(Theme.cScrim, 1)
                opacity: Edit.active ? (Theme.isLight ? 0.34 : 0.5) : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutCubic
                    }

                }

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
                // taken at the press, see the layer
                property bool lift: false
                // a plain click should not flash a box, so wait for real travel
                readonly property int threshold: 4
                // ctrl or shift adds to the icons already selected
                property bool additive: false

                function begin() {
                    field.dragging = true;
                    field.publish();
                    // with icons, the board draws the box over them
                    if (unit.icons) {
                        DesktopIcons.beginBand(field.additive);
                        field.track();
                        return ;
                    }
                    fade.stop();
                    box.opacity = 1;
                }

                // widget cards sit on the same screen-sized board, so they read the box as is
                function publish() {
                    Widgets.marquee = {
                        "screen": layer.screen ? layer.screen.name : "",
                        "x": Math.min(field.ax, field.bx),
                        "y": Math.min(field.ay, field.by),
                        "w": Math.abs(field.bx - field.ax),
                        "h": Math.abs(field.by - field.ay)
                    };
                }

                function track() {
                    if (unit.icons && field.dragging)
                        DesktopIcons.updateBand(Math.min(field.ax, field.bx), Math.min(field.ay, field.by), Math.abs(field.bx - field.ax), Math.abs(field.by - field.ay));

                }

                function finish() {
                    if (field.dragging) {
                        if (!unit.icons)
                            fade.restart();

                        Widgets.marquee = null;
                    }
                    if (unit.icons)
                        DesktopIcons.endBand();

                    field.dragging = false;
                    field.armed = false;
                }

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPressed: (m) => {
                    // any press on bare desktop lets the selected widgets go
                    Widgets.clearSelection();
                    // and in edit mode puts the sheet away
                    if (Edit.active && m.button === Qt.LeftButton)
                        Edit.closeSheet();

                    if (unit.icons) {
                        DesktopIcons.arm(false);
                        DesktopIcons.focusVisible = false;
                    }

                    if (m.button === Qt.RightButton) {
                        field.armed = false;
                        if (unit.icons) {
                            DesktopIcons.clearSelection();
                            DesktopIcons.menuX = m.x;
                            DesktopIcons.menuY = m.y;
                            DesktopIcons.probePaste();
                        }
                        if (Prefs.desktopMenu) {
                            menu.custom = null;
                            menu.openAt(m.x, m.y);
                        }
                        return ;
                    }
                    field.lift = !ToplevelManager.activeToplevel;
                    field.additive = (m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) !== 0;
                    if (unit.icons) {
                        boardLoader.forceActiveFocus();
                        if (!field.additive)
                            DesktopIcons.clearSelection();

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
                    if (field.dragging) {
                        field.publish();
                        field.track();
                    } else if (Math.abs(field.bx - field.ax) > field.threshold || Math.abs(field.by - field.ay) > field.threshold) {
                        field.begin();
                    }
                }
                onReleased: (m) => {
                    field.finish();
                    if (unit.icons && m.button === Qt.LeftButton)
                        DesktopIcons.arm(true);

                }
                onCanceled: field.finish()

                // drawn here while lifted; under the windows it goes up on the pointer layer
                HeldPointer {
                    held: field.dragging
                    stage: layer.lifted ? null : pointerStage
                }

                // square, on whole pixels, a solid edge over a clear tint: the way
                // windows and macos draw it, so it reads on any wallpaper
                Rectangle {
                    id: box

                    x: Math.round(Math.min(field.ax, field.bx))
                    y: Math.round(Math.min(field.ay, field.by))
                    width: Math.round(Math.abs(field.bx - field.ax))
                    height: Math.round(Math.abs(field.by - field.ay))
                    color: Theme.alpha(Theme.accent, 0.28)
                    border.width: 1
                    border.color: Theme.accent
                    antialiasing: false
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

            // built only on the screen that shows the icons, and only while they are on
            Loader {
                id: boardLoader

                anchors.fill: parent
                active: unit.iconsUp
                enabled: unit.icons
                focus: true
                // escape leaves edit mode, once the desktop has the keys
                Keys.onEscapePressed: (event) => {
                    if (Edit.active)
                        Edit.backOut();
                    else
                        event.accepted = false;
                }

                sourceComponent: IconBoard {
                }

            }

            // files dragged over the desktop: from a file manager, a browser, the
            // screenshot card, or our own icons being moved
            DropArea {
                anchors.fill: parent
                enabled: unit.icons
                onEntered: (d) => {
                    DesktopIcons.dragApp = d.formats.indexOf(DesktopIcons.appMime) >= 0;
                    d.accept(DesktopIcons.dragApp ? Qt.CopyAction : d.proposedAction);
                }
                // the action follows the modifiers held: ctrl copies, ctrl+shift links
                onPositionChanged: (d) => {
                    DesktopIcons.hover(d.x, d.y, d.proposedAction);
                }
                onExited: DesktopIcons.leaveDrag()
                onDropped: (d) => {
                    DesktopIcons.dropped(d);
                }
            }

        }

        // with a window focused the box stays down under the windows, so the pointer
        // it pulls is drawn up here, over everything, from the press on so it is
        // mapped before the drag starts. no input, and no fade (layerrules.lua)
        PanelWindow {
            id: pointerLayer

            screen: unit.modelData
            visible: field.armed && !field.lift && PointerPictures.usable
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lucid-pointer"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: pointerStage

                anchors.fill: parent
            }

        }

        // the menu cannot live on the background layer or windows would cover it,
        // so it gets its own overlay that only exists while it is open
        PanelWindow {
            id: menuLayer

            screen: unit.modelData
            // up the moment the menu opens, so the fade-in plays inside a mapped
            // surface, and stays up until the fade-out finishes
            visible: menu.open || menu.showing
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
                Keys.onPressed: (e) => {
                    return menu.key(e);
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: menu.open = false
                }

                DesktopMenu {
                    id: menu

                    icons: unit.icons
                    fieldW: menuLayer.width
                    fieldH: menuLayer.height
                    monitor: Hyprland.monitorFor(unit.modelData)
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

            BackgroundEffect.blurRegion: (Theme.blurAmount > 0 && menu.open) ? menuBlur : null

            // one slot per card in the cascade: regions take no repeater
            Region {
                id: menuBlur

                MenuBlur {
                    host: menu
                    level: 0
                }

                MenuBlur {
                    host: menu
                    level: 1
                }

                MenuBlur {
                    host: menu
                    level: 2
                }

                MenuBlur {
                    host: menu
                    level: 3
                }

            }

        }

    }

}
