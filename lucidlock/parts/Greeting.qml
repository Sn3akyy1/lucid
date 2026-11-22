import QtQuick

// good morning, by name or not
WidgetBase {
    id: gr

    readonly property string first: gr.lock && gr.lock.displayName ? gr.lock.displayName.split(" ")[0] : ""

    implicitWidth: Math.min(line.implicitWidth, gr.avail)
    implicitHeight: line.implicitHeight

    Text {
        id: line

        width: Math.min(implicitWidth, gr.avail)
        x: gr.xFor(width, gr.width)
        elide: Text.ElideRight
        text: gr.lock ? gr.lock.greeting + (gr.opts.style !== "plain" && gr.first !== "" ? ", " + gr.first : "") : ""
        color: gr.tonal ? gr.theme.fgAccentContainer : gr.theme.subtext
        font.family: gr.theme.fontFamily
        font.pixelSize: Math.round(gr.theme.fontBodyLg * gr.k)
        font.variableAxes: gr.theme.axes(Math.round(gr.theme.fontBodyLg * gr.k), 420, 0)
    }

}
