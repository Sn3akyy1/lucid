import QtQuick
import Quickshell
import Quickshell.Io
import qs

// how the palettes matugen builds are shaped (from the wallpaper, or from one
// colour of your own), and the applications that follow the palette: every
// matugen template, how the last change rendered it, the ones Lucid can wire
// up for apps already installed, and your own. Templates.qml does the work
// for the templates, set-mode.sh rebuilds the palette
Column {
    id: page

    readonly property string home: Quickshell.env("HOME")
    readonly property string currentTheme: Prefs.currentTheme
    // the wallpaper on screen, whose colours the generator card offers
    property string appliedWallpaper: ""
    // the themes matugen builds, which the generator settings reshape
    readonly property bool generated: page.currentTheme === "matugen" || page.currentTheme === "colour"
    readonly property var styles: [{
        "key": "scheme-tonal-spot",
        "label": I18n.tr("Tonal"),
        "hint": I18n.tr("Calm tones of one hue. Material's default.")
    }, {
        "key": "scheme-vibrant",
        "label": I18n.tr("Vibrant"),
        "hint": I18n.tr("The most colourful take on it.")
    }, {
        "key": "scheme-expressive",
        "label": I18n.tr("Expressive"),
        "hint": I18n.tr("Turns the hues around the wheel for livelier, less expected pairings.")
    }, {
        "key": "scheme-fidelity",
        "label": I18n.tr("Fidelity"),
        "hint": I18n.tr("Keeps the accent as close to the colour itself as it can.")
    }, {
        "key": "scheme-content",
        "label": I18n.tr("Content"),
        "hint": I18n.tr("Like Fidelity, with the accent taken straight from the colour.")
    }, {
        "key": "scheme-rainbow",
        "label": I18n.tr("Rainbow"),
        "hint": I18n.tr("Playful accents over neutral surfaces; the colour's own hue steps aside.")
    }, {
        "key": "scheme-fruit-salad",
        "label": I18n.tr("Fruit salad"),
        "hint": I18n.tr("A playful mix of hues; the colour's own hue steps aside.")
    }, {
        "key": "scheme-neutral",
        "label": I18n.tr("Neutral"),
        "hint": I18n.tr("Nearly grey, with a trace of the colour.")
    }, {
        "key": "scheme-monochrome",
        "label": I18n.tr("Monochrome"),
        "hint": I18n.tr("Greys only.")
    }]
    readonly property string styleHint: {
        for (var i = 0; i < page.styles.length; i++) {
            if (page.styles[i].key === Prefs.matugenScheme)
                return page.styles[i].hint;

        }
        return "";
    }
    // the wallpaper colour in use: the picked one while it is that picture's
    readonly property int wallpaperColourIndex: Prefs.matugenSourceImage !== "" && Prefs.matugenSourceImage === page.appliedWallpaper ? Prefs.matugenSourceIndex : 0

    // a generator setting changed: store it, and rebuild the palette if the
    // theme on screen is one matugen builds
    function setGenerator(key, value) {
        Prefs.set(key, value);
        if (page.generated)
            regenerate.restart();

    }

    function setThemeColour(hex) {
        Prefs.set("themeColour", hex);
        if (page.currentTheme === "colour")
            regenerate.restart();

    }
    // for "n minutes ago" in the templates summary
    property real now: Date.now()
    readonly property string templatesSummary: {
        var rec = Templates.record;
        if (rec.time === undefined)
            return I18n.tr("Nothing rendered yet. The templates render on the next change of theme or wallpaper.");

        var source = rec.source;
        var themes = Prefs.themeCatalogue;
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === rec.source)
                source = themes[i].name;

        }
        var mins = Math.max(0, Math.round((page.now / 1000 - rec.time) / 60));
        var when = mins < 1 ? "just now" : (mins < 60 ? mins + " min ago" : (mins < 1440 ? Math.round(mins / 60) + " h ago" : Math.round(mins / 1440) + " d ago"));
        var parts = [I18n.tr("%1 rendered", Templates.renderedCount)];
        if (Templates.failedCount > 0)
            parts.push(I18n.tr("%1 failed", Templates.failedCount));

        return parts.join(", ") + " · " + source + ", " + rec.mode + ", " + when;
    }

    function applyTheme(id) {
        if (id !== page.currentTheme)
            Prefs.themeChangeRequested(id);

    }

    spacing: Theme.dp(26)
    Component.onCompleted: Templates.refresh()

    FileView {
        path: page.home + "/.cache/current_wallpaper"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.appliedWallpaper = text().trim()
    }

    // prefs.json is written a moment after a change, so the new values ride
    // along in the environment. set-mode.sh rebuilds whatever theme is on
    Timer {
        id: regenerate

        interval: 400
        onTriggered: Quickshell.execDetached(["env", "LUCID_MATUGEN_SCHEME=" + Prefs.matugenScheme, "LUCID_MATUGEN_CONTRAST=" + Prefs.matugenContrast, "LUCID_MATUGEN_SOURCE_IMAGE=" + Prefs.matugenSourceImage, "LUCID_MATUGEN_SOURCE_INDEX=" + Prefs.matugenSourceIndex, "LUCID_THEME_COLOUR=" + Prefs.themeColour, page.home + "/.config/lucid/set-mode.sh", Prefs.colorMode])
    }

    Timer {
        interval: 30000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: page.now = Date.now()
    }

    SettingCard {
        title: I18n.tr("GENERATED PALETTES")
        subtitle: I18n.tr("How Matugen builds a palette from your wallpaper, and Your colour from one colour you pick.")

        SettingRow {
            title: I18n.tr("Your colour")
            description: I18n.tr("What the Your colour theme is built from. Pick it from anywhere on screen, type it, or start from one of these.")
            stacked: true

            ThemeColourPicker {
                width: parent.width
                colour: Prefs.themeColour
                inUse: page.currentTheme === "colour"
                onPicked: (hex) => {
                    return page.setThemeColour(hex);
                }
                onUseIt: page.applyTheme("colour")
            }

        }

        SettingRow {
            title: I18n.tr("Style")
            description: page.styleHint
            enabled: page.generated
            disabledReason: I18n.tr("Only for Matugen and Your colour, which matugen builds; Pywal and the fixed themes bring their own palette.")
            stacked: true

            M3Chips {
                width: parent.width
                enabled: page.generated
                current: Prefs.matugenScheme
                options: page.styles
                onChosen: (key) => {
                    return page.setGenerator("matugenScheme", key);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Contrast")
            description: I18n.tr("How far apart text and surfaces sit. 0 is the design as specified.")
            enabled: page.generated
            disabledReason: I18n.tr("Only for Matugen and Your colour, which matugen builds; Pywal and the fixed themes bring their own palette.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: page.generated
                from: -100
                to: 100
                stepSize: 10
                decimals: 0
                suffix: " %"
                value: Math.round(Prefs.matugenContrast * 100)
                onMoved: (v) => {
                    return page.setGenerator("matugenContrast", v / 100);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Colour from the wallpaper")
            description: I18n.tr("The colours Matugen finds in the wallpaper, most dominant first, each shown as the accent it gives. The pick holds for this wallpaper; another one starts from its most dominant.")
            enabled: page.currentTheme === "matugen"
            disabledReason: I18n.tr("Only for Matugen, which builds the palette from the wallpaper.")
            showDivider: false
            stacked: true

            WallpaperColours {
                width: parent.width
                image: page.appliedWallpaper
                current: page.wallpaperColourIndex
                active: page.currentTheme === "matugen"
                onChosen: (index) => {
                    Prefs.set("matugenSourceImage", page.appliedWallpaper);
                    page.setGenerator("matugenSourceIndex", index);
                }
            }

        }

    }

    SettingCard {
        id: templatesCard

        title: I18n.tr("APP TEMPLATES")
        subtitle: I18n.tr("Each template writes the palette into an application's own config whenever the theme or the wallpaper changes, the fixed themes included.")

        SettingRow {
            title: I18n.tr("Last change")
            description: page.templatesSummary

            M3Button {
                text: Templates.busy === "*" ? I18n.tr("Rendering...") : I18n.tr("Render again")
                enabled: Templates.busy === "" && Templates.record.time !== undefined
                // refresh
                iconPath: "refresh"
                onClicked: Templates.renderAll()
            }

        }

        Repeater {
            model: Templates.items
            onItemAdded: templatesCard.regroupLater()
            onItemRemoved: templatesCard.regroupLater()

            delegate: TemplateRow {
            }

        }

    }

    SettingCard {
        id: catalogCard

        title: I18n.tr("ADD AN APP")
        subtitle: I18n.tr("Installed applications Lucid has a template for that aren't wired up yet.")
        visible: Templates.catalog.length > 0

        Repeater {
            model: Templates.catalog
            onItemAdded: catalogCard.regroupLater()
            onItemRemoved: catalogCard.regroupLater()

            delegate: SettingRow {
                id: offer

                required property var modelData

                title: offer.modelData.app
                description: offer.modelData.name + " · " + offer.modelData.output

                M3Button {
                    text: Templates.busy === offer.modelData.name ? I18n.tr("Adding...") : I18n.tr("Add")
                    enabled: Templates.busy === ""
                    iconPath: "add"
                    onClicked: Templates.addFromCatalog(offer.modelData)
                }

            }

        }

    }

    SettingCard {
        title: I18n.tr("YOUR OWN TEMPLATE")

        SettingRow {
            title: I18n.tr("Add a template")
            description: I18n.tr("Any text file with matugen's variables where the colours go, like {{colors.primary.default.hex}}. Try it to see what it writes with your colours before adding it.")
            stacked: true

            TemplateForm {
                width: parent.width
            }

        }

        SettingRow {
            title: I18n.tr("Colour variables")
            description: I18n.tr("The roles of the current palette. Click one to copy the variable that writes it.")
            showDivider: false
            stacked: true

            ColourTokens {
                width: parent.width
            }

        }

        SettingRow {
            title: I18n.tr("Configuration file")
            description: I18n.tr("The templates live in ~/.config/matugen/config.toml. Switching one off keeps its block there, commented out.")

            M3Button {
                text: I18n.tr("Open")
                onClicked: Templates.openFile(Templates.configPath)
            }

        }

    }

}
