import QtQuick
import Quickshell
import qs

// the applications that follow the palette: every matugen template, how the
// last change of theme or wallpaper rendered it, the ones Lucid can wire up
// for apps already installed, and your own. Templates.qml does the work
Column {
    id: page

    // for "n minutes ago" in the templates summary
    property real now: Date.now()
    readonly property string templatesSummary: {
        var rec = Templates.record;
        if (rec.time === undefined)
            return "Nothing rendered yet. The templates render on the next change of theme or wallpaper.";

        var source = rec.source;
        var themes = Prefs.themeCatalogue;
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === rec.source)
                source = themes[i].name;

        }
        var mins = Math.max(0, Math.round((page.now / 1000 - rec.time) / 60));
        var when = mins < 1 ? "just now" : (mins < 60 ? mins + " min ago" : (mins < 1440 ? Math.round(mins / 60) + " h ago" : Math.round(mins / 1440) + " d ago"));
        var parts = [Templates.renderedCount + " rendered"];
        if (Templates.failedCount > 0)
            parts.push(Templates.failedCount + " failed");

        return parts.join(", ") + " · " + source + ", " + rec.mode + ", " + when;
    }

    spacing: 26
    Component.onCompleted: Templates.refresh()

    Timer {
        interval: 30000
        running: page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: page.now = Date.now()
    }

    SettingCard {
        id: templatesCard

        title: "APP TEMPLATES"
        subtitle: "Each template writes the palette into an application's own config whenever the theme or the wallpaper changes, the fixed themes included."

        SettingRow {
            title: "Last change"
            description: page.templatesSummary

            M3Button {
                text: Templates.busy === "*" ? "Rendering..." : "Render again"
                enabled: Templates.busy === "" && Templates.record.time !== undefined
                // refresh
                iconPath: "M17.65 6.35A7.958 7.958 0 0 0 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0 1 12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"
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

        title: "ADD AN APP"
        subtitle: "Installed applications Lucid has a template for that aren't wired up yet."
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
                    text: Templates.busy === offer.modelData.name ? "Adding..." : "Add"
                    enabled: Templates.busy === ""
                    iconPath: "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2Z"
                    onClicked: Templates.addFromCatalog(offer.modelData)
                }

            }

        }

    }

    SettingCard {
        title: "YOUR OWN TEMPLATE"

        SettingRow {
            title: "Add a template"
            description: "Any text file with matugen's variables where the colours go, like {{colors.primary.default.hex}}. Try it to see what it writes with your colours before adding it."
            stacked: true

            TemplateForm {
                width: parent.width
            }

        }

        SettingRow {
            title: "Colour variables"
            description: "The roles of the current palette. Click one to copy the variable that writes it."
            showDivider: false
            stacked: true

            ColourTokens {
                width: parent.width
            }

        }

        SettingRow {
            title: "Configuration file"
            description: "The templates live in ~/.config/matugen/config.toml. Switching one off keeps its block there, commented out."

            M3Button {
                text: "Open"
                onClicked: Templates.openFile(Templates.configPath)
            }

        }

    }

}
