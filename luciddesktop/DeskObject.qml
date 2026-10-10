import "../luciddocks"
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs

// the things on the desk, drawn rather than taken from the icon theme so they
// share one hand with the prints: a folder with its tab and a sheet inside, a
// page with a folded corner and its type on a tab, and a bin with a lid. A
// folder comes in two parts - its back, and the front flap - so what it holds
// can fan out between them
Item {
    id: obj

    // "folder", "home", "document" or "trash"
    property string kind: "folder"
    // "back" or "front"; a page and the bin are all front
    property string part: "front"
    // the side of the square it is drawn in
    property real size: Theme.dp(64)
    // 0 shut, 1 open: the folder's flap, the bin's lid
    property real open: 0
    // something under the pointer lifts a little off its shadow
    property bool lifted: false
    // the bin with something in it
    property bool full: false
    // a page's type, as a word on its tab, and what is on the page: lines of
    // "text", a zip down an "archive", a note for "audio", a screen for "video"
    property string tag: ""
    property string variant: "text"

    readonly property real s: obj.size
    // the shell's corner dial, kept within what reads at icon size
    readonly property real k: Math.max(0.15, Math.min(1.6, Theme.cornerScale))
    readonly property real r: Math.max(1.5, obj.s * 0.075 * obj.k)
    readonly property bool isFolder: obj.kind === "folder" || obj.kind === "home"

    // the palette: a folder in the wallpaper's own colour, paper pale in its
    // hue, and the bin a quiet grey with a breath of it. Never the tertiary
    readonly property color folderFront: Theme.atTone(Theme.cPrimary, Theme.isLight ? 70 : 74)
    readonly property color folderFrontLow: Theme.atTone(Theme.cPrimary, Theme.isLight ? 64 : 67)
    readonly property color folderBack: Theme.atTone(Theme.cPrimary, Theme.isLight ? 52 : 56)
    readonly property color folderInk: Theme.atTone(Theme.cPrimary, Theme.isLight ? 34 : 30)
    readonly property color paper: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.5), Theme.isLight ? 96 : 92)
    readonly property color paperFold: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.5), Theme.isLight ? 84 : 80)
    readonly property color ink: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.4), 30)
    readonly property color binBody: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.3), Theme.isLight ? 78 : 72)
    readonly property color binLid: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.3), Theme.isLight ? 86 : 82)
    readonly property color binRib: Theme.atTone(Theme.withSat(Theme.cPrimary, 0.3), Theme.isLight ? 62 : 56)

    // a gulp: something just went in the bin
    property real gulp: 0
    readonly property real lid: Math.max(obj.open, obj.gulp, obj.full ? 0.28 : 0)

    function swallow() {
        gulpAnim.restart();
    }

    width: obj.s
    height: obj.s
    layer.enabled: true
    layer.smooth: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.6
        shadowColor: Qt.rgba(0, 0, 0, obj.lifted ? 0.42 : 0.3)
        shadowHorizontalOffset: 0
        shadowVerticalOffset: obj.lifted ? Theme.dp(4) : 1.5
    }

    SequentialAnimation {
        id: gulpAnim

        NumberAnimation {
            target: obj
            property: "gulp"
            to: 1
            duration: 140
            easing.type: Easing.OutQuad
        }

        PauseAnimation {
            duration: 120
        }

        NumberAnimation {
            target: obj
            property: "gulp"
            to: 0
            duration: 420
            easing.type: Easing.OutBounce
        }

    }

    // ---- a folder: the back with its tab, and a sheet standing in it ------

    Shape {
        id: back

        readonly property real x0: obj.s * 0.06
        readonly property real x1: obj.s * 0.94
        readonly property real yTab: obj.s * 0.12
        readonly property real yTop: obj.s * 0.2
        readonly property real yBot: obj.s * 0.88
        readonly property real tabEnd: obj.s * 0.4
        readonly property real slant: obj.s * 0.08
        readonly property real rt: Math.min(obj.r, (back.yTop - back.yTab) * 0.9)

        anchors.fill: parent
        visible: obj.isFolder && obj.part === "back"
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: obj.folderBack
            strokeColor: "transparent"
            pathHints: ShapePath.PathFillOnRight | ShapePath.PathSolid | ShapePath.PathNonIntersecting

            PathSvg {
                path: {
                    var b = back;
                    var r = obj.r;
                    var t = b.rt;
                    return "M " + b.x0 + " " + (b.yTab + t) + " Q " + b.x0 + " " + b.yTab + " " + (b.x0 + t) + " " + b.yTab + " L " + (b.tabEnd - t * 0.6) + " " + b.yTab + " Q " + b.tabEnd + " " + b.yTab + " " + (b.tabEnd + t * 0.5) + " " + (b.yTab + t * 0.6) + " L " + (b.tabEnd + b.slant - t * 0.5) + " " + (b.yTop - t * 0.6) + " Q " + (b.tabEnd + b.slant) + " " + b.yTop + " " + (b.tabEnd + b.slant + t) + " " + b.yTop + " L " + (b.x1 - r) + " " + b.yTop + " Q " + b.x1 + " " + b.yTop + " " + b.x1 + " " + (b.yTop + r) + " L " + b.x1 + " " + (b.yBot - r) + " Q " + b.x1 + " " + b.yBot + " " + (b.x1 - r) + " " + b.yBot + " L " + (b.x0 + r) + " " + b.yBot + " Q " + b.x0 + " " + b.yBot + " " + b.x0 + " " + (b.yBot - r) + " Z";
                }
            }

        }

        // the sheet inside, which rises as the flap opens
        Rectangle {
            x: obj.s * 0.15
            y: obj.s * (0.26 - 0.1 * obj.open)
            width: obj.s * 0.7
            height: obj.s * 0.5
            radius: Math.max(1, obj.r * 0.5)
            color: obj.paper
            antialiasing: true

            Rectangle {
                x: parent.width * 0.14
                y: parent.height * 0.18
                width: parent.width * 0.5
                height: Math.max(1.5, obj.s * 0.03)
                radius: height / 2
                color: Theme.alpha(obj.ink, 0.22)
            }

        }

    }

    // the front flap, which tips open toward you from its bottom edge
    Rectangle {
        id: flap

        x: obj.s * 0.06
        y: obj.s * 0.34
        width: obj.s * 0.88
        height: obj.s * 0.54
        visible: obj.isFolder && obj.part === "front"
        radius: obj.r
        antialiasing: true
        transform: Rotation {
            origin.x: flap.width / 2
            origin.y: flap.height
            axis.x: 1
            axis.y: 0
            axis.z: 0
            distanceToPlane: obj.s * 3
            angle: -obj.open * 26
        }

        gradient: Gradient {
            GradientStop {
                position: 0
                color: obj.folderFront
            }

            GradientStop {
                position: 1
                color: obj.folderFrontLow
            }

        }

        // a lit top edge, the way a fold catches the light
        Rectangle {
            x: flap.radius * 0.6
            y: 1
            width: parent.width - flap.radius * 1.2
            height: Math.max(1, obj.s * 0.018)
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.35)
        }

        DockGlyph {
            visible: obj.kind === "home"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: obj.s * 0.01
            width: parent.height * 0.6
            height: width
            pathData: DesktopIcons.glyphs.home
            glyphColor: obj.folderInk
        }

    }

    // ---- a page ------------------------------------------------------------

    Item {
        id: page

        readonly property real w: obj.s * 0.68
        readonly property real h: obj.s * 0.86
        readonly property real px0: (obj.s - page.w) / 2
        readonly property real py0: obj.s * 0.06
        readonly property real ear: page.w * 0.28

        anchors.fill: parent
        visible: obj.kind === "document"

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // a hairline edge, so a white page still reads on a white sky
            ShapePath {
                fillColor: obj.paper
                strokeColor: Theme.alpha(obj.ink, 0.16)
                strokeWidth: 1
                pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting

                PathSvg {
                    path: {
                        var x = page.px0;
                        var y = page.py0;
                        var w = page.w;
                        var h = page.h;
                        var e = page.ear;
                        var r = Math.min(obj.r * 0.7, e * 0.5);
                        return "M " + (x + r) + " " + y + " L " + (x + w - e) + " " + y + " L " + (x + w) + " " + (y + e) + " L " + (x + w) + " " + (y + h - r) + " Q " + (x + w) + " " + (y + h) + " " + (x + w - r) + " " + (y + h) + " L " + (x + r) + " " + (y + h) + " Q " + x + " " + (y + h) + " " + x + " " + (y + h - r) + " L " + x + " " + (y + r) + " Q " + x + " " + y + " " + (x + r) + " " + y + " Z";
                    }
                }

            }

            // the folded corner
            ShapePath {
                fillColor: obj.paperFold
                strokeColor: "transparent"

                PathSvg {
                    path: {
                        var x = page.px0 + page.w - page.ear;
                        var y = page.py0;
                        var e = page.ear;
                        var r = Math.min(obj.r * 0.6, e * 0.35);
                        return "M " + x + " " + y + " L " + x + " " + (y + e - r) + " Q " + x + " " + (y + e) + " " + (x + r) + " " + (y + e) + " L " + (x + e) + " " + (y + e) + " Z";
                    }
                }

            }

        }

        // lines of text: a heading in the accent, then the body
        Repeater {
            model: page.visible && obj.variant === "text" ? 5 : 0

            Rectangle {
                required property int index

                x: page.px0 + page.w * 0.16
                y: page.py0 + page.h * (0.34 + index * 0.11) + (index > 0 ? page.h * 0.03 : 0)
                width: page.w * (index === 0 ? 0.4 : (index === 4 ? 0.38 : 0.68))
                height: Math.max(1.5, obj.s * (index === 0 ? 0.05 : 0.032))
                radius: height / 2
                color: index === 0 ? Theme.alpha(Theme.cPrimary, 0.7) : Theme.alpha(obj.ink, 0.2)
            }

        }

        // an archive: a zip down the middle of the page, and its pull
        Item {
            id: zip

            readonly property real tooth: Math.max(1.5, obj.s * 0.035)

            visible: obj.variant === "archive"
            x: page.px0 + page.w / 2
            y: page.py0

            Repeater {
                model: zip.visible ? Math.floor(page.h * 0.5 / zip.tooth) : 0

                Rectangle {
                    required property int index

                    x: index % 2 === 0 ? -zip.tooth * 1.6 : 0
                    y: index * zip.tooth
                    width: zip.tooth * 1.6
                    height: zip.tooth * 0.8
                    radius: height / 2
                    color: Theme.alpha(obj.ink, 0.42)
                }

            }

            Rectangle {
                x: -width / 2
                y: page.h * 0.5
                width: obj.s * 0.12
                height: obj.s * 0.17
                radius: Math.min(width / 2, Math.max(1.5, obj.r * 0.5))
                color: Theme.accent
                antialiasing: true

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.5
                    width: parent.width * 0.4
                    height: parent.height * 0.3
                    radius: width / 2
                    color: obj.paper
                }

            }

        }

        // audio: a note; video: a screen with a play mark on it
        Rectangle {
            visible: obj.variant === "video"
            x: page.px0 + page.w * 0.16
            y: page.py0 + page.h * 0.3
            width: page.w * 0.68
            height: width * 0.66
            radius: Math.max(1.5, obj.r * 0.6)
            color: Theme.accent
            antialiasing: true

            DockGlyph {
                anchors.centerIn: parent
                width: parent.height * 0.7
                height: width
                pathData: DesktopIcons.glyphs.play
                glyphColor: Theme.fgAccent
            }

        }

        DockGlyph {
            visible: obj.variant === "audio"
            x: page.px0 + (page.w - width) / 2
            y: page.py0 + page.h * 0.24
            width: page.w * 0.66
            height: width
            pathData: "M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6Z"
            glyphColor: Theme.accent
        }

        // its type, on a tab that sticks out past the left edge
        Rectangle {
            visible: obj.tag !== "" && obj.s >= 40
            x: page.px0 - obj.s * 0.08
            y: page.py0 + page.h - height - obj.s * 0.1
            width: Math.max(height * 1.4, tagText.implicitWidth + obj.s * 0.12)
            height: Math.round(obj.s * 0.2)
            radius: Math.min(height / 2, Math.max(2, obj.r * 0.6))
            color: Theme.accent
            antialiasing: true

            Text {
                id: tagText

                anchors.centerIn: parent
                text: obj.tag
                color: Theme.fgAccent
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(7, Math.round(obj.s * 0.13))
                font.weight: Font.Bold
                font.letterSpacing: 0.3
            }

        }

    }

    // ---- the bin -----------------------------------------------------------

    Item {
        id: bin

        anchors.fill: parent
        visible: obj.kind === "trash"

        // what was thrown away, sticking up out of it
        Repeater {
            model: obj.full ? 2 : 0

            Rectangle {
                required property int index

                x: obj.s * (index === 0 ? 0.3 : 0.46)
                y: obj.s * (index === 0 ? 0.2 : 0.23) - obj.lid * obj.s * 0.03
                width: obj.s * 0.24
                height: obj.s * 0.3
                radius: Math.max(1, obj.r * 0.4)
                rotation: index === 0 ? -14 : 10
                color: obj.paper
                antialiasing: true

                Rectangle {
                    x: parent.width * 0.18
                    y: parent.height * 0.22
                    width: parent.width * 0.6
                    height: Math.max(1.5, obj.s * 0.03)
                    radius: height / 2
                    color: Theme.alpha(obj.ink, 0.25)
                }

            }

        }

        Shape {
            id: can

            readonly property real yTop: obj.s * 0.33
            readonly property real yBot: obj.s * 0.93
            readonly property real top0: obj.s * 0.21
            readonly property real top1: obj.s * 0.79
            readonly property real bot0: obj.s * 0.28
            readonly property real bot1: obj.s * 0.72

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transformOrigin: Item.Bottom
            scale: 1 + obj.gulp * 0.04

            ShapePath {
                fillColor: obj.binBody
                strokeColor: "transparent"
                pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting

                PathSvg {
                    path: {
                        var r = obj.r * 0.9;
                        var c = can;
                        return "M " + c.top0 + " " + c.yTop + " L " + c.top1 + " " + c.yTop + " L " + (c.bot1 + r * 0.12) + " " + (c.yBot - r) + " Q " + c.bot1 + " " + c.yBot + " " + (c.bot1 - r) + " " + c.yBot + " L " + (c.bot0 + r) + " " + c.yBot + " Q " + c.bot0 + " " + c.yBot + " " + (c.bot0 - r * 0.12) + " " + (c.yBot - r) + " Z";
                    }
                }

            }

            // three ribs down its side
            ShapePath {
                strokeColor: obj.binRib
                strokeWidth: Math.max(1.5, obj.s * 0.04)
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"

                PathMove {
                    x: obj.s * 0.37
                    y: obj.s * 0.44
                }

                PathLine {
                    x: obj.s * 0.39
                    y: obj.s * 0.82
                }

                PathMove {
                    x: obj.s * 0.5
                    y: obj.s * 0.44
                }

                PathLine {
                    x: obj.s * 0.5
                    y: obj.s * 0.82
                }

                PathMove {
                    x: obj.s * 0.63
                    y: obj.s * 0.44
                }

                PathLine {
                    x: obj.s * 0.61
                    y: obj.s * 0.82
                }

            }

        }

        // the lid and its handle, hinged at the left end
        Item {
            id: lidItem

            x: obj.s * 0.15
            y: obj.s * 0.21
            width: obj.s * 0.7
            height: obj.s * 0.1
            transform: [
                Rotation {
                    origin.x: 0
                    origin.y: lidItem.height
                    angle: -obj.lid * 22
                },
                Translate {
                    y: -obj.lid * obj.s * 0.07
                }
            ]

            Rectangle {
                x: parent.width * 0.33
                y: -obj.s * 0.07
                width: parent.width * 0.34
                height: obj.s * 0.11
                radius: Math.min(height / 2, obj.r * 0.8)
                color: "transparent"
                border.width: Math.max(1.5, obj.s * 0.04)
                border.color: obj.binLid
                antialiasing: true
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.min(height / 2, obj.r * 0.8)
                color: obj.binLid
                antialiasing: true
            }

        }

    }

}
