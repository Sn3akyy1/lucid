import QtQuick
import "../lucidprefs"
import Quickshell
import qs

Item {
    id: menu

    property Item frame: null

    readonly property real panelW: 272
    readonly property real gap: 12
    readonly property bool open: menu.frame !== null && menu.frame.menuOpen
    readonly property real boardW: (menu.frame && menu.frame.board) ? menu.frame.board.width : 1920
    readonly property real boardH: (menu.frame && menu.frame.board) ? menu.frame.board.height : 1080
    readonly property bool toRight: menu.frame ? (menu.frame.x + menu.frame.width + menu.gap + menu.panelW <= menu.boardW) : true
    readonly property var typeInfo: menu.frame ? Widgets.typeAt(menu.frame.wtype) : null
    readonly property var variantInfo: menu.frame ? Widgets.variantAt(menu.frame.wtype, menu.frame.wvariant) : null
    readonly property var optionList: menu.frame ? Widgets.optionsFor(menu.frame.wtype, menu.frame.wvariant) : []
    readonly property bool resizable: menu.frame !== null && menu.frame.resizable
    readonly property var screens: Quickshell.screens

    function clampY(want) {
        if (!menu.frame)
            return want;

        var lo = 8 - menu.frame.y;
        var hi = menu.boardH - panel.height - 8 - menu.frame.y;
        return hi < lo ? lo : Math.max(lo, Math.min(hi, want));
    }

    width: menu.panelW
    height: panel.height
    visible: panel.opacity > 0.01
    // right of the card, else left, else clamped onto the screen over the card
    x: {
        if (!menu.frame)
            return 0;

        var want = menu.toRight ? menu.frame.width + menu.gap : -menu.panelW - menu.gap;
        var lo = 8 - menu.frame.x;
        var hi = menu.boardW - menu.panelW - 8 - menu.frame.x;
        return hi < lo ? lo : Math.max(lo, Math.min(hi, want));
    }
    y: menu.clampY(0)

    Rectangle {
        id: panel

        width: menu.panelW
        height: inner.implicitHeight + 24
        radius: Theme.radiusLg
        color: Theme.withBlur("#000000")
        opacity: menu.open ? 1 : 0
        scale: menu.open ? 1 : 0.94
        transformOrigin: menu.toRight ? Item.TopLeft : Item.TopRight

        Behavior on opacity {
            NumberAnimation {
                duration: menu.open ? Theme.durShort : Theme.durExit
                easing.type: Theme.easeStandard
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: menu.open ? Theme.durEnter : Theme.durExit
                easing.type: Theme.easeStandard
            }

        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onWheel: (wheel) => {
                return wheel.accepted = true;
            }
        }

        Column {
            id: inner

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 12

            Item {
                width: parent.width
                height: headerRow.implicitHeight

                Row {
                    id: headerRow

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    WidgetGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: menu.frame ? menu.frame.wtype : "clock"
                        size: 20
                        color: Theme.accent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: menu.typeInfo ? menu.typeInfo.name : ""
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTitle
                            font.bold: true
                        }

                        Text {
                            text: menu.variantInfo ? menu.variantInfo.name : ""
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                        }

                    }

                }

                // the hover chrome used to carry this, and the menu is now the
                // only place it can live
                WidgetButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "pin"
                    iconSize: 14
                    diameter: 28
                    active: menu.frame ? menu.frame.pinned : false
                    onClicked: {
                        if (menu.frame)
                            Widgets.togglePinned(menu.frame.uid);

                    }
                }

            }

            Column {
                width: parent.width
                spacing: 7
                visible: menu.typeInfo && menu.typeInfo.variants.length > 1

                Text {
                    text: "STYLE"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: menu.typeInfo ? menu.typeInfo.variants : []

                        Rectangle {
                            id: chip

                            required property var modelData

                            readonly property bool selected: menu.frame && menu.frame.wvariant === chip.modelData.id

                            width: chipLabel.implicitWidth + 22
                            height: 30
                            radius: 15
                            color: chip.selected ? Theme.accentContainer : (chipArea.containsMouse ? Theme.bgActive : Theme.bgHover)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durShort
                                }

                            }

                            Text {
                                id: chipLabel

                                anchors.centerIn: parent
                                text: chip.modelData.name
                                color: chip.selected ? Theme.fgAccentContainer : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: chip.selected
                            }

                            MouseArea {
                                id: chipArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (menu.frame)
                                        Widgets.setVariant(menu.frame.uid, chip.modelData.id);

                                }
                            }

                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 7

                Text {
                    text: "SIZE"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                M3Segmented {
                    width: parent.width
                    implicitHeight: 34
                    visible: !menu.resizable
                    trackColor: Theme.bgHover
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
                    onChosen: (key) => {
                        if (menu.frame)
                            Widgets.setScale(menu.frame.uid, parseFloat(key));

                    }
                }

                // a variant that owns its size gets the two shapes worth a button and
                // the numbers, the rest of it is the grips on the card itself
                Text {
                    width: parent.width
                    visible: menu.resizable
                    text: menu.frame ? (Math.round(menu.frame.bodyW) + " × " + Math.round(menu.frame.bodyH) + " · drag any edge") : ""
                    color: Theme.subtextDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabel
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    spacing: 8
                    visible: menu.resizable

                    Repeater {
                        model: [{
                            "key": "full",
                            "label": "Full width"
                        }, {
                            "key": "reset",
                            "label": "Reset"
                        }]

                        Rectangle {
                            id: sizeBtn

                            required property var modelData

                            width: (menu.panelW - 24 - 8) / 2
                            height: 32
                            radius: 16
                            color: sizeArea.containsMouse ? Theme.bgActive : Theme.bgHover

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durQuick
                                }

                            }

                            Text {
                                anchors.centerIn: parent
                                text: sizeBtn.modelData.label
                                color: Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: true
                            }

                            MouseArea {
                                id: sizeArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!menu.frame)
                                        return ;

                                    if (sizeBtn.modelData.key === "full")
                                        menu.frame.fillWidth();
                                    else
                                        Widgets.resetSize(menu.frame.uid);
                                }
                            }

                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 2
                visible: menu.optionList.length > 0

                Text {
                    text: "OPTIONS"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.bold: true
                    font.letterSpacing: 0.8
                    bottomPadding: 5
                }

                Repeater {
                    model: menu.optionList

                    Item {
                        id: opt

                        required property var modelData

                        readonly property var value: menu.frame ? menu.frame.opt(opt.modelData.key) : opt.modelData.def

                        width: inner.width
                        height: opt.modelData.type === "bool" ? 42 : (optLabel.implicitHeight + optHolder.implicitHeight + 12)

                        Text {
                            id: optLabel

                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.topMargin: opt.modelData.type === "bool" ? 0 : 1
                            height: opt.modelData.type === "bool" ? parent.height : implicitHeight
                            verticalAlignment: Text.AlignVCenter
                            text: opt.modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                        }

                        Item {
                            id: optHolder

                            implicitWidth: opt.modelData.type === "bool" ? 52 : parent.width
                            implicitHeight: opt.modelData.type === "bool" ? 32 : 34
                            anchors.right: parent.right
                            anchors.top: opt.modelData.type === "bool" ? undefined : optLabel.bottom
                            anchors.topMargin: opt.modelData.type === "bool" ? 0 : 6
                            anchors.verticalCenter: opt.modelData.type === "bool" ? parent.verticalCenter : undefined

                            M3Switch {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                visible: opt.modelData.type === "bool"
                                checked: opt.value === true
                                onToggled: (v) => {
                                    if (menu.frame)
                                        menu.frame.setOpt(opt.modelData.key, v);

                                }
                            }

                            M3Segmented {
                                width: parent.width
                                implicitHeight: 34
                                visible: opt.modelData.type === "choice"
                                current: String(opt.value)
                                options: opt.modelData.choices ? opt.modelData.choices : []
                                onChosen: (key) => {
                                    if (menu.frame)
                                        menu.frame.setOpt(opt.modelData.key, key);

                                }
                            }

                            M3TextField {
                                width: parent.width
                                implicitHeight: 34
                                visible: opt.modelData.type === "text"
                                text: String(opt.value)
                                placeholder: opt.modelData.placeholder ? opt.modelData.placeholder : ""
                                onAccepted: (v) => {
                                    if (menu.frame)
                                        menu.frame.setOpt(opt.modelData.key, v);

                                }
                            }

                        }

                    }

                }

            }

            Column {
                width: parent.width
                spacing: 7
                visible: menu.screens.length > 1

                Text {
                    text: "SCREEN"
                    color: Theme.accent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fs(10)
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                M3Segmented {
                    width: parent.width
                    implicitHeight: 34
                    current: (menu.frame && menu.frame.screenName !== "") ? menu.frame.screenName : (menu.screens.length > 0 ? menu.screens[0].name : "")
                    options: menu.screens.map((s) => {
                        return ({
                            "key": s.name,
                            "label": s.name
                        });
                    })
                    onChosen: (key) => {
                        if (menu.frame)
                            Widgets.setScreen(menu.frame.uid, key);

                    }
                }

            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.alpha(Theme.outline, 0.6)
            }

            Row {
                width: parent.width
                spacing: 8

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 36
                    radius: 18
                    color: dupArea.containsMouse ? Theme.bgActive : Theme.bgHover

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        WidgetGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "add"
                            size: 15
                            color: Theme.subtext
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Duplicate"
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: true
                        }

                    }

                    MouseArea {
                        id: dupArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (menu.frame)
                                Widgets.spawn(menu.frame.wtype, menu.frame.wvariant);

                        }
                    }

                }

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 36
                    radius: 18
                    color: remArea.containsMouse ? Theme.errorContainer : Theme.bgHover

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        WidgetGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: "trash"
                            size: 15
                            color: remArea.containsMouse ? Theme.fgErrorContainer : Theme.error
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Remove"
                            color: remArea.containsMouse ? Theme.fgErrorContainer : Theme.error
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabel
                            font.bold: true
                        }

                    }

                    MouseArea {
                        id: remArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (menu.frame)
                                Widgets.close(menu.frame.uid);

                        }
                    }

                }

            }

        }

    }

}
