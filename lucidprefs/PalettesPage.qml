import QtQuick
import Quickshell
import Quickshell.Io
import qs

// where palettes come from beyond the ones Lucid ships: the tinted-theming
// gallery, a scheme repo, or a single file. add-theme.py turns each into a
// theme; scheme-gallery.py keeps the gallery. the palette on screen can also
// be edited here and written out (palette-edit.py)
Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property string currentTheme: Prefs.currentTheme

    // the gallery, as scheme-gallery.py indexed it
    property var schemes: []
    property int galleryUpdated: 0
    // idle | working | error
    property string galleryState: "idle"
    property string galleryError: ""
    property string query: ""
    property string variant: "all"
    // cards drawn so far; the rest wait behind "Show more"
    property int shown: 48
    readonly property var filtered: {
        var q = page.query.trim().toLowerCase();
        return page.schemes.filter((s) => {
            if (page.variant !== "all" && s.variant !== page.variant)
                return false;

            return q === "" || s.name.toLowerCase().indexOf(q) >= 0 || s.author.toLowerCase().indexOf(q) >= 0 || s.system === q;
        });
    }
    // gallery id -> the theme it became, for the ones already added
    readonly property var added: {
        var out = {};
        var list = Prefs.userThemes || [];
        for (var i = 0; i < list.length; i++) {
            var src = list[i].source || "";
            if (src.indexOf("tinted:") === 0)
                out[src.slice(7)] = list[i].id;

        }
        return out;
    }
    // the gallery scheme being added, and whether to switch to it after
    property string busyScheme: ""
    property bool useAfter: false

    // the repo or file import: idle | working | done | error
    property string addState: "idle"
    property string addMessage: ""
    property var addResult: null
    property string repoUrl: ""
    property string filePath: ""

    // the name the palette on screen goes by: a fixed theme's own, and none
    // for the ones made from a wallpaper or a colour
    readonly property string themeLabel: {
        if (["matugen", "pywal", "colour"].indexOf(page.currentTheme) >= 0)
            return "";

        var list = Prefs.themeCatalogue || [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === page.currentTheme)
                return list[i].name;

        }
        return "";
    }
    // export: lucid | base16, and idle | working | done | error
    property string exportFormat: "lucid"
    property string exportState: "idle"
    property string exportMessage: ""
    readonly property string exportName: paletteEditor.editing ? paletteEditor.themeName : (page.themeLabel || "My palette")

    function applyTheme(id) {
        if (id !== page.currentTheme)
            Prefs.themeChangeRequested(id);

    }

    function importFrom(source, working) {
        if (source.trim() === "" || page.addState === "working")
            return ;

        page.addState = "working";
        page.addMessage = working;
        page.addResult = null;
        themeImport.running = false;
        themeImport.command = ["python3", page.home + "/.config/lucid/add-theme.py", source.trim()];
        themeImport.running = true;
    }

    function addScheme(scheme, use) {
        if (page.busyScheme !== "")
            return ;

        if (page.added[scheme.id] !== undefined) {
            if (use)
                page.applyTheme(page.added[scheme.id]);

            return ;
        }
        page.busyScheme = scheme.id;
        page.useAfter = use;
        galleryImport.running = false;
        galleryImport.command = ["python3", page.home + "/.config/lucid/add-theme.py", scheme.file, "--name", scheme.name, "--source", "tinted:" + scheme.id];
        galleryImport.running = true;
    }

    function updateGallery() {
        if (page.galleryState === "working")
            return ;

        page.galleryState = "working";
        page.galleryError = "";
        galleryUpdate.running = false;
        galleryUpdate.command = ["python3", page.home + "/.config/lucid/scheme-gallery.py", "update"];
        galleryUpdate.running = true;
    }

    spacing: 26
    onQueryChanged: page.shown = 48
    onVariantChanged: page.shown = 48

    FileView {
        id: indexFile

        path: page.home + "/.cache/lucid/schemes/index.json"
        watchChanges: true
        printErrors: false
        onFileChanged: indexFile.reload()
        onLoaded: {
            try {
                var data = JSON.parse(indexFile.text());
                page.schemes = data.schemes || [];
                page.galleryUpdated = data.updated || 0;
            } catch (e) {
                page.schemes = [];
            }
        }
        // not downloaded yet, or the cache was cleared
        onLoadFailed: {
            page.schemes = [];
            page.galleryUpdated = 0;
        }
    }

    Process {
        id: galleryUpdate

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text.trim());
                } catch (e) {
                }
                page.galleryState = r && r.ok ? "idle" : "error";
                page.galleryError = r && !r.ok ? r.error : (r ? "" : "The gallery could not be read.");
                indexFile.reload();
            }
        }

    }

    Process {
        id: galleryImport

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text.trim());
                } catch (e) {
                }
                page.busyScheme = "";
                if (!r || !r.ok) {
                    page.galleryError = r && r.error ? r.error : "That scheme could not be added.";
                    return ;
                }
                Prefs.rescanThemes();
                if (page.useAfter)
                    page.applyTheme(r.id);

            }
        }

    }

    Process {
        id: themeImport

        property string errText: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text.trim());
                } catch (e) {
                    r = null;
                }
                if (!r) {
                    page.addState = "error";
                    // a crash leaves stdout empty, so the traceback is the only clue
                    page.addMessage = themeImport.errText.trim().split("\n").pop() || "Import failed.";
                    return ;
                }
                if (!r.ok) {
                    page.addState = "error";
                    page.addMessage = r.error;
                    return ;
                }
                page.addState = "done";
                page.addResult = r;
                // the generated description is the point; the wallpaper count is an aside
                page.addMessage = r.desc + (r.wallpapers > 0 ? "  \u00b7  " + r.wallpapers + " wallpapers" : "");
                Prefs.rescanThemes();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: themeImport.errText = text
        }

    }

    Process {
        id: exportPicker

        stdout: StdioCollector {
            onStreamFinished: {
                var dest = text.trim();
                if (dest === "") {
                    page.exportState = "idle";
                    return ;
                }
                exporter.running = false;
                exporter.command = ["python3", page.home + "/.config/lucid/palette-edit.py", "export", paletteEditor.palettePath, page.exportFormat, dest, page.exportName, Prefs.colorMode];
                exporter.running = true;
            }
        }

    }

    Process {
        id: exporter

        stdout: StdioCollector {
            onStreamFinished: {
                var r = null;
                try {
                    r = JSON.parse(text.trim());
                } catch (e) {
                }
                page.exportState = r && r.ok ? "done" : "error";
                page.exportMessage = r ? (r.ok ? "Written to " + r.file.replace(page.home, "~") + "." : r.error) : "The palette could not be written.";
            }
        }

    }

    Process {
        id: filePicker

        stdout: StdioCollector {
            onStreamFinished: {
                var chosen = text.trim();
                if (chosen !== "")
                    fileField.set(chosen);

            }
        }

    }

    SettingCard {
        title: "GALLERY"
        subtitle: "Colour schemes from tinted-theming, base16 and base24, each drawn in its own colours. Add one to your themes, or use it straight away."

        SettingRow {
            title: page.schemes.length > 0 ? page.schemes.length + " schemes" : "Not downloaded yet"
            description: page.galleryState === "working" ? "Downloading..." : (page.galleryState === "error" ? page.galleryError : (page.schemes.length > 0 ? "Downloaded " + new Date(page.galleryUpdated * 1000).toLocaleDateString(Qt.locale(), Locale.ShortFormat) + " from github.com/tinted-theming/schemes." : "About half a megabyte from github.com/tinted-theming/schemes, kept in ~/.cache/lucid/schemes."))

            M3Button {
                text: page.galleryState === "working" ? "Downloading..." : (page.schemes.length > 0 ? "Update" : "Download")
                variant: page.schemes.length > 0 ? "tonal" : "filled"
                enabled: page.galleryState !== "working"
                onClicked: page.updateGallery()
            }

        }

        SettingRow {
            title: "Browse"
            description: page.filtered.length === page.schemes.length ? "Hover a scheme to add it or use it." : page.filtered.length + " of " + page.schemes.length + " match."
            visible: page.schemes.length > 0
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 14

                Row {
                    spacing: 10

                    M3TextField {
                        width: 280
                        placeholder: "Search by name or author"
                        onEdited: (v) => {
                            return page.query = v;
                        }
                    }

                    M3Segmented {
                        width: 250
                        anchors.verticalCenter: parent.verticalCenter
                        current: page.variant
                        options: [{
                            "key": "all",
                            "label": "All"
                        }, {
                            "key": "dark",
                            "label": "Dark"
                        }, {
                            "key": "light",
                            "label": "Light"
                        }]
                        onChosen: (key) => {
                            return page.variant = key;
                        }
                    }

                }

                Flow {
                    width: parent.width
                    spacing: 10

                    Repeater {
                        model: page.filtered.slice(0, page.shown)

                        delegate: SchemeCard {
                            required property var modelData

                            scheme: modelData
                            added: page.added[modelData.id] !== undefined
                            busy: page.busyScheme === modelData.id
                            onAddRequested: page.addScheme(modelData, false)
                            onUseRequested: page.addScheme(modelData, true)
                        }

                    }

                }

                M3Button {
                    visible: page.filtered.length > page.shown
                    text: "Show more (" + (page.filtered.length - page.shown) + " left)"
                    onClicked: page.shown += 48
                }

            }

        }

    }

    SettingCard {
        title: "IMPORT"

        SettingRow {
            title: "Import a scheme"
            description: "From a colour-scheme repo, or a file you have. base16 and base24 YAML, name-keyed JSON (Catppuccin and friends) and palettes Lucid exported are read exactly; anything else gives up its hex codes, sorted by tone. A repo's wallpapers come along with it."
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 12

                Row {
                    spacing: 10

                    M3TextField {
                        id: repoField

                        width: 360
                        placeholder: "https://github.com/catppuccin/palette"
                        enabled: page.addState !== "working"
                        onEdited: (v) => {
                            return page.repoUrl = v;
                        }
                        onAccepted: (v) => {
                            page.repoUrl = v;
                            page.importFrom(v, "Cloning and reading the scheme...");
                        }
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Import repo"
                        variant: "filled"
                        enabled: page.repoUrl.trim() !== "" && page.addState !== "working"
                        iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                        onClicked: page.importFrom(page.repoUrl, "Cloning and reading the scheme...")
                    }

                }

                Row {
                    spacing: 10

                    M3TextField {
                        id: fileField

                        width: 360
                        placeholder: "A scheme file, like ~/Downloads/nord.yaml"
                        enabled: page.addState !== "working"
                        onEdited: (v) => {
                            return page.filePath = v;
                        }
                        onAccepted: (v) => {
                            page.filePath = v;
                            page.importFrom(v, "Reading the scheme...");
                        }
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Choose..."
                        enabled: page.addState !== "working"
                        onClicked: {
                            filePicker.command = ["sh", "-c", "zenity --file-selection --title='Choose a colour scheme' 2>/dev/null || true"];
                            filePicker.running = true;
                        }
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Import file"
                        variant: "filled"
                        enabled: page.filePath.trim() !== "" && page.addState !== "working"
                        iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                        onClicked: page.importFrom(page.filePath, "Reading the scheme...")
                    }

                }


                Rectangle {
                    width: parent.width
                    height: status.implicitHeight + 24
                    radius: Theme.radiusSm
                    color: Theme.bgSunken
                    visible: page.addState !== "idle"

                    Row {
                        id: status

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState === "done" && page.addResult !== null
                            color: page.addResult ? page.addResult.swatchBg : "transparent"

                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.centerIn: parent
                                color: page.addResult ? page.addResult.swatchAccent : "transparent"
                            }

                        }

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState !== "done"
                            color: page.addState === "error" ? Theme.alpha(Theme.error, 0.18) : Theme.alpha(Theme.accent, 0.18)

                            Text {
                                anchors.centerIn: parent
                                text: page.addState === "error" ? "!" : "..."
                                color: page.addState === "error" ? Theme.error : Theme.accent
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontTitle
                                font.bold: true
                            }

                        }

                        Column {
                            width: status.width - 180
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                text: {
                                    if (page.addState === "working")
                                        return "Importing...";

                                    if (page.addState === "error")
                                        return "Could not import it";

                                    return page.addResult ? page.addResult.name : "";
                                }
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontLabel
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: page.addMessage
                                color: page.addState === "error" ? Theme.error : Theme.subtext
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }

                        }

                        M3Button {
                            text: "Apply"
                            variant: "filled"
                            anchors.verticalCenter: parent.verticalCenter
                            visible: page.addState === "done" && page.addResult !== null
                            onClicked: {
                                page.applyTheme(page.addResult.id);
                                page.addState = "idle";
                                repoField.set("");
                                fileField.set("");
                            }
                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "EDITOR"
        subtitle: "The palette on screen, one colour at a time. The shell wears the draft while you work on it."

        SettingRow {
            title: "Edit the palette"
            description: "Pick a key colour and change it: the rest of the palette is built again from the six, the way an imported scheme is, and a colour that would not read against the background is moved to one that does. Any other role can be set by itself. Nothing is kept until you save it as a theme."
            showDivider: false
            stacked: true

            PaletteEditor {
                id: paletteEditor

                width: parent.width
                baseName: page.themeLabel
            }

        }

    }

    SettingCard {
        title: "EXPORT"

        SettingRow {
            title: "Save the palette to a file"
            description: "The palette on screen, draft included. A Lucid palette keeps every role and imports back exactly as it is; base16 YAML works with tinted-theming's tools and templates, and anything else that reads base16."
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 12

                Row {
                    spacing: 10

                    M3Segmented {
                        width: 300
                        anchors.verticalCenter: parent.verticalCenter
                        current: page.exportFormat
                        options: [{
                            "key": "lucid",
                            "label": "Lucid palette"
                        }, {
                            "key": "base16",
                            "label": "base16 YAML"
                        }]
                        onChosen: (key) => {
                            return page.exportFormat = key;
                        }
                    }

                    M3Button {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.exportState === "working" ? "Saving..." : "Save as..."
                        variant: "filled"
                        enabled: page.exportState !== "working"
                        onClicked: {
                            page.exportState = "working";
                            page.exportMessage = "";
                            var file = page.exportName.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "palette";
                            exportPicker.running = false;
                            exportPicker.command = ["sh", "-c", "zenity --file-selection --save --title='Export the palette' --filename=\"$1\" 2>/dev/null || true", "sh", page.home + "/" + file + (page.exportFormat === "lucid" ? ".json" : ".yaml")];
                            exportPicker.running = true;
                        }
                    }

                }

                Text {
                    width: parent.width
                    visible: page.exportMessage !== ""
                    text: page.exportMessage
                    color: page.exportState === "error" ? Theme.error : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    wrapMode: Text.WordWrap
                }

            }

        }

    }

}
