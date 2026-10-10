import "../luciddocks"
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs

// one icon on the desktop: a picture or a preview, its name under it, and the
// handling for a click, a double click, a right click and a drag. Under the
// pointer it tilts toward it like a card in the hand, a light sliding over it;
// a folder held under the pointer fans out what it holds; a file that has
// just arrived drops into place
Item {
    id: tile

    // one icon per name for as long as the name is on the desktop: the
    // folder changing around it never rebuilds it or moves it to another
    required property string key

    readonly property var modelData: DesktopIcons.byKey[tile.key] || DesktopIcons.emptyItem
    readonly property var spot: DesktopIcons.placed[tile.key] || null
    readonly property bool selected: DesktopIcons.selected[tile.key] === true
    readonly property bool hovered: tileArea.containsMouse
    // a drag is taking this one along: it waits, faded, where it was
    readonly property bool lifted: DesktopIcons.dragKey !== "" && DesktopIcons.dragKeys.indexOf(tile.key) >= 0
    readonly property bool dropTarget: DesktopIcons.dropInto === tile.key
    readonly property int px: DesktopIcons.iconPx
    // pictures show themselves: a cached thumbnail, or the image file itself
    readonly property bool isImage: tile.modelData.mime.indexOf("image/") === 0 && tile.modelData.size < 60000000
    readonly property string preview: {
        if (!Prefs.desktopIconsThumbs)
            return "";

        if (tile.modelData.thumb !== "")
            return "file://" + tile.modelData.thumb;

        return tile.isImage ? tile.modelData.uri : "";
    }
    readonly property string themeIcon: tile.iconFor(tile.modelData)
    property bool appeared: false

    // objects | shapes | glass | classic
    readonly property string look: Prefs.desktopIconStyle
    readonly property string kind: tile.modelData.kind
    readonly property bool isFolder: tile.kind === "dir" || tile.kind === "home"
    readonly property bool hasThumb: thumb.status === Image.Ready
    readonly property bool objects: tile.look === "objects"
    // a picture as a print on paper, set down askew
    readonly property bool framed: tile.look === "shapes" || tile.objects
    // the object look draws folders, pages and the bin itself; an app keeps
    // its own icon, bare, the way it was designed to be seen
    readonly property bool drawn: tile.objects && !tile.hasThumb && tile.kind !== "app"
    // what a drawn page carries: lines for text, and everything else that is
    // not a picture
    readonly property string pageKind: {
        var m = tile.modelData.mime;
        if (m.indexOf("audio/") === 0)
            return "audio";

        if (m.indexOf("video/") === 0)
            return "video";

        if (/zip|tar|rar|7z|compressed|archive|bzip|gzip|x-xz|zstd/.test(m))
            return "archive";

        return "text";
    }
    // the object look's card, the widgets' own material, under the pointer,
    // selected, or about to take a drop
    readonly property bool carded: tile.objects && (tile.hovered || tile.selected || tile.dropTarget)
    // a name kept for the pointer comes out in a wave from the icon under it
    readonly property bool nameWanted: !DesktopIcons.namesOnHover || tile.hovered || tile.selected || tile.fanning || DesktopIcons.namesOut
    property bool nameOut: false
    property int trashSeen: 0
    // the shell's colours on the icon: never on a picture, never on an app's
    // own icon, which is how people find it
    readonly property bool tinted: !tile.hasThumb && tile.kind !== "app" && (Prefs.desktopIconTint === "all" || (Prefs.desktopIconTint === "folders" && tile.isFolder))
    // each kind wears a palette role: folders the accent, apps the secondary,
    // files and the trash a quiet surface with a breath of the accent. Never
    // the tertiary: on most wallpapers it is the one colour that looks foreign
    readonly property color role: tile.isFolder ? Theme.cPrimary : (tile.kind === "app" ? Theme.cSecondary : Theme.withSat(Theme.cPrimary, 0.45))
    readonly property color container: tile.isFolder ? Theme.accentContainer : (tile.kind === "app" ? Theme.secondaryContainer : Qt.tint(Theme.bgHigh, Theme.alpha(Theme.accent, 0.12)))
    readonly property color onContainer: tile.isFolder ? Theme.fgAccentContainer : (tile.kind === "app" ? Theme.fgSecondaryContainer : Theme.text)
    // squares that follow the shell's corners, or the expressive shapes
    readonly property bool squares: Prefs.desktopIconShape !== "expressive"
    // the print's border: a pale paper in the wallpaper's own hue
    readonly property color paper: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.5), Theme.isLight ? 95 : 88)
    // a saturated tone of the role: colourising keeps the icon's own light and
    // shade, so a mid tone gives a dark icon its colour without going muddy
    readonly property color tintColor: Theme.atTone(tile.role, Theme.isLight ? 45 : 72)
    // a shape per kind from the shell's own vocabulary: the cookie for
    // folders, the calendar's rounded pentagon for apps, a scallop for the
    // trash, a squircle for files. turn is how far it twists under the pointer
    readonly property var shapeSpec: {
        if (tile.isFolder)
            return {
                "form": "lobed",
                "lobes": 4,
                "depth": 0.16,
                "round": 0,
                "spin": 45,
                "turn": 45
            };

        if (tile.kind === "app")
            return {
                "form": "polygon",
                "lobes": 5,
                "depth": 0,
                "round": 0.32,
                "spin": 0,
                "turn": 36
            };

        if (tile.kind === "trash")
            return {
                "form": "lobed",
                "lobes": 12,
                "depth": 0.08,
                "round": 0,
                "spin": 0,
                "turn": 15
            };

        return {
            "form": "squircle",
            "lobes": 0,
            "depth": 0,
            "round": 0,
            "spin": 0,
            "turn": 8
        };
    }

    // the pointer over the icon, -1..1 from its middle, for the tilt
    property real ptrX: 0
    property real ptrY: 0
    readonly property bool tilting: tile.hovered && !tileArea.pressed && tile.look !== "classic" && !tile.lifted
    readonly property real tiltMax: 20

    // the fan a folder opens under the pointer, or under a drag about to drop
    // into it: what it holds, read when it is asked for
    property bool held: false
    readonly property bool fanning: tile.isFolder && (tile.held || tile.dropTarget) && tile.peekCount > 0
    property var peekItems: []
    property int peekCount: -1

    // dropping in after an arrival
    property real landY: 0

    function openIt() {
        if (!DesktopIcons.isSelected(tile.key))
            DesktopIcons.selectOnly(tile.key);

        DesktopIcons.openSelection();
    }

    function iconFor(entry) {
        void IconTheme.generation;
        var names = entry.icons || [];
        for (var i = 0; i < names.length; i++) {
            var p = IconTheme.resolve(names[i]);
            if (p !== "")
                return p;

        }
        return IconTheme.resolve(entry.kind === "dir" ? "folder" : "text-x-generic");
    }

    function maybeLand() {
        if (DesktopIcons.arrivals[tile.key])
            landing.restart();

    }

    width: DesktopIcons.tileW
    height: DesktopIcons.tileH
    visible: tile.spot !== null
    x: tile.spot ? DesktopIcons.tileX(tile.spot.c) : 0
    y: tile.spot ? DesktopIcons.tileY(tile.spot.r) : 0
    // a selected name may run past the cell, over the one below, and a fan
    // over the one above
    z: tile.fanning ? 3 : (tile.selected ? 2 : (tile.hovered ? 1 : 0))
    opacity: tile.appeared ? (tile.lifted ? 0.45 : 1) : 0
    Component.onCompleted: {
        tile.trashSeen = DesktopIcons.trashCount;
        tile.nameOut = tile.nameWanted;
        appearTimer.start();
        tile.maybeLand();
    }
    onNameWantedChanged: {
        if (!tile.nameWanted) {
            nameWave.stop();
            tile.nameOut = false;
            return ;
        }
        var from = DesktopIcons.namesFrom;
        var d = tile.spot && !tile.hovered ? Math.sqrt(Math.pow(tile.spot.c - from.c, 2) + Math.pow(tile.spot.r - from.r, 2)) : 0;
        nameWave.interval = Math.max(1, Math.round(d * 45));
        nameWave.restart();
    }
    // an icon that goes (deleted, renamed) while under the pointer lets go of it
    Component.onDestruction: {
        if (DesktopIcons.hoverKey === tile.key)
            DesktopIcons.hoverKey = "";
    }
    onHoveredChanged: {
        if (tile.hovered)
            DesktopIcons.hoverKey = tile.key;
        else if (DesktopIcons.hoverKey === tile.key)
            DesktopIcons.hoverKey = "";
        if (tile.hovered && tile.isFolder) {
            holdTimer.restart();
        } else {
            holdTimer.stop();
            tile.held = false;
        }
        if (!tile.hovered) {
            tile.ptrX = 0;
            tile.ptrY = 0;
        }
    }
    onDropTargetChanged: {
        if (tile.dropTarget && tile.isFolder && tile.peekCount < 0)
            peekProc.ask();

    }

    Timer {
        id: appearTimer

        interval: 20
        onTriggered: tile.appeared = true
    }

    Timer {
        id: nameWave

        onTriggered: tile.nameOut = tile.nameWanted
    }

    Timer {
        id: holdTimer

        interval: 420
        onTriggered: {
            tile.held = true;
            peekProc.ask();
        }
    }

    Process {
        id: peekProc

        function ask() {
            if (peekProc.running || tile.modelData.path === "")
                return ;

            peekProc.command = ["python3", DesktopIcons.script, "peek", tile.modelData.path];
            peekProc.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text);
                    tile.peekItems = d.items;
                    tile.peekCount = d.count;
                } catch (e) {
                    tile.peekCount = 0;
                }
            }
        }
    }

    Connections {
        function onArrivalsChanged() {
            tile.maybeLand();
        }

        function onLaunchTickChanged() {
            if (DesktopIcons.launched === tile.key)
                bounce.restart();

        }

        // something went in the bin: its lid gulps
        function onTrashCountChanged() {
            if (tile.kind === "trash" && DesktopIcons.trashCount > tile.trashSeen)
                object.swallow();

            tile.trashSeen = DesktopIcons.trashCount;
        }

        target: DesktopIcons
    }

    // stepping aside for a widget, and back, slides rather than jumps
    Behavior on x {
        enabled: tile.appeared

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }

    }

    Behavior on y {
        enabled: tile.appeared

        NumberAnimation {
            duration: Theme.durMedium
            easing.type: Easing.OutBack
            easing.overshoot: 1.1
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durShort
        }

    }

    // glass: every icon on a frosted card of its own, the widgets' material;
    // objects: that same card, only under the pointer or when selected;
    // classic: a highlight that only shows under the pointer or when selected
    Rectangle {
        id: plate

        readonly property bool glass: tile.look === "glass"

        x: Theme.dp(4)
        y: Theme.dp(2)
        width: parent.width - Theme.dp(8)
        height: Math.max(parent.height - Theme.dp(4), nameBox.y + nameBox.height + (tile.objects ? Theme.dp(8) : Theme.dp(6)) - y)
        radius: tile.objects ? Theme.radiusLg : (plate.glass ? Theme.radiusMd : Theme.radiusSm)
        color: {
            if (tile.objects)
                return tile.dropTarget ? Qt.tint(Theme.bg, Theme.alpha(Theme.accent, 0.3)) : Theme.bg;

            if (tile.dropTarget)
                return Theme.alpha(Theme.accent, 0.38);

            if (plate.glass)
                return tile.selected ? Qt.tint(Theme.bg, Theme.alpha(Theme.accent, 0.28)) : Theme.bg;

            return tile.selected ? Theme.alpha(Theme.accent, 0.22) : "#ffffff";
        }
        opacity: {
            if (tile.objects)
                return tile.carded && !tile.lifted ? 1 : 0;

            if (plate.glass || tile.selected || tile.dropTarget)
                return 1;

            return tileArea.pressed ? 0.16 : (tile.hovered ? 0.1 : 0);
        }
        // it settles in rather than blinking on
        scale: tile.objects && !tile.carded ? 0.94 : 1
        visible: (tile.look !== "shapes" || tile.dropTarget) && plate.opacity > 0.01
        border.width: tile.objects ? (tile.selected || tile.dropTarget ? 2 : 1) : (plate.glass ? (tile.selected ? 2 : 1) : ((tile.selected || tile.dropTarget) ? 1 : 0))
        border.color: {
            if (tile.objects)
                return (tile.selected || tile.dropTarget) ? Theme.accent : Theme.alpha(Theme.text, 0.08);

            return plate.glass ? (tile.selected ? Theme.accent : (tile.hovered ? Theme.alpha(Theme.accent, 0.5) : Theme.alpha(Theme.text, 0.1))) : Theme.alpha(Theme.accent, 0.7);
        }
        onHeightChanged: DesktopIcons.noteCard(tile.key, plate.height)

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durQuick
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durShort
                easing.type: Easing.OutBack
            }

        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.durShort
            }

        }

    }

    // the icon and what goes with it, tipped toward the pointer as one: a
    // folder's back, what it holds fanning out of it, and its front
    Item {
        id: body

        width: tile.px
        height: tile.px
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dp(8)
        transform: [
            Translate {
                y: tile.landY
            },
            Rotation {
                origin.x: body.width / 2
                origin.y: body.height / 2
                // close up, so the turn reads as a card tipping toward you
                // rather than one squashing flat
                distanceToPlane: tile.px * 3
                axis.x: 1
                axis.y: 0
                axis.z: 0
                angle: tile.tilting ? -tile.ptrY * tile.tiltMax : 0

                Behavior on angle {
                    SpringAnimation {
                        spring: 3.5
                        damping: 0.28
                    }

                }

            },
            Rotation {
                origin.x: body.width / 2
                origin.y: body.height / 2
                // close up, so the turn reads as a card tipping toward you
                // rather than one squashing flat
                distanceToPlane: tile.px * 3
                axis.x: 0
                axis.y: 1
                axis.z: 0
                angle: tile.tilting ? tile.ptrX * tile.tiltMax : 0

                Behavior on angle {
                    SpringAnimation {
                        spring: 3.5
                        damping: 0.28
                    }

                }

            }
        ]

        // the object look's folder: its back and the sheet in it, behind the fan
        DeskObject {
            visible: tile.drawn && tile.isFolder
            kind: tile.kind === "home" ? "home" : "folder"
            part: "back"
            size: tile.px
            open: object.open
            lifted: object.lifted
        }

        // what a folder holds, fanned out from behind it: three cards that rise
        // and spread, and how many there are in all
        Item {
            id: fan

            width: tile.px
            height: tile.px

            Repeater {
                model: Math.min(3, tile.peekItems.length)

                Rectangle {
                    id: card

                    required property int index

                    readonly property var entry: tile.peekItems[card.index] || ({})
                    readonly property int n: Math.min(3, tile.peekItems.length)
                    // spread evenly either side of upright
                    readonly property real at: card.n === 1 ? 0 : (card.index / (card.n - 1)) * 2 - 1
                    readonly property string pic: card.entry.thumb ? "file://" + card.entry.thumb : ((card.entry.mime || "").indexOf("image/") === 0 && card.entry.size < 30000000 ? card.entry.uri : "")

                    width: Math.round(tile.px * 0.62)
                    height: width
                    x: Math.round((fan.width - width) / 2)
                    y: Math.round((fan.height - height) / 2)
                    radius: Theme.rad(8)
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.alpha(Theme.text, 0.12)
                    antialiasing: true
                    transformOrigin: Item.Bottom
                    opacity: tile.fanning ? 1 : 0
                    rotation: tile.fanning ? card.at * 22 : 0

                    Image {
                        anchors.fill: parent
                        anchors.margins: card.pic !== "" ? Theme.dp(3) : Math.round(parent.width * 0.16)
                        source: card.pic !== "" ? card.pic : tile.iconFor(card.entry)
                        sourceSize.width: width
                        sourceSize.height: height
                        fillMode: card.pic !== "" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        antialiasing: true
                        // among drawn objects the theme's own colours would
                        // look borrowed: its folders and pages take the palette
                        layer.enabled: tile.objects && card.pic === "" && card.entry.kind !== "app"
                        layer.effect: MultiEffect {
                            colorization: 0.9
                            colorizationColor: tile.tintColor
                            brightness: 0.35
                            contrast: 0.15
                        }
                    }

                    transform: Translate {
                        x: tile.fanning ? card.at * tile.px * 0.34 : 0
                        y: tile.fanning ? -tile.px * (0.58 - Math.abs(card.at) * 0.12) : 0

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.durMedium + card.index * 40
                                easing.type: Easing.OutBack
                            }

                        }

                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.durMedium + card.index * 40
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.6
                            }

                        }

                    }

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Theme.durMedium + card.index * 40
                            easing.type: Easing.OutBack
                        }

                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

            }

        }

        Item {
            id: art

            width: tile.px
            height: tile.px
            transformOrigin: Item.Bottom

            // or one of the expressive shapes, which deepens and turns under the
            // pointer and lifts off its shadow
            // a square with the shell's own corners, which round out a little
            // more under the pointer, as if it took a breath
            Rectangle {
                id: square

                readonly property real rest: Theme.rad(Math.round(tile.px * 0.3))

                anchors.fill: parent
                anchors.margins: Math.round(tile.px * 0.04)
                visible: tile.look === "shapes" && tile.squares && !tile.hasThumb
                radius: Math.min(width / 2, (tile.hovered || tile.dropTarget) ? square.rest * 1.35 + Theme.rad(4) : square.rest)
                color: (tile.selected || tile.dropTarget) ? Theme.accent : tile.container
                antialiasing: true
                scale: tile.hovered ? 1.06 : 1
                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.7
                    shadowColor: Qt.rgba(0, 0, 0, tile.hovered ? 0.5 : 0.3)
                    shadowHorizontalOffset: -tile.ptrX * 4
                    shadowVerticalOffset: tile.hovered ? Theme.dp(6) - tile.ptrY * 3 : Theme.dp(2)
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.2
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            IconShape {
                id: shape

                anchors.fill: parent
                visible: tile.look === "shapes" && !tile.squares && !tile.hasThumb
                form: tile.shapeSpec.form
                lobes: tile.shapeSpec.lobes
                depth: tile.shapeSpec.depth * (tile.hovered || tile.dropTarget ? 1.8 : 1)
                round: tile.shapeSpec.round * (tile.hovered || tile.dropTarget ? 1.4 : 1)
                spin: tile.shapeSpec.spin + (tile.hovered || tile.dropTarget ? tile.shapeSpec.turn : 0)
                fill: (tile.selected || tile.dropTarget) ? Theme.accent : tile.container
                scale: tile.hovered ? 1.06 : 1
                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.7
                    shadowColor: Qt.rgba(0, 0, 0, tile.hovered ? 0.55 : 0.35)
                    shadowHorizontalOffset: -tile.ptrX * 4
                    shadowVerticalOffset: tile.hovered ? Theme.dp(6) - tile.ptrY * 3 : Theme.dp(2)
                }

                Behavior on depth {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutBack
                        easing.overshoot: 2
                    }

                }

                Behavior on round {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on spin {
                    NumberAnimation {
                        duration: Theme.durMedium * 1.4
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on fill {
                    ColorAnimation {
                        duration: Theme.durShort
                    }

                }

            }

            // the object look: a folder's front flap, a page, the bin
            DeskObject {
                id: object

                visible: tile.drawn
                kind: tile.isFolder ? (tile.kind === "home" ? "home" : "folder") : (tile.kind === "trash" ? "trash" : "document")
                part: "front"
                size: tile.px
                open: tile.dropTarget ? 1 : (tile.fanning ? 0.8 : (tile.hovered ? 0.4 : 0))
                lifted: tile.hovered || tile.dropTarget
                full: tile.kind === "trash" && DesktopIcons.trashCount > 0
                tag: DesktopIcons.typeTag(tile.modelData)
                variant: tile.pageKind

                Behavior on open {
                    SpringAnimation {
                        spring: 4
                        damping: 0.32
                    }

                }

            }

            // a theme with nothing for it still gets a shape, never a blank
            DockGlyph {
                anchors.centerIn: parent
                width: themed.width * 0.84
                height: width
                visible: tile.themeIcon === "" && !tile.hasThumb && !tile.drawn
                pathData: tile.isFolder ? (tile.kind === "home" ? DesktopIcons.glyphs.home : DesktopIcons.glyphs.folder) : (tile.kind === "trash" ? DesktopIcons.glyphs.trash : DesktopIcons.glyphs.file)
                glyphColor: tile.look === "shapes" ? tile.onContainer : (tile.look === "glass" ? Theme.text : "#ffffff")
                opacity: 0.9
            }

            Image {
                id: themed

                readonly property real side: tile.look === "shapes" ? Math.round(tile.px * 0.62) : (tile.objects ? Math.round(tile.px * 0.9) : tile.px)

                anchors.centerIn: parent
                width: themed.side
                height: themed.side
                visible: !tile.hasThumb && tile.themeIcon !== "" && !tile.drawn
                source: tile.themeIcon
                // rendered at the size it is shown: an svg drawn large and then
                // shrunk (mipmapped, too) comes out soft
                sourceSize.width: themed.side
                sourceSize.height: themed.side
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                // the shell's colours on the icon, its light and shade kept
                layer.enabled: tile.tinted
                layer.effect: MultiEffect {
                    colorization: 0.9
                    colorizationColor: tile.tintColor
                    brightness: 0.35
                    contrast: 0.15
                }
            }

            // a picture: a print with a border of pale paper in the wallpaper's
            // hue, set down slightly askew,
            // that straightens up under the pointer (shapes); a plain preview with
            // a hairline edge otherwise, so a white picture still reads
            Item {
                id: photo

                readonly property bool framed: tile.framed
                readonly property real tilt: {
                    var h = 0;
                    for (var i = 0; i < tile.key.length; i++)
                        h = (h * 31 + tile.key.charCodeAt(i)) % 997;
                    return (h % 9) - 4;
                }
                readonly property real pad: photo.framed ? 3 : 0

                anchors.centerIn: parent
                anchors.verticalCenterOffset: photo.framed ? -Theme.dp(2) : 0
                width: thumb.paintedWidth + 2 * photo.pad
                height: thumb.paintedHeight + 2 * photo.pad + (photo.framed ? Theme.dp(5) : 0)
                visible: tile.hasThumb
                rotation: photo.framed && !tile.hovered && !tile.selected ? photo.tilt : 0
                scale: photo.framed && tile.hovered ? 1.08 : 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: photo.framed ? 0 : -1
                    radius: photo.framed ? 2 : 4
                    antialiasing: true
                    color: photo.framed ? (tile.selected ? Theme.accent : tile.paper) : "transparent"
                    border.width: photo.framed ? 0 : (tile.selected ? 2 : 1)
                    border.color: tile.selected ? Theme.accent : Qt.rgba(0, 0, 0, 0.25)
                }

                Behavior on rotation {
                    NumberAnimation {
                        duration: Theme.durMedium
                        easing.type: Easing.OutBack
                    }

                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durShort
                        easing.type: Easing.OutBack
                    }

                }

            }

            Image {
                id: thumb

                x: Math.round((art.width - thumb.width) / 2)
                y: Math.round((art.height - thumb.height) / 2 - (photo.framed ? 4.5 : 0))
                width: (photo.framed ? Math.round(tile.px * 1.24) : art.width) - (photo.framed ? Theme.dp(8) : 0)
                height: art.height - (photo.framed ? Theme.dp(13) : 0)
                source: tile.preview
                // the decoder scales the picture down well; the GPU then only
                // turns it, with smoothed edges so the tilt has no jaggies
                sourceSize.width: thumb.width
                sourceSize.height: thumb.height
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                smooth: true
                antialiasing: true
                rotation: photo.rotation
                scale: photo.scale
            }

            // how many a folder holds, while its fan is out
            Rectangle {
                visible: tile.fanning
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -Theme.dp(6)
                anchors.topMargin: -Theme.dp(2)
                width: Math.max(height, countText.implicitWidth + Theme.dp(10))
                height: Theme.dp(18)
                radius: Theme.pill(18)
                color: Theme.accent
                z: 5

                Text {
                    id: countText

                    anchors.centerIn: parent
                    text: tile.peekCount > 999 ? "999+" : String(tile.peekCount)
                    color: Theme.fgAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLabelSm
                    font.weight: Font.Bold
                }

            }

            // a symbolic link wears a small arrow, the way file managers mark one
            Rectangle {
                visible: tile.modelData.link
                width: Math.round(tile.px * 0.38)
                height: width
                radius: width / 2
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                color: Theme.bg

                DockGlyph {
                    anchors.centerIn: parent
                    width: parent.width - Theme.dp(4)
                    height: width
                    pathData: DesktopIcons.glyphs.link
                    glyphColor: Theme.text
                }

            }

            // a launcher that is not allowed to run yet
            Rectangle {
                visible: tile.kind === "app" && !tile.modelData.exec
                width: Math.round(tile.px * 0.38)
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: Theme.bg

                DockGlyph {
                    anchors.centerIn: parent
                    width: parent.width - Theme.dp(4)
                    height: width
                    pathData: DesktopIcons.glyphs.shield
                    glyphColor: Theme.accent
                }

            }

            // opening squashes it a touch and lets it spring back: the click landed
            SequentialAnimation {
                id: bounce

                NumberAnimation {
                    target: art
                    property: "scale"
                    to: 0.84
                    duration: 90
                    easing.type: Easing.OutQuad
                }

                NumberAnimation {
                    target: art
                    property: "scale"
                    to: 1
                    duration: 380
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }

            }

        }

    }

    // an arrival: a ring of the accent spreading out where it lands
    Rectangle {
        id: ripple

        width: tile.px
        height: tile.px
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dp(8)
        color: "transparent"
        border.width: 3
        border.color: Theme.accent
        opacity: 0
        scale: 0.4
    }

    SequentialAnimation {
        id: landing

        PropertyAction {
            target: tile
            property: "landY"
            value: -tile.px * 0.9
        }

        PropertyAction {
            target: ripple
            property: "opacity"
            value: 0
        }

        NumberAnimation {
            target: tile
            property: "landY"
            to: 0
            duration: 620
            easing.type: Easing.OutBounce
        }

        ParallelAnimation {
            NumberAnimation {
                target: ripple
                property: "scale"
                from: 0.6
                to: 2.1
                duration: 700
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: ripple
                property: "opacity"
                from: 0.85
                to: 0
                duration: 700
                easing.type: Easing.OutCubic
            }

        }

    }

    Item {
        id: nameBox

        // at rest one line, the extension left off when the icon already
        // says the kind; under the pointer or selected, the whole name
        readonly property bool full: tile.hovered || tile.selected
        readonly property int lines: tile.selected ? 5 : 3
        readonly property bool narrow: tile.px <= 32
        // on a card the name takes the card's colour
        readonly property bool onCard: tile.look === "glass" || tile.carded
        // selected in the other looks, the name sits on the accent
        readonly property bool chip: tile.selected && !nameBox.onCard
        // on the bare wallpaper it reads what is under it: dark ink on a
        // light sky, white with a shade elsewhere
        readonly property real under: tile.spot ? DesktopIcons.lumaAt(DesktopIcons.tileX(tile.spot.c) + nameBox.x, DesktopIcons.tileY(tile.spot.r) + nameBox.y, nameBox.width, Math.max(16, label.height)) : -1
        readonly property bool onLight: !nameBox.onCard && !nameBox.chip && nameBox.under > 66

        anchors.horizontalCenter: parent.horizontalCenter
        y: body.y + body.height + (tile.objects ? Theme.dp(7) : Theme.dp(6))
        width: parent.width - Theme.dp(12)
        height: label.height
        visible: DesktopIcons.renaming !== tile.key && nameBox.opacity > 0.01
        opacity: tile.nameOut ? 1 : 0
        transform: Translate {
            y: tile.nameOut ? 0 : -Theme.dp(5)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.durShort
                    easing.type: Easing.OutCubic
                }

            }

        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durShort
            }

        }

        Rectangle {
            anchors.centerIn: label
            width: Math.min(nameBox.width + Theme.dp(6), label.contentWidth + Theme.dp(12))
            height: label.contentHeight + Theme.dp(4)
            radius: Math.min(Theme.radiusXs, height / 2)
            color: Theme.accent
            visible: nameBox.chip
        }

        Text {
            id: label

            width: parent.width
            text: nameBox.full ? tile.modelData.label : DesktopIcons.shortLabel(tile.modelData)
            color: {
                if (nameBox.chip)
                    return Theme.fgAccent;

                if (nameBox.onCard)
                    return Theme.text;

                return nameBox.onLight ? Theme.atTone(Theme.withSat(Theme.cPrimary, 0.35), 12) : "#ffffff";
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            // a long name keeps its start and its end, which is where names
            // differ (a date, a number, a version)
            // (small icons have narrow cells: two lines there)
            wrapMode: nameBox.full || nameBox.narrow ? Text.Wrap : Text.NoWrap
            maximumLineCount: nameBox.full ? nameBox.lines : (nameBox.narrow ? 2 : 1)
            elide: nameBox.full || nameBox.narrow ? Text.ElideRight : Text.ElideMiddle
            // on the wallpaper, a soft halo in the opposite tone instead of a
            // box: the name still looks set on the desktop itself
            layer.enabled: !nameBox.onCard && !nameBox.chip
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: nameBox.onLight ? 0.45 : 0.55
                shadowColor: nameBox.onLight ? Qt.rgba(1, 1, 1, 0.75) : Qt.rgba(0, 0, 0, nameBox.under >= 0 && nameBox.under < 40 ? 0.7 : 0.95)
                shadowHorizontalOffset: 0
                shadowVerticalOffset: nameBox.onLight ? 0 : 1
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durShort
                }

            }

        }

    }

    // what rides under the pointer in a drag: the picture alone
    Item {
        id: proxy

        width: tile.px
        height: tile.px
        Drag.active: tileArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: tile.px / 2
        Drag.hotSpot.y: tile.px / 2
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

        // a press on an icon already in the selection keeps the selection (it
        // may be the start of a drag); a release without a drag narrows it
        property bool narrow: false

        x: Theme.dp(4)
        y: Theme.dp(2)
        width: parent.width - Theme.dp(8)
        height: parent.height - Theme.dp(4)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        drag.target: proxy
        drag.threshold: 8
        onPositionChanged: (m) => {
            var cx = body.x + body.width / 2 - tileArea.x;
            var cy = body.y + body.height / 2 - tileArea.y;
            tile.ptrX = Math.max(-1, Math.min(1, (m.x - cx) / (tileArea.width / 2)));
            tile.ptrY = Math.max(-1, Math.min(1, (m.y - cy) / (tileArea.height / 2)));
        }
        onPressed: (m) => {
            tile.forceActiveFocus();
            tileArea.narrow = false;
            if (m.button === Qt.RightButton) {
                if (!tile.selected)
                    DesktopIcons.selectOnly(tile.key);

                var p = tileArea.mapToItem(null, m.x, m.y);
                DesktopIcons.openMenu(DesktopIcons.selectedKeys, p.x, p.y);
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
            body.grabToImage((r) => {
                proxy.Drag.imageSource = r.url;
            });
            proxy.Drag.mimeData = DesktopIcons.dragData();
        }
        onReleased: (m) => {
            if (m.button === Qt.LeftButton && tileArea.narrow && !tileArea.drag.active)
                DesktopIcons.selectOnly(tile.key);

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
