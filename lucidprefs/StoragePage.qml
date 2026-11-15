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
    readonly property var kindNames: [I18n.tr("Other"), I18n.tr("Videos"), I18n.tr("Pictures"), I18n.tr("Music"), I18n.tr("Documents"), I18n.tr("Archives"), I18n.tr("Code"), I18n.tr("Apps and libraries")]
    readonly property var kindIcons: ["category", "movie", "image", "music_note", "description", "archive", "code", "apps"]
    readonly property var cats: [{
        "key": "system",
        "label": I18n.tr("System"),
        "color": Theme.accent
    }, {
        "key": "apps",
        "label": I18n.tr("Apps and libraries"),
        "color": page.kindColors[7]
    }, {
        "key": "pkgcache",
        "label": I18n.tr("Package cache"),
        "color": page.hue(295)
    }, {
        "key": "caches",
        "label": I18n.tr("Caches"),
        "color": page.hue(262)
    }, {
        "key": "trash",
        "label": I18n.tr("Trash"),
        "color": Theme.error
    }, {
        "key": "video",
        "label": I18n.tr("Videos"),
        "color": page.kindColors[1]
    }, {
        "key": "image",
        "label": I18n.tr("Pictures"),
        "color": page.kindColors[2]
    }, {
        "key": "audio",
        "label": I18n.tr("Music"),
        "color": page.kindColors[3]
    }, {
        "key": "docs",
        "label": I18n.tr("Documents"),
        "color": page.kindColors[4]
    }, {
        "key": "archive",
        "label": I18n.tr("Archives"),
        "color": page.kindColors[5]
    }, {
        "key": "code",
        "label": I18n.tr("Code"),
        "color": page.kindColors[6]
    }, {
        "key": "other",
        "label": I18n.tr("Other files"),
        "color": Theme.accentContainer
    }, {
        "key": "hidden",
        "label": I18n.tr("Restricted"),
        "color": Theme.alpha(Theme.text, 0.22)
    }]
    readonly property var cacheNotes: ({
        "cache:thumbnails": I18n.tr("Small previews of your pictures and videos, made again as folders are opened."),
        "cache:pip": I18n.tr("Python packages pip downloaded, fetched again when a project needs them."),
        "cache:yay": I18n.tr("Sources and builds left over from installing AUR packages."),
        "cache:paru": I18n.tr("Sources and builds left over from installing AUR packages."),
        "cache:npm": I18n.tr("JavaScript packages npm downloaded, fetched again when a project needs them."),
        "cache:yarn": I18n.tr("JavaScript packages Yarn downloaded, fetched again when a project needs them."),
        "cache:bun": I18n.tr("JavaScript packages Bun downloaded, fetched again when a project needs them."),
        "cache:gobuild": I18n.tr("Compiled Go packages, rebuilt on the next build."),
        "cache:nodegyp": I18n.tr("Headers for building native Node modules, downloaded again when needed."),
        "cache:cargo": I18n.tr("Crates Cargo downloaded, fetched again on the next build."),
        "cache:gradle": I18n.tr("Dependencies of Java and Android builds, fetched again on the next build."),
        "cache:maven": I18n.tr("Dependencies of Java builds, fetched again on the next build."),
        "cache:electron": I18n.tr("Electron builds that development tools downloaded."),
        "cache:composer": I18n.tr("PHP packages Composer downloaded."),
        "cache:shaders": I18n.tr("Compiled shaders. Games and apps build them again, so their next start is slower.")
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
        return page.kindNames[k] || I18n.tr("Other");
    }

    function low(v) {
        return !!v && v.avail / Math.max(1, v.used + v.avail) * 100 < Prefs.storageLowPercent;
    }

    function ago(t) {
        var d = Math.max(0, Date.now() / 1000 - t);
        if (d < 90)
            return I18n.tr("just now");

        if (d < 3600)
            return I18n.tr("%1 minutes ago", Math.round(d / 60));

        if (d < 86400) {
            var h = Math.round(d / 3600);
            return h === 1 ? I18n.tr("an hour ago") : I18n.tr("%1 hours ago", h);
        }
        var days = Math.round(d / 86400);
        if (days === 1)
            return I18n.tr("yesterday");

        if (days < 14)
            return I18n.tr("%1 days ago", days);

        if (days < 60)
            return I18n.tr("%1 weeks ago", Math.round(days / 7));

        if (days < 730)
            return I18n.tr("%1 months ago", Math.round(days / 30));

        return I18n.tr("%1 years ago", Math.round(days / 365));
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
        return n === 1 ? "1 " + one : Number(n).toLocaleString(I18n.locale, "f", 0) + " " + many;
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
            "title": I18n.tr("Trash"),
            "body": I18n.tr("%1 you deleted, still taking up room.", page.count(it.count, "item", "items")),
            "verb": I18n.tr("Empty"),
            "ask": I18n.tr("Empty the trash?"),
            "askBody": I18n.tr("Everything in it is deleted for good. This cannot be undone.")
        };

        if (it.id === "pacman")
            return {
            "title": I18n.tr("Old package downloads"),
            "body": I18n.tr("pacman keeps every package it downloads. %1 of what you have, and %2 to software you removed. The version you have installed of each one stays. Asks for your password.", page.count(it.old, I18n.tr("is an older version"), I18n.tr("are older versions")), page.count(it.gone, I18n.tr("belongs"), I18n.tr("belong"))),
            "verb": I18n.tr("Clean"),
            "ask": I18n.tr("Clean the package cache?"),
            "askBody": I18n.tr("pacman -Sc runs as root and keeps only the packages you have installed. Downgrading to an older version would mean downloading it again.")
        };

        if (it.id === "orphans") {
            var names = (it.names || []).map((x) => {
                return x.n;
            });
            return {
                "title": I18n.tr("Unused dependencies"),
                "body": I18n.tr("%1 installed for something that is gone: %2. Asks for your password.", page.count(it.count, I18n.tr("package was"), I18n.tr("packages were")), page.listOf(names, 3)),
                "verb": I18n.tr("Remove"),
                "ask": I18n.tr("Remove %1?", page.count(it.count, "package", "packages")),
                "askBody": I18n.tr("pacman -Rns removes %1. Each was pulled in by something no longer installed. If you use one of them directly, install it on purpose first.", page.listOf(names, 24))
            };
        }
        if (it.id === "journal")
            return {
            "title": I18n.tr("System logs"),
            "body": I18n.tr("The journal takes %1. Shrinking it keeps the newest %2. Asks for your password.", Storage.size(it.total), Storage.size(it.keep)),
            "verb": I18n.tr("Shrink"),
            "ask": I18n.tr("Shrink the system logs?"),
            "askBody": I18n.tr("journalctl deletes the oldest log files until %1 is left.", Storage.size(it.keep))
        };

        if (it.id === "coredumps")
            return {
            "title": I18n.tr("Crash dumps"),
            "body": I18n.tr("%1 saved when programs crashed. They only matter if you are debugging those crashes. Asks for your password.", page.count(it.count, I18n.tr("memory snapshot"), I18n.tr("memory snapshots"))),
            "verb": I18n.tr("Delete"),
            "ask": I18n.tr("Delete the crash dumps?"),
            "askBody": "Everything in /var/lib/systemd/coredump goes, and coredumpctl can no longer show those crashes."
        };

        if (it.id === "flatpak") {
            var refs = (it.names || []).map((x) => {
                return x.n;
            });
            return {
                "title": I18n.tr("Unused Flatpak runtimes"),
                "body": I18n.tr("%1 that no installed app needs any more.", page.count(it.count, "runtime", "runtimes")),
                "verb": I18n.tr("Remove"),
                "ask": I18n.tr("Remove unused runtimes?"),
                "askBody": "flatpak uninstall --unused removes " + page.listOf(refs, 12) + "."
            };
        }
        if (it.id === "othercaches")
            return {
            "title": I18n.tr("Other app caches"),
            "body": I18n.tr("Kept by your apps, biggest first: %1. Close an app before clearing its cache by hand.", (it.top || []).map((t) => {
                return t.n + " " + Storage.size(t.s);
            }).join(", ")),
            "verb": I18n.tr("Show"),
            "show": it.path
        };

        if (it.id === "downloads")
            return {
            "title": I18n.tr("Old downloads"),
            "body": I18n.tr("%1 in %2 have not changed in %3 days.", page.count(it.count, "thing", "things"), page.tilde(it.path), it.days),
            "verb": I18n.tr("Show"),
            "show": it.path
        };

        var note = page.cacheNotes[it.id] || I18n.tr("Made again when needed.");
        return {
            "title": it.title || it.id,
            "body": note,
            "verb": I18n.tr("Clear"),
            "ask": I18n.tr("Clear %1?", (it.title || I18n.tr("this cache")).toLowerCase()),
            "askBody": I18n.tr("%1 Nothing you made is kept in here.", note)
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
        Prefs.askConfirm(I18n.tr("Move to the trash?"), I18n.tr("“%1” (%2) goes to the trash. The space comes back once the trash is emptied.", page.baseName(path), Storage.size(size)), I18n.tr("Move"), "storage-trash:" + path);
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
                page.notice = r.freed > 0 ? I18n.tr("Done. %1 came back.", Storage.size(r.freed)) : "Done.";
                page.noticeBad = false;
            } else if (r.error !== "cancelled") {
                page.notice = I18n.tr("That did not work: %1", r.error);
                page.noticeBad = true;
            }
        }

        function onTrashed(path, ok) {
            if (!ok) {
                page.notice = I18n.tr("“%1” could not be moved to the trash.", page.baseName(path));
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
        title: I18n.tr("OVERVIEW")

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

        title: I18n.tr("USAGE MAP")
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
        title: I18n.tr("FREE UP SPACE")
        subtitle: page.notice !== "" ? page.notice : (Storage.cleanup ? (page.reclaimable > 0 ? I18n.tr("About %1 could go without touching anything you made. Each item asks before it deletes.", Storage.size(page.reclaimable)) : I18n.tr("Nothing here is worth clearing right now.")) : "")

        SettingRow {
            title: Storage.measuring ? I18n.tr("Measuring") : I18n.tr("Waiting to measure")
            description: I18n.tr("Looking at caches, old packages and the trash.")
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
        title: I18n.tr("CACHES AND TRASH")
        subtitle: I18n.tr("Things your apps and tools keep around to save time. They come back on their own when needed.")
        visible: page.cacheItems.length > 0

        Repeater {
            model: page.cacheItems

            StorageCleanRow {
                pal: page
            }

        }

    }

    SettingCard {
        title: I18n.tr("WORTH A LOOK")
        subtitle: I18n.tr("Not deleted from here, because only you can say what is still needed. Show opens them in the usage map.")
        visible: page.reviewItems.length > 0

        Repeater {
            model: page.reviewItems

            StorageCleanRow {
                pal: page
            }

        }

    }

    SettingCard {
        title: I18n.tr("DUPLICATES")
        subtitle: I18n.tr("The same file in more than one place, matched by size and by samples of what is inside. Keeping one of each gets %1 back.", Storage.size(page.dupeWaste))
        visible: page.dupes.length > 0

        Repeater {
            model: page.allDupes ? page.dupes : page.dupes.slice(0, 4)

            SettingRow {
                id: dupeRow

                required property var modelData

                title: page.baseName(dupeRow.modelData.files[0].p)
                description: I18n.tr("%1 copies of %2. Keeping one gets %3 back.", dupeRow.modelData.files.length, Storage.size(dupeRow.modelData.size), Storage.size(dupeRow.modelData.waste))
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
                                radius: Theme.rad(12)
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
                                    text: (copy.index === 0 ? I18n.tr("Oldest copy, changed ") : I18n.tr("Changed ")) + page.ago(copy.modelData.m)
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
            title: page.allDupes ? I18n.tr("Show fewer") : I18n.tr("Show %1 more", (page.dupes.length - 4))
            visible: page.dupes.length > 4

            M3IconButton {
                iconPath: page.allDupes ? "expand_less" : "expand_more"
                onClicked: page.allDupes = !page.allDupes
            }

        }

    }

    SettingCard {
        title: I18n.tr("LARGEST FILES")
        subtitle: page.vol ? I18n.tr("Your biggest files on %1.", page.vol.name) : ""
        visible: page.large.length > 0

        Repeater {
            model: page.allLarge ? page.large.slice(0, 30) : page.large.slice(0, 8)

            SettingRow {
                id: bigRow

                required property var modelData

                title: page.baseName(bigRow.modelData.p)
                description: I18n.tr("%1  ·  changed %2", page.tilde(page.dirName(bigRow.modelData.p)), page.ago(bigRow.modelData.m))

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
            title: page.allLarge ? I18n.tr("Show fewer") : I18n.tr("Show %1 more", (Math.min(30, page.large.length) - 8))
            visible: page.large.length > 8

            M3IconButton {
                iconPath: page.allLarge ? "expand_less" : "expand_more"
                onClicked: page.allLarge = !page.allLarge
            }

        }

    }

    SettingCard {
        title: I18n.tr("DRIVES")
        subtitle: Storage.mountError
        visible: Storage.drives.length > 0

        Repeater {
            model: Storage.drives

            SettingRow {
                id: driveRow

                required property var modelData
                readonly property var d: driveRow.modelData
                readonly property var h: Storage.health[driveRow.d.path] || null
                readonly property string kind: driveRow.d.removable ? I18n.tr("Removable drive") : (driveRow.d.rota ? I18n.tr("Hard drive") : (driveRow.d.tran === "nvme" ? I18n.tr("NVMe SSD") : "SSD"))

                title: driveRow.d.model || driveRow.d.name
                description: [driveRow.kind, Storage.size(driveRow.d.size), driveRow.d.temp > 0 ? Units.degUnit(driveRow.d.temp) : ""].filter((s) => {
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
                        text: I18n.tr("Eject")
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
                            radius: Theme.rad(12)
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
                                    return I18n.tr("Asking the drive…");

                                if (!h)
                                    return I18n.tr("Health not checked. Reading it needs your password.");

                                if (!h.ok)
                                    return h.error === "cancelled" ? I18n.tr("Health not checked.") : I18n.tr("Could not read its health: %1", h.error);

                                var bits = [h.passed === false ? I18n.tr("The drive reports it is failing. Back up what matters on it.") : I18n.tr("Healthy")];
                                if (h.wear !== undefined && h.wear !== null)
                                    bits.push(I18n.tr("%1% worn", h.wear));

                                if (h.hours)
                                    bits.push(Number(h.hours).toLocaleString(I18n.locale, "f", 0) + " hours on");

                                if (h.written)
                                    bits.push(I18n.tr("%1 written", Storage.size(h.written)));

                                if (h.mediaErrors)
                                    bits.push(I18n.tr("%1 media errors", h.mediaErrors));

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
                            text: driveRow.h && driveRow.h.ok ? I18n.tr("Check again") : I18n.tr("Check")
                            enabled: Storage.checking === ""
                            onClicked: Storage.checkHealth(driveRow.d.path)
                        }

                    }

                }

            }

        }

        SettingRow {
            title: I18n.tr("Trim SSDs every week")
            description: I18n.tr("Tells each SSD which blocks are free, which keeps writes fast. This is fstrim.timer, and changing it asks for your password.")
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
        title: I18n.tr("HOUSEKEEPING")

        SettingRow {
            title: I18n.tr("Warn when space runs low")
            resetKey: "storageLowWarn"
            description: I18n.tr("A notification when the system drive, or the one your home is on, gets below %1% free. Checked every ten minutes.", Prefs.storageLowPercent)

            M3Switch {
                checked: Prefs.storageLowWarn
                onToggled: (v) => {
                    return Prefs.storageLowWarn = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Warn below")
            resetKey: "storageLowPercent"
            enabled: Prefs.storageLowWarn
            disabledReason: I18n.tr("Warnings are off.")
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
            title: I18n.tr("Empty the trash by itself")
            resetKey: "storageTrashDays"
            description: I18n.tr("Deletes what has been in the trash longer than this. Lucid checks when it starts and every six hours.")
            stacked: true

            M3Chips {
                width: parent.width
                options: [{
                    "key": 0,
                    "label": I18n.tr("Never")
                }, {
                    "key": 7,
                    "label": I18n.tr("After a week")
                }, {
                    "key": 30,
                    "label": I18n.tr("After a month")
                }, {
                    "key": 90,
                    "label": I18n.tr("After three months")
                }]
                current: Prefs.storageTrashDays
                onChosen: (k) => {
                    Prefs.storageTrashDays = k;
                }
            }

        }

    }

}
