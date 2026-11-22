import QtQuick

// today, long, short, or the weekday stacked over the day
WidgetBase {
    id: dl

    readonly property string style: dl.opts.style || "long"
    readonly property var now: dl.lock ? dl.lock.now : new Date()
    // the shell's language on the lock, the machine's at login
    readonly property var loc: dl.lock ? dl.lock.locale : null
    readonly property color ink: dl.tonal ? dl.theme.fgAccentContainer : dl.theme.text

    implicitWidth: dl.style === "stacked" ? stack.implicitWidth : line.implicitWidth
    implicitHeight: dl.style === "stacked" ? stack.implicitHeight : line.implicitHeight

    Text {
        id: line

        width: Math.min(implicitWidth, dl.avail)
        x: dl.xFor(width, dl.width)
        visible: dl.style !== "stacked"
        elide: Text.ElideRight
        text: dl.loc ? dl.now.toLocaleDateString(dl.loc, dl.style === "short" ? "ddd d MMM" : "dddd, d MMMM") : "" // i18n-skip
        color: dl.ink
        font.family: dl.theme.fontFamily
        font.pixelSize: Math.round(dl.theme.fontTitleLg * dl.k)
        font.variableAxes: dl.theme.axes(Math.round(dl.theme.fontTitleLg * dl.k), 520, 0)
        font.weight: Font.Medium
    }

    Column {
        id: stack

        x: dl.xFor(width, dl.width)
        visible: dl.style === "stacked"
        spacing: dl.kp(2)

        Text {
            width: stack.width
            horizontalAlignment: dl.hAlign
            text: dl.loc ? dl.now.toLocaleDateString(dl.loc, "dddd") : "" // i18n-skip
            color: dl.tonal ? dl.theme.fgAccentContainer : dl.theme.accent
            font.family: dl.theme.fontFamily
            font.pixelSize: Math.round(dl.theme.fontTitleMd * dl.k)
            font.variableAxes: dl.theme.axes(Math.round(dl.theme.fontTitleMd * dl.k), 600, 0)
            font.weight: Font.DemiBold
        }

        Text {
            horizontalAlignment: dl.hAlign
            text: dl.loc ? dl.now.toLocaleDateString(dl.loc, "d MMMM") : "" // i18n-skip
            color: dl.ink
            font.family: dl.theme.fontFamily
            font.pixelSize: Math.round(dl.theme.fontHeadlineMd * dl.k)
            font.variableAxes: dl.theme.axes(Math.round(dl.theme.fontHeadlineMd * dl.k), 520, 40)
            font.weight: Font.Medium
        }

    }

}
