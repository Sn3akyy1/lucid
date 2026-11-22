import QtQuick
import "Catalog.js" as Catalog

// one widget in a slot: the widget itself, a card under it when the slot asks
// for cards, and in the editor an outline to pick it by and a handle to drag
// it by. wherever a change moves it, it glides there (Flip.qml)
Item {
    id: host

    required property string type
    property var slot: null
    // the copy under the pointer while this widget is dragged
    property bool ghost: false
    readonly property var stage: host.slot ? host.slot.stage : null
    readonly property var theme: host.stage ? host.stage.theme : null
    readonly property var info: Catalog.widget(host.type)
    // the space a drag opens where it would land
    readonly property bool isDrop: host.type === "__drop__"
    // lock-only widgets never reach the login screen
    readonly property bool allowed: !!host.stage && !host.isDrop && Catalog.shownOn(host.type, host.stage.greeter)
    readonly property var opts: host.stage ? host.stage.optsOf(host.type) : ({})
    readonly property string styleNow: host.opts && host.opts.style ? host.opts.style : ""
    readonly property bool hasIt: host.allowed && !!body.item && body.item.shown
    readonly property bool editing: !!host.stage && host.stage.editing && !host.ghost
    readonly property real editK: host.ghost ? 0 : (host.stage ? host.stage.editK : 0)
    readonly property bool picked: host.editing && host.stage.selected === host.type
    // the editor shows every widget with its empty state where it has nothing
    // to say; a stand-in is only for one this screen can never show
    readonly property bool stands: (host.editing || host.ghost) && !host.allowed && !host.isDrop
    readonly property bool carded: !!host.slot && host.slot.cards
    // the clock's card wears the accent's container; a face that brings its
    // own containers sits on a plain one
    readonly property bool tonalCard: host.carded && host.type === "clock" && ["stacked", "inline"].indexOf(host.opts.style) !== -1
    readonly property real cardPad: host.carded ? host.dp(host.type === "clock" ? 26 : 20) : 0
    readonly property real cs: host.stage ? host.stage.chromeScale : 1
    // the editor's own text, a readable size on a scaled-down preview
    readonly property real g: Math.max(1, 0.45 / host.cs)
    // while dragged, this one stays behind: a hole where it will land when
    // the drag is over its own slot, folded away when it is over another
    readonly property bool dragged: !host.ghost && !!host.stage && host.stage.dragType === host.type && !host.isDrop
    readonly property bool folded: host.dragged && !!host.stage.dragTarget && host.stage.dragTarget.slot !== host.slot.slotId
    // while one widget is picked the rest step back, so the eye stays on it
    readonly property bool dimmed: host.editing && !!host.stage.selected && host.stage.selected !== host.type && host.stage.dragType === "" && !host.isDrop
    property real dimK: host.dimmed ? 0.45 : 1
    // the selection's frame comes in a little large and settles onto the widget
    property real settle: 0
    readonly property real lit: host.editing && !host.dragged && !host.isDrop ? (host.picked ? 1 : (pick.containsMouse ? 0.6 : 0)) * host.editK : 0
    readonly property real ring: host.dp(10) / host.cs
    readonly property real naturalW: host.stands ? stand.width : (host.carded ? host.slot.maxWidth : (body.item ? body.item.implicitWidth : 0))
    readonly property real naturalH: host.stands ? stand.height : (body.item ? body.item.implicitHeight : 0) + host.cardPad * 2

    function dp(px) {
        return host.theme ? host.theme.dp(px) : px;
    }

    visible: host.isDrop || host.hasIt || host.editing || host.ghost
    implicitWidth: host.folded ? 0 : (host.isDrop ? (host.carded ? host.slot.maxWidth : host.stage.dragSize.width) : host.naturalW)
    implicitHeight: host.folded ? 0 : (host.isDrop ? host.stage.dragSize.height : host.naturalH)
    // a widget that comes or goes moves the rest of its slot
    onVisibleChanged: {
        if (host.stage && !host.ghost)
            host.stage.relayout(true);

    }
    onStyleNowChanged: flip.repop()
    onPickedChanged: {
        if (host.picked)
            settleIn.restart();

    }

    Behavior on dimK {
        NumberAnimation {
            duration: host.theme ? host.theme.ms(240) : 240
            easing.type: Easing.BezierSpline
            easing.bezierCurve: host.theme ? host.theme.curveEffects : [0.31, 0.94, 0.34, 1, 1, 1]
        }

    }

    NumberAnimation {
        id: settleIn

        target: host
        property: "settle"
        from: 1
        to: 0
        duration: host.theme ? host.theme.ms(420) : 420
        easing.type: Easing.BezierSpline
        easing.bezierCurve: host.theme ? host.theme.curveFastSpatial : [0.42, 1.67, 0.21, 0.9, 1, 1]
    }

    Flip {
        id: flip

        stage: host.stage
        key: host.type
        home: host
        live: !host.ghost && !host.isDrop
    }

    // ── what is drawn, gliding as one ───────────────────────────────────────
    Item {
        id: visual

        width: host.width
        height: host.height
        opacity: flip.fade * host.dimK
        transform: [
            Scale {
                origin.x: visual.width / 2
                origin.y: visual.height / 2
                xScale: flip.ps
                yScale: flip.ps
            },
            Scale {
                xScale: flip.ds
                yScale: flip.ds
            },
            Translate {
                x: flip.dx
                y: flip.dy
            }
        ]

        // the card, in a slot that gives each widget one
        Rectangle {
            anchors.fill: parent
            visible: host.carded && !host.stands && !host.isDrop
            opacity: host.dragged ? 0 : 1
            radius: host.theme ? host.theme.shapeXl : 0
            color: host.theme ? (host.tonalCard ? host.theme.accentContainer : host.theme.card) : "transparent"
        }

        Loader {
            id: body

            x: host.cardPad
            y: host.cardPad
            width: host.carded ? host.width - host.cardPad * 2 : (item ? item.implicitWidth : 0)
            height: item ? item.implicitHeight : 0
            active: host.allowed
            visible: !host.stands
            opacity: host.dragged ? 0 : 1
            // nothing in a widget may be pressed while the editor has it
            enabled: !host.editing && !host.ghost
            sourceComponent: host.stage && !host.isDrop ? host.stage.componentFor(host.type) : null
            onLoaded: {
                body.item.theme = Qt.binding(() => {
                    return host.theme;
                });
                body.item.lock = Qt.binding(() => {
                    return host.stage.lock;
                });
                body.item.opts = Qt.binding(() => {
                    return host.opts;
                });
                body.item.align = Qt.binding(() => {
                    return host.slot.align;
                });
                body.item.avail = Qt.binding(() => {
                    return host.carded ? host.slot.maxWidth - host.cardPad * 2 : host.slot.maxWidth;
                });
                body.item.availH = Qt.binding(() => {
                    return host.slot.maxHeight;
                });
                body.item.screenH = Qt.binding(() => {
                    return host.stage.height;
                });
                body.item.focusK = Qt.binding(() => {
                    return host.ghost ? 0 : host.stage.focusK;
                });
                body.item.shrinkTo = Qt.binding(() => {
                    return host.slot.shrinkTo;
                });
                body.item.carded = Qt.binding(() => {
                    return host.carded;
                });
                body.item.tonal = Qt.binding(() => {
                    return host.tonalCard;
                });
                body.item.onCard = Qt.binding(() => {
                    return !!host.slot && host.slot.onCard;
                });
                body.item.greeter = Qt.binding(() => {
                    return host.stage.greeter;
                });
                body.item.preview = Qt.binding(() => {
                    return host.stage.preview;
                });
                body.item.editing = Qt.binding(() => {
                    return host.stage.editing;
                });
            }
        }

        // the editor's stand-in for a widget this screen can never show
        Item {
            id: stand

            width: standRow.implicitWidth + host.dp(32) * host.g
            height: host.dp(48) * host.g
            visible: host.stands
            opacity: host.dragged ? 0 : 1

            Rectangle {
                anchors.fill: parent
                radius: host.theme ? host.theme.shapeLg : 12
                color: host.theme ? host.theme.alpha(host.theme.text, 0.05) : "transparent"
            }

            DashedBox {
                anchors.fill: parent
                radius: host.theme ? host.theme.shapeLg : 12
                line: 1.5 / host.cs
                dash: 5 / host.cs
                color: host.theme ? host.theme.alpha(host.theme.text, 0.4) : "white"
            }

            Row {
                id: standRow

                anchors.centerIn: parent
                spacing: host.dp(10) * host.g

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: host.info ? host.info.icon : "info"
                    size: host.dp(20) * host.g
                    color: host.theme ? host.theme.subtext : "white"
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        text: host.info ? host.stage.tr(host.info.name) : host.type // i18n-dynamic
                        color: host.theme ? host.theme.text : "white"
                        font.family: host.theme ? host.theme.fontFamily : ""
                        font.pixelSize: Math.round((host.theme ? host.theme.fontLabelLg : 13) * host.g)
                        font.weight: Font.Medium
                    }

                    Text {
                        text: host.stage && host.stage.lock ? host.stage.lock.tr("On the lock screen only") : ""
                        color: host.theme ? host.theme.subtextDim : "white"
                        font.family: host.theme ? host.theme.fontFamily : ""
                        font.pixelSize: Math.round((host.theme ? host.theme.fontLabelSm : 11) * host.g)
                    }

                }

            }

        }

        // where a drag would land, or the hole a dragged widget left: a tonal
        // shape of its size, breathing, with the widget's own mark in it
        Rectangle {
            id: spot

            readonly property string what: host.isDrop ? (host.stage ? host.stage.dragType : "") : host.type
            readonly property var whatInfo: Catalog.widget(spot.what)

            anchors.fill: parent
            visible: host.isDrop || (host.dragged && !host.folded)
            radius: Math.min(height / 2, (host.theme ? host.theme.shapeXl : 24))
            color: host.theme ? host.theme.alpha(host.theme.accent, 0.14 + 0.06 * spot.breath) : "transparent"
            opacity: 0

            property real breath: 0

            DashedBox {
                anchors.fill: parent
                radius: parent.radius
                line: 2 / host.cs
                dash: 7 / host.cs
                color: host.theme ? host.theme.alpha(host.theme.accent, 0.6 + 0.3 * spot.breath) : "white"
            }

            Glyph {
                anchors.centerIn: parent
                name: spot.whatInfo ? spot.whatInfo.icon : "add"
                size: Math.min(parent.height * 0.6, host.dp(26) / host.cs)
                color: host.theme ? host.theme.accent : "white"
                opacity: 0.55 + 0.3 * spot.breath
                visible: parent.height > host.dp(14) / host.cs
            }

            NumberAnimation on opacity {
                running: spot.visible
                from: 0
                to: 1
                duration: host.theme ? host.theme.ms(200) : 200
                easing.type: Easing.OutCubic
            }

            // an infinite loop only while it is on screen
            SequentialAnimation on breath {
                running: spot.visible
                loops: Animation.Infinite

                NumberAnimation {
                    to: 1
                    duration: 900
                    easing.type: Easing.InOutSine
                }

                NumberAnimation {
                    to: 0
                    duration: 900
                    easing.type: Easing.InOutSine
                }

            }

        }

        // ── picked, or under the pointer, in the editor ─────────────────────
        // a tonal frame a step off the widget's own edge: a state layer on
        // hover, an accent outline once picked, settling in with a spring
        Rectangle {
            id: frame

            x: -host.ring
            y: -host.ring
            width: host.width + host.ring * 2
            height: host.height + host.ring * 2
            visible: host.lit > 0.01
            opacity: Math.min(1, host.lit * 1.6)
            scale: 1 + 0.035 * host.settle
            radius: (host.carded ? (host.theme ? host.theme.shapeXl : 24) : (host.theme ? host.theme.shapeLg : 16)) + host.ring
            color: host.theme ? host.theme.alpha(host.theme.accent, host.picked ? 0.1 : 0.07) : "transparent"
            border.width: host.picked ? 2.5 / host.cs : 0
            border.color: host.theme ? host.theme.accent : "white"

            Behavior on opacity {
                NumberAnimation {
                    duration: host.theme ? host.theme.ms(160) : 160
                    easing.type: Easing.OutCubic
                }

            }

        }

        // its name on a tag that sits on the frame's top edge, with a grip
        // that says it can be carried
        Rectangle {
            id: tag

            x: frame.x + Math.min(frame.radius * 0.7, frame.width * 0.2)
            y: frame.y - height / 2
            width: tagRow.implicitWidth + host.dp(16) / host.cs
            height: host.dp(24) / host.cs
            radius: height / 2
            visible: frame.visible && !host.stands
            opacity: frame.opacity
            scale: 1 + 0.08 * host.settle
            transformOrigin: Item.Left
            color: host.theme ? (host.picked ? host.theme.accent : host.theme.cardHigh) : "black"

            Row {
                id: tagRow

                anchors.centerIn: parent
                spacing: host.dp(3) / host.cs

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_indicator"
                    size: host.dp(14) / host.cs
                    color: host.theme ? (host.picked ? host.theme.fgAccent : host.theme.subtext) : "white"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: host.dp(2) / host.cs
                    text: host.info ? host.stage.tr(host.info.name) : host.type // i18n-dynamic
                    color: host.theme ? (host.picked ? host.theme.fgAccent : host.theme.text) : "white"
                    font.family: host.theme ? host.theme.fontFamily : ""
                    font.pixelSize: Math.round((host.theme ? host.theme.fontLabelMd : 12) / host.cs)
                    font.weight: Font.DemiBold
                }

            }

        }

    }

    // ── picking it up: a click picks, a drag carries it ─────────────────────
    MouseArea {
        id: pick

        property point press: Qt.point(0, 0)
        property bool carrying: false
        // a press that turned into a drag is not a click
        property bool travelled: false

        anchors.fill: parent
        anchors.margins: host.folded ? 0 : -host.dp(6) / host.cs
        visible: host.editing && !host.isDrop
        hoverEnabled: true
        preventStealing: true
        cursorShape: pick.carrying ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (mouse) => {
            pick.press = Qt.point(mouse.x, mouse.y);
            pick.carrying = false;
            pick.travelled = false;
        }
        onPositionChanged: (mouse) => {
            if (!pick.pressed)
                return ;

            var p = pick.mapToItem(host.stage, mouse.x, mouse.y);
            if (!pick.carrying) {
                var o = pick.mapToItem(host.stage, pick.press.x, pick.press.y);
                // a few pixels on screen, however small the preview is drawn
                if (Math.hypot(p.x - o.x, p.y - o.y) < host.dp(6) / host.cs)
                    return ;

                pick.carrying = true;
                pick.travelled = true;
                var at = host.mapToItem(host.stage, 0, 0);
                host.stage.beginDrag(host.type, host.slot.slotId, Qt.point(o.x - at.x, o.y - at.y), Qt.size(host.width, host.height), false);
            }
            host.stage.moveDrag(p);
        }
        // the drop rebuilds the slots, this widget's among them, so it is
        // made once this release is over, from locals: a handler that
        // outlives its own delegate cannot reach its ids any more
        onReleased: (mouse) => {
            if (pick.carrying) {
                pick.carrying = false;
                var st = host.stage;
                var at = pick.mapToItem(st, mouse.x, mouse.y);
                Qt.callLater(() => {
                    return st.endDrag(at);
                });
            }
        }
        onCanceled: {
            if (pick.carrying) {
                pick.carrying = false;
                host.stage.cancelDrag();
            }
        }
        onClicked: {
            if (!pick.travelled)
                host.stage.picked(host.type);

        }
    }

}
