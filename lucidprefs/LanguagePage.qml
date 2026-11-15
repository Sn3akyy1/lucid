import QtQuick
import Quickshell
import qs
import qs.lucidui

Column {
    id: page

    property string path: ""
    spacing: Theme.dp(26)

    SettingCard {
        title: I18n.tr("LANGUAGE")

        SettingRow {
            title: I18n.tr("Language")
            description: I18n.tr("Automatic follows the system language, here %1. Text the translation doesn't cover stays in English.", I18n.autoName)
            stacked: true

            M3Segmented {
                width: parent.width
                current: Prefs.language
                options: [{
                    "key": "auto",
                    "label": I18n.tr("Automatic")
                }].concat(I18n.languages.map((l) => {
                    return {
                        "key": l.code,
                        "label": l.name
                    };
                }))
                onChosen: (key) => {
                    return Prefs.language = key;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("ADD A LANGUAGE")

        SettingRow {
            title: I18n.tr("Import a translation")
            description: I18n.tr("A .json file named after the language, like de.json, in the format of an exported one. It is copied into %1 and appears above.", I18n.userDir)
            stacked: true

            Row {
                spacing: Theme.dp(10)

                M3TextField {
                    width: Math.min(page.width - Theme.dp(260), Theme.dp(420))
                    placeholder: I18n.tr("Path to the file, e.g. ~/Downloads/de.json")
                    commitOnBlur: false
                    onEdited: (value) => {
                        return page.path = value.trim();
                    }
                    onAccepted: (value) => {
                        return I18n.importFile(value.trim());
                    }
                }

                M3Button {
                    text: I18n.tr("Import")
                    variant: "filled"
                    enabled: page.path !== ""
                    onClicked: I18n.importFile(page.path)
                }

                M3Button {
                    text: I18n.tr("Open folder")
                    onClicked: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "sh", I18n.userDir])
                }

            }

        }

        SettingRow {
            title: I18n.tr("Result")
            description: I18n.report
            warning: I18n.reportBad ? I18n.report : ""
            visible: I18n.report !== ""
        }

    }

    SettingCard {
        title: I18n.tr("SHARE OR START ONE")

        SettingRow {
            title: I18n.tr("Export the template")
            description: I18n.tr("Every text in Lucid with an empty translation, saved to your home folder as lucid-template.json. Fill it in, give it a name and a locale in _meta, and import it here.")

            M3Button {
                text: I18n.tr("Export")
                onClicked: I18n.exportCatalogue("template")
            }

        }

        SettingRow {
            title: I18n.tr("Export the current language")
            description: I18n.tr("The language in use as it is, saved to your home folder, to share it or to correct it.")
            enabled: I18n.language !== "en"
            disabledReason: I18n.tr("English is the text in the code, so it has no file.")

            M3Button {
                text: I18n.tr("Export")
                onClicked: I18n.exportCatalogue(I18n.language)
            }

        }

    }

}
