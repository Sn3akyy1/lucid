import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import "../lucidnotif"

// what is listening or watching right now: the microphone, the camera and the
// screen, each with the apps behind it. nothing in use, no pill at all
BarPill {
    id: root

    // Lucid's own screen recorder and the toast, handed in by shell.qml
    property var recorder: null
    property var toast: null
    readonly property bool recording: !!root.recorder && root.recorder.recordingState !== "idle"
    readonly property var icons: ({
        "mic": "M12 14q-1.25 0-2.125-.875T9 11V5q0-1.25.875-2.125T12 2q1.25 0 2.125.875T15 5v6q0 1.25-.875 2.125T12 14Zm-1 7v-3.075q-2.6-.35-4.3-2.325T5 11h2q0 2.075 1.463 3.538T12 16q2.075 0 3.538-1.463T17 11h2q0 2.6-1.7 4.6T13 17.925V21h-2Z",
        "camera": "M4 20q-.825 0-1.412-.587T2 18V6q0-.825.588-1.412T4 4h12q.825 0 1.413.588T18 6v4.5l4-4v11l-4-4V18q0 .825-.587 1.413T16 20H4Z",
        "screen": "M4 17q-.825 0-1.412-.587T2 15V5q0-.825.588-1.412T4 3h16q.825 0 1.413.588T22 5v10q0 .825-.587 1.413T20 17h-5v2h2v2H7v-2h2v-2H4Z",
        "shield": "M12 22q-3.475-.875-5.738-3.988T4 11.1V5l8-3l8 3v6.1q0 3.8-2.262 6.913T12 22Z"
    })
    readonly property var nouns: ({
        "mic": "the microphone",
        "camera": "the camera",
        "screen": "the screen"
    })
    readonly property var watched: String(Prefs.privacyWatch || "").split(",")

    // a recording stream is listening to you when what feeds it is an input
    // device; one fed by an output (a visualiser on a speaker's monitor) or by
    // another app is not. read off the links, which are there as soon as it runs
    readonly property var micApps: root.names(Audio.recordStreams.filter((s) => {
        return root.feedsOf(s).some((src) => {
            return !src.isStream && !src.isSink;
        });
    }).map(root.micLabel))
    readonly property var videoNodes: (Pipewire.nodes ? Pipewire.nodes.values : []).filter((n) => {
        return !!n && (n.type & PwNodeType.Video) !== 0;
    })
    readonly property var cameraNodes: root.videoNodes.filter((n) => {
        return (n.type & PwNodeType.Source) !== 0 && /^(v4l2|libcamera)_/.test(n.name || "");
    })
    // a screen being shared is a video source that is not a camera: the portal
    // makes one for each share and drops it when the share ends
    readonly property var screenNodes: root.videoNodes.filter((n) => {
        return (n.type & PwNodeType.Source) !== 0 && !/^(v4l2|libcamera)_/.test(n.name || "");
    })
    // programs holding a camera device open themselves, not through PipeWire
    property var cameraHolders: []
    readonly property var cameraApps: root.names(root.consumersOf(root.cameraNodes).concat(root.cameraHolders.filter((c) => {
        return c !== "pipewire" && c !== "wireplumber";
    })).concat(root.cameraHolders.indexOf("pipewire") !== -1 && root.consumersOf(root.cameraNodes).length === 0 ? ["An app through PipeWire"] : []))
    readonly property var screenApps: root.names(root.screenNodes.length > 0 ? root.consumersOf(root.screenNodes).concat(root.consumersOf(root.screenNodes).length === 0 ? ["An app"] : []) : [])
    readonly property var rows: {
        const out = [];
        if (root.watched.indexOf("mic") !== -1 && root.micApps.length > 0)
            out.push({
            "kind": "mic",
            "title": "Microphone",
            "apps": root.micApps
        });

        if (root.watched.indexOf("camera") !== -1 && root.cameraApps.length > 0)
            out.push({
            "kind": "camera",
            "title": "Camera",
            "apps": root.cameraApps
        });

        if (root.watched.indexOf("screen") !== -1 && (root.screenApps.length > 0 || root.recording))
            out.push({
            "kind": "screen",
            "title": "Screen",
            "apps": root.recording ? ["Lucid is recording"].concat(root.screenApps) : root.screenApps
        });

        return out;
    }
    readonly property int horizontalPadding: 10

    // one entry per program, in the order they turned up
    function names(list) {
        const out = [];
        for (const n of list) {
            const s = String(n || "").trim();
            if (s !== "" && out.indexOf(s) === -1)
                out.push(s);

        }
        return out;
    }

    // a pulse loopback has no program name; while Lucid records, the one on
    // the microphone is its own
    function micLabel(stream) {
        if (/^input\.loopback/.test(stream.name || ""))
            return root.recording ? "Lucid's recording" : "An audio loopback";

        return Audio.appLabel(stream);
    }

    // the nodes linked into a stream
    function feedsOf(stream) {
        if (!Pipewire.linkGroups)
            return [];

        const out = [];
        for (const g of Pipewire.linkGroups.values) {
            if (g && g.target === stream && g.source)
                out.push(g.source);

        }
        return out;
    }

    // the streams a set of source nodes is linked into, as program names
    function consumersOf(sources) {
        if (sources.length === 0 || !Pipewire.linkGroups)
            return [];

        const out = [];
        for (const g of Pipewire.linkGroups.values) {
            if (g && g.source && g.target && sources.indexOf(g.source) !== -1)
                out.push(Audio.appLabel(g.target));

        }
        return out;
    }

    // the dot face: one mark, in the colour of the most telling use
    readonly property bool dotFace: Prefs.privacyStyle === "dot"
    readonly property string topKind: {
        const kinds = root.rows.map((r) => {
            return r.kind;
        });
        return kinds.indexOf("screen") !== -1 ? "screen" : (kinds.indexOf("camera") !== -1 ? "camera" : (kinds.length > 0 ? kinds[0] : ""));
    }

    function colourOf(kind) {
        return kind === "screen" ? Theme.error : (kind === "camera" ? Theme.success : Theme.warning);
    }

    // what each kind was last seen used by, for telling what is new
    property var seen: ({})
    // nothing is announced for a moment after start, so a reload does not
    // report what was already running as news
    property bool armed: false

    // an app starting on the microphone, the camera or the screen is worth a
    // toast; Lucid's own recording is not, since you started it
    onRowsChanged: {
        const now = {};
        for (const r of root.rows)
            now[r.kind] = r.apps;
        if (root.armed && Prefs.privacyToast && root.toast) {
            for (const kind in now) {
                const before = root.seen[kind] || [];
                for (const app of now[kind]) {
                    if (before.indexOf(app) !== -1 || app === "Lucid is recording" || app === "Lucid's recording")
                        continue;

                    root.toast.enqueue({
                        "icon": root.icons[kind],
                        "label": app + " is using " + root.nouns[kind],
                        "key": "privacy-" + kind
                    });
                }
            }
        }
        root.seen = now;
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: root.armed = true
    }

    shown: Prefs.showPrivacy && (root.rows.length > 0 || Prefs.privacyAlwaysShown)
    // the last use ending folds an open panel away with the pill
    onShownChanged: {
        if (!root.shown)
            root.expanded = false;

    }
    compactWidth: compactRow.implicitWidth + root.horizontalPadding * 2
    panelWidth: 320
    panelHeight: panelColumn.implicitHeight + 32
    expandedRadius: Theme.shapeXl

    // the streams' names only arrive once they are bound; filtered on the type
    // alone, so a node never leaves the list while it lives
    PwObjectTracker {
        objects: root.videoNodes.filter((n) => {
            return (n.type & PwNodeType.Stream) !== 0;
        })
    }

    Process {
        id: holders

        command: ["sh", "-c", "for d in $(find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -printf '%h\\n' 2>/dev/null | sort -u); do p=${d%/fd}; cat \"$p/comm\" 2>/dev/null; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const list = root.names(this.text.split("\n"));
                if (JSON.stringify(list) !== JSON.stringify(root.cameraHolders))
                    root.cameraHolders = list;

            }
        }

    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: Prefs.showPrivacy
        onTriggered: holders.running = true
        onRunningChanged: {
            if (!running)
                root.cameraHolders = [];

        }
    }

    compactContent: [
        Row {
            id: compactRow

            anchors.centerIn: parent
            spacing: 4

            // nothing in use, kept in place: a quiet shield
            NotifIcon {
                visible: root.rows.length === 0
                anchors.verticalCenter: parent.verticalCenter
                size: 16
                path: root.icons.shield
                color: Theme.subtextDim
            }

            Rectangle {
                id: dot

                visible: root.dotFace && root.rows.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: root.colourOf(root.topKind)

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: dot.visible

                    NumberAnimation {
                        to: 0.45
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        to: 1
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }

                }

            }

            Repeater {
                model: root.dotFace ? [] : root.rows

                Rectangle {
                    id: mark

                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 22
                    radius: 11
                    color: Theme.alpha(root.colourOf(mark.modelData.kind), 0.2)

                    NotifIcon {
                        anchors.centerIn: parent
                        size: 15
                        path: root.icons[mark.modelData.kind]
                        color: root.colourOf(mark.modelData.kind)
                    }

                    // a slow breath, the sign that this is live
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: mark.visible

                        NumberAnimation {
                            to: 0.55
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }

                        NumberAnimation {
                            to: 1
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }

                    }

                }

            }

        }
    ]

    panelContent: [
        Column {
            id: panelColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            Text {
                text: root.rows.length > 0 ? "In use now" : "Nothing in use"
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.weight: Font.DemiBold
            }

            Text {
                visible: root.rows.length === 0
                width: parent.width
                text: "No app is using the microphone, the camera or the screen."
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBodyMd
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.rows

                Rectangle {
                    id: useRow

                    required property var modelData

                    width: panelColumn.width
                    height: rowColumn.implicitHeight + 20
                    radius: Theme.radiusMd
                    color: Theme.withBlur(Theme.bgActive)

                    Rectangle {
                        id: badge

                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34
                        height: 34
                        radius: 17
                        color: Theme.alpha(root.colourOf(useRow.modelData.kind), 0.18)

                        NotifIcon {
                            anchors.centerIn: parent
                            size: 18
                            path: root.icons[useRow.modelData.kind]
                            color: root.colourOf(useRow.modelData.kind)
                        }

                    }

                    Column {
                        id: rowColumn

                        anchors.left: badge.right
                        anchors.leftMargin: 12
                        anchors.right: stop.visible ? stop.left : parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            text: useRow.modelData.title
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyLg
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: useRow.modelData.apps.join(", ")
                            color: Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                    }

                    // Lucid's own recording can be ended from here
                    Rectangle {
                        id: stop

                        visible: useRow.modelData.kind === "screen" && root.recording
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: stopLabel.implicitWidth + 24
                        height: 32
                        radius: 16
                        color: stopArea.containsMouse ? Theme.error : Theme.alpha(Theme.error, 0.85)

                        Text {
                            id: stopLabel

                            anchors.centerIn: parent
                            text: "Stop"
                            color: Theme.fgError
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontLabelLg
                            font.weight: Font.Medium
                        }

                        MouseArea {
                            id: stopArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.recorder)
                                    root.recorder.stopRecording();

                            }
                        }

                    }

                }

            }

        }
    ]
}
