import QtQuick
import Quickshell.Widgets
import qs
import qs.lucidicons
import qs.lucidui

// where to go: home, recent and trash, the home folders, bookmarks (gtk's own
// list, shared with every other file manager), this computer and its drives.
// each row wears its place's glyph, the emblem on that folder's own icon; one
// pill glides to the row you are in. every row takes drops; the trash row
// trashes what lands on it
Item {
    id: side

    required property var app
    required property var win
    readonly property string here: side.win.tab ? side.win.tab.path : ""
    // the row the pill sits under, or none when the folder has no row
    property Item activeRow: null
    readonly property real rowH: Theme.dp(48)
    // the sidebar's own width: shown or hidden it keeps it and slides, so
    // nothing in it is squeezed or cut while it goes
    readonly property real fullW: Theme.dp(236)

    // a row going dark lets go only once the rows have all been told: going to a
    // row further down, the one above hears first, and letting go there made
    // the pill vanish and reappear instead of gliding
    function letGo(p) {
        if (side.activeRow === p && !p.on)
            side.activeRow = null;

    }

    // drives here, and shares on other computers, apart
    readonly property var devices: side.app.volumes.filter(function(v) {
        return !v.remote;
    })
    readonly property var shares: side.app.volumes.filter(function(v) {
        return v.remote === true;
    })

    // gnome seeds the bookmarks file with the home folders; those already have rows
    readonly property var bookmarks: {
        var have = ({});
        have[side.app.home] = true;
        for (var i = 0; i < side.app.places.length; i++) have[side.app.places[i].path] = true
        return side.app.bookmarks.filter(function(b) {
            return !have[b.path];
        });
    }

    component Heading: LText {
        width: parent ? parent.width : 0
        leftPadding: Theme.dp(22)
        topPadding: Theme.dp(16)
        bottomPadding: Theme.dp(4)
        role: "labelLarge"
        color: Theme.subtext
    }

    component Place: Item {
        id: place

        property string label: ""
        property string slot: "folder"
        property string target: ""
        property string trailing: ""
        property real usage: -1
        // a drive's room left, as words
        property string free: ""
        property bool ejectable: false
        property bool drop: true
        property bool missing: false
        // a colour a bookmark was given, or none
        property string tint: ""
        // the material symbol for a row the icon theme has no glyph for
        property string icon: "folder"
        property string ejectTip: "Eject"
        readonly property bool on: place.target !== "" && side.here === place.target
        property bool hovering: false

        // a drop landing: a wave from where it fell, what fell flying into the
        // glyph, the glyph taking it (a squash and spring; the trash wobbles) and
        // +n rising off it
        property real bounce: 1
        property real wobble: 0
        property real pulse: 0
        property int landed: 0
        property url landedImage
        readonly property bool isTrash: place.target.indexOf("trash:") === 0
        // the glyph's own swell under the pointer or a drag, eased apart from the bounce
        property real swell: rowArea.pressed ? 0.92 : (rowArea.containsMouse || place.hovering) ? 1.12 : 1

        function receive(x, y, n) {
            if (Theme.motionScale <= 0)
                return ;

            place.landed = n;
            place.landedImage = side.app.dragImage;
            waveLoader.cx = x;
            waveLoader.cy = y;
            waveLoader.restart();
            flyer.fromX = x - flyer.width / 2;
            flyer.fromY = y - flyer.height / 2;
            take.restart();
        }

        signal eject()
        signal menu(real x, real y)
        // a click on a row with nowhere to go, like a drive not mounted yet
        signal picked()

        width: parent ? parent.width : 0
        height: side.rowH
        opacity: place.missing ? 0.5 : 1
        // how much of the row the pill covers right now: its words and glyph
        // light as the pill arrives, not before
        readonly property real lit: {
            var top = Math.max(place.y, glider.upper), bottom = Math.min(place.y + place.height, glider.lower);
            return Math.max(0, Math.min(1, (bottom - top) / Math.max(1, place.height))) * glider.opacity;
        }
        readonly property color ink: Qt.tint(Theme.text, Qt.rgba(Theme.fgAccentContainer.r, Theme.fgAccentContainer.g, Theme.fgAccentContainer.b, place.lit))
        readonly property color softInk: Qt.tint(Theme.subtext, Qt.rgba(Theme.fgAccentContainer.r, Theme.fgAccentContainer.g, Theme.fgAccentContainer.b, place.lit))

        onOnChanged: {
            if (place.on)
                side.activeRow = place;
            else if (side.activeRow === place)
                Qt.callLater(side.letGo, place);
        }
        Component.onCompleted: {
            if (place.on)
                side.activeRow = place;

        }
        Component.onDestruction: {
            if (side.activeRow === place)
                side.activeRow = null;

        }

        Behavior on swell {
            NumberAnimation {
                duration: Theme.durDefaultSpatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        // what fell travels into the glyph and is gone, then the glyph takes it
        SequentialAnimation {
            id: take

            PropertyAction {
                target: flyer
                property: "t"
                value: 0
            }

            NumberAnimation {
                target: flyer
                property: "t"
                to: 1
                duration: Theme.ms(320)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeEmphasizedAccel
            }

            ScriptAction {
                script: {
                    if (place.isTrash)
                        shake.restart();
                    else
                        squash.restart();
                    rise.restart();
                }
            }

        }

        // either way it ends the same: the glyph flashes the accent and +n floats up
        ParallelAnimation {
            id: rise

            NumberAnimation {
                target: place
                property: "pulse"
                from: 1
                to: 0
                duration: Theme.ms(620)
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: countUp
                property: "t"
                from: 0
                to: 1
                duration: Theme.ms(900)
                easing.type: Easing.OutCubic
            }

        }

        ParallelAnimation {
            id: squash

            SequentialAnimation {
                NumberAnimation {
                    target: place
                    property: "bounce"
                    to: 0.74
                    duration: Theme.ms(80)
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: place
                    property: "bounce"
                    to: 1.24
                    duration: Theme.ms(130)
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: place
                    property: "bounce"
                    to: 1
                    duration: Theme.ms(380)
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveFastSpatial
                }

            }

        }

        ParallelAnimation {
            id: shake

            SequentialAnimation {
                NumberAnimation {
                    target: place
                    property: "wobble"
                    to: -13
                    duration: Theme.ms(70)
                }

                NumberAnimation {
                    target: place
                    property: "wobble"
                    to: 10
                    duration: Theme.ms(110)
                }

                NumberAnimation {
                    target: place
                    property: "wobble"
                    to: -6
                    duration: Theme.ms(110)
                }

                NumberAnimation {
                    target: place
                    property: "wobble"
                    to: 3
                    duration: Theme.ms(100)
                }

                NumberAnimation {
                    target: place
                    property: "wobble"
                    to: 0
                    duration: Theme.ms(140)
                    easing.type: Easing.OutQuad
                }

            }

        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.dp(8)
            anchors.rightMargin: Theme.dp(8)
            radius: height / 2
            // the pill under the row you are in is the glider's; this lights for drops
            color: place.hovering ? Theme.alpha(Theme.accent, 0.22) : "transparent"

            // the row's own pointer: hover tint, the ripple, and the clicks
            StateLayer {
                id: rowArea

                anchors.fill: parent
                anchors.rightMargin: place.ejectable ? Theme.dp(40) : 0
                radius: parent.radius
                tint: place.on ? Theme.fgAccentContainer : Theme.text
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        var p = rowArea.mapToItem(side.win.contentRoot, mouse.x, mouse.y);
                        place.menu(p.x, p.y);
                    } else if (place.target !== "") {
                        if (mouse.button === Qt.MiddleButton || (mouse.modifiers & Qt.ControlModifier))
                            side.win.newTab(place.target);
                        else
                            side.win.go(place.target);
                    } else if (mouse.button === Qt.LeftButton) {
                        place.picked();
                    }
                }
            }

            // the wave a drop sends across the pill from where it fell
            Loader {
                id: waveLoader

                property real cx: 0
                property real cy: 0

                function restart() {
                    waveLoader.active = false;
                    waveLoader.active = true;
                }

                anchors.fill: parent
                active: false

                sourceComponent: ClippingRectangle {
                    color: "transparent"
                    radius: height / 2

                    Rectangle {
                        id: dropWave

                        readonly property real reach: Math.sqrt(waveLoader.width * waveLoader.width + waveLoader.height * waveLoader.height)
                        property real grow: 0.05
                        property real fade: 1

                        x: waveLoader.cx - width / 2
                        y: waveLoader.cy - height / 2
                        width: dropWave.reach * 2 * dropWave.grow
                        height: width
                        radius: width / 2
                        color: Theme.accent
                        opacity: 0.3 * dropWave.fade

                        ParallelAnimation {
                            running: true
                            onFinished: waveLoader.active = false

                            NumberAnimation {
                                target: dropWave
                                property: "grow"
                                to: 1
                                duration: Theme.ms(520)
                                easing.type: Easing.OutCubic
                            }

                            SequentialAnimation {
                                PauseAnimation {
                                    duration: Theme.ms(200)
                                }

                                NumberAnimation {
                                    target: dropWave
                                    property: "fade"
                                    to: 0
                                    duration: Theme.ms(380)
                                }

                            }

                        }

                    }

                }

            }

            // the place's glyph, swelling under the pointer or a drop
            PlaceGlyph {
                id: rowIcon

                x: Theme.dp(14)
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.dp(22)
                slot: place.slot
                fallback: place.icon
                color: Qt.tint(place.tint !== "" ? side.app.ink(place.tint) : place.softInk, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, place.pulse))
                animateColor: false
                scale: place.swell * place.bounce
                rotation: place.wobble

            }

            LText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.dp(50)
                anchors.right: freeText.visible ? freeText.left : tail.left
                anchors.rightMargin: Theme.dp(6)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: place.usage >= 0 ? -Theme.dp(5) : 0
                role: "titleSmall"
                text: place.label
                color: place.ink
                elide: Text.ElideRight
            }

            LText {
                id: freeText

                visible: place.free !== ""
                anchors.right: tail.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.dp(5)
                role: "labelSmall"
                text: place.free
                color: place.softInk
            }

            // what fell, on its way into the glyph: its own picture when it came
            // from lumen, a page otherwise
            Item {
                id: flyer

                property real fromX: 0
                property real fromY: 0
                property real t: 1
                readonly property real toX: rowIcon.x + rowIcon.width / 2 - width / 2
                readonly property real toY: rowIcon.y + rowIcon.height / 2 - height / 2

                z: 3
                width: Theme.dp(30)
                height: Theme.dp(30)
                // a little arc on the way, as a thing tossed rather than slid
                x: flyer.fromX + (flyer.toX - flyer.fromX) * flyer.t
                y: flyer.fromY + (flyer.toY - flyer.fromY) * flyer.t - Math.sin(Math.PI * flyer.t) * Theme.dp(10)
                scale: 1 - 0.72 * flyer.t
                opacity: 1 - Math.pow(flyer.t, 4)
                visible: flyer.t < 1

                Image {
                    anchors.fill: parent
                    visible: place.landedImage.toString() !== ""
                    source: place.landedImage
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    visible: place.landedImage.toString() === ""
                    radius: Theme.dp(8)
                    color: Theme.secondaryContainer

                    Icon {
                        anchors.centerIn: parent
                        name: "draft"
                        size: Theme.dp(18)
                        fill: 1
                        color: Theme.fgSecondaryContainer
                    }

                }

            }

            // +n, rising off the glyph
            LText {
                id: countUp

                property real t: 0

                z: 3
                x: rowIcon.x + rowIcon.width - Theme.dp(4)
                y: rowIcon.y - Theme.dp(6) - countUp.t * Theme.dp(14)
                role: "labelLarge"
                text: "+" + place.landed
                color: Theme.accent
                opacity: countUp.t <= 0 || countUp.t >= 1 ? 0 : (countUp.t < 0.15 ? countUp.t / 0.15 : (1 - countUp.t) / 0.85)
                visible: opacity > 0
            }

            // how full a drive is
            Rectangle {
                visible: place.usage >= 0
                anchors.left: parent.left
                anchors.leftMargin: Theme.dp(50)
                anchors.right: tail.left
                anchors.rightMargin: Theme.dp(10)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Theme.dp(11)
                height: Theme.dp(4)
                radius: height / 2
                color: Theme.alpha(place.ink, 0.14)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, place.usage))
                    height: parent.height
                    radius: height / 2
                    color: place.usage > 0.9 ? Theme.error : Qt.tint(Theme.accent, Qt.rgba(Theme.fgAccentContainer.r, Theme.fgAccentContainer.g, Theme.fgAccentContainer.b, place.lit))

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durDefaultSpatial
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Theme.curveDefaultSpatial
                        }

                    }

                }

            }

            Item {
                id: tail

                anchors.right: parent.right
                anchors.rightMargin: Theme.dp(8)
                anchors.verticalCenter: parent.verticalCenter
                width: place.ejectable ? Theme.dp(30) : count.implicitWidth + Theme.dp(6)
                height: Theme.dp(30)

                LText {
                    id: count

                    anchors.centerIn: parent
                    visible: !place.ejectable && place.trailing !== ""
                    role: "labelMedium"
                    text: place.trailing
                    color: place.softInk
                }

                IconButton {
                    anchors.centerIn: parent
                    visible: place.ejectable
                    size: "xs"
                    icon: "eject"
                    tooltip: place.ejectTip
                    onClicked: place.eject()

                    Tip {
                    }

                }

            }

            DropArea {
                anchors.fill: parent
                enabled: place.drop && place.target !== ""
                keys: ["text/uri-list"]
                onEntered: place.hovering = true
                onExited: place.hovering = false
                onDropped: (drop) => {
                    place.hovering = false;
                    if (place.target.indexOf("trash:") === 0) {
                        var uris = [];
                        for (var k = 0; k < drop.urls.length; k++) uris.push(drop.urls[k].toString())
                        drop.acceptProposedAction();
                        side.win.trashUris(uris);
                    } else {
                        side.win.pane.dropInto(place.target, drop);
                    }
                    if (drop.accepted)
                        place.receive(drop.x, drop.y, drop.urls.length);

                }
            }

        }

    }

    // at its own width always, sliding out to the left as the sidebar closes
    Flickable {
        id: scroll

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: Math.min(0, side.width - side.fullW)
        width: side.fullW
        opacity: Math.max(0, Math.min(1, side.width / side.fullW * 1.3 - 0.3))
        contentHeight: list.implicitHeight + Theme.dp(12)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // flickable's own wheel crawls: on wayland it takes a notch's 15 pixels.
        // four rows a notch; a touchpad (the one with phases) at the folder view's pace
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                var maxY = Math.max(0, scroll.contentHeight - scroll.height);
                if (event.phase !== Qt.NoScrollPhase) {
                    sideGlide.stop();
                    scroll.contentY = Math.max(0, Math.min(maxY, scroll.contentY - event.pixelDelta.y * 2.4));
                    return ;
                }
                sideGlide.to = Math.max(0, Math.min(maxY, (sideGlide.running ? sideGlide.to : scroll.contentY) - event.angleDelta.y / 120 * side.rowH * 4));
                sideGlide.restart();
            }
        }

        NumberAnimation {
            id: sideGlide

            target: scroll
            property: "contentY"
            duration: Theme.durShort
            easing.type: Easing.OutCubic
        }

        // the pill for the row you are in. going to another row it stretches: the
        // edge on the way leads, the other follows and closes up behind it, with
        // nothing overshooting the row. from no row at all it appears in place
        Rectangle {
            id: glider

            // its edges: Item's own top and bottom are anchor lines, final, so not these
            property real upper: 0
            property real lower: 0
            // it has been somewhere since it last faded, so the next row is a glide
            property bool settled: false

            // glide: to another row; otherwise the row itself moved (a list above it
            // changed), and both edges go together
            function follow(glide) {
                var r = side.activeRow;
                if (!r) {
                    glider.settled = false;
                    return ;
                }
                var t = r.y, b = r.y + r.height;
                if (!glider.settled || Theme.motionScale <= 0) {
                    edges.stop();
                    glider.upper = t;
                    glider.lower = b;
                    glider.settled = true;
                    return ;
                }
                if (Math.abs(t - glider.upper) < 0.5 && Math.abs(b - glider.lower) < 0.5)
                    return ;

                var down = t > glider.upper;
                var lead = glide ? Theme.ms(200) : Theme.ms(260);
                var trail = glide ? Theme.ms(330) : Theme.ms(260);
                topAnim.to = t;
                bottomAnim.to = b;
                topAnim.duration = down ? trail : lead;
                bottomAnim.duration = down ? lead : trail;
                topAnim.easing.bezierCurve = down ? Theme.curveStandard : Theme.easeEmphasizedDecel;
                bottomAnim.easing.bezierCurve = down ? Theme.easeEmphasizedDecel : Theme.curveStandard;
                edges.restart();
            }

            x: Theme.dp(8)
            y: glider.upper
            width: list.width - Theme.dp(16)
            height: Math.max(0, glider.lower - glider.upper)
            radius: Math.min(height, side.rowH) / 2
            color: Theme.accentContainer
            opacity: side.activeRow ? 1 : 0
            scale: side.activeRow ? 1 : 0.94
            visible: opacity > 0

            ParallelAnimation {
                id: edges

                NumberAnimation {
                    id: topAnim

                    target: glider
                    property: "upper"
                    easing.type: Easing.BezierSpline
                }

                NumberAnimation {
                    id: bottomAnim

                    target: glider
                    property: "lower"
                    easing.type: Easing.BezierSpline
                }

            }

            Connections {
                function onActiveRowChanged() {
                    glider.follow(true);
                }

                target: side
            }

            // the row moves when the lists above it change
            Connections {
                function onYChanged() {
                    glider.follow(false);
                }

                target: side.activeRow
                ignoreUnknownSignals: true
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durShort
                }

            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveStandard
                }

            }

        }

        Column {
            id: list

            width: scroll.width

            Item {
                width: parent.width
                height: Theme.dp(8)
            }

            Place {
                label: "Home"
                slot: "folder-home"
                target: side.app.home
            }

            Place {
                label: "Recent"
                slot: "recent"
                target: "recent:///"
                drop: false
            }

            Place {
                label: "Trash"
                slot: side.app.trashCount > 0 ? "trash-full" : "trash"
                target: "trash:///"
                trailing: side.app.trashCount > 0 ? String(side.app.trashCount) : ""
                onMenu: (x, y) => {
                    return side.win.trashMenu(x, y);
                }
            }

            Heading {
                text: "Folders"
                visible: side.app.places.length > 0
            }

            Repeater {
                model: side.app.places

                delegate: Place {
                    required property var modelData

                    label: modelData.label
                    slot: modelData.slot || "folder"
                    target: modelData.path
                }

            }

            Heading {
                text: "Bookmarks"
            }

            // none yet: how to make one
            LText {
                visible: side.bookmarks.length === 0
                width: parent.width
                leftPadding: Theme.dp(22)
                rightPadding: Theme.dp(16)
                topPadding: Theme.dp(2)
                bottomPadding: Theme.dp(6)
                role: "bodySmall"
                wrapMode: Text.WordWrap
                text: "Ctrl+D keeps the folder you're in here"
                color: Theme.subtext
            }

            Repeater {
                model: side.bookmarks

                delegate: Place {
                    required property var modelData

                    label: modelData.label
                    // a folder on another machine draws as one
                    slot: modelData.remote || !modelData.path ? "folder-remote" : "folder"
                    target: modelData.path || modelData.uri
                    tint: side.app.bookmarkColour(modelData.uri)
                    missing: modelData.path !== "" && !modelData.exists
                    onMenu: (x, y) => {
                        return side.win.bookmarkMenu(modelData, x, y);
                    }
                }

            }

            Heading {
                text: "Devices"
            }

            // the system's own drive first, then other disks, then what's plugged in
            Repeater {
                model: side.devices

                delegate: Place {
                    required property var modelData
                    readonly property var space: side.app.volumeSpace[modelData.id] || null

                    label: modelData.label
                    slot: modelData.slot || "drive"
                    target: modelData.mounted ? (modelData.path || modelData.uri) : ""
                    usage: space && space.total > 0 ? 1 - space.free / space.total : -1
                    free: space && space.total > 0 ? side.app.sizeText(space.free) + " free" : ""
                    ejectable: modelData.mounted && (modelData.canEject || modelData.canUnmount)
                    onEject: side.win.unmount(modelData)
                    onMenu: (x, y) => {
                        return side.win.driveMenu(modelData, x, y);
                    }
                    // a drive not mounted yet mounts on a click
                    onPicked: {
                        if (!modelData.mounted)
                            side.win.mount(modelData);

                    }
                }

            }

            Heading {
                text: "Network"
            }

            // shares connected to, then the computers nearby, then a new one
            Repeater {
                model: side.shares

                delegate: Place {
                    required property var modelData
                    readonly property var space: side.app.volumeSpace[modelData.id] || null

                    label: modelData.label
                    slot: modelData.slot || "network"
                    target: modelData.path || modelData.uri
                    usage: space && space.total > 0 ? 1 - space.free / space.total : -1
                    free: space && space.total > 0 ? side.app.sizeText(space.free) + " free" : ""
                    ejectable: modelData.canUnmount || modelData.canEject
                    ejectTip: "Disconnect"
                    onEject: side.win.unmount(modelData)
                    onMenu: (x, y) => {
                        return side.win.driveMenu(modelData, x, y);
                    }
                }

            }

            // hidden, it must not hold the pill: an unseen row still sits under it
            Place {
                visible: side.app.canDiscover
                label: "Nearby"
                slot: "network"
                target: side.app.canDiscover ? "network:///" : ""
                drop: false
            }

            Place {
                label: "Connect to server"
                slot: "connect"
                icon: "add_link"
                drop: false
                onPicked: side.win.connectServer("")
            }

        }

    }

}
