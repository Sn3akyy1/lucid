import QtQuick
import qs
import qs.lucidui

// a material dropdown: a filled field that shows the choice, and the choices in
// a menu hung off it, opening upward when there is no room below
Item {
    id: dd

    property string label: ""
    // [{label, hint}]
    property var options: []
    property int current: -1
    // what the menu draws in, above everything else: the window's content
    property Item host: null
    readonly property bool shown: pop.shown
    readonly property var choice: dd.current >= 0 && dd.current < dd.options.length ? dd.options[dd.current] : null
    readonly property real pad: Theme.dp(6)
    // the widest name and the widest row, for the field and the menu
    readonly property real widestName: {
        var w = 0;
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i);
            if (it)
                w = Math.max(w, it.nameWidth);

        }
        return w;
    }
    readonly property real widestRow: {
        var w = 0;
        for (var i = 0; i < rep.count; i++) {
            var it = rep.itemAt(i);
            if (it)
                w = Math.max(w, it.natural);

        }
        return w;
    }

    signal picked(int index)
    // closed without the keyboard: the caller hands focus back where it was
    signal dismissed()

    function openMenu() {
        if (!dd.host || dd.options.length === 0)
            return ;

        var p = dd.mapToItem(dd.host, 0, 0);
        var gap = Theme.dp(4), edge = Theme.dp(8);
        var want = Math.min(dd.options.length, 8) * Theme.dp(56) + 2 * dd.pad;
        var below = dd.host.height - (p.y + dd.height) - gap - edge;
        var above = p.y - gap - edge;
        pop.below = below >= Math.min(want, rows.implicitHeight + 2 * dd.pad) || below >= above;
        // a long list scrolls rather than covering the window
        pop.room = Math.min(Theme.dp(520), Math.max(Theme.dp(120), pop.below ? below : above));
        pop.aw = Math.min(Math.max(dd.width, dd.widestRow + 2 * dd.pad), dd.host.width - 2 * edge);
        pop.ax = Math.max(edge, Math.min(p.x, dd.host.width - pop.aw - edge));
        pop.fy = p.y;
        pop.keyed = dd.activeFocus;
        pop.hot = dd.current;
        pop.shown = true;
        keys.forceActiveFocus();
        Qt.callLater(pop.reveal);
    }

    function closeMenu() {
        if (!pop.shown)
            return ;

        pop.shown = false;
        if (pop.keyed)
            dd.forceActiveFocus();
        else
            dd.dismissed();
    }

    function choose(i) {
        if (i >= 0 && i < dd.options.length && i !== dd.current)
            dd.picked(i);

        dd.closeMenu();
    }

    implicitWidth: Math.min(Theme.dp(340), Math.max(Theme.dp(200), dd.widestName + Theme.dp(16 + 48)))
    implicitHeight: Theme.dp(52)
    activeFocusOnTab: true
    Keys.onPressed: (event) => {
        if ([Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Down, Qt.Key_Up].indexOf(event.key) >= 0) {
            dd.openMenu();
            event.accepted = true;
        }
    }
    onVisibleChanged: {
        if (!visible)
            dd.closeMenu();

    }

    Rectangle {
        id: box

        readonly property bool lit: dd.shown || dd.activeFocus

        anchors.fill: parent
        color: Theme.surfaceHighest
        topLeftRadius: Theme.rad(10)
        topRightRadius: Theme.rad(10)

        Rectangle {
            anchors.fill: parent
            topLeftRadius: box.topLeftRadius
            topRightRadius: box.topRightRadius
            color: Theme.text
            opacity: fieldArea.pressed ? Theme.statePressed : fieldArea.containsMouse ? Theme.stateHover : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFastEffects
                }

            }

        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: box.lit ? Theme.dp(2) : 1
            color: box.lit ? Theme.primary : Theme.subtext
        }

        LText {
            x: Theme.dp(16)
            y: Theme.dp(7)
            role: "bodySmall"
            text: dd.label
            color: box.lit ? Theme.primary : Theme.subtext
        }

        LText {
            x: Theme.dp(16)
            y: Theme.dp(24)
            width: box.width - Theme.dp(16 + 44)
            elide: Text.ElideRight
            role: "bodyLarge"
            text: dd.choice ? dd.choice.label : ""
            color: Theme.text
        }

        Icon {
            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            name: "expand_more"
            size: Theme.dp(24)
            color: box.lit ? Theme.primary : Theme.subtext
            rotation: dd.shown ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

        MouseArea {
            id: fieldArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dd.openMenu()
        }

    }

    Item {
        id: pop

        property bool shown: false
        property bool below: true
        property bool keyed: false
        property int hot: -1
        property real ax: 0
        property real aw: 0
        property real fy: 0
        property real room: 0

        // the lit row in view, once the menu has its size
        function reveal() {
            var it = rep.itemAt(pop.hot);
            if (!it)
                return ;

            if (it.y < list.contentY)
                list.contentY = it.y;
            else if (it.y + it.height > list.contentY + list.height)
                list.contentY = it.y + it.height - list.height;
        }

        parent: dd.host
        anchors.fill: parent
        z: 390
        visible: pop.shown || card.opacity > 0

        // a press anywhere else puts the menu away, and the wheel stays here
        MouseArea {
            anchors.fill: parent
            enabled: pop.shown
            acceptedButtons: Qt.AllButtons
            onPressed: dd.closeMenu()
            onWheel: (wheel) => {
            }
        }

        Item {
            id: keys

            Keys.onPressed: (event) => {
                var n = dd.options.length;
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) {
                    dd.closeMenu();
                } else if (event.key === Qt.Key_Down) {
                    pop.hot = pop.hot < 0 ? 0 : Math.min(n - 1, pop.hot + 1);
                    pop.reveal();
                } else if (event.key === Qt.Key_Up) {
                    pop.hot = pop.hot < 0 ? n - 1 : Math.max(0, pop.hot - 1);
                    pop.reveal();
                } else if (event.key === Qt.Key_Home || event.key === Qt.Key_PageUp) {
                    pop.hot = 0;
                    pop.reveal();
                } else if (event.key === Qt.Key_End || event.key === Qt.Key_PageDown) {
                    pop.hot = n - 1;
                    pop.reveal();
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    dd.choose(pop.hot);
                } else if (event.text !== "" && event.text.trim() !== "") {
                    // a letter goes to the next choice that starts with it
                    var c = event.text.toLowerCase();
                    for (var k = 1; k <= n; k++) {
                        var j = (Math.max(0, pop.hot) + k) % n;
                        if (dd.options[j].label.toLowerCase().indexOf(c) === 0) {
                            pop.hot = j;
                            pop.reveal();
                            break;
                        }
                    }
                } else {
                    return ;
                }
                event.accepted = true;
            }
        }

        Rectangle {
            id: card

            x: pop.ax
            y: pop.below ? pop.fy + dd.height + Theme.dp(4) : pop.fy - Theme.dp(4) - card.height
            width: pop.aw
            height: Math.min(rows.implicitHeight + 2 * dd.pad, pop.room)
            radius: Theme.radiusMd
            color: Theme.bgOpaque
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.08)
            opacity: pop.shown ? 1 : 0
            transform: Scale {
                // it grows out of the field: from its top edge below it, its bottom above
                origin.y: pop.below ? 0 : card.height
                yScale: pop.shown ? 1 : 0.86

                Behavior on yScale {
                    NumberAnimation {
                        duration: pop.shown ? Theme.durFastSpatial : Theme.durShort
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveFastSpatial
                    }

                }

            }

            // the press stays in the menu, off the catcher under it
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Flickable {
                id: list

                anchors.fill: parent
                anchors.margins: dd.pad
                contentHeight: rows.implicitHeight
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                // long lists scroll: a notch is two rows, a touchpad goes as it goes
                WheelHandler {
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        var maxY = Math.max(0, list.contentHeight - list.height);
                        var d = event.phase !== Qt.NoScrollPhase ? event.pixelDelta.y * 2.4 : event.angleDelta.y / 120 * Theme.dp(112);
                        list.contentY = Math.max(0, Math.min(maxY, list.contentY - d));
                    }
                }

                Column {
                    id: rows

                    width: list.width

                    Repeater {
                        id: rep

                        model: dd.options

                        delegate: Item {
                            id: opt

                            required property var modelData
                            required property int index
                            readonly property bool chosen: opt.index === dd.current
                            readonly property bool lit: optArea.containsMouse || pop.hot === opt.index
                            readonly property string hint: opt.modelData.hint || ""
                            // an eliding text reports its elided width, so measure the words
                            readonly property real nameWidth: Math.ceil(nameMetrics.advanceWidth)
                            readonly property real natural: Theme.dp(48) + Math.ceil(Math.max(nameMetrics.advanceWidth, Math.min(hintMetrics.advanceWidth, Theme.dp(300)))) + Theme.dp(16)

                            width: rows.width
                            height: opt.hint !== "" ? Theme.dp(56) : Theme.dp(44)

                            TextMetrics {
                                id: nameMetrics

                                font: name.font
                                text: opt.modelData.label
                            }

                            TextMetrics {
                                id: hintMetrics

                                font: hintText.font
                                text: opt.hint
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm
                                color: Theme.secondaryContainer
                                opacity: opt.chosen ? 1 : 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusSm
                                color: opt.chosen ? Theme.fgSecondaryContainer : Theme.text
                                opacity: opt.lit ? (optArea.pressed ? Theme.statePressed : Theme.stateHover) : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durFastEffects
                                    }

                                }

                            }

                            Icon {
                                x: Theme.dp(14)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: Theme.dp(20)
                                color: Theme.fgSecondaryContainer
                                visible: opt.chosen
                            }

                            Column {
                                x: Theme.dp(48)
                                width: opt.width - Theme.dp(48 + 12)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.dp(1)

                                LText {
                                    id: name

                                    width: parent.width
                                    elide: Text.ElideRight
                                    role: "bodyLarge"
                                    text: opt.modelData.label
                                    color: opt.chosen ? Theme.fgSecondaryContainer : Theme.text
                                }

                                LText {
                                    id: hintText

                                    visible: opt.hint !== ""
                                    width: parent.width
                                    elide: Text.ElideRight
                                    role: "bodySmall"
                                    text: opt.hint
                                    color: opt.chosen ? Theme.alpha(Theme.fgSecondaryContainer, 0.78) : Theme.subtext
                                }

                            }

                            MouseArea {
                                id: optArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: pop.hot = opt.index
                                onClicked: dd.choose(opt.index)
                            }

                        }

                    }

                }

            }

            Behavior on opacity {
                NumberAnimation {
                    duration: pop.shown ? Theme.durShort : Theme.durFastEffects
                }

            }

        }

    }

}
