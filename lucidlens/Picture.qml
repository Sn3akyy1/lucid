import QtQuick
import qs

// one picture as lens draws it: the file turned, straightened, adjusted, drawn on
// and cropped. its own coordinates are the picture's pixels, so a scale above it
// zooms it, and a grab of it is the edited picture at full size
Item {
    id: pic

    property url source
    property bool animated: false
    property bool vector: false
    // a neighbour waiting its turn decodes no bigger than `limit`
    property bool full: true
    property size limit: Qt.size(2560, 1600)
    // {turns, flipH, flipV, angle, crop: {x, y, w, h} of the frame, adjust: {...}, marks: [...]}
    property var edits: null
    // the crop tool's view: the whole frame, the crop not applied
    property bool showFrame: false
    // the edits left out while compare is held
    property bool original: false
    property var draft: null
    property bool playing: true
    // laid over the still and turned with it: a video's player, loaded from its
    // file by url (so its imports load with the first one), given overlayProps,
    // made again only when the url or the key changes
    property url overlay: ""
    property string overlayKey: ""
    property var overlayProps: ({})
    readonly property Item overlayItem: over.item
    readonly property Item image: pic.animated ? (anim.item || null) : still
    readonly property int status: pic.image ? pic.image.status : Image.Null
    readonly property bool ready: pic.status === Image.Ready
    readonly property real natW: pic.image ? pic.image.implicitWidth : 0
    readonly property real natH: pic.image ? pic.image.implicitHeight : 0
    readonly property var used: pic.original ? null : pic.edits
    readonly property int turns: pic.used ? pic.used.turns || 0 : 0
    readonly property bool flipH: pic.used ? pic.used.flipH === true : false
    readonly property bool flipV: pic.used ? pic.used.flipV === true : false
    readonly property real angle: pic.used ? pic.used.angle || 0 : 0
    readonly property real frameW: pic.turns % 2 ? pic.natH : pic.natW
    readonly property real frameH: pic.turns % 2 ? pic.natW : pic.natH
    readonly property var crop: pic.used && pic.used.crop ? pic.used.crop : null
    readonly property rect cut: !pic.crop || pic.showFrame ? Qt.rect(0, 0, pic.frameW, pic.frameH) : Qt.rect(pic.crop.x * pic.frameW, pic.crop.y * pic.frameH, pic.crop.w * pic.frameW, pic.crop.h * pic.frameH)
    // straightened, it is scaled up until no corner of the frame is left empty
    readonly property real cover: {
        var a = Math.abs(pic.angle) * Math.PI / 180;
        if (a < 0.00001 || pic.frameW <= 0 || pic.frameH <= 0)
            return 1;

        var c = Math.cos(a), s = Math.sin(a);
        return Math.max((pic.frameW * c + pic.frameH * s) / pic.frameW, (pic.frameW * s + pic.frameH * c) / pic.frameH);
    }
    readonly property var adjust: pic.used && pic.used.adjust ? pic.used.adjust : ({})
    readonly property bool adjusting: {
        var a = pic.adjust;
        for (var k in a) {
            if (k !== "vignette" && a[k])
                return true;

        }
        return false;
    }
    readonly property var marks: pic.used && pic.used.marks ? pic.used.marks : []
    // the picture's own pixels, untransformed: where a pointer lands on it
    readonly property alias body: body
    readonly property alias frameItem: frame

    function adj(key) {
        return (pic.adjust[key] || 0) / 100;
    }

    function loadOverlay() {
        if (pic.overlay.toString() === "")
            over.source = "";
        else
            over.setSource(pic.overlay, pic.overlayProps);
    }

    onOverlayChanged: Qt.callLater(pic.loadOverlay)
    onOverlayKeyChanged: Qt.callLater(pic.loadOverlay)

    implicitWidth: pic.cut.width
    implicitHeight: pic.cut.height
    width: implicitWidth
    height: implicitHeight
    clip: pic.used !== null

    Item {
        id: frame

        x: -pic.cut.x
        y: -pic.cut.y
        width: pic.frameW
        height: pic.frameH

        Item {
            id: body

            x: (pic.frameW - pic.natW) / 2
            y: (pic.frameH - pic.natH) / 2
            width: pic.natW
            height: pic.natH
            // turned first, then mirrored as it now lies, then straightened
            transform: [
                Rotation {
                    origin.x: body.width / 2
                    origin.y: body.height / 2
                    angle: pic.turns * 90
                },
                Scale {
                    origin.x: body.width / 2
                    origin.y: body.height / 2
                    xScale: pic.flipH ? -1 : 1
                    yScale: pic.flipV ? -1 : 1
                },
                Rotation {
                    origin.x: body.width / 2
                    origin.y: body.height / 2
                    angle: pic.angle
                },
                Scale {
                    origin.x: body.width / 2
                    origin.y: body.height / 2
                    xScale: pic.cover
                    yScale: pic.cover
                }
            ]

            Image {
                id: still

                anchors.fill: parent
                visible: !pic.animated && !pic.adjusting
                source: pic.animated ? "" : pic.source
                asynchronous: true
                autoTransform: true
                retainWhileLoading: true
                cache: false
                smooth: true
                mipmap: !pic.vector
                sourceSize: pic.vector ? Qt.size(2048, 2048) : (pic.full ? undefined : pic.limit)
            }

            Loader {
                id: anim

                anchors.fill: parent
                active: pic.animated
                visible: !pic.adjusting

                sourceComponent: AnimatedImage {
                    source: pic.source
                    autoTransform: true
                    cache: false
                    smooth: true
                    playing: pic.playing
                }

            }

            Loader {
                id: over

                anchors.fill: parent
            }

            ShaderEffect {
                id: fx

                anchors.fill: parent
                visible: pic.adjusting && pic.ready
                property variant source: pic.image
                property real exposure: pic.adj("exposure")
                property real contrast: pic.adj("contrast")
                property real highlights: pic.adj("highlights")
                property real shadows: pic.adj("shadows")
                property real saturation: pic.adj("saturation")
                property real vibrance: pic.adj("vibrance")
                property real warmth: pic.adj("warmth")
                property real tint: pic.adj("tint")
                property real fade: pic.adj("fade")
                property real mono: pic.adj("mono")

                fragmentShader: Qt.resolvedUrl("shaders/adjust.frag.qsb")
            }

            // marks are kept in the full picture's pixels; a neighbour decoded
            // smaller draws them scaled to match
            MarkLayer {
                id: markLayer

                readonly property real unit: pic.used && pic.used.natW > 0 ? body.width / pic.used.natW : 1

                width: body.width / markLayer.unit
                height: body.height / markLayer.unit
                scale: markLayer.unit
                transformOrigin: Item.TopLeft
                marks: pic.marks
                draft: pic.draft
                // what the boxes pixelate: always the one drawn, adjusted or not
                under: pic.adjusting ? fx : pic.image
                longSide: Math.max(pic.natW, pic.natH)
            }

        }

    }

    ShaderEffect {
        anchors.fill: parent
        visible: !pic.showFrame && pic.adj("vignette") !== 0
        property real amount: pic.adj("vignette")

        fragmentShader: Qt.resolvedUrl("shaders/vignette.frag.qsb")
    }

}
