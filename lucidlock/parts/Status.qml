import QtQuick

// the glanceable half of a status bar, for a screen that has no bar. chips is
// one connected group, round at its ends and tight in between; icons is the
// marks alone, the way a phone's lock screen shows them
WidgetBase {
    id: st

    readonly property string style: st.opts.style || "chips"
    // the items the data offers, less the ones switched off in the options
    readonly property var items: {
        var all = st.lock && st.lock.statusItems ? st.lock.statusItems : [];
        return all.filter((it) => {
            return st.opts[it.key] !== false;
        });
    }

    function toneOf(t) {
        switch (t) {
        case "accent":
            return st.tonal ? st.theme.fgAccentContainer : st.theme.accent;
        case "error":
            return st.theme.error;
        case "success":
            return st.theme.success;
        case "warning":
            return st.theme.warning;
        case "dim":
            return st.tonal ? st.theme.alpha(st.theme.fgAccentContainer, 0.7) : st.theme.subtextDim;
        }
        return st.tonal ? st.theme.fgAccentContainer : st.theme.subtext;
    }

    // the chips as one row, every label in full
    readonly property real fullW: {
        var w = 0;
        for (var i = 0; i < st.items.length; i++) w += Math.ceil(labelSize.advanceWidth(st.items[i].label)) + st.kp(9) + st.kp(18) + st.kp(32)
        return w + st.dp(3) * Math.max(0, st.items.length - 1);
    }
    // too long for its slot (a long network name, say): each chip keeps its
    // mark and only the numbers keep their words, rather than the row running
    // past the slot to the edge of whatever it sits on
    readonly property bool squeezed: st.style !== "icons" && st.fullW * 1.03 > st.avail

    hasContent: st.items.length > 0
    implicitWidth: st.style === "icons" ? icons.implicitWidth : chips.implicitWidth
    implicitHeight: st.style === "icons" ? icons.implicitHeight : chips.implicitHeight

    FontMetrics {
        id: labelSize

        font.family: st.theme.fontFamily
        font.pixelSize: Math.round(st.theme.fontLabelLg * st.k)
        font.variableAxes: st.theme.axes(Math.round(st.theme.fontLabelLg * st.k), 520, 0)
        font.weight: Font.Medium
    }

    Row {
        id: chips

        x: st.xFor(implicitWidth, st.width)
        visible: st.style !== "icons"
        spacing: st.dp(3)

        Repeater {
            model: st.style !== "icons" ? st.items : []

            Rectangle {
                id: chip

                required property var modelData
                required property int index
                readonly property bool lead: chip.index === 0
                readonly property bool tail: chip.index === st.items.length - 1
                readonly property string text: st.squeezed ? (chip.modelData.short || "") : chip.modelData.label

                height: st.kp(40)
                width: content.implicitWidth + (chip.text === "" ? st.kp(26) : st.kp(32))
                color: st.carded ? (st.tonal ? st.theme.alpha(st.theme.fgAccentContainer, 0.1) : st.theme.cardHigh) : (st.onCard ? st.theme.cardHigh : st.theme.card)
                topLeftRadius: chip.lead ? height / 2 : st.theme.shapeSm
                bottomLeftRadius: chip.lead ? height / 2 : st.theme.shapeSm
                topRightRadius: chip.tail ? height / 2 : st.theme.shapeSm
                bottomRightRadius: chip.tail ? height / 2 : st.theme.shapeSm

                // a press on the one chip that does something
                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: parent.topLeftRadius
                    bottomLeftRadius: parent.bottomLeftRadius
                    topRightRadius: parent.topRightRadius
                    bottomRightRadius: parent.bottomRightRadius
                    color: st.theme.text
                    opacity: tap.pressed ? st.theme.statePressed : (hover.hovered ? st.theme.stateHover : 0)
                    visible: chip.modelData.interactive === true
                }

                Row {
                    id: content

                    anchors.centerIn: parent
                    spacing: st.kp(9)

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: chip.modelData.glyph
                        size: st.kp(18)
                        color: st.toneOf(chip.modelData.tone)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: chip.text !== ""
                        text: chip.text
                        color: st.tonal ? st.theme.fgAccentContainer : st.theme.text
                        font.family: st.theme.fontFamily
                        font.pixelSize: Math.round(st.theme.fontLabelLg * st.k)
                        font.variableAxes: st.theme.axes(Math.round(st.theme.fontLabelLg * st.k), 520, 0)
                        font.weight: Font.Medium
                    }

                }

                HoverHandler {
                    id: hover

                    // a pointer handler ignores Item.enabled unless told to
                    enabled: chip.modelData.interactive === true && chip.enabled && !st.editing
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tap

                    enabled: chip.modelData.interactive === true && !st.editing
                    onTapped: st.lock.activateStatus(chip.modelData.key)
                }

            }

        }

    }

    Row {
        id: icons

        x: st.xFor(implicitWidth, st.width)
        visible: st.style === "icons"
        spacing: st.kp(16)

        Repeater {
            model: st.style === "icons" ? st.items : []

            Row {
                id: mark

                required property var modelData

                spacing: st.kp(5)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: mark.modelData.glyph
                    size: st.kp(20)
                    color: st.toneOf(mark.modelData.tone)
                }

                // only a number earns its words here
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: mark.modelData.short !== undefined && mark.modelData.short !== ""
                    text: mark.modelData.short || ""
                    color: st.tonal ? st.theme.fgAccentContainer : st.theme.text
                    font.family: st.theme.fontFamily
                    font.pixelSize: Math.round(st.theme.fontLabelLg * st.k)
                    font.variableAxes: st.theme.axes(Math.round(st.theme.fontLabelLg * st.k), 560, 0)
                    font.weight: Font.Medium
                }

                TapHandler {
                    enabled: mark.modelData.interactive === true && !st.editing
                    onTapped: st.lock.activateStatus(mark.modelData.key)
                }

            }

        }

    }

}
