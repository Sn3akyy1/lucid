import QtQuick
import QtQuick.Effects
import qs
import qs.lucidicons
import qs.lucidui

// one icon on the desktop: the icon theme's picture or a thumbnail in a tonal well,
// its name under it, and the click, double click, right click and drag on it.
// material you states: the well lights under the pointer and takes the primary
// container when selected, the name becomes a pill, and a keyboard focus ring
Item {
    id: tile

    // one delegate per name for as long as it is on the desktop, so the folder
    // changing around it never rebuilds it
    required property string key
    // the name left the folder: it flies off (into the trash, a folder) or fades
    required property bool gone
    // the board, to be told when it has finished leaving
    property var host: null

    // what it was last, so a leaving icon still draws itself
    property var held: DesktopIcons.blank({})
    property var heldSpot: null
    readonly property var modelData: DesktopIcons.byKey[tile.key] || tile.held
    readonly property var spot: DesktopIcons.placed[tile.key] || tile.heldSpot
    readonly property string kind: tile.modelData.kind
    readonly property bool selected: DesktopIcons.selected[tile.key] === true
    readonly property bool hovered: tileArea.containsMouse && !tile.gone
    readonly property bool pressed: tileArea.pressed && (tileArea.pressedButtons & Qt.LeftButton) !== 0
    // a drag is taking this one along: it waits, faded, where it was
    readonly property bool lifted: DesktopIcons.dragKey !== "" && DesktopIcons.dragKeys.indexOf(tile.key) >= 0
    readonly property bool dropTarget: DesktopIcons.dropInto === tile.key
    readonly property bool isFolder: tile.kind === "dir" || tile.kind === "home"
    readonly property bool cut: DesktopIcons.cutKeys[tile.key] === true
    readonly property bool editing: DesktopIcons.renaming === tile.key
    readonly property bool ring: DesktopIcons.focusVisible && DesktopIcons.cursorKey === tile.key && DesktopIcons.hasKeys
    readonly property int px: DesktopIcons.iconPx
    readonly property real wellPad: DesktopIcons.wellPad
    readonly property real wellSize: DesktopIcons.wellSize
    // a folder about to take a drop opens, the way the theme draws it; home keeps its house
    readonly property string iconPath: {
        var p = tile.modelData.icon;
        if (tile.dropTarget && tile.kind === "dir" && DesktopIcons.specials.folderDrop)
            p = DesktopIcons.specials.folderDrop;

        return p ? "file://" + p : "";
    }
    readonly property string lucidSlot: tile.slotOf(tile.modelData)
    // a thumbnail a file manager or we made, or a picture small enough to show itself
    readonly property string preview: {
        if (!Prefs.desktopIconsThumbs || tile.kind !== "file")
            return "";

        if (tile.modelData.thumb !== "")
            return "file://" + tile.modelData.thumb;

        var m = tile.modelData.mime;
        if (!tile.modelData.canThumb && m.indexOf("image/") === 0 && m !== "image/svg+xml" && tile.modelData.size < 40000000)
            return tile.modelData.uri;

        return "";
    }
    readonly property bool hasThumb: thumb.status === Image.Ready
    // whether the wallpaper under the name is light, for its ink and the well
    readonly property real under: tile.spot ? DesktopIcons.lumaAt(tile.x + nameBox.x, tile.y + nameBox.y, nameBox.width, Math.max(Theme.dp(16), label.height)) : -1
    readonly property bool onLight: tile.under > 66
    // selection reads in the palette while the desktop has the keys, grey once a window does
    readonly property bool active: DesktopIcons.hasKeys || tile.editing
    readonly property color neutral: tile.onLight ? "#000000" : "#ffffff"
    property bool appeared: false
    // where it flies when it goes, relative to where it is
    property real flyX: 0
    property real flyY: 0
    // the animations' own scales, on top of the hover and press ones bound below
    property real pop: 1
    property real gulpK: 1

    // lucid's own icon for an item, unless legacy icons are on: the folder or file kind
    // the helper named, home's own folder, a full or an empty trash, a drive, and a
    // launcher's app tile. "" draws the icon theme's picture as before
    function slotOf(m) {
        if (Prefs.envLegacyIcons || !m)
            return "";

        if (m.kind === "home")
            return "folder-home";

        if (m.kind === "trash")
            return DesktopIcons.trashCount > 0 ? "trash-full" : "trash";

        // a share on another computer is no disk here
        if (m.kind === "drive")
            return /^(smb|sftp|ftps?|ftpis|davs?|nfs|afp):/.test(m.uri || "") ? "network" : m.canEject ? "drive-usb" : "drive";

        if (m.kind === "app")
            return LucidIcons.appSlot(m.appId, m.wmClass, m.iconName, m.label, m.cats);

        return m.slot || (m.kind === "dir" ? "folder" : "");
    }

    function openIt() {
        if (!DesktopIcons.isSelected(tile.key))
            DesktopIcons.selectOnly(tile.key);

        DesktopIcons.openSelection();
    }

    width: DesktopIcons.tileW
    height: DesktopIcons.tileH
    visible: tile.spot !== null
    x: tile.spot ? DesktopIcons.tileX(tile.spot.c) : 0
    y: tile.spot ? DesktopIcons.tileY(tile.spot.r) : 0
    // a selected name may run on over the cell below, a rename over its neighbours
    z: tile.editing ? 3 : (tile.selected ? 2 : (tile.hovered ? 1 : 0))
    opacity: tile.appeared ? (tile.lifted ? 0.4 : 1) : 0
    Component.onCompleted: {
        tile.held = DesktopIcons.byKey[tile.key] || tile.held;
        tile.heldSpot = DesktopIcons.placed[tile.key] || null;
        if (DesktopIcons.waking)
            tile.wakeUp();
        else
            appearTimer.start();
        if (DesktopIcons.arrivals[tile.key])
            arrive.restart();

    }
    Component.onDestruction: {
        if (DesktopIcons.hoverKey === tile.key)
            DesktopIcons.hoverKey = "";

    }
    onModelDataChanged: {
        if (DesktopIcons.byKey[tile.key])
            tile.held = DesktopIcons.byKey[tile.key];

    }
    onSpotChanged: {
        if (DesktopIcons.placed[tile.key])
            tile.heldSpot = DesktopIcons.placed[tile.key];

    }
    onHoveredChanged: {
        if (tile.hovered)
            DesktopIcons.hoverKey = tile.key;
        else if (DesktopIcons.hoverKey === tile.key)
            DesktopIcons.hoverKey = "";
    }
    onGoneChanged: {
        if (!tile.gone) {
            leave.stop();
            tile.flyX = 0;
            tile.flyY = 0;
            tile.pop = 1;
            tile.opacity = Qt.binding(() => {
                return tile.appeared ? (tile.lifted ? 0.4 : 1) : 0;
            });
            return ;
        }
        var t = DesktopIcons.flyTo[tile.key];
        flyXAnim.to = t ? t.x - (tile.x + tile.width / 2) : 0;
        flyYAnim.to = t ? t.y - (tile.y + body.y + body.height / 2) : 0;
        shrink.to = t ? 0.25 : 0.7;
        leave.duration = t ? 420 : 220;
        leave.restart();
    }

    // the icons turned on and off from the menu: a wave from the corner they fill from
    function wakeUp() {
        stow.stop();
        if (!tile.appeared)
            tile.pop = 0.6;

        wake.delay = DesktopIcons.waveDelay(tile.spot, DesktopIcons.wakeStep);
        wake.restart();
    }

    Connections {
        function onLiveChanged() {
            if (tile.gone)
                return ;

            if (DesktopIcons.live) {
                tile.wakeUp();
            } else {
                wake.stop();
                stow.delay = DesktopIcons.waveDelay(tile.spot, DesktopIcons.stowStep);
                stow.restart();
            }
        }

        target: DesktopIcons
    }

    SequentialAnimation {
        id: wake

        property int delay: 0

        PauseAnimation {
            duration: wake.delay
        }

        ScriptAction {
            script: tile.appeared = true
        }

        NumberAnimation {
            target: tile
            property: "pop"
            to: 1
            duration: Theme.durEnter
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
        }

    }

    SequentialAnimation {
        id: stow

        property int delay: 0

        PauseAnimation {
            duration: stow.delay
        }

        ScriptAction {
            script: tile.appeared = false
        }

        NumberAnimation {
            target: tile
            property: "pop"
            to: 0.6
            duration: Theme.durShort
            easing.type: Easing.InCubic
        }

    }

    Timer {
        id: appearTimer

        interval: 16
        onTriggered: tile.appeared = true
    }

    Connections {
        function onArrivalsChanged() {
            if (DesktopIcons.arrivals[tile.key])
                arrive.restart();

        }

        function onLaunchTickChanged() {
            if (DesktopIcons.launched === tile.key)
                launch.restart();

        }

        function onReceiveTickChanged() {
            if (DesktopIcons.received === tile.key)
                gulp.restart();

        }

        target: DesktopIcons
    }

    transform: Translate {
        x: tile.flyX
        y: tile.flyY
    }

    // stepping aside for a widget, and back, glides on m3's spatial spring
    Behavior on x {
        enabled: tile.appeared && !tile.gone

        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    Behavior on y {
        enabled: tile.appeared && !tile.gone

        NumberAnimation {
            duration: Theme.durDefaultSpatial
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Theme.curveDefaultSpatial
        }

    }

    Behavior on opacity {
        enabled: !tile.gone

        NumberAnimation {
            duration: Theme.durShort
        }

    }

    // going: into the trash or a folder when there is one to fly to, otherwise a fade
    ParallelAnimation {
        id: leave

        property int duration: 220

        onFinished: {
            if (tile.host)
                Qt.callLater(tile.host.dispose, tile.key);

        }

        NumberAnimation {
            id: flyXAnim

            target: tile
            property: "flyX"
            duration: leave.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        NumberAnimation {
            id: flyYAnim

            target: tile
            property: "flyY"
            duration: leave.duration
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.easeEmphasizedAccel
        }

        NumberAnimation {
            id: shrink

            target: tile
            property: "pop"
            duration: leave.duration
            easing.type: Easing.InCubic
        }

        NumberAnimation {
            target: tile
            property: "opacity"
            to: 0
            duration: leave.duration
            easing.type: Easing.InCubic
        }

    }

    // the well: a rounded square of the palette behind the picture
    Rectangle {
        id: well

        readonly property real fill: {
            if (tile.dropTarget)
                return 0.42;

            if (tile.selected && tile.active)
                return 0.86;

            if (tile.selected)
                return 0.24 + (tile.hovered ? 0.06 : 0);

            if (tile.pressed)
                return 0.2;

            return tile.hovered ? 0.13 : 0;
        }
        readonly property bool tonal: (tile.selected && tile.active) || tile.dropTarget

        x: Math.round((tile.width - width) / 2)
        y: DesktopIcons.wellTop
        width: tile.wellSize
        height: tile.wellSize
        radius: Math.round(tile.wellSize * (tile.hovered || tile.selected || tile.dropTarget ? 0.32 : 0.26))
        color: tile.dropTarget ? Theme.alpha(Theme.accent, well.fill) : (well.tonal ? Theme.alpha(Theme.accentContainer, well.fill) : Theme.alpha(tile.neutral, well.fill))
        border.width: tile.dropTarget ? 2 : 0
        border.color: Theme.accent
        scale: (tile.dropTarget ? 1.08 : 1) * tile.gulpK
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on scale {
            enabled: !gulp.running

            NumberAnimation {
                duration: Theme.durMedium
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }

        }

    }

    // keyboard focus: m3's ring, a little outside the well
    Rectangle {
        x: well.x - Theme.dp(3)
        y: well.y - Theme.dp(3)
        width: well.width + Theme.dp(6)
        height: well.height + Theme.dp(6)
        radius: well.radius + Theme.dp(3)
        color: "transparent"
        border.width: Theme.dp(2)
        border.color: Theme.accent
        opacity: tile.ring ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

    }

    Item {
        id: body

        width: tile.px
        height: tile.px
        x: Math.round((tile.width - tile.px) / 2)
        y: well.y + tile.wellPad
        transformOrigin: Item.Center
        scale: (tile.pressed && !tileArea.drag.active ? 0.9 : (tile.hovered || tile.dropTarget ? 1.06 : 1)) * tile.pop
        // hidden files sit back a little, and so does whatever is cut
        opacity: tile.cut ? 0.45 : (tile.modelData.hidden ? 0.55 : 1)

        Behavior on scale {
            enabled: !tile.gone && !arrive.running && !launch.running && !wake.running && !stow.running

            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.easeEmphasizedDecel
            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Loader {
            anchors.fill: parent
            active: !tile.hasThumb && tile.lucidSlot !== ""

            sourceComponent: TonalIcon {
                size: tile.px
                slot: tile.lucidSlot
                hovered: tile.hovered || tile.dropTarget
                // the tile swells under the pointer: drawn that large then
                scaleHint: tile.hovered || tile.dropTarget ? 1.1 : 1
            }

        }

        Image {
            id: themed

            anchors.fill: parent
            visible: !tile.hasThumb && tile.iconPath !== "" && tile.lucidSlot === ""
            source: tile.iconPath
            // drawn at the size it is shown: an svg rendered large and shrunk comes out soft
            sourceSize.width: Math.round(tile.px * DesktopIcons.dpr)
            sourceSize.height: Math.round(tile.px * DesktopIcons.dpr)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }

        // a theme with nothing for it still gets a picture
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.round(tile.px * 0.08)
            visible: !tile.hasThumb && tile.lucidSlot === "" && (tile.iconPath === "" || themed.status === Image.Error)
            radius: Theme.rad(Math.round(tile.px * 0.24))
            color: tile.isFolder ? Theme.accentContainer : Theme.surfaceHighest

            Icon {
                anchors.centerIn: parent
                size: Math.round(tile.px * 0.5)
                name: tile.isFolder ? (tile.kind === "home" ? "home" : "folder") : (tile.kind === "trash" ? "delete" : (tile.kind === "drive" ? "hard_drive" : (tile.kind === "app" ? "apps" : "description")))
                color: tile.isFolder ? Theme.fgAccentContainer : Theme.text
                fill: 1
            }

        }

        // a thumbnail on a thin mat with a shadow, like a print laid on the desk
        Item {
            id: photo

            readonly property real pw: Math.round(thumb.paintedWidth)
            readonly property real ph: Math.round(thumb.paintedHeight)

            visible: tile.hasThumb
            x: Math.round((body.width - photo.pw) / 2) - Theme.dp(2)
            y: Math.round((body.height - photo.ph) / 2) - Theme.dp(2)
            width: photo.pw + Theme.dp(4)
            height: photo.ph + Theme.dp(4)
            layer.enabled: photo.visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.45
                shadowColor: Qt.rgba(0, 0, 0, 0.45)
                shadowVerticalOffset: Theme.dp(1)
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.dp(4)
                color: "#f4f4f4"
            }

        }

        Image {
            id: thumb

            x: photo.x + Theme.dp(2)
            y: photo.y + Theme.dp(2)
            width: tile.px - Theme.dp(4)
            height: tile.px - Theme.dp(4)
            visible: tile.hasThumb
            source: tile.preview
            sourceSize.width: Math.round(width * DesktopIcons.dpr)
            sourceSize.height: Math.round(height * DesktopIcons.dpr)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            // painted size, not the box, so the mat hugs the picture
            horizontalAlignment: Image.AlignLeft
            verticalAlignment: Image.AlignTop
        }

        // a symbolic link and a launcher nobody has allowed yet wear a badge
        Repeater {
            model: [tile.modelData.link ? "link" : "", tile.kind === "app" && !tile.modelData.exec ? "lock" : ""]

            Rectangle {
                required property string modelData
                required property int index

                visible: modelData !== ""
                width: Math.round(Math.max(Theme.dp(16), tile.px * 0.36))
                height: width
                radius: width / 2
                x: index === 0 ? -Theme.dp(3) : body.width - width + Theme.dp(3)
                y: body.height - height + Theme.dp(3)
                color: index === 0 ? Theme.surfaceHighest : Theme.accentContainer
                border.width: 1
                border.color: Theme.alpha(Theme.text, 0.12)

                Icon {
                    anchors.centerIn: parent
                    size: Math.round(parent.width * 0.62)
                    name: parent.modelData
                    color: parent.index === 0 ? Theme.text : Theme.fgAccentContainer
                    fill: 1
                }

            }

        }

        // a new arrival grows in
        SequentialAnimation {
            id: arrive

            PropertyAction {
                target: tile
                property: "pop"
                value: 0.3
            }

            NumberAnimation {
                target: tile
                property: "pop"
                to: 1
                duration: Theme.durEnter + 100
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }

        }

        // opening presses it in and lets it spring back: the click landed
        SequentialAnimation {
            id: launch

            NumberAnimation {
                target: tile
                property: "pop"
                to: 0.84
                duration: 90
                easing.type: Easing.OutQuad
            }

            NumberAnimation {
                target: tile
                property: "pop"
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }

        }

    }

    // a folder that just took a drop gulps
    SequentialAnimation {
        id: gulp

        NumberAnimation {
            target: tile
            property: "gulpK"
            to: 1.16
            duration: 120
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            target: tile
            property: "gulpK"
            to: 1
            duration: 420
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

    }

    // colour tags, a little cluster on the well's corner
    Row {
        x: well.x - Theme.dp(2)
        y: well.y - Theme.dp(2)
        spacing: -Theme.dp(4)
        visible: tile.modelData.tags.length > 0

        Repeater {
            model: tile.modelData.tags.slice(0, 3)

            Rectangle {
                required property string modelData

                width: Theme.dp(12)
                height: width
                radius: width / 2
                color: DesktopIcons.tagColor(modelData)
                border.width: Theme.dp(2)
                border.color: Theme.isLight ? "#ffffff" : Theme.alpha("#000000", 0.55)
            }

        }

    }

    // a folder held under a drag counts down before it springs open in the file manager
    CircularProgress {
        id: spring

        readonly property bool on: DesktopIcons.springKey === tile.key

        x: well.x + well.width - width / 2 - Theme.dp(4)
        y: well.y - height / 2 + Theme.dp(4)
        width: Theme.dp(22)
        height: Theme.dp(22)
        thickness: Theme.dp(3)
        wavy: false
        animated: false
        color: Theme.accent
        trackColor: Theme.alpha(Theme.accent, 0.25)
        visible: spring.on
        value: 0
        onOnChanged: {
            springRun.stop();
            spring.value = 0;
            if (spring.on)
                springRun.start();

        }

        NumberAnimation {
            id: springRun

            target: spring
            property: "value"
            from: 0
            to: 1
            duration: 1100
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.dp(2)
            z: -1
            radius: width / 2
            color: Theme.bg
        }

    }

    Item {
        id: nameBox

        // at rest two lines; selected, the whole name
        readonly property bool full: tile.selected
        readonly property bool pill: tile.selected

        x: Theme.dp(3)
        y: DesktopIcons.labelTop
        width: parent.width - Theme.dp(6)
        height: label.height
        visible: !tile.editing

        // selected, the name sits on a pill: the primary while the desktop has the keys
        Rectangle {
            anchors.centerIn: label
            width: Math.min(nameBox.width + Theme.dp(4), label.contentWidth + Theme.dp(14))
            height: label.contentHeight + Theme.dp(4)
            radius: label.lineCount > 1 ? Theme.radiusSm : height / 2
            color: tile.active ? Theme.accent : Theme.alpha(Theme.surfaceHighest, 0.92)
            opacity: nameBox.pill ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                }

            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

        Text {
            id: label

            width: parent.width
            text: nameBox.full || tile.hovered ? tile.modelData.label : DesktopIcons.shortLabel(tile.modelData)
            color: nameBox.pill ? (tile.active ? Theme.fgAccent : Theme.text) : (tile.onLight ? Theme.atTone(Theme.withSat(Theme.cPrimary, 0.3), 10) : "#ffffff")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelLg
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            // one line keeps a long name's start and end, where names differ
            wrapMode: nameBox.full || tile.hovered || DesktopIcons.nameLines > 1 ? Text.Wrap : Text.NoWrap
            maximumLineCount: nameBox.full || tile.hovered ? 6 : DesktopIcons.nameLines
            elide: nameBox.full || tile.hovered || DesktopIcons.nameLines > 1 ? Text.ElideRight : Text.ElideMiddle
            lineHeight: 1.05
            opacity: tile.cut ? 0.6 : 1
            // on the wallpaper, a soft shade in the opposite tone rather than a box
            layer.enabled: !nameBox.pill
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 0.5
                shadowColor: tile.onLight ? Qt.rgba(1, 1, 1, 0.8) : Qt.rgba(0, 0, 0, 0.9)
                shadowVerticalOffset: tile.onLight ? 0 : 1
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    // what rides under the pointer in a drag: a little stack of what goes, and how many.
    // a grab renders only what is visible, and the press grabs it: up off the surface from the hover on
    Item {
        id: dragFace

        readonly property var keys: DesktopIcons.isSelected(tile.key) ? DesktopIcons.selectedKeys : [tile.key]
        readonly property int count: Math.max(1, dragFace.keys.length)
        readonly property var stack: {
            var others = dragFace.keys.filter((k) => {
                return k !== tile.key;
            }).slice(0, 2);
            return others.reverse().concat([tile.key]);
        }

        x: -10000
        width: tile.px + Theme.dp(28)
        height: tile.px + Theme.dp(28)
        visible: tileArea.containsMouse

        // made only under the pointer: a tile at rest carries no second picture
        Repeater {
            model: dragFace.visible ? dragFace.stack : []

            Item {
                id: sheet

                required property string modelData
                required property int index
                readonly property var it: DesktopIcons.byKey[modelData] || null
                readonly property int depth: dragFace.stack.length - 1 - index
                // a thumbnail where the desktop shows one, else lucid's icon as on the tile
                readonly property bool photo: sheet.it !== null && Prefs.desktopIconsThumbs && sheet.it.kind === "file" && sheet.it.thumb !== ""
                readonly property string slot: sheet.photo ? "" : tile.slotOf(sheet.it)

                x: Theme.dp(10) + depth * Theme.dp(4)
                y: Theme.dp(12) - depth * Theme.dp(4)
                width: tile.px
                height: tile.px
                rotation: depth === 0 ? 0 : (depth === 1 ? 7 : -7)
                opacity: depth === 0 ? 1 : 0.85

                Image {
                    anchors.fill: parent
                    visible: sheet.slot === ""
                    source: sheet.it ? (sheet.photo ? "file://" + sheet.it.thumb : (sheet.it.icon ? "file://" + sheet.it.icon : "")) : ""
                    sourceSize.width: tile.px
                    sourceSize.height: tile.px
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Loader {
                    anchors.fill: parent
                    active: sheet.slot !== ""

                    sourceComponent: TonalIcon {
                        size: tile.px
                        slot: sheet.slot
                    }

                }

            }

        }

        Rectangle {
            visible: dragFace.count > 1
            anchors.right: parent.right
            anchors.top: parent.top
            width: Math.max(height, countText.implicitWidth + Theme.dp(10))
            height: Theme.dp(20)
            radius: height / 2
            color: Theme.accent

            Text {
                id: countText

                anchors.centerIn: parent
                text: String(dragFace.count)
                color: Theme.fgAccent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelSm
                font.weight: Font.Bold
            }

        }

    }

    Item {
        id: proxy

        width: tile.px
        height: tile.px
        Drag.active: tileArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: dragFace.width / 2
        Drag.hotSpot.y: dragFace.height / 2
        Drag.onDragStarted: {
            DesktopIcons.dragKeys = DesktopIcons.selectedKeys.slice();
            DesktopIcons.dragKey = tile.key;
        }
        Drag.onDragFinished: (action) => {
            proxy.x = 0;
            proxy.y = 0;
            DesktopIcons.endDrag();
        }
    }

    MouseArea {
        id: tileArea

        // a press on an icon already selected keeps the selection (it may start a drag); a release narrows it
        property bool narrow: false

        x: Theme.dp(4)
        y: Theme.dp(2)
        width: parent.width - Theme.dp(8)
        height: parent.height - Theme.dp(4)
        enabled: !tile.gone
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: proxy
        drag.threshold: Theme.dp(8)
        onPressed: (m) => {
            tile.forceActiveFocus();
            DesktopIcons.arm(false);
            DesktopIcons.tipHold = true;
            DesktopIcons.focusVisible = false;
            tileArea.narrow = false;
            var at = tileArea.mapToItem(null, m.x, m.y);
            if (m.button === Qt.RightButton) {
                if (!tile.selected)
                    DesktopIcons.selectOnly(tile.key);

                DesktopIcons.openMenu(DesktopIcons.selectedKeys, at.x, at.y);
                return ;
            }
            if (m.modifiers & Qt.ControlModifier)
                DesktopIcons.toggle(tile.key);
            else if (m.modifiers & Qt.ShiftModifier)
                DesktopIcons.selectRange(tile.key);
            else if (!tile.selected)
                DesktopIcons.selectOnly(tile.key);
            else
                tileArea.narrow = true;
            // the drag image, ready by the time the pointer has moved far enough
            dragFace.grabToImage((r) => {
                proxy.Drag.imageSource = r.url;
            });
            proxy.Drag.mimeData = DesktopIcons.dragData();
        }
        onReleased: (m) => {
            if (m.button !== Qt.LeftButton || tileArea.drag.active)
                return ;

            if (tileArea.narrow)
                DesktopIcons.selectOnly(tile.key);

            DesktopIcons.arm(true);
        }
        onClicked: (m) => {
            if (m.button === Qt.LeftButton && Prefs.desktopIconsOpen === "single" && !(m.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)))
                tile.openIt();

        }
        onDoubleClicked: (m) => {
            if (m.button === Qt.LeftButton && Prefs.desktopIconsOpen !== "single")
                tile.openIt();

        }
    }

}
