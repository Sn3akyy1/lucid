import QtQuick
import QtQuick.Controls.Basic
import qs
import qs.lucidui
import qs.lucidprefs as LP

// edit mode's sheet of options, docked to the side of the display away from what
// it is about: the bar's, one module's, or the dock's. everything applies as it is set
Item {
    id: sheet

    // the settings rows inside reset straight away in here, with no dialog to ask
    readonly property bool isEditSheet: true
    readonly property int wheelStep: 190

    property bool hosted: false
    // what it shows, kept while it slides away so it never empties on the way out
    property string kind: ""
    property string moduleId: ""
    property string side: "right"
    // crossing to the other side: out, over, and back in
    property bool swapping: false
    property real reveal: sheet.hosted && !sheet.swapping ? 1 : 0
    readonly property bool shown: sheet.reveal > 0.01
    // the glass cannot slide, so it comes on once the sheet is in place
    readonly property bool settled: sheet.hosted && !sheet.swapping && sheet.reveal > 0.97
    readonly property real edge: Theme.dp(12)
    readonly property real radius: Theme.rad(28)

    readonly property var mod: Prefs.barModuleById[sheet.moduleId] || null
    readonly property string title: sheet.kind === "bar" ? "Bar" : (sheet.kind === "dock" ? "Dock" : (sheet.mod ? sheet.mod.name : ""))
    readonly property string blurb: sheet.kind === "bar" ? "Its style, its size and how its modules open" : (sheet.kind === "dock" ? "Its style, its size and how it behaves" : (sheet.mod ? sheet.mod.desc : ""))
    readonly property string glyph: sheet.kind === "bar" ? "toolbar" : (sheet.kind === "dock" ? "dock_to_bottom" : (sheet.mod && sheet.mod.icon ? sheet.mod.icon : "tune"))

    function latch() {
        if (Edit.sheet === "")
            return ;

        const changed = Edit.sheet !== sheet.kind || Edit.module !== sheet.moduleId;
        sheet.kind = Edit.sheet;
        sheet.moduleId = Edit.module;
        if (changed) {
            scroll.stop();
            flick.contentY = 0;
            fadeIn.restart();
        }
    }

    function follow() {
        if (!sheet.hosted || Edit.side === sheet.side)
            return ;

        sheet.swapping = true;
        swapTimer.restart();
    }

    onHostedChanged: {
        if (sheet.hosted) {
            if (!sheet.shown)
                sheet.side = Edit.side;

            sheet.latch();
            sheet.follow();
        }
    }

    width: Math.min(Theme.dp(480), parent ? parent.width - sheet.edge * 2 : Theme.dp(480))
    x: sheet.side === "right" ? (parent ? parent.width : 0) - sheet.width - sheet.edge + (1 - sheet.reveal) * Theme.dp(56) : sheet.edge - (1 - sheet.reveal) * Theme.dp(56)
    opacity: sheet.reveal
    visible: sheet.shown

    Connections {
        function onSheetChanged() {
            sheet.latch();
        }

        function onModuleChanged() {
            sheet.latch();
        }

        function onSideChanged() {
            sheet.follow();
        }

        target: Edit
    }

    Timer {
        id: swapTimer

        interval: Theme.durShort + 20
        onTriggered: {
            sheet.side = Edit.side;
            sheet.swapping = false;
        }
    }

    // a wheel anywhere on the sheet stops here, rather than scrolling what is behind
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            return event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: sheet.radius
        color: Theme.bg
    }

    Item {
        id: head

        width: parent.width
        height: Theme.dp(84)

        LP.M3IconButton {
            id: backBtn

            x: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            visible: Edit.back !== ""
            size: Theme.dp(40)
            iconPath: "arrow_back"
            onClicked: Edit.goBack()
        }

        Rectangle {
            id: badge

            x: backBtn.visible ? backBtn.x + backBtn.width + Theme.dp(6) : Theme.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dp(44)
            height: Theme.dp(44)
            radius: Theme.rad(14)
            color: Theme.alpha(Theme.accent, 0.16)

            Icon {
                anchors.centerIn: parent
                name: sheet.glyph
                size: Theme.dp(22)
                color: Theme.accent
            }

        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: Theme.dp(14)
            anchors.right: closeBtn.left
            anchors.rightMargin: Theme.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            Text {
                width: parent.width
                text: sheet.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitleLg
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: sheet.blurb
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
            }

        }

        LP.M3IconButton {
            id: closeBtn

            anchors.right: parent.right
            anchors.rightMargin: Theme.dp(14)
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.dp(40)
            iconPath: "close"
            onClicked: Edit.closeSheet()
        }

    }

    Flickable {
        id: flick

        anchors.top: head.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.dp(12)
        anchors.rightMargin: Theme.dp(12)
        clip: true
        contentWidth: width
        contentHeight: body.height + Theme.dp(18)
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 6000
        maximumFlickVelocity: 9000

        Loader {
            id: body

            width: flick.width
            height: body.item ? body.item.implicitHeight : 0
            sourceComponent: sheet.kind === "bar" ? barBody : (sheet.kind === "dock" ? dockBody : (sheet.kind === "module" ? moduleBody : null))
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                event.accepted = true;
                var maxY = Math.max(0, flick.contentHeight - flick.height);
                var base = scroll.running ? scroll.to : flick.contentY;
                var target = Math.max(0, Math.min(maxY, base - (event.angleDelta.y / 120) * sheet.wheelStep));
                if (target === base)
                    return ;

                scroll.stop();
                scroll.from = flick.contentY;
                scroll.to = target;
                scroll.start();
            }
        }

        NumberAnimation {
            id: scroll

            target: flick
            property: "contentY"
            duration: Theme.ms(170)
            easing.type: Easing.OutCubic
        }

        ScrollBar.vertical: ScrollBar {
            policy: flick.contentHeight > flick.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
            width: Theme.dp(8)
            bottomPadding: sheet.radius / 2

            contentItem: Rectangle {
                implicitWidth: Theme.dp(4)
                radius: width / 2
                color: Theme.alpha(Theme.text, 0.28)
            }

            background: Item {
            }

        }

    }

    NumberAnimation {
        id: fadeIn

        target: body
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.durMedium
        easing.type: Easing.OutCubic
    }

    Component {
        id: barBody

        Column {
            spacing: Theme.dp(26)

            BarSheetTop {
                width: parent.width
            }

            LP.BarPage {
                width: parent.width
                inSheet: true
            }

        }

    }

    Component {
        id: moduleBody

        Column {
            spacing: Theme.dp(26)

            ModuleSheetTop {
                width: parent.width
                moduleId: sheet.moduleId
            }

            LP.BarModuleCard {
                width: parent.width
                moduleId: sheet.moduleId
            }

        }

    }

    Component {
        id: dockBody

        Column {
            spacing: Theme.dp(26)

            DockSheetTop {
                width: parent.width
            }

            LP.DockPage {
                width: parent.width
                inSheet: true
            }

        }

    }

    Behavior on reveal {
        NumberAnimation {
            duration: sheet.swapping ? Theme.durShort : Theme.durMedium
            easing.type: Easing.OutCubic
        }

    }

}
