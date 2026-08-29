import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Widgets
import qs

Item {
    id: pane

    property var host
    property string query: ""
    property string mode: "browse"
    // search | trending | fav | recent | local
    property string resultsKind: "search"
    property string resultsTitle: ""
    property var categories: []
    property var trendingGifs: []
    property var searchResults: []
    property var localGifs: []
    property bool loading: false
    property string errorText: ""
    property int hoverIndex: -1

    // "giphy" | "tenor" | ""
    readonly property string provider: {
        if (!pane.host)
            return "";

        if (pane.host.giphyKey !== "")
            return "giphy";

        if (pane.host.tenorKey !== "")
            return "tenor";

        return "";
    }
    readonly property bool hasKey: pane.provider !== ""
    readonly property real colWidth: Math.floor((pane.width - 12) / 2)

    readonly property var entries: {
        if (!pane.host)
            return [];

        if (pane.resultsKind === "fav")
            return pane.host.favGifs;

        if (pane.resultsKind === "recent")
            return pane.host.recentGifsView;

        if (pane.resultsKind === "local")
            return pane.localGifs;

        if (pane.resultsKind === "trending")
            return pane.trendingGifs;

        return pane.searchResults;
    }

    readonly property var tiles: {
        if (!pane.host)
            return [];

        var out = [];
        out.push({
            "kind": "fav",
            "label": "Favourites",
            "preview": pane.host.favGifs.length > 0 ? pane.host.favGifs[0].preview : "",
            "count": pane.host.favGifs.length
        });
        out.push({
            "kind": "trending",
            "label": "Trending GIFs",
            "preview": pane.trendingGifs.length > 0 ? pane.trendingGifs[0].preview : "",
            "count": pane.trendingGifs.length
        });
        out.push({
            "kind": "recent",
            "label": "Recents",
            "preview": pane.host.recentGifsView.length > 0 ? pane.host.recentGifsView[0].preview : "",
            "count": pane.host.recentGifsView.length
        });
        out.push({
            "kind": "local",
            "label": "Local",
            "preview": pane.localGifs.length > 0 ? pane.localGifs[0].preview : "",
            "count": pane.localGifs.length
        });
        for (var i = 0; i < pane.categories.length; i++) {
            out.push({
                "kind": "search",
                "label": pane.categories[i].term,
                "preview": pane.categories[i].image,
                "count": 0
            });
        }
        return out;
    }

    readonly property var columns: {
        var a = [];
        var b = [];
        var ha = 0;
        var hb = 0;
        var list = pane.entries;
        for (var i = 0; i < list.length; i++) {
            var it = list[i];
            var ratio = (it.w > 0 && it.h > 0) ? (it.h / it.w) : 0.7;
            var h = pane.colWidth * ratio;
            if (ha <= hb) {
                a.push(it);
                ha += h + 8;
            } else {
                b.push(it);
                hb += h + 8;
            }
        }
        return [a, b];
    }

    readonly property real wallHeight: {
        var totals = [0, 0];
        for (var c = 0; c < pane.columns.length; c++) {
            var list = pane.columns[c];
            for (var i = 0; i < list.length; i++) totals[c] += pane.gifHeight(list[i]) + 8;
        }
        return Math.max(totals[0], totals[1]);
    }

    signal queryRequested(string q)

    function gifHeight(entry) {
        var ratio = (entry.w > 0 && entry.h > 0) ? (entry.h / entry.w) : 0.7;
        return Math.max(60, Math.min(220, pane.colWidth * ratio));
    }

    function openLane(tile) {
        if (tile.kind === "search") {
            pane.queryRequested(tile.label);
            return ;
        }
        pane.resultsKind = tile.kind;
        pane.resultsTitle = tile.label;
        pane.mode = "results";
        if (tile.kind === "local")
            localScan.running = true;
        else if (tile.kind === "trending" && pane.trendingGifs.length === 0)
            pane.fetchTrending();
    }

    function back() {
        if (pane.resultsKind === "search" && pane.query !== "")
            pane.queryRequested("");

        pane.mode = "browse";
    }

    // "search" | "trending" | "categories"
    function apiUrl(kind, query) {
        if (pane.provider === "giphy") {
            var g = "https://api.giphy.com/v1/gifs/" + (kind === "trending" ? "trending" : kind) + "?api_key=" + encodeURIComponent(pane.host.giphyKey) + "&rating=pg-13";
            if (kind !== "categories")
                g += "&limit=30";

            if (kind === "search")
                g += "&q=" + encodeURIComponent(query);

            return g;
        }
        var path = kind === "trending" ? "featured" : kind;
        var t = "https://tenor.googleapis.com/v2/" + path + "?key=" + encodeURIComponent(pane.host.tenorKey) + "&client_key=lucidmoji&contentfilter=medium";
        if (kind === "categories")
            t += "&type=featured";
        else
            t += "&limit=30&media_filter=tinygif,gif";
        if (kind === "search")
            t += "&q=" + encodeURIComponent(query);

        return t;
    }

    function parseGifs(text) {
        var out = [];
        var d = JSON.parse(text);
        var i;
        if (pane.provider === "giphy") {
            var gl = d.data || [];
            for (i = 0; i < gl.length; i++) {
                var im = gl[i].images || {};
                var prev = im.fixed_width || im.downsized || im.original;
                var full = im.original || im.fixed_width;
                if (!prev || !full)
                    continue;

                out.push({
                    "url": full.url,
                    "preview": prev.url,
                    "local": false,
                    "path": "",
                    "w": parseInt(prev.width) || 0,
                    "h": parseInt(prev.height) || 0,
                    "desc": gl[i].title || ""
                });
            }
            return out;
        }
        var list = d.results || [];
        for (i = 0; i < list.length; i++) {
            var f = list[i].media_formats || {};
            if (!f.gif || !f.tinygif)
                continue;

            var dims = f.tinygif.dims || [0, 0];
            out.push({
                "url": f.gif.url,
                "preview": f.tinygif.url,
                "local": false,
                "path": "",
                "w": dims[0] || 0,
                "h": dims[1] || 0,
                "desc": list[i].content_description || ""
            });
        }
        return out;
    }

    function request(url, onOk) {
        pane.loading = true;
        pane.errorText = "";
        var xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return ;

            pane.loading = false;
            if (xhr.status !== 200) {
                var who = pane.provider === "giphy" ? "Giphy" : "Tenor";
                pane.errorText = xhr.status === 0 ? ("No connection to " + who) : (who + " returned " + xhr.status + " — check your key");
                return ;
            }
            try {
                onOk(xhr.responseText);
            } catch (e) {
                pane.errorText = "Could not read the response";
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fetchCategories() {
        if (!pane.hasKey)
            return ;

        pane.request(pane.apiUrl("categories", ""), function(text) {
            var d = JSON.parse(text);
            var out = [];
            var i;
            if (pane.provider === "giphy") {
                var cats = d.data || [];
                for (i = 0; i < cats.length; i++) {
                    var g = ((cats[i].gif || {}).images || {}).fixed_width;
                    out.push({
                        "term": cats[i].name_encoded || cats[i].name || "",
                        "image": g ? g.url : ""
                    });
                }
                pane.categories = out;
                return ;
            }
            var tags = d.tags || [];
            for (i = 0; i < tags.length; i++) {
                // searchterm is clean ("lol"), name is decorated ("#lol")
                out.push({
                    "term": tags[i].searchterm || (tags[i].name || "").replace("#", ""),
                    "image": tags[i].image || ""
                });
            }
            pane.categories = out;
        });
    }

    function fetchTrending() {
        if (!pane.hasKey)
            return ;

        pane.request(pane.apiUrl("trending", ""), function(text) {
            pane.trendingGifs = pane.parseGifs(text);
        });
    }

    function search() {
        var q = pane.query.trim();
        if (!pane.hasKey || q === "") {
            pane.searchResults = [];
            return ;
        }
        pane.request(pane.apiUrl("search", q), function(text) {
            pane.searchResults = pane.parseGifs(text);
        });
    }

    function activate(entry) {
        if (!entry)
            return ;

        if (entry.local)
            pane.host.copyGifFile(entry.path);
        else
            pane.host.insert(entry.url);
        pane.host.pushRecentGif(entry);
    }

    onQueryChanged: {
        if (!pane.visible)
            return ;

        if (pane.query.trim() === "") {
            pane.mode = "browse";
            return ;
        }
        pane.resultsKind = "search";
        pane.resultsTitle = pane.query.trim();
        pane.mode = "results";
        searchDebounce.restart();
    }
    onVisibleChanged: {
        if (!pane.visible)
            return ;

        localScan.running = true;
        if (!pane.hasKey)
            return ;

        if (pane.categories.length === 0)
            pane.fetchCategories();

        if (pane.trendingGifs.length === 0)
            pane.fetchTrending();

    }

    Timer {
        id: searchDebounce

        interval: 350
        onTriggered: pane.search()
    }

    Process {
        id: localScan

        command: ["sh", "-c", "find \"$1\" -maxdepth 3 -type f -iname '*.gif' 2>/dev/null | head -200", "sh", pane.host ? pane.host.gifDir : ""]

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim();
                    if (p === "")
                        continue;

                    out.push({
                        "url": "file://" + p,
                        "preview": "file://" + p,
                        "local": true,
                        "path": p,
                        "w": 0,
                        "h": 0,
                        "desc": p.split("/").pop()
                    });
                }
                pane.localGifs = out;
            }
        }

    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 16

        Text {
            id: backLabel

            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: pane.mode === "results" ? "‹  " + pane.resultsTitle : (pane.loading ? "Loading…" : "Browse")
            color: pane.errorText !== "" ? Theme.error : Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true

            HoverHandler {
                id: backHover

                enabled: pane.mode === "results"
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: pane.mode === "results"
                onTapped: pane.back()
            }

        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: pane.errorText !== "" ? pane.errorText : (pane.mode === "results" ? pane.entries.length + "" : "")
            color: pane.errorText !== "" ? Theme.error : Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
            font.bold: true
        }

    }

    GridView {
        id: browseGrid

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: keyNotice.visible ? keyNotice.top : parent.bottom
        anchors.topMargin: 6
        anchors.bottomMargin: keyNotice.visible ? 6 : 0
        visible: pane.mode === "browse"
        clip: true
        cellWidth: Math.floor(browseGrid.width / 2)
        cellHeight: 92
        model: pane.tiles
        boundsBehavior: Flickable.StopAtBounds

        delegate: Item {
            id: tile

            required property var modelData
            required property int index

            width: browseGrid.cellWidth
            height: browseGrid.cellHeight

            ClippingRectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radiusSm
                color: Theme.bgTile

                AnimatedImage {
                    anchors.fill: parent
                    source: tile.modelData.preview
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    playing: pane.visible && pane.mode === "browse"
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durShort
                        }

                    }

                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.cShadow, tileHover.hovered ? 0.3 : 0.45)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                        }

                    }

                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    text: tile.modelData.label
                    color: "white"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }

            }

            HoverHandler {
                id: tileHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: pane.openLane(tile.modelData)
            }

        }

        ScrollBar.vertical: ScrollBar {
            id: browseScroll

            policy: ScrollBar.AsNeeded
            visible: browseGrid.contentHeight > browseGrid.height
            width: 8

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: Theme.alpha(Theme.text, 0.2)
            }

            background: Rectangle {
                color: "transparent"
            }

        }

    }

    Flickable {
        id: wall

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 6
        visible: pane.mode === "results"
        clip: true
        contentWidth: width
        contentHeight: pane.wallHeight + 8
        boundsBehavior: Flickable.StopAtBounds

        Row {
            x: 4
            spacing: 8

            Repeater {
                model: pane.columns

                delegate: Column {
                    id: col

                    required property var modelData
                    required property int index

                    spacing: 8

                    Repeater {
                        model: col.modelData

                        delegate: ClippingRectangle {
                            id: gifCell

                            required property var modelData

                            width: pane.colWidth - 4
                            height: pane.gifHeight(gifCell.modelData)
                            radius: Theme.radiusSm
                            color: Theme.bgTile

                            AnimatedImage {
                                anchors.fill: parent
                                source: gifCell.modelData.preview
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                playing: pane.visible && pane.mode === "results"
                                opacity: status === Image.Ready ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durShort
                                    }

                                }

                            }

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.alpha(Theme.accent, 0.25)
                                visible: cellHover.hovered
                            }

                            Text {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 5
                                anchors.rightMargin: 6
                                text: pane.host && pane.host.isFavGif(gifCell.modelData.url) ? "★" : "☆"
                                color: pane.host && pane.host.isFavGif(gifCell.modelData.url) ? Theme.accent : "white"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fs(15)
                                visible: cellHover.hovered || (pane.host && pane.host.isFavGif(gifCell.modelData.url))

                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: pane.host.toggleFavGif(gifCell.modelData)
                                }

                            }

                            HoverHandler {
                                id: cellHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: pane.activate(gifCell.modelData)
                            }

                        }

                    }

                }

            }

        }

        ScrollBar.vertical: ScrollBar {
            id: wallScroll

            policy: ScrollBar.AsNeeded
            visible: wall.contentHeight > wall.height
            width: 8

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: Theme.alpha(Theme.text, 0.2)
            }

            background: Rectangle {
                color: "transparent"
            }

        }

    }

    Column {
        id: keyNotice

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2
        visible: pane.mode === "browse" && !pane.hasKey

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "🔑  Add a Giphy key for Trending and search"
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "developers.giphy.com → config.json as \"giphyKey\""
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
        }

    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 60
        spacing: 8
        visible: !pane.loading && pane.mode === "results" && pane.entries.length === 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: pane.hasKey ? "🫥" : "🔑"
            font.family: "Noto Color Emoji"
            font.pixelSize: Theme.fs(26)
            opacity: 0.5
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                if (!pane.hasKey)
                    return "Add a free Giphy API key to browse and search GIFs";

                if (pane.errorText !== "")
                    return pane.errorText;

                if (pane.resultsKind === "fav")
                    return "Hover a GIF and hit ☆ to keep it here";

                if (pane.resultsKind === "recent")
                    return "GIFs you send show up here";

                if (pane.resultsKind === "local")
                    return "No .gif files in " + (pane.host ? pane.host.gifDir : "");

                return "No GIFs found";
            }
            color: Theme.subtext
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLabel
            font.bold: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !pane.hasKey
            text: "Get one at developers.giphy.com (email only, no card),\nthen put it in lucidmoji/config.json as \"giphyKey\""
            color: Theme.subtextDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fs(10)
        }

    }

}
