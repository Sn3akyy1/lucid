import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// editing an icon's name, in place over its label. It needs the keyboard for
// itself, so it lives on an overlay of its own for as long as the edit lasts;
// a click anywhere else keeps the name, the way file managers do
PanelWindow {
    id: layer

    readonly property var item: DesktopIcons.byKey[DesktopIcons.renaming] || null
    readonly property var spot: DesktopIcons.placed[DesktopIcons.renaming] || null

    function commit() {
        if (DesktopIcons.renaming !== "")
            DesktopIcons.rename(DesktopIcons.renaming, field.text);

    }

    screen: DesktopIcons.screen
    visible: DesktopIcons.live && layer.item !== null && layer.spot !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lucid-desktop-rename"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: {
        if (!layer.visible || !layer.item)
            return ;

        field.text = layer.item.label;
        // the name without its extension, ready to type over
        var dot = layer.item.kind === "file" ? field.text.lastIndexOf(".") : -1;
        field.select(0, dot > 0 ? dot : field.text.length);
        field.forceActiveFocus();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: layer.commit()
    }

    Rectangle {
        id: box

        x: layer.spot ? DesktopIcons.tileX(layer.spot.c) - Theme.dp(10) : 0
        y: layer.spot ? DesktopIcons.tileY(layer.spot.r) + DesktopIcons.iconPx + Theme.dp(10) : 0
        width: DesktopIcons.tileW + Theme.dp(24)
        height: field.contentHeight + Theme.dp(10)
        radius: 6
        color: Theme.bg
        border.width: 1
        border.color: Theme.accent

        TextInput {
            id: field

            anchors.fill: parent
            anchors.margins: Theme.dp(5)
            color: Theme.text
            selectionColor: Theme.accent
            selectedTextColor: Theme.fgAccent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabelMd
            horizontalAlignment: TextInput.AlignHCenter
            wrapMode: TextInput.WrapAnywhere
            selectByMouse: true
            Keys.onReturnPressed: layer.commit()
            Keys.onEnterPressed: layer.commit()
            Keys.onEscapePressed: DesktopIcons.renaming = ""
        }

    }

}
