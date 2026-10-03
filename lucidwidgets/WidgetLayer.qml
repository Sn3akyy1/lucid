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

        PanelWindow {
            id: layer

            PaletteFade {
                active: layer.visible
            }

            readonly property bool suppressed: Prefs.widgetHideFullscreen && layer.fullscreenUp
            readonly property bool fullscreenUp: {
                var t = Hyprland.activeToplevel;
                if (!t || !t.lastIpcObject)
                    return false;

                return (t.lastIpcObject.fullscreen || 0) > 0;
            }

            screen: unit.modelData
            visible: Prefs.loaded && Widgets.loaded && (deck.panelLive || (Prefs.widgetsEnabled && Widgets.count > 0 && !layer.suppressed))
            color: "transparent"
            // reserves nothing and refuses to be shrunk into the bar and dock's strips,
            // so a card can be dragged to a true screen edge and sit under the dock.
            // setting exclusiveZone at all would silently undo this
            exclusionMode: ExclusionMode.Ignore
            // the widget panel lifts the whole board over the windows until it has slid away
            WlrLayershell.layer: deck.panelLive ? WlrLayer.Overlay : (Prefs.widgetOnTop ? WlrLayer.Top : WlrLayer.Bottom)
            WlrLayershell.keyboardFocus: deck.panelUp ? WlrKeyboardFocus.Exclusive : (deck.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // lastIpcObject only moves when something asks it to, so nudge it on the
            // events that can change whether a window is fullscreen
            Connections {
                function onRawEvent(event) {
                    if (event.name === "fullscreen" || event.name === "activewindowv2" || event.name === "closewindow")
                        fullscreenPoll.restart();

                }

                enabled: Prefs.widgetHideFullscreen
                target: Hyprland
            }

            Timer {
                id: fullscreenPoll

                interval: 120
                onTriggered: Hyprland.refreshToplevels()
            }

            Item {
                id: deck

                // bumped whenever the repeater's children change, so frameAt() bindings re-run
                property int rev: 0
                property Item dragFrame: null

                readonly property string screenName: layer.screen ? layer.screen.name : ""
                readonly property bool isPrimary: layer.screen !== null && layer.screen === Monitors.mainScreen
                // the widget panel is open on this screen, and still on its way out
                readonly property bool panelUp: Widgets.panelScreen !== "" && Widgets.panelScreen === deck.screenName
                readonly property bool panelLive: deck.panelUp || panel.shown
                readonly property int frameCount: rep.count
                readonly property bool editing: Widgets.editUid !== "" && deck.editFrame !== null
                // only ask for keys at all once something you can type into is placed;
                // on-demand hands focus back the moment a window is clicked, which
                // exclusive would not
                readonly property bool wantsKeyboard: {
                    for (var i = 0; i < Widgets.model.count; i++) {
                        var e = Widgets.model.get(i);
                        if (!e.closing && (e.wtype === "notes" || e.wtype === "todo"))
                            return true;

                    }
                    return false;
                }
                readonly property bool grabbing: Widgets.dragUid !== "" || Widgets.menuUid !== "" || deck.editing
                readonly property Item menuFrame: {
                    var _ = deck.rev;
                    for (var i = 0; i < rep.count; i++) {
                        var f = rep.itemAt(i);
                        if (f && f.uid === Widgets.menuUid && f.visible)
                            return f;

                    }
                    return null;
                }
                readonly property Item editFrame: {
                    var _ = deck.rev;
                    for (var i = 0; i < rep.count; i++) {
                        var f = rep.itemAt(i);
                        if (f && f.uid === Widgets.editUid && f.visible)
                            return f;

                    }
                    return null;
                }

                function frameAt(i) {
                    var _ = deck.rev;
                    return (i >= 0 && i < rep.count) ? rep.itemAt(i) : null;
                }

                function frameFor(uid) {
                    for (var i = 0; i < rep.count; i++) {
                        var f = rep.itemAt(i);
                        if (f && f.uid === uid)
                            return f;

                    }
                    return null;
                }

                // a board point over the open panel, where a dragged card is let go of
                function binHit(px, py) {
                    return deck.panelUp && panel.sheetHit(px, py);
                }

                // the topmost card under a board point, for the menu overlay: it
                // covers the screen while it is up, so the cards never see the press
                function frameUnder(px, py) {
                    var best = null;
                    for (var i = 0; i < rep.count; i++) {
                        var f = rep.itemAt(i);
                        if (!f || !f.visible || f.closing)
                            continue;

                        if (px < f.x || px > f.x + f.width || py < f.y || py > f.y + f.height)
                            continue;

                        if (best === null || f.z >= best.z)
                            best = f;

                    }
                    return best;
                }

                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: {
                    var busy = Widgets.editUid !== "" || Widgets.menuUid !== "" || Object.keys(Widgets.selection).length > 0;
                    Widgets.editUid = "";
                    Widgets.menuUid = "";
                    Widgets.clearSelection();
                    if (!busy && deck.panelUp)
                        Widgets.closePanel();

                }
                onWidthChanged: deck.report()
                onHeightChanged: deck.report()
                Component.onCompleted: deck.report()

                function report() {
                    if (deck.isPrimary && deck.width > 0) {
                        Widgets.canvasW = deck.width;
                        Widgets.canvasH = deck.height;
                    }
                }

                // the dim behind the cards while the widget panel is open, and the way out of it
                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.cScrim, Theme.blurAmount > 0 ? 0.3 : 0.5)
                    opacity: panel.reveal
                    visible: opacity > 0.01

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        enabled: deck.panelUp
                        onWheel: (event) => {
                            return event.accepted = true;
                        }
                    }

                }

                // click-through everywhere except the cards, so this only fires for the
                // open menu, a note being typed in, or the widget panel
                MouseArea {
                    anchors.fill: parent
                    enabled: deck.grabbing || deck.panelUp
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: {
                        var busy = Widgets.menuUid !== "" || Widgets.editUid !== "";
                        Widgets.menuUid = "";
                        Widgets.editUid = "";
                        if (!busy && deck.panelUp) {
                            Widgets.clearSelection();
                            Widgets.closePanel();
                        }

                    }
                }

                // the cards stack among themselves, under the guides and the panel
                Item {
                    anchors.fill: parent

                    Repeater {
                        id: rep

                        model: Widgets.model
                        onItemAdded: deck.rev++
                        onItemRemoved: deck.rev++

                        WidgetFrame {
                            board: deck
                        }

                    }

                }

                Rectangle {
                    width: 1
                    height: deck.height
                    x: deck.dragFrame ? deck.dragFrame.guideX : -1
                    color: Theme.accent
                    opacity: (deck.dragFrame && deck.dragFrame.guideX >= 0) ? 0.65 : 0
                    visible: opacity > 0.01
                    z: 900

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                Rectangle {
                    height: 1
                    width: deck.width
                    y: deck.dragFrame ? deck.dragFrame.guideY : -1
                    color: Theme.accent
                    opacity: (deck.dragFrame && deck.dragFrame.guideY >= 0) ? 0.65 : 0
                    visible: opacity > 0.01
                    z: 900

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                WidgetPanel {
                    id: panel

                    anchors.fill: parent
                    z: 1000
                    board: deck
                }

            }

            mask: Region {
                x: 0
                y: 0
                width: (deck.grabbing || deck.panelUp) ? layer.width : 0
                height: (deck.grabbing || deck.panelUp) ? layer.height : 0

            WidgetRegion {
                frame: deck.frameAt(0)
            }

            WidgetRegion {
                frame: deck.frameAt(1)
            }

            WidgetRegion {
                frame: deck.frameAt(2)
            }

            WidgetRegion {
                frame: deck.frameAt(3)
            }

            WidgetRegion {
                frame: deck.frameAt(4)
            }

            WidgetRegion {
                frame: deck.frameAt(5)
            }

            WidgetRegion {
                frame: deck.frameAt(6)
            }

            WidgetRegion {
                frame: deck.frameAt(7)
            }

            WidgetRegion {
                frame: deck.frameAt(8)
            }

            WidgetRegion {
                frame: deck.frameAt(9)
            }

            WidgetRegion {
                frame: deck.frameAt(10)
            }

            WidgetRegion {
                frame: deck.frameAt(11)
            }

            WidgetRegion {
                frame: deck.frameAt(12)
            }

            WidgetRegion {
                frame: deck.frameAt(13)
            }

            WidgetRegion {
                frame: deck.frameAt(14)
            }

            WidgetRegion {
                frame: deck.frameAt(15)
            }

            WidgetRegion {
                frame: deck.frameAt(16)
            }

            WidgetRegion {
                frame: deck.frameAt(17)
            }

            WidgetRegion {
                frame: deck.frameAt(18)
            }

            WidgetRegion {
                frame: deck.frameAt(19)
            }

            }

            // the open panel frosts the whole screen behind its dim, cards and sheet alike
            BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? (deck.panelUp ? wholeBlur : widgetBlur) : null

            Region {
                id: wholeBlur

                width: layer.width
                height: layer.height
            }

            Region {
                id: widgetBlur

            WidgetRegion {
                blur: true
                frame: deck.frameAt(0)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(1)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(2)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(3)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(4)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(5)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(6)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(7)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(8)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(9)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(10)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(11)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(12)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(13)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(14)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(15)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(16)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(17)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(18)
            }

            WidgetRegion {
                blur: true
                frame: deck.frameAt(19)
            }

            }

        }

        // an options panel on the widget layer would sit under every window, so it
        // gets an overlay of its own that only exists while the panel is up
        PanelWindow {
            id: menuLayer

            // the frame the panel belongs to, held past the close so the fade-out
            // keeps its geometry and its contents
            property Item held: null

            readonly property Item target: deck.menuFrame

            screen: unit.modelData
            // up the moment the menu opens, so the fade-in plays inside a mapped
            // surface, and stays up until the fade-out finishes
            visible: menuLayer.target !== null || menu.visible
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: menuLayer.target !== null ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            onTargetChanged: if (menuLayer.target)
                menuLayer.held = menuLayer.target
            onVisibleChanged: if (!menuLayer.visible)
                menuLayer.held = null

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: Widgets.menuUid = ""

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: (mouse) => {
                        var f = mouse.button === Qt.RightButton ? deck.frameUnder(mouse.x, mouse.y) : null;
                        var was = Widgets.menuUid;
                        Widgets.menuUid = "";
                        // a right press on another card carries the panel over to it,
                        // the way it did when the panel still sat on the widget layer
                        if (f && f.uid !== was)
                            f.toggleMenu(mouse.x - f.x, mouse.y - f.y);

                    }
                }

                WidgetMenu {
                    id: menu

                    frame: menuLayer.held
                    fieldW: menuLayer.width
                    fieldH: menuLayer.height
                }

            }

            // no input once the panel starts closing, so the fade-out is never a
            // dead region over the screen
            mask: Region {
                width: menuLayer.target ? menuLayer.width : 0
                height: menuLayer.target ? menuLayer.height : 0
            }

            BackgroundEffect.blurRegion: Theme.blurAmount > 0 ? menuBlur : null

            Region {
                id: menuBlur

                WidgetRegion {
                    blur: true
                    part: "menu"
                    panel: menu
                }

            }

        }

    }

}
