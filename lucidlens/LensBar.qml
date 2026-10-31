import QtQuick
import qs
import qs.lucidlumen
import qs.lucidui

// the bar along the top: what is shown and where it sits in the folder, and
// the tools for it. editing, it holds the way out, undo and saving instead
Item {
    id: bar

    required property var win
    required property var app
    required property var stage
    readonly property bool editing: bar.win.mode === "edit"
    readonly property var cur: bar.win.current
    readonly property string zoomText: !bar.stage.current || !bar.stage.current.ready ? "" : (!bar.stage.zoomed ? "Fit" : Math.round(bar.stage.shownScale * 100) + "%")
    readonly property string facts: {
        var c = bar.cur;
        if (!c)
            return "";

        var out = [];
        if (bar.win.items.length > 1)
            out.push((bar.win.index + 1) + " of " + bar.win.items.length);

        var i = bar.win.info;
        if (i && i.w)
            out.push(i.w + " × " + i.h);

        if (i && i.video && i.duration > 0)
            out.push(bar.app.timeText(i.duration * 1000));

        out.push(bar.app.sizeText(c.size || 0));
        if (bar.win.dirty)
            out.push("Unsaved edits");
        else if (bar.win.kept)
            out.push("Original kept");

        return out.join("  ·  ");
    }

    Row {
        id: lead

        x: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(8)

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: bar.editing ? "close" : "grid_view"
            tooltip: bar.editing ? "Done editing (Esc)" : "All pictures (G)"
            checkable: !bar.editing
            checked: bar.win.overview

            Tip {
            }

            onClicked: {
                if (bar.editing)
                    bar.win.closeEditor();
                else
                    bar.win.overview = !bar.win.overview;
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Theme.dp(80), tools.x - lead.x - Theme.dp(64))
            spacing: Theme.dp(1)

            LText {
                width: parent.width
                role: "titleMedium"
                text: bar.editing ? "Edit" : (bar.cur ? bar.cur.name : "Lens")
                elide: Text.ElideMiddle
            }

            LText {
                width: parent.width
                role: "bodySmall"
                color: Theme.subtext
                text: bar.editing ? (bar.cur ? bar.cur.name : "") : (bar.win.pasted ? "Pasted from the clipboard  ·  save a copy to keep it" : bar.facts)
                elide: Text.ElideMiddle
                visible: text !== ""
                tabular: true
            }

        }

    }

    Row {
        id: tools

        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.dp(2)

        // a quick turn or two in the viewer waits here to be kept or let go;
        // a picture pasted from the clipboard is kept by saving a copy
        Row {
            visible: !bar.editing && (bar.win.dirty || bar.win.pasted)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(6)

            Button {
                visible: bar.win.dirty
                variant: "text"
                size: "s"
                text: "Discard"
                onClicked: bar.win.revert()
            }

            Button {
                variant: "tonal"
                size: "s"
                icon: "save"
                text: bar.win.busy ? "Saving…" : bar.win.pasted ? "Save a copy" : "Save"
                disabled: bar.win.busy
                onClicked: bar.win.save(bar.win.pasted)
            }

            Item {
                width: Theme.dp(8)
                height: 1
            }

        }

        Row {
            visible: !bar.editing && !bar.win.narrow
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.dp(2)

            IconButton {
                icon: "zoom_out"
                tooltip: "Zoom out (−)"
                disabled: !bar.stage.zoomed

                Tip {
                }

                onClicked: bar.stage.zoomBy(0.8)
            }

            // the zoom as it is; a click offers the usual steps
            Rectangle {
                id: zoomChip

                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(Theme.dp(58), zoomLabel.implicitWidth + Theme.dp(20))
                height: Theme.dp(32)
                radius: height / 2
                color: Theme.surfaceHigh

                LText {
                    id: zoomLabel

                    anchors.centerIn: parent
                    role: "labelLarge"
                    text: bar.zoomText || "–"
                    tabular: true
                }

                MouseArea {
                    id: zoomArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var p = zoomChip.mapToItem(bar.win.contentItem, 0, zoomChip.height + Theme.dp(4));
                        bar.win.zoomMenu(p.x - Theme.dp(40), p.y);
                    }
                }

                HoverLayer {
                    area: zoomArea
                }

            }

            IconButton {
                icon: "zoom_in"
                tooltip: "Zoom in (+)"

                Tip {
                }

                onClicked: bar.stage.zoomBy(1.25)
            }

            Item {
                width: Theme.dp(10)
                height: 1
            }

        }

        IconButton {
            visible: !bar.editing && wide.ok
            icon: "rotate_left"
            tooltip: "Rotate left (Shift+R)"
            disabled: !bar.win.canTurn

            Tip {
            }

            onClicked: bar.win.turn(-1)
        }

        IconButton {
            visible: !bar.editing && wide.ok
            icon: "rotate_right"
            tooltip: "Rotate right (R)"
            disabled: !bar.win.canTurn

            Tip {
            }

            onClicked: bar.win.turn(1)
        }

        Item {
            visible: !bar.editing && wide.ok
            width: Theme.dp(10)
            height: 1
        }

        // a video's one edit is a trim
        IconButton {
            visible: !bar.editing && bar.win.isVideo
            icon: "content_cut"
            tooltip: "Trim (E)"
            checkable: true
            checked: bar.win.trimming
            disabled: bar.cur !== null && bar.cur.broken === true

            Tip {
            }

            onClicked: bar.win.trimming ? bar.win.closeTrim() : bar.win.startTrim()
        }

        IconButton {
            visible: !bar.editing && !bar.win.isVideo
            icon: "crop"
            tooltip: "Crop (C)"
            disabled: !bar.win.canEdit

            Tip {
            }

            onClicked: bar.win.openEditor("crop")
        }

        IconButton {
            visible: !bar.editing && !bar.win.isVideo
            icon: "tune"
            tooltip: "Edit (E)"
            disabled: !bar.win.canEdit

            Tip {
            }

            onClicked: bar.win.openEditor("adjust")
        }

        IconButton {
            visible: !bar.editing && !bar.win.isVideo
            icon: "draw"
            tooltip: "Draw (D)"
            disabled: !bar.win.canEdit

            Tip {
            }

            onClicked: bar.win.openEditor("markup")
        }

        IconButton {
            visible: !bar.editing
            icon: "info"
            tooltip: bar.win.showInfo ? "Hide details (I)" : "Details (I)"
            checkable: true
            checked: bar.win.showInfo

            Tip {
            }

            onClicked: bar.win.showInfo = !bar.win.showInfo
        }

        IconButton {
            id: moreBtn

            visible: !bar.editing
            icon: "more_vert"
            tooltip: "More"

            Tip {
            }

            onClicked: {
                var p = moreBtn.mapToItem(bar.win.contentItem, 0, moreBtn.height + Theme.dp(4));
                bar.win.moreMenu(p.x - Theme.dp(230), p.y);
            }
        }

        // editing: undo and redo, the original held up beside it, and saving
        IconButton {
            visible: bar.editing
            icon: "undo"
            tooltip: "Undo (Ctrl+Z)"
            disabled: bar.win.stepsHere.past.length === 0

            Tip {
            }

            onClicked: bar.win.undo()
        }

        IconButton {
            visible: bar.editing
            icon: "redo"
            tooltip: "Redo (Ctrl+Y)"
            disabled: bar.win.stepsHere.future.length === 0

            Tip {
            }

            onClicked: bar.win.redo()
        }

        IconButton {
            id: compareBtn

            visible: bar.editing
            icon: "compare"
            tooltip: bar.win.dirty ? "Hold to see it without these edits (\\)" : "Hold to see the original (\\)"
            checkable: true
            checked: bar.win.comparing
            disabled: !bar.win.dirty && !bar.win.kept

            Tip {
            }

            MouseArea {
                anchors.fill: parent
                enabled: !compareBtn.disabled
                onPressed: bar.win.comparing = true
                onReleased: bar.win.comparing = false
                onCanceled: bar.win.comparing = false
            }

        }

        Item {
            visible: bar.editing
            width: Theme.dp(8)
            height: 1
        }

        // with nothing unsaved, going back means going back to the kept original
        Button {
            visible: bar.editing && !bar.win.narrow
            anchors.verticalCenter: parent.verticalCenter
            variant: "text"
            text: !bar.win.dirty && bar.win.kept ? "Revert to original" : "Reset"
            disabled: bar.win.busy || (!bar.win.dirty && !bar.win.kept)
            onClicked: bar.win.dirty ? bar.win.revert() : bar.win.revertOriginal()
        }

        Button {
            visible: bar.editing
            anchors.verticalCenter: parent.verticalCenter
            variant: "tonal"
            text: "Save copy"
            disabled: !bar.win.dirty || bar.win.busy
            onClicked: bar.win.save(true)
        }

        Item {
            visible: bar.editing
            width: Theme.dp(6)
            height: 1
        }

        Button {
            visible: bar.editing
            anchors.verticalCenter: parent.verticalCenter
            variant: "filled"
            icon: "save"
            text: bar.win.busy ? "Saving…" : "Save"
            disabled: !bar.win.dirty || bar.win.busy || bar.win.pasted
            onClicked: bar.win.save(false)
        }

    }

    QtObject {
        id: wide

        readonly property bool ok: bar.width >= Theme.dp(900)
    }

}
