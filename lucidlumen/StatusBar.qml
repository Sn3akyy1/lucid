import QtQuick
import qs
import qs.lucidui

// the pane's foot: how many things, what is selected, room left on the drive,
// and every copy or move still running, each with a way to stop it
Item {
    id: foot

    required property var app
    required property var win
    readonly property var tab: foot.win.tab
    readonly property var running: {
        var out = [];
        var j = foot.app.jobs;
        if (foot.app.jobsRev < 0)
            return out;

        for (var k in j) out.push(j[k])
        return out;
    }
    readonly property string countText: {
        var t = foot.tab;
        if (!t || t.rev < 0)
            return "";

        var n = t.model.count;
        if (t.selCount > 0) {
            var bytes = 0, files = 0;
            for (var u in t.sel) {
                var i = t.index[u];
                if (i === undefined)
                    continue;

                // the index can still name a row that just went (moved out, say)
                var it = t.model.get(i);
                if (!it)
                    continue;

                if (it.kind !== "dir") {
                    bytes += it.size;
                    files++;
                }
            }
            return t.selCount + " of " + n + " selected" + (files > 0 ? " · " + foot.app.sizeText(bytes) : "");
        }
        if (t.searching)
            return n + (n === 1 ? " result" : " results") + (t.searchDone ? (t.searchTruncated ? " (stopped at " + n + ")" : "") : " so far…");

        return n + (n === 1 ? " item" : " items") + (t.filter !== "" ? " match “" + t.filter + "”" : "") + (t.asAdmin ? " · As administrator" : "");
    }

    implicitHeight: Theme.dp(36) + jobsCol.implicitHeight

    Column {
        id: jobsCol

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.dp(16)
        anchors.rightMargin: Theme.dp(12)
        spacing: Theme.dp(4)

        Repeater {
            model: foot.running

            delegate: Item {
                required property var modelData
                readonly property real frac: modelData.total > 0 ? modelData.done / modelData.total : (modelData.count > 0 ? modelData.files / modelData.count : 0)

                width: jobsCol.width
                height: Theme.dp(40)

                Icon {
                    id: jobIcon

                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.mode === "copy" ? "content_copy" : "content_cut"
                    size: Theme.dp(18)
                    color: Theme.accent
                }

                LText {
                    id: jobText

                    anchors.left: jobIcon.right
                    anchors.leftMargin: Theme.dp(10)
                    anchors.top: parent.top
                    anchors.topMargin: Theme.dp(3)
                    width: parent.width - Theme.dp(80)
                    role: "labelMedium"
                    text: (modelData.mode === "copy" ? "Copying " : "Moving ") + (modelData.count === 1 && modelData.name ? "“" + modelData.name + "”" : modelData.count + " items") + " to " + foot.app.titleFor(modelData.dest) + (modelData.total > 0 ? " · " + foot.app.sizeText(modelData.done) + " of " + foot.app.sizeText(modelData.total) : "")
                    color: Theme.text
                    elide: Text.ElideRight
                }

                LinearProgress {
                    anchors.left: jobText.left
                    anchors.right: stop.left
                    anchors.rightMargin: Theme.dp(10)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.dp(6)
                    value: parent.frac
                }

                IconButton {
                    id: stop

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: "xs"
                    icon: "close"
                    tooltip: "Stop"

                    Tip {
                    }

                    onClicked: foot.app.cancelJob(modelData.job)
                }

            }

        }

    }

    LText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.dp(22)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(10)
        role: "labelMedium"
        text: foot.countText
        color: Theme.subtext
    }

    LText {
        anchors.right: parent.right
        anchors.rightMargin: Theme.dp(22)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.dp(10)
        role: "labelMedium"
        visible: foot.tab !== null && !foot.tab.isSpecial && foot.tab.free.total > 0
        text: foot.tab ? foot.app.sizeText(foot.tab.free.free) + " free" : ""
        color: Theme.subtext
    }

}
