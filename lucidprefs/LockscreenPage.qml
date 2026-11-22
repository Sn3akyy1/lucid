import QtQuick
import qs

// the lock screen and the login screen, which wear one layout: a live preview
// up top that opens into the editor, the presets under it, then the backdrop,
// how the lock behaves, and what the login screen is sent
Column {
    id: page

    // told by Settings when the page comes on and off screen
    property bool pageShown: false

    spacing: Theme.dp(26)
    onPageShownChanged: {
        if (page.pageShown)
            preview.replay();

    }

    // ── the preview ─────────────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: Theme.dp(14)

        LockPreview {
            id: preview

            width: parent.width
            height: implicitHeight
            onOpened: LockStyle.openEditor("")
        }

        Item {
            width: parent.width
            height: Math.max(screens.height, customise.height)

            Row {
                id: screens

                spacing: Theme.dp(10)

                M3Segmented {
                    width: fitWidth
                    current: preview.greeterLook ? "login" : "lock"
                    options: [{
                        "key": "lock",
                        "label": I18n.tr("Lock screen")
                    }, {
                        "key": "login",
                        "label": I18n.tr("Login screen")
                    }]
                    onChosen: (key) => {
                        return preview.greeterLook = key === "login";
                    }
                }

                M3Segmented {
                    width: fitWidth
                    current: preview.previewFocus ? "typing" : "rest"
                    options: [{
                        "key": "rest",
                        "label": I18n.tr("Resting")
                    }, {
                        "key": "typing",
                        "label": I18n.tr("Typing")
                    }]
                    onChosen: (key) => {
                        return preview.previewFocus = key === "typing";
                    }
                }

            }

            M3Button {
                id: customise

                anchors.right: parent.right
                variant: "filled"
                iconPath: "edit"
                text: I18n.tr("Customise")
                onClicked: LockStyle.openEditor("")
            }

        }

    }

    // ── layout ──────────────────────────────────────────────────────────────
    SettingCard {
        title: I18n.tr("LAYOUT")

        SettingRow {
            title: I18n.tr("Preset")
            description: I18n.tr("%1. Each preset keeps its own widgets, so trying another loses nothing.", LockStyle.presetInfo(LockStyle.preset).blurb)
            stacked: true

            Grid {
                id: presetGrid

                readonly property real tileW: (width - columnSpacing * (columns - 1)) / columns

                width: parent.width
                columns: width > Theme.dp(620) ? 5 : 3
                columnSpacing: Theme.dp(12)
                rowSpacing: Theme.dp(14)

                Repeater {
                    model: LockStyle.presets

                    LockPresetThumb {
                        required property var modelData

                        width: presetGrid.tileW
                        preset: modelData.id
                        name: modelData.name
                        current: LockStyle.preset === modelData.id
                        onChosen: LockStyle.setPreset(modelData.id)
                    }

                }

            }

        }

        SettingRow {
            title: I18n.tr("Widgets")
            description: I18n.tr("Open the editor to add, move and style them: click one on the preview to change it, or a + to put another in that place.")
            showDivider: false

            M3Button {
                variant: "tonal"
                iconPath: "edit"
                text: I18n.tr("Edit widgets")
                onClicked: LockStyle.openEditor("widgets")
            }

        }

    }

    // ── backdrop ────────────────────────────────────────────────────────────
    SettingCard {
        title: I18n.tr("BACKDROP")

        SettingRow {
            title: I18n.tr("Blur")
            resetKey: "lockBlur"
            description: I18n.tr("How far the wallpaper frosts over at rest. Typing frosts it further.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 5
                suffix: "%"
                value: Prefs.lockBlur
                onMoved: (v) => {
                    return Prefs.lockBlur = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Dim")
            resetKey: "lockDim"
            description: I18n.tr("How dark the wallpaper goes under the clock and the cards.")
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 100
                stepSize: 5
                suffix: "%"
                value: Prefs.lockDim
                onMoved: (v) => {
                    return Prefs.lockDim = Math.round(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Accent wash")
            resetKey: "lockTint"
            description: I18n.tr("Lays the wallpaper's own colour back over it, faintly, the way Material You tints a surface.")
            showDivider: false

            M3Switch {
                checked: Prefs.lockTint
                onToggled: (v) => {
                    return Prefs.lockTint = v;
                }
            }

        }

    }

    // ── behaviour ───────────────────────────────────────────────────────────
    SettingCard {
        title: I18n.tr("BEHAVIOUR")

        SettingRow {
            title: I18n.tr("Grow out of the desktop")
            resetKey: "lockDive"
            description: I18n.tr("Locking photographs the screen first, so the lock frosts over your windows and the desktop sinks away under it. Off, the lock simply fades in.")

            M3Switch {
                checked: Prefs.lockDive
                onToggled: (v) => {
                    return Prefs.lockDive = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Back to resting")
            resetKey: "lockIdleBack"
            description: I18n.tr("Once you stop typing, the lock puts the field away and shows the day again after this long.")

            M3Segmented {
                width: fitWidth
                current: Prefs.lockIdleBack
                options: [{
                    "key": 10,
                    "label": I18n.tr("10 s")
                }, {
                    "key": 25,
                    "label": I18n.tr("25 s")
                }, {
                    "key": 60,
                    "label": I18n.tr("1 min")
                }, {
                    "key": 0,
                    "label": I18n.tr("Never")
                }]
                onChosen: (key) => {
                    return Prefs.lockIdleBack = key;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Other screens")
            resetKey: "lockOtherScreens"
            description: I18n.tr("What every screen but the main one shows while locked.")
            showDivider: false

            M3Segmented {
                width: fitWidth
                current: Prefs.lockOtherScreens
                options: [{
                    "key": "clock",
                    "label": I18n.tr("The clock")
                }, {
                    "key": "blank",
                    "label": I18n.tr("Nothing")
                }]
                onChosen: (key) => {
                    return Prefs.lockOtherScreens = key;
                }
            }

        }

    }

    // ── the login screen ────────────────────────────────────────────────────
    SettingCard {
        title: I18n.tr("LOGIN SCREEN")

        SettingRow {
            title: I18n.tr("Wear this layout at login")
            resetKey: "lockLoginSync"
            description: {
                switch (LockStyle.loginStatus) {
                case "lock ok":
                    return I18n.tr("The login screen shows this layout when your account is picked. Widgets that need you logged in, such as media and notifications, stay off it.");
                case "lock old":
                    return I18n.tr("Sent, but the login screen installed on this machine predates layouts. Run  sudo bash ~/lucid/support/sddm/install-theme.sh  once to update it.");
                case "lock readonly":
                    return I18n.tr("The login screen's folder for your account is not writable, so nothing can be sent. Run  sudo bash ~/lucid/support/sddm/install-theme.sh  to fix its permissions.");
                case "lock notlucid":
                    return I18n.tr("SDDM is using another theme. Lucid's login screen is the one that can wear this layout.");
                case "lock notheme":
                    return I18n.tr("SDDM is not set up on this machine, so there is no login screen to send it to.");
                }
                return I18n.tr("The login screen shows this layout when your account is picked. Widgets that need you logged in, such as media and notifications, stay off it.");
            }

            M3Switch {
                checked: Prefs.lockLoginSync
                onToggled: (v) => {
                    return Prefs.lockLoginSync = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Weather at login")
            resetKey: "lockLoginWeather"
            enabled: Prefs.lockLoginSync
            disabledReason: I18n.tr("The login screen is not being sent this layout.")
            description: I18n.tr("The login screen has no internet of its own, so it shows the last reading taken here, for up to six hours. Other accounts on this machine can read it: the sky and the temperature, never where you are.")

            M3Switch {
                checked: Prefs.lockLoginWeather
                enabled: Prefs.lockLoginSync
                onToggled: (v) => {
                    return Prefs.lockLoginWeather = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Send it now")
            enabled: Prefs.lockLoginSync
            disabledReason: I18n.tr("The login screen is not being sent this layout.")
            description: LockStyle.loginSyncedAt > 0 ? I18n.tr("Sent %1. Every change is sent on its own a moment after you make it.", Qt.formatTime(new Date(LockStyle.loginSyncedAt), Prefs.clock24h ? "HH:mm" : "h:mm AP")) : I18n.tr("Every change is sent on its own a moment after you make it.") // i18n-skip
            showDivider: false

            M3Button {
                variant: "tonal"
                text: I18n.tr("Send")
                enabled: Prefs.lockLoginSync
                onClicked: LockStyle.syncNow()
            }

        }

    }

}
