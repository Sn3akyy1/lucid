import QtQuick
import Quickshell
import qs
import qs.lucidui

// a card's own sheet: what it is, its faces drawn live, its colour, its size and
// whatever else it can do. it hangs off the right-click point and frosts with Glass
Item {
    id: menu

    property Item frame: null
    property real fieldW: 1920
    property real fieldH: 1080

    readonly property real panelW: Theme.dp(320)
    readonly property real edge: Theme.dp(8)
    readonly property real pad: Theme.dp(16)
    readonly property real cornerRadius: Theme.dp(28)
    readonly property bool open: menu.frame !== null && menu.frame.menuOpen
    // the right-click point, in screen coordinates
    readonly property real originX: menu.frame ? menu.frame.x + menu.frame.menuAtX : 0
    readonly property real originY: menu.frame ? menu.frame.y + menu.frame.menuAtY : 0
    readonly property real fullH: Math.min(body.implicitHeight + menu.pad * 2, menu.fieldH - menu.edge * 2)
    // the sheet hangs off the corner it was opened at, and flips rather than run off the screen
    readonly property bool toRight: menu.originX + menu.panelW + menu.edge <= menu.fieldW
    readonly property bool toDown: menu.originY + menu.fullH + menu.edge <= menu.fieldH
    readonly property var typeInfo: menu.frame ? Widgets.typeAt(menu.frame.wtype) : null
    readonly property var variantInfo: menu.frame ? Widgets.variantAt(menu.frame.wtype, menu.frame.wvariant) : null
    // colour has swatches of its own; everything else is listed
    readonly property var optionList: menu.frame ? Widgets.optionsFor(menu.frame.wtype, menu.frame.wvariant).filter((o) => {
        return o.key !== "tone";
    }) : []
    readonly property var boolOptions: menu.optionList.filter((o) => {
        return o.type === "bool";
    })
    readonly property var otherOptions: menu.optionList.filter((o) => {
        return o.type !== "bool";
    })
    readonly property bool resizable: menu.frame !== null && menu.frame.resizable
    readonly property var screens: Quickshell.screens
    readonly property string tone: {
        var t = menu.frame ? menu.frame.opt("tone") : "auto";
        return t === undefined || t === "" ? "auto" : String(t);
    }
    readonly property var tones: [{
        "key": "auto",
        "label": "Auto",
        "fill": Theme.surfaceHighest,
        "dot": Theme.primary
    }, {
        "key": "surface",
        "label": "Surface",
        "fill": Theme.surfaceContainer,
        "dot": Theme.text
    }, {
        "key": "primary",
        "label": "Primary",
        "fill": Theme.primaryContainer,
        "dot": Theme.primary
    }, {
        "key": "secondary",
        "label": "Secondary",
        "fill": Theme.secondaryContainer,
        "dot": Theme.secondary
    }, {
        "key": "tertiary",
        "label": "Tertiary",
        "fill": Theme.tertiaryContainer,
        "dot": Theme.tertiary
    }]
    // eases 0..1 as the sheet opens; the blur follows its height, so it grows with it
    property real reveal: menu.open ? 1 : 0

    function clampY(want) {
        var hi = menu.fieldH - menu.height - menu.edge;
        return hi < menu.edge ? menu.edge : Math.max(menu.edge, Math.min(hi, want));
    }

    function close() {
        Widgets.menuUid = "";
    }

    width: menu.panelW
    height: Math.round(menu.fullH * (0.86 + 0.14 * menu.reveal))
    visible: menu.reveal > 0.01
    // down-right of the click, else flipped, else clamped onto the screen
    x: {
        var want = menu.toRight ? menu.originX : menu.originX - menu.panelW;
        var hi = menu.fieldW - menu.panelW - menu.edge;
        return hi < menu.edge ? menu.edge : Math.max(menu.edge, Math.min(hi, want));
    }
    y: menu.clampY(menu.toDown ? menu.originY : menu.originY - menu.height)

    Behavior on reveal {
        NumberAnimation {
            // a blur region cannot fade, so the exit is quick and accelerating
            duration: menu.open ? Theme.durDefaultSpatial : Theme.durFastEffects
            easing.type: menu.open ? Easing.Bezier : Easing.InCubic
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    // a section: a small accent label over its content
    component Section: Column {
        id: sec

        property string title: ""

        width: body.width
        spacing: Theme.dp(8)

        LText {
            leftPadding: Theme.dp(4)
            role: "labelMedium"
            weight: 620
            color: Theme.primary
            text: sec.title
        }

    }

    Rectangle {
        id: panel

        anchors.fill: parent
        radius: menu.cornerRadius
        color: Theme.withBlur(Theme.surfaceContainer)
        opacity: Math.min(1, menu.reveal * 1.6)
        clip: true

        // swallows clicks and the wheel so nothing reaches the catcher behind
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onWheel: (wheel) => {
                return wheel.accepted = true;
            }
        }

        Flickable {
            id: scroller

            anchors.fill: parent
            anchors.margins: menu.pad
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: body

                width: scroller.width
                spacing: Theme.dp(18)

                // header: the card's mark, its name and face, lock and close
                Item {
                    width: body.width
                    height: Theme.dp(44)

                    MaterialShape {
                        id: mark

                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(42)
                        height: Theme.dp(42)
                        shape: "cookie9"
                        color: Theme.primaryContainer

                        WidgetGlyph {
                            anchors.centerIn: parent
                            name: menu.frame ? menu.frame.wtype : "clock"
                            size: Theme.dp(20)
                            color: Theme.fgPrimaryContainer
                        }

                    }

                    Column {
                        anchors.left: mark.right
                        anchors.leftMargin: Theme.dp(12)
                        anchors.right: headBtns.left
                        anchors.rightMargin: Theme.dp(6)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -Theme.dp(2)

                        LText {
                            width: parent.width
                            role: "titleMedium"
                            weight: 620
                            text: menu.typeInfo ? menu.typeInfo.name : ""
                            elide: Text.ElideRight
                        }

                        LText {
                            width: parent.width
                            role: "bodySmall"
                            color: Theme.subtext
                            text: (menu.variantInfo ? menu.variantInfo.name : "") + (menu.frame && menu.frame.pinned ? "  ·  locked" : "")
                            elide: Text.ElideRight
                        }

                    }

                    Row {
                        id: headBtns

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.dp(2)

                        IconButton {
                            variant: "tonal"
                            checkable: true
                            checked: menu.frame ? menu.frame.pinned : false
                            size: "xs"
                            icon: "keep"
                            iconFill: checked ? 1 : 0
                            tooltip: checked ? "Unlock" : "Lock in place"
                            onClicked: {
                                if (menu.frame)
                                    Widgets.togglePinned(menu.frame.uid);

                            }
                        }

                        IconButton {
                            size: "xs"
                            icon: "close"
                            onClicked: menu.close()
                        }

                    }

                }

                // style: every face of this card, drawn small and live
                Section {
                    visible: menu.typeInfo !== null && menu.typeInfo.variants.length > 1
                    title: "Style"

                    Flow {
                        width: body.width
                        spacing: Theme.dp(6)

                        Repeater {
                            model: menu.typeInfo ? menu.typeInfo.variants : []

                            Item {
                                id: face

                                required property var modelData
                                readonly property bool on: menu.frame !== null && menu.frame.wvariant === face.modelData.id
                                readonly property real tileW: (body.width - Theme.dp(12)) / 3

                                width: face.tileW
                                height: face.tileW * 0.78 + Theme.dp(24)

                                Rectangle {
                                    id: thumb

                                    width: parent.width
                                    height: face.tileW * 0.78
                                    radius: face.on ? Theme.dp(14) : Theme.dp(18)
                                    color: face.on ? Theme.alpha(Theme.primary, 0.14) : Theme.withBlur(Theme.surfaceHigh)
                                    border.width: face.on ? 2 : 0
                                    border.color: Theme.primary

                                    Behavior on radius {
                                        NumberAnimation {
                                            duration: Theme.durFastSpatial
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.curveFastSpatial
                                        }

                                    }

                                    WidgetPreview {
                                        anchors.fill: parent
                                        anchors.margins: Theme.dp(6)
                                        wtype: menu.frame ? menu.frame.wtype : ""
                                        wvariant: face.modelData.id
                                        live: menu.open
                                        opts: menu.frame ? menu.frame.opts : ({})
                                    }

                                    Rectangle {
                                        visible: face.on
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: Theme.dp(4)
                                        width: Theme.dp(18)
                                        height: Theme.dp(18)
                                        radius: Theme.dp(9)
                                        color: Theme.primary

                                        Icon {
                                            anchors.centerIn: parent
                                            name: "check"
                                            size: Theme.dp(13)
                                            weight: 700
                                            color: Theme.fgPrimary
                                        }

                                    }

                                    StateLayer {
                                        radius: parent.radius
                                        onClicked: {
                                            if (menu.frame && !face.on)
                                                Widgets.setVariant(menu.frame.uid, face.modelData.id);

                                        }
                                    }

                                }

                                LText {
                                    anchors.top: thumb.bottom
                                    anchors.topMargin: Theme.dp(4)
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    role: "labelMedium"
                                    color: face.on ? Theme.primary : Theme.subtext
                                    text: face.modelData.name
                                    elide: Text.ElideRight
                                }

                            }

                        }

                    }

                }

                // colour: the m3 container the card sits on
                Section {
                    visible: menu.frame !== null && !menu.frame.bare
                    title: "Colour"

                    Row {
                        width: body.width
                        spacing: (body.width - 5 * 44) / 4

                        Repeater {
                            model: menu.tones

                            Column {
                                id: sw

                                required property var modelData
                                readonly property bool on: menu.tone === sw.modelData.key

                                width: Theme.dp(44)
                                spacing: Theme.dp(4)

                                Item {
                                    width: Theme.dp(44)
                                    height: Theme.dp(44)

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.dp(22)
                                        color: "transparent"
                                        border.width: 2
                                        border.color: sw.on ? Theme.primary : "transparent"
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: sw.on ? Theme.dp(34) : Theme.dp(38)
                                        height: width
                                        radius: sw.on ? Theme.dp(12) : width / 2
                                        color: sw.modelData.fill
                                        border.width: sw.modelData.key === "surface" ? 1 : 0
                                        border.color: Theme.alpha(Theme.text, 0.22)

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                        Behavior on radius {
                                            NumberAnimation {
                                                duration: Theme.durFastSpatial
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveFastSpatial
                                            }

                                        }

                                        Icon {
                                            visible: sw.modelData.key === "auto"
                                            anchors.centerIn: parent
                                            name: "auto_awesome"
                                            size: Theme.dp(18)
                                            fill: 1
                                            color: sw.modelData.dot
                                        }

                                        Rectangle {
                                            visible: sw.modelData.key !== "auto"
                                            anchors.centerIn: parent
                                            width: Theme.dp(12)
                                            height: Theme.dp(12)
                                            radius: Theme.dp(6)
                                            color: sw.modelData.dot
                                        }

                                    }

                                    StateLayer {
                                        radius: Theme.dp(22)
                                        onClicked: {
                                            if (menu.frame)
                                                menu.frame.setOpt("tone", sw.modelData.key);

                                        }
                                    }

                                }

                                LText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    role: "labelSmall"
                                    color: sw.on ? Theme.primary : Theme.subtext
                                    text: sw.modelData.label
                                }

                            }

                        }

                    }

                }

                // size: a zoom step, or for a stretchable card its numbers and two shortcuts
                Section {
                    title: "Size"

                    ButtonGroup {
                        visible: !menu.resizable
                        width: body.width
                        size: "xs"
                        current: menu.frame ? String(menu.frame.zoom) : "1"
                        options: [{
                            "key": "0.75",
                            "label": "S"
                        }, {
                            "key": "1",
                            "label": "M"
                        }, {
                            "key": "1.25",
                            "label": "L"
                        }, {
                            "key": "1.5",
                            "label": "XL"
                        }]
                        onPicked: (key) => {
                            if (menu.frame)
                                Widgets.setScale(menu.frame.uid, parseFloat(key));

                        }
                    }

                    LText {
                        visible: menu.resizable
                        leftPadding: Theme.dp(4)
                        role: "bodySmall"
                        color: Theme.subtext
                        text: menu.frame ? Math.round(menu.frame.bodyW) + " × " + Math.round(menu.frame.bodyH) + "  ·  drag any edge" : ""
                    }

                    Row {
                        visible: menu.resizable
                        spacing: Theme.dp(8)

                        Button {
                            variant: "tonal"
                            size: "xs"
                            icon: "width_full"
                            text: "Full width"
                            onClicked: {
                                if (menu.frame)
                                    menu.frame.fillWidth();

                            }
                        }

                        Button {
                            variant: "tonal"
                            size: "xs"
                            icon: "restart_alt"
                            text: "Reset"
                            onClicked: {
                                if (menu.frame)
                                    Widgets.resetSize(menu.frame.uid);

                            }
                        }

                    }

                }

                // options: switches as one grouped list, choices under their labels
                Section {
                    visible: menu.optionList.length > 0
                    title: "Options"

                    Column {
                        visible: menu.boolOptions.length > 0
                        width: body.width
                        spacing: Theme.dp(2)

                        Repeater {
                            model: menu.boolOptions

                            Rectangle {
                                id: brow

                                required property var modelData
                                required property int index
                                readonly property bool value: menu.frame ? menu.frame.opt(brow.modelData.key) === true : brow.modelData.def === true

                                width: body.width
                                height: Theme.dp(50)
                                topLeftRadius: brow.index === 0 ? Theme.dp(18) : Theme.dp(4)
                                topRightRadius: brow.index === 0 ? Theme.dp(18) : Theme.dp(4)
                                bottomLeftRadius: brow.index === menu.boolOptions.length - 1 ? Theme.dp(18) : Theme.dp(4)
                                bottomRightRadius: brow.index === menu.boolOptions.length - 1 ? Theme.dp(18) : Theme.dp(4)
                                color: Theme.withBlur(Theme.surfaceHigh)

                                LText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.dp(16)
                                    anchors.right: bsw.left
                                    anchors.rightMargin: Theme.dp(10)
                                    anchors.verticalCenter: parent.verticalCenter
                                    role: "bodyMedium"
                                    text: brow.modelData.label
                                    elide: Text.ElideRight
                                }

                                Switch {
                                    id: bsw

                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.dp(12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: brow.value
                                    onToggled: (v) => {
                                        if (menu.frame)
                                            menu.frame.setOpt(brow.modelData.key, v);

                                    }
                                }

                            }

                        }

                    }

                    Repeater {
                        model: menu.otherOptions

                        Column {
                            id: crow

                            required property var modelData
                            readonly property var value: menu.frame ? menu.frame.opt(crow.modelData.key) : crow.modelData.def

                            width: body.width
                            topPadding: Theme.dp(4)
                            spacing: Theme.dp(6)

                            LText {
                                leftPadding: Theme.dp(4)
                                role: "bodyMedium"
                                text: crow.modelData.label
                            }

                            ButtonGroup {
                                width: body.width
                                size: "xs"
                                current: String(crow.value)
                                options: crow.modelData.choices ? crow.modelData.choices : []
                                onPicked: (key) => {
                                    if (menu.frame)
                                        menu.frame.setOpt(crow.modelData.key, key);

                                }
                            }

                        }

                    }

                }

                // screen: only once there is more than one
                Section {
                    visible: menu.screens.length > 1
                    title: "Screen"

                    ButtonGroup {
                        width: body.width
                        size: "xs"
                        current: (menu.frame && menu.frame.screenName !== "") ? menu.frame.screenName : (Monitors.mainScreen ? Monitors.mainScreen.name : "")
                        options: menu.screens.map((s) => {
                            return ({
                                "key": s.name,
                                "label": s.name
                            });
                        })
                        onPicked: (key) => {
                            if (menu.frame)
                                Widgets.setScreen(menu.frame.uid, key);

                        }
                    }

                }

                Row {
                    width: body.width
                    spacing: Theme.dp(8)

                    Button {
                        width: (body.width - Theme.dp(8)) / 2
                        variant: "tonal"
                        size: "s"
                        icon: "content_copy"
                        text: "Duplicate"
                        disabled: Widgets.full
                        onClicked: {
                            if (!menu.frame)
                                return ;

                            Widgets.spawn(menu.frame.wtype, menu.frame.wvariant);
                            menu.close();
                        }
                    }

                    Button {
                        width: (body.width - Theme.dp(8)) / 2
                        variant: "tonal"
                        danger: true
                        size: "s"
                        icon: "delete"
                        text: "Remove"
                        onClicked: {
                            if (!menu.frame)
                                return ;

                            var uid = menu.frame.uid;
                            menu.close();
                            Widgets.close(uid);
                        }
                    }

                }

            }

        }

    }

}
