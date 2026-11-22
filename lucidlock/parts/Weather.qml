import QtQuick

// the sky outside: a line beside the day, a compact mark, or a card. the
// login screen gets the last reading the shell took, when it may have one
WidgetBase {
    id: wx

    readonly property var w: wx.lock ? wx.lock.weather : null
    readonly property bool ok: !!wx.w && wx.w.ok === true
    readonly property string style: wx.opts.style || "line"
    readonly property bool details: wx.opts.details !== false
    readonly property bool boxed: wx.style === "card" && !wx.carded
    readonly property string detailText: {
        if (!wx.ok)
            return "";

        var parts = [];
        if (wx.w.hi && wx.w.lo)
            parts.push(wx.lock.tr("H %1  L %2", wx.w.hi, wx.w.lo));

        if (wx.w.feels)
            parts.push(wx.lock.tr("feels %1", wx.w.feels));

        if (wx.w.at)
            parts.push(wx.lock.tr("as of %1", wx.w.at));

        return parts.join("  ·  ");
    }
    readonly property color ink: wx.tonal ? wx.theme.fgAccentContainer : wx.theme.text
    readonly property color dim: wx.tonal ? wx.theme.alpha(wx.theme.fgAccentContainer, 0.75) : wx.theme.subtextDim

    hasContent: wx.ok || wx.editing
    implicitWidth: wx.style === "card" ? card.width : (wx.style === "compact" ? compact.implicitWidth : line.implicitWidth)
    implicitHeight: wx.style === "card" ? card.height : (wx.style === "compact" ? compact.implicitHeight : line.implicitHeight)

    // ── line ────────────────────────────────────────────────────────────────
    Row {
        id: line

        x: wx.xFor(implicitWidth, wx.width)
        visible: wx.style === "line"
        spacing: wx.kp(14)
        layoutDirection: wx.align === Qt.AlignRight ? Qt.RightToLeft : Qt.LeftToRight

        WeatherGlyph {
            anchors.verticalCenter: parent.verticalCenter
            kind: wx.ok ? wx.w.kind : "cloud"
            size: wx.kp(50)
            tint: wx.tonal ? wx.theme.fgAccentContainer : wx.theme.accent
            cloudColor: wx.ink
            motionScale: wx.theme.motionScale
            animate: wx.visible && wx.style === "line"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: wx.ok ? wx.w.temp : "—°"
            color: wx.ink
            font.family: wx.theme.fontFamily
            font.pixelSize: Math.round(wx.theme.fontHeadlineMd * wx.k)
            font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontHeadlineMd * wx.k), 520, 30)
            font.weight: Font.Medium
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: wx.kp(26)
            color: wx.theme.hairline
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: wx.kp(2)

            Text {
                x: wx.align === Qt.AlignRight ? parent.width - width : 0
                text: wx.ok ? wx.w.desc : (!wx.lock ? "" : (wx.greeter ? wx.lock.tr("No reading sent") : wx.lock.tr("Weather unavailable")))
                color: wx.ink
                font.family: wx.theme.fontFamily
                font.pixelSize: Math.round(wx.theme.fontBodyMd * wx.k)
                font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontBodyMd * wx.k), 450, 0)
            }

            Text {
                x: wx.align === Qt.AlignRight ? parent.width - width : 0
                visible: wx.details && wx.detailText !== ""
                text: wx.detailText
                color: wx.dim
                font.family: wx.theme.fontFamily
                font.pixelSize: Math.round(wx.theme.fontLabelMd * wx.k)
                font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontLabelMd * wx.k), 450, 0)
            }

        }

    }

    // ── compact ─────────────────────────────────────────────────────────────
    Row {
        id: compact

        x: wx.xFor(implicitWidth, wx.width)
        visible: wx.style === "compact"
        spacing: wx.kp(8)

        WeatherGlyph {
            anchors.verticalCenter: parent.verticalCenter
            kind: wx.ok ? wx.w.kind : "cloud"
            size: wx.kp(32)
            tint: wx.tonal ? wx.theme.fgAccentContainer : wx.theme.accent
            cloudColor: wx.ink
            motionScale: wx.theme.motionScale
            animate: wx.visible && wx.style === "compact"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: wx.ok ? wx.w.temp : "—°"
            color: wx.ink
            font.family: wx.theme.fontFamily
            font.pixelSize: Math.round(wx.theme.fontTitleLg * wx.k)
            font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontTitleLg * wx.k), 560, 20)
            font.weight: Font.DemiBold
        }

    }

    // ── card ────────────────────────────────────────────────────────────────
    Rectangle {
        id: card

        readonly property real pad: wx.boxed ? wx.kp(20) : 0

        x: wx.xFor(width, wx.width)
        visible: wx.style === "card"
        width: Math.min(wx.avail, Math.max(wx.kp(260), cardRow.implicitWidth + card.pad * 2))
        height: cardCol.implicitHeight + card.pad * 2
        radius: wx.theme.shapeXl
        color: wx.boxed ? (wx.onCard ? wx.theme.cardHigh : wx.theme.card) : "transparent"

        Column {
            id: cardCol

            x: card.pad
            y: card.pad
            width: card.width - card.pad * 2
            spacing: wx.kp(10)

            Row {
                id: cardRow

                spacing: wx.kp(12)

                WeatherGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: wx.ok ? wx.w.kind : "cloud"
                    size: wx.kp(58)
                    tint: wx.tonal ? wx.theme.fgAccentContainer : wx.theme.accent
                    cloudColor: wx.ink
                    motionScale: wx.theme.motionScale
                    animate: wx.visible && wx.style === "card"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wx.ok ? wx.w.temp : "—°"
                    color: wx.ink
                    font.family: wx.theme.fontFamily
                    font.pixelSize: Math.round(wx.theme.fontDisplaySm * wx.k)
                    font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontDisplaySm * wx.k), 500, 60)
                    font.weight: Font.Medium
                }

            }

            Column {
                spacing: wx.kp(2)
                width: parent.width

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: wx.ok ? wx.w.desc : (!wx.lock ? "" : (wx.greeter ? wx.lock.tr("No reading sent") : wx.lock.tr("Weather unavailable")))
                    color: wx.ink
                    font.family: wx.theme.fontFamily
                    font.pixelSize: Math.round(wx.theme.fontTitleSm * wx.k)
                    font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontTitleSm * wx.k), 560, 0)
                    font.weight: Font.DemiBold
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: wx.details && wx.detailText !== ""
                    text: wx.detailText
                    color: wx.dim
                    font.family: wx.theme.fontFamily
                    font.pixelSize: Math.round(wx.theme.fontLabelMd * wx.k)
                    font.variableAxes: wx.theme.axes(Math.round(wx.theme.fontLabelMd * wx.k), 450, 0)
                }

            }

        }

    }

}
