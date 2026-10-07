import QtQuick
import qs
import qs.lucidui

Column {
    id: page

    property bool pageShown: false
    property string mount: ""
    property string pendingPath: ""
    property bool allLarge: false
    property bool allDupes: false
    property string notice: ""
    property bool noticeBad: false
    property var autoScanned: ({})

    // volumes worth choosing between; the efi partition is not one
    readonly property var vols: Storage.volumes.filter((v) => {
        return v.size >= 1073741824;
    })
    readonly property var vol: {
        for (var i = 0; i < Storage.volumes.length; i++) {
            if (Storage.volumes[i].mount === page.mount)
                return Storage.volumes[i];

        }
        return null;
    }
    readonly property var scan: Storage.scans[page.mount] || null
    readonly property var drive: {
        for (var i = 0; i < Storage.drives.length; i++) {
            if (page.vol && Storage.drives[i].name === page.vol.disk)
                return Storage.drives[i];

        }
        return null;
    }
    readonly property bool wantsScan: page.pageShown && page.mount !== "" && Storage.tried[page.mount] === true && !Storage.scanning && !page.autoScanned[page.mount] && (!page.scan || Date.now() / 1000 - page.scan.time > 21600)

    // tile and segment colours: the accent, then evenly round the wheel from it
    readonly property real hue0: Theme.accent.hslHue >= 0 ? Theme.accent.hslHue * 360 : 100
    readonly property var kindColors: [Theme.accentContainer, page.hue(33), page.hue(65), page.hue(98), page.hue(131), page.hue(164), page.hue(196), page.hue(229)]
    readonly property var kindNames: ["Other", "Videos", "Pictures", "Music", "Documents", "Archives", "Code", "Apps and libraries"]
    readonly property var kindIcons: ["category", "movie", "image", "music_note", "description", "archive", "code", "apps"]
    readonly property var cats: [{
        "key": "system",
        "label": "System",
        "color": Theme.accent
    }, {
        "key": "apps",
        "label": "Apps and libraries",
        "color": page.kindColors[7]
    }, {
        "key": "pkgcache",
        "label": "Package cache",
        "color": page.hue(295)
    }, {
        "key": "caches",
        "label": "Caches",
        "color": page.hue(262)
    }, {
        "key": "trash",
        "label": "Trash",
        "color": Theme.error
    }, {
        "key": "video",
        "label": "Videos",
        "color": page.kindColors[1]
    }, {
        "key": "image",
        "label": "Pictures",
        "color": page.kindColors[2]
    }, {
        "key": "audio",
        "label": "Music",
        "color": page.kindColors[3]
    }, {
        "key": "docs",
        "label": "Documents",
        "color": page.kindColors[4]
    }, {
        "key": "archive",
        "label": "Archives",
        "color": page.kindColors[5]
    }, {
        "key": "code",
        "label": "Code",
        "color": page.kindColors[6]
    }, {
        "key": "other",
        "label": "Other files",
        "color": Theme.accentContainer
    }, {
        "key": "hidden",
        "label": "Restricted",
        "color": Theme.alpha(Theme.text, 0.22)
    }]
    readonly property var cacheNotes: ({
        "cache:thumbnails": "Small previews of your pictures and videos, made again as folders are opened.",
        "cache:pip": "Python packages pip downloaded, fetched again when a project needs them.",
        "cache:yay": "Sources and builds left over from installing AUR packages.",
        "cache:paru": "Sources and builds left over from installing AUR packages.",
        "cache:npm": "JavaScript packages npm downloaded, fetched again when a project needs them.",
        "cache:yarn": "JavaScript packages Yarn downloaded, fetched again when a project needs them.",
        "cache:bun": "JavaScript packages Bun downloaded, fetched again when a project needs them.",
        "cache:gobuild": "Compiled Go packages, rebuilt on the next build.",
        "cache:nodegyp": "Headers for building native Node modules, downloaded again when needed.",
        "cache:cargo": "Crates Cargo downloaded, fetched again on the next build.",
        "cache:gradle": "Dependencies of Java and Android builds, fetched again on the next build.",
        "cache:maven": "Dependencies of Java builds, fetched again on the next build.",
        "cache:electron": "Electron builds that development tools downloaded.",
        "cache:composer": "PHP packages Composer downloaded.",
        "cache:shaders": "Compiled shaders. Games and apps build them again, so their next start is slower."
    })
    readonly property var items: Storage.cleanup ? Storage.cleanup.items : []
    readonly property var systemItems: page.items.filter((it) => {
        return ["pacman", "orphans", "journal", "coredumps", "flatpak"].indexOf(it.id) >= 0 && it.size >= 1048576;
    }).sort((a, b) => {
        return b.size - a.size;
    })
    readonly property var cacheItems: page.items.filter((it) => {
        return (it.id === "trash" || it.id.indexOf("cache:") === 0) && it.size >= 1048576;
    }).sort((a, b) => {
        return b.size - a.size;
    })
    readonly property var reviewItems: page.items.filter((it) => {
        return (it.id === "othercaches" || it.id === "downloads") && it.size >= 1048576;
    })
    readonly property real reclaimable: page.systemItems.concat(page.cacheItems).reduce((a, it) => {
        return a + it.size;
    }, 0)
    readonly property var large: {
        void Storage.rev;
        return page.scan && page.scan.large ? page.scan.large : [];
    }
    readonly property var dupes: {
        void Storage.rev;
        return page.scan && page.scan.dupes ? page.scan.dupes : [];
    }
    readonly property real dupeWaste: page.dupes.reduce((a, g) => {
        return a + g.waste;
    }, 0)

    function hue(off) {
        return Theme.statusHue((page.hue0 + off) % 360);
    }

    function kindColor(k) {
        return page.kindColors[k] || page.kindColors[0];
    }

    function kindInk(k) {
        return k === 0 || !page.kindColors[k] ? Theme.fgAccentContainer : Theme.fgOnFill;
    }

    function kindIcon(k) {
        return page.kindIcons[k] || "category";
    }

    function kindName(k) {
        return page.kindNames[k] || "Other";
    }

    function low(v) {
        return !!v && v.avail / Math.max(1, v.used + v.avail) * 100 < Prefs.storageLowPercent;
    }

    function ago(t) {
        var d = Math.max(0, Date.now() / 1000 - t);
        if (d < 90)
            return "just now";

        if (d < 3600)
            return Math.round(d / 60) + " minutes ago";

        if (d < 86400) {
            var h = Math.round(d / 3600);
            return h === 1 ? "an hour ago" : h + " hours ago";
        }
        var days = Math.round(d / 86400);
        if (days === 1)
            return "yesterday";

        if (days < 14)
            return days + " days ago";

        if (days < 60)
            return Math.round(days / 7) + " weeks ago";

        if (days < 730)
            return Math.round(days / 30) + " months ago";

        return Math.round(days / 365) + " years ago";
    }

    function tilde(p) {
        return p === Storage.home ? "~" : (p.indexOf(Storage.home + "/") === 0 ? "~" + p.substring(Storage.home.length) : p);
    }

    function baseName(p) {
        return p.substring(p.lastIndexOf("/") + 1);
    }

    function dirName(p) {
        return p.substring(0, p.lastIndexOf("/")) || "/";
    }

    function count(n, one, many) {
        return n === 1 ? "1 " + one : Number(n).toLocaleString(Qt.locale(), "f", 0) + " " + many;
    }

    function listOf(names, shown) {
        if (names.length <= shown)
            return names.join(", ");

        return names.slice(0, shown).join(", ") + " and " + (names.length - shown) + " more";
    }

    // the words and the action behind one cleanup item
    function about(it) {
        if (it.id === "trash")
            return {
            "title": "Trash",
            "body": page.count(it.count, "item", "items") + " you deleted, still taking up room.",
            "verb": "Empty",
            "ask": "Empty the trash?",
            "askBody": "Everything in it is deleted for good. This cannot be undone."
        };

        if (it.id === "pacman")
            return {
            "title": "Old package downloads",
            "body": "pacman keeps every package it downloads. " + page.count(it.old, "is an older version", "are older versions") + " of what you have, and " + page.count(it.gone, "belongs", "belong") + " to software you removed. The version you have installed of each one stays. Asks for your password.",
            "verb": "Clean",
            "ask": "Clean the package cache?",
            "askBody": "pacman -Sc runs as root and keeps only the packages you have installed. Downgrading to an older version would mean downloading it again."
        };

        if (it.id === "orphans") {
            var names = (it.names || []).map((x) => {
                return x.n;
            });
            return {
                "title": "Unused dependencies",
                "body": page.count(it.count, "package was", "packages were") + " installed for something that is gone: " + page.listOf(names, 3) + ". Asks for your password.",
                "verb": "Remove",
                "ask": "Remove " + page.count(it.count, "package", "packages") + "?",
                "askBody": "pacman -Rns removes " + page.listOf(names, 24) + ". Each was pulled in by something no longer installed. If you use one of them directly, install it on purpose first."
            };
        }
        if (it.id === "journal")
            return {
            "title": "System logs",
            "body": "The journal takes " + Storage.size(it.total) + ". Shrinking it keeps the newest " + Storage.size(it.keep) + ". Asks for your password.",
            "verb": "Shrink",
            "ask": "Shrink the system logs?",
            "askBody": "journalctl deletes the oldest log files until " + Storage.size(it.keep) + " is left."
        };

        if (it.id === "coredumps")
            return {
            "title": "Crash dumps",
            "body": page.count(it.count, "memory snapshot", "memory snapshots") + " saved when programs crashed. They only matter if you are debugging those crashes. Asks for your password.",
            "verb": "Delete",
            "ask": "Delete the crash dumps?",
            "askBody": "Everything in /var/lib/systemd/coredump goes, and coredumpctl can no longer show those crashes."
        };

        if (it.id === "flatpak") {
            var refs = (it.names || []).map((x) => {
                return x.n;
            });
            return {
                "title": "Unused Flatpak runtimes",
                "body": page.count(it.count, "runtime", "runtimes") + " that no installed app needs any more.",
                "verb": "Remove",
                "ask": "Remove unused runtimes?",
                "askBody": "flatpak uninstall --unused removes " + page.listOf(refs, 12) + "."
            };
        }
        if (it.id === "othercaches")
            return {
            "title": "Other app caches",
            "body": "Kept by your apps, biggest first: " + (it.top || []).map((t) => {
                return t.n + " " + Storage.size(t.s);
            }).join(", ") + ". Close an app before clearing its cache by hand.",
            "verb": "Show",
            "show": it.path
        };

        if (it.id === "downloads")
            return {
            "title": "Old downloads",
            "body": page.count(it.count, "thing", "things") + " in " + page.tilde(it.path) + " have not changed in " + it.days + " days.",
            "verb": "Show",
            "show": it.path
        };

        var note = page.cacheNotes[it.id] || "Made again when needed.";
        return {
            "title": it.title || it.id,
            "body": note,
            "verb": "Clear",
            "ask": "Clear " + (it.title || "this cache").toLowerCase() + "?",
            "askBody": note + " Nothing you made is kept in here."
        };
    }

    function act(it) {
        var a = page.about(it);
        if (a.show)
            page.showInMap(a.show);
        else
            Prefs.askConfirm(a.ask, a.askBody, a.verb, "storage-clean:" + it.id);
    }

    function askTrash(path, size) {
        Prefs.askConfirm("Move to the trash?", "“" + page.baseName(path) + "” (" + Storage.size(size) + ") goes to the trash. The space comes back once the trash is emptied.", "Move", "storage-trash:" + path);
    }

    function showInMap(path) {
        var homeVol = null;
        for (var i = 0; i < Storage.volumes.length; i++) {
            if (Storage.volumes[i].home)
                homeVol = Storage.volumes[i];

        }
        if (homeVol && homeVol.mount !== page.mount && path.indexOf(Storage.home) === 0) {
            page.pendingPath = path;
            page.mount = homeVol.mount;
            return ;
        }
        if (!page.scan)
            return ;

        mapView.goTo(path);
        for (var p = page.parent; p; p = p.parent) {
            if (typeof p.scrollToItem === "function") {
                p.scrollToItem(mapCard);
                break;
            }
        }
    }

    // a drive never scanned, or not for six hours, is scanned once per visit
    function autoScan() {
        if (!page.wantsScan)
            return ;

        var a = Object.assign({}, page.autoScanned);
        a[page.mount] = true;
        page.autoScanned = a;
        Storage.scan(page.mount);
    }

    function wake() {
        Storage.refreshVolumes();
        Storage.probeTrim();
        if (!Storage.cleanup || Date.now() / 1000 - Storage.cleanup.time > 120)
            Storage.measure();

        if (page.mount !== "")
            Storage.ensure(page.mount);

    }

    spacing: Theme.dp(26)
    onPageShownChanged: {
        if (page.pageShown)
            page.wake();

    }
    onVolsChanged: {
        if (page.vols.length > 0 && !page.vols.some((v) => {
            return v.mount === page.mount;
        }))
            page.mount = page.vols[0].mount;

    }
    onMountChanged: {
        if (page.mount !== "")
            Storage.ensure(page.mount);

    }
    onWantsScanChanged: {
        if (page.wantsScan)
            Qt.callLater(page.autoScan);

    }
    onScanChanged: {
        if (page.scan && page.pendingPath !== "") {
            var p = page.pendingPath;
            page.pendingPath = "";
            Qt.callLater(page.showInMap, p);
        }
    }
    Component.onCompleted: {
        if (Storage.volumes.length === 0)
            Storage.refreshVolumes();

    }

    Connections {
        function onCleaned(r) {
            if (r.ok) {
                page.notice = r.freed > 0 ? "Done. " + Storage.size(r.freed) + " came back." : "Done.";
                page.noticeBad = false;
            } else if (r.error !== "cancelled") {
                page.notice = "That did not work: " + r.error;
                page.noticeBad = true;
            }
        }

        function onTrashed(path, ok) {
            if (!ok) {
                page.notice = "“" + page.baseName(path) + "” could not be moved to the trash.";
                page.noticeBad = true;
            }
        }

        target: Storage
    }

    M3Chips {
        width: parent.width
        visible: page.vols.length > 1
        options: page.vols.map((v) => {
            return {
                "key": v.mount,
                "label": v.name + "  ·  " + Storage.size(v.used + v.avail)
            };
        })
        current: page.mount
        onChosen: (k) => {
            page.mount = k;
        }
    }

    SettingCard {
        title: "OVERVIEW"

        StorageOverview {
            width: parent.width
            pal: page
            vol: page.vol
            scan: page.scan
            drive: page.drive
        }

    }

    SettingCard {
        id: mapCard

        title: "USAGE MAP"
        visible: page.scan !== null

        StorageMap {
            id: mapView

            width: parent.width
            pal: page
            scan: page.scan
            volName: page.vol ? page.vol.name : ""
            onTrashRequested: (path, node) => {
                return page.askTrash(path, node ? node.s : 0);
            }
        }

    }

    SettingCard {
        title: "FREE UP SPACE"
        subtitle: page.notice !== "" ? page.notice : (Storage.cleanup ? (page.reclaimable > 0 ? "About " + Storage.size(page.reclaimable) + " could go without touching anything you made. Each item asks before it deletes." : "Nothing here is worth clearing right now.") : "")

        SettingRow {
            title: Storage.measuring ? "Measuring" : "Waiting to measure"
            description: "Looking at caches, old packages and the trash."
            visible: !Storage.cleanup

            LoadingIndicator {
                width: Theme.dp(36)
                height: Theme.dp(36)
                running: parent.visible && !Storage.cleanup
            }

        }

        Repeater {
            model: page.systemItems

            StorageCleanRow {
                pal: page
            }

        }

    }

    SettingCard {
        title: "CACHES AND TRASH"
        subtitle: "Things your apps and tools keep around to save time. They come back on their own when needed."
        visible: page.cacheItems.length > 0

        Repeater {
            model: page.cacheItems

            StorageCleanRow {
                pal: page
            }

        }

    }

    SettingCard {
        title: "WORTH A LOOK"
        subtitle: "Not deleted from here, because only you can say what is still needed. Show opens them in the usage map."
        visible: page.reviewItems.length > 0

        Repeater {
            model: page.reviewItems

            StorageCleanRow {
                pal: page
            }

        }

    }

    SettingCard {
        title: "DUPLICATES"
        subtitle: "The same file in more than one place, matched by size and by samples of what is inside. Keeping one of each gets " + Storage.size(page.dupeWaste) + " back."
        visible: page.dupes.length > 0

        Repeater {
            model: page.allDupes ? page.dupes : page.dupes.slice(0, 4)

            SettingRow {
                id: dupeRow

                required property var modelData

                title: page.baseName(dupeRow.modelData.files[0].p)
                description: dupeRow.modelData.files.length + " copies of " + Storage.size(dupeRow.modelData.size) + ". Keeping one gets " + Storage.size(dupeRow.modelData.waste) + " back."
                stacked: true

                Column {
                    width: parent.width
                    spacing: Theme.dp(2)

                    Repeater {
                        model: dupeRow.modelData.files

                        Item {
                            id: copy

                            required property var modelData
                            required property int index

                            width: parent.width
                            height: Theme.dp(44)

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.dp(12)
                                color: Theme.bgSunken
                            }

                            Icon {
                                id: copyMark

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.dp(12)
                                anchors.verticalCenter: parent.verticalCenter
                                name: page.kindIcon(copy.modelData.k || 0)
                                size: Theme.dp(17)
                                color: Theme.subtext
                            }

                            Column {
                                anchors.left: copyMark.right
                                anchors.leftMargin: Theme.dp(10)
                                anchors.right: copyBtns.left
                                anchors.rightMargin: Theme.dp(8)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    width: parent.width
                                    text: page.baseName(copy.modelData.p) === dupeRow.title ? page.tilde(page.dirName(copy.modelData.p)) : page.tilde(copy.modelData.p)
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBodyMd
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    width: parent.width
                                    text: (copy.index === 0 ? "Oldest copy, changed " : "Changed ") + page.ago(copy.modelData.m)
                                    color: Theme.subtext
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabelMd
                                }

                            }

                            Row {
                                id: copyBtns

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.dp(4)
                                anchors.verticalCenter: parent.verticalCenter

                                M3IconButton {
                                    size: Theme.dp(36)
                                    iconPath: "folder_open"
                                    onClicked: Storage.reveal(copy.modelData.p)
                                }

                                M3IconButton {
                                    size: Theme.dp(36)
                                    iconPath: "delete"
                                    destructive: true
                                    enabled: Storage.trashing === ""
                                    onClicked: page.askTrash(copy.modelData.p, copy.modelData.s)
                                }

                            }

                        }

                    }

                }

            }

        }

        SettingRow {
            title: page.allDupes ? "Show fewer" : "Show " + (page.dupes.length - 4) + " more"
            visible: page.dupes.length > 4

            M3IconButton {
                iconPath: page.allDupes ? "expand_less" : "expand_more"
                onClicked: page.allDupes = !page.allDupes
            }

        }

    }

    SettingCard {
        title: "LARGEST FILES"
        subtitle: page.vol ? "Your biggest files on " + page.vol.name + "." : ""
        visible: page.large.length > 0

        Repeater {
            model: page.allLarge ? page.large.slice(0, 30) : page.large.slice(0, 8)

            SettingRow {
                id: bigRow

                required property var modelData

                title: page.baseName(bigRow.modelData.p)
                description: page.tilde(page.dirName(bigRow.modelData.p)) + "  ·  changed " + page.ago(bigRow.modelData.m)

                Row {
                    spacing: Theme.dp(4)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        rightPadding: Theme.dp(8)
                        text: Storage.size(bigRow.modelData.s)
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBodyLg
                        font.weight: Font.Medium
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconPath: "folder_open"
                        onClicked: Storage.reveal(bigRow.modelData.p)
                    }

                    M3IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconPath: "delete"
                        destructive: true
                        enabled: Storage.trashing === ""
                        onClicked: page.askTrash(bigRow.modelData.p, bigRow.modelData.s)
                    }

                }

            }

        }

        SettingRow {
            title: page.allLarge ? "Show fewer" : "Show " + (Math.min(30, page.large.length) - 8) + " more"
            visible: page.large.length > 8

            M3IconButton {
                iconPath: page.allLarge ? "expand_less" : "expand_more"
                onClicked: page.allLarge = !page.allLarge
            }

        }

    }

    SettingCard {
        title: "DRIVES"
        subtitle: Storage.mountError
        visible: Storage.drives.length > 0

        Repeater {
            model: Storage.drives

            SettingRow {
                id: driveRow

                required property var modelData
                readonly property var d: driveRow.modelData
                readonly property var h: Storage.health[driveRow.d.path] || null
                readonly property string kind: driveRow.d.removable ? "Removable drive" : (driveRow.d.rota ? "Hard drive" : (driveRow.d.tran === "nvme" ? "NVMe SSD" : "SSD"))

                title: driveRow.d.model || driveRow.d.name
                description: [driveRow.kind, Storage.size(driveRow.d.size), driveRow.d.temp > 0 ? Math.round(driveRow.d.temp) + " °C" : ""].filter((s) => {
                    return s !== "";
                }).join("  ·  ")
                stacked: true

                Column {
                    width: parent.width
                    spacing: Theme.dp(2)

                    Repeater {
                        model: driveRow.d.parts

                        StoragePartRow {
                            width: parent.width
                            part: modelData
                        }

                    }

                    M3Button {
                        anchors.right: parent.right
                        variant: "tonal"
                        text: "Eject"
                        visible: driveRow.d.removable
                        enabled: Storage.mounting === ""
                        onClicked: Storage.eject(driveRow.d.path, driveRow.d.parts.filter((p) => {
                            return (p.mounts || []).some((m) => {
                                return m.indexOf("/") === 0;
                            });
                        }).map((p) => {
                            return p.path;
                        }))
                    }

                    Item {
                        width: parent.width
                        height: Math.max(Theme.dp(48), healthText.implicitHeight + Theme.dp(16))

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.dp(12)
                            color: Theme.bgSunken
                        }

                        Icon {
                            id: healthMark

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            name: driveRow.h && driveRow.h.ok ? (driveRow.h.passed === false ? "warning" : "check_circle") : "monitor_heart"
                            size: Theme.dp(18)
                            fill: driveRow.h && driveRow.h.ok ? 1 : 0
                            color: driveRow.h && driveRow.h.ok ? (driveRow.h.passed === false ? Theme.error : Theme.success) : Theme.subtext
                        }

                        Text {
                            id: healthText

                            anchors.left: healthMark.right
                            anchors.leftMargin: Theme.dp(10)
                            anchors.right: healthBtn.left
                            anchors.rightMargin: Theme.dp(10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                var h = driveRow.h;
                                if (Storage.checking === driveRow.d.path)
                                    return "Asking the drive…";

                                if (!h)
                                    return "Health not checked. Reading it needs your password.";

                                if (!h.ok)
                                    return h.error === "cancelled" ? "Health not checked." : "Could not read its health: " + h.error;

                                var bits = [h.passed === false ? "The drive reports it is failing. Back up what matters on it." : "Healthy"];
                                if (h.wear !== undefined && h.wear !== null)
                                    bits.push(h.wear + "% worn");

                                if (h.hours)
                                    bits.push(Number(h.hours).toLocaleString(Qt.locale(), "f", 0) + " hours on");

                                if (h.written)
                                    bits.push(Storage.size(h.written) + " written");

                                if (h.mediaErrors)
                                    bits.push(h.mediaErrors + " media errors");

                                return bits.join("  ·  ");
                            }
                            color: driveRow.h && driveRow.h.ok && driveRow.h.passed === false ? Theme.error : Theme.subtext
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                            wrapMode: Text.WordWrap
                        }

                        M3Button {
                            id: healthBtn

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(4)
                            anchors.verticalCenter: parent.verticalCenter
                            variant: "text"
                            text: driveRow.h && driveRow.h.ok ? "Check again" : "Check"
                            enabled: Storage.checking === ""
                            onClicked: Storage.checkHealth(driveRow.d.path)
                        }

                    }

                }

            }

        }

        SettingRow {
            title: "Trim SSDs every week"
            description: "Tells each SSD which blocks are free, which keeps writes fast. This is fstrim.timer, and changing it asks for your password."
            visible: Storage.trimKnown && Storage.drives.some((d) => {
                return !d.rota;
            })

            M3Switch {
                checked: Storage.trimEnabled
                onToggled: (v) => {
                    return Storage.setTrim(v);
                }
            }

        }

    }

    SettingCard {
        title: "HOUSEKEEPING"

        SettingRow {
            title: "Warn when space runs low"
            resetKey: "storageLowWarn"
            description: "A notification when the system drive, or the one your home is on, gets below " + Prefs.storageLowPercent + "% free. Checked every ten minutes."

            M3Switch {
                checked: Prefs.storageLowWarn
                onToggled: (v) => {
                    return Prefs.storageLowWarn = v;
                }
            }

        }

        SettingRow {
            title: "Warn below"
            resetKey: "storageLowPercent"
            enabled: Prefs.storageLowWarn
            disabledReason: "Warnings are off."
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.storageLowWarn
                from: 5
                to: 25
                stepSize: 1
                suffix: "%"
                value: Prefs.storageLowPercent
                onMoved: (v) => {
                    return Prefs.storageLowPercent = Math.round(v);
                }
            }

        }

        SettingRow {
            title: "Empty the trash by itself"
            resetKey: "storageTrashDays"
            description: "Deletes what has been in the trash longer than this. Lucid checks when it starts and every six hours."
            stacked: true

            M3Chips {
                width: parent.width
                options: [{
                    "key": 0,
                    "label": "Never"
                }, {
                    "key": 7,
                    "label": "After a week"
                }, {
                    "key": 30,
                    "label": "After a month"
                }, {
                    "key": 90,
                    "label": "After three months"
                }]
                current: Prefs.storageTrashDays
                onChosen: (k) => {
                    Prefs.storageTrashDays = k;
                }
            }

        }

    }

}
