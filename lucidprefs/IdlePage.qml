import QtQuick
import qs

Column {
    id: page

    property bool showConf: false

    readonly property string installHint: I18n.tr("hypridle is not installed. Install the hypridle package and this page comes to life.")

    // a step set earlier than the one before it still fires, just out of turn
    function orderWarning(key) {
        var st = Idle.stages;
        for (var i = 1; i < st.length; i++) {
            if (st[i].key === key && st[i].after <= st[i - 1].after)
                return I18n.tr("This runs before “%1” above it, so the steps happen out of order.", st[i - 1].name);

        }
        return "";
    }

    spacing: Theme.dp(26)
    onVisibleChanged: Idle.watching = page.visible
    Component.onCompleted: Idle.watching = page.visible

    IdleSequence {
        width: parent.width
    }

    SettingCard {
        title: I18n.tr("IDLE DAEMON")

        SettingRow {
            title: I18n.tr("Status")
            enabled: Idle.installed
            disabledReason: page.installHint
            description: Idle.summary + (Idle.installed ? I18n.tr(". Lucid writes hypridle's config for you and restarts it whenever something here changes.") : "")
            warning: Idle.lastError

            M3Button {
                variant: "tonal"
                text: I18n.tr("Restart")
                enabled: Idle.installed && Prefs.idleEnabled
                onClicked: Idle.restart()
            }

        }

        SettingRow {
            title: I18n.tr("Start at login")
            resetKey: "idleAutostart"
            enabled: Idle.installed
            disabledReason: page.installHint
            description: Idle.startsAtLogin ? I18n.tr("hypridle comes up with your session, whether or not Lucid is running.") : I18n.tr("hypridle only runs while Lucid starts it.")

            M3Switch {
                checked: Prefs.idleAutostart
                enabled: Idle.installed
                onToggled: (v) => {
                    return Prefs.idleAutostart = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Keep this machine awake")
            resetKey: "idleKeepAwake"
            enabled: Idle.installed
            disabledReason: page.installHint
            description: I18n.tr("Holds every step below until you turn this off — through a reboot too. For a presentation, a long download, or a film.")
            showDivider: false

            M3Switch {
                checked: Prefs.idleKeepAwake
                enabled: Idle.installed
                onToggled: (v) => {
                    return Prefs.idleKeepAwake = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("WHEN YOU WALK AWAY")

        SettingRow {
            title: I18n.tr("Dim the screen")
            resetKey: "idleDim"
            visible: Idle.hasBacklight
            description: I18n.tr("Turns the backlight down first, as a warning that the rest is coming. Moving the mouse puts it straight back.")

            M3Switch {
                checked: Prefs.idleDim
                onToggled: (v) => {
                    return Prefs.idleDim = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Dim after")
            resetKey: "idleDimAfter"
            visible: Idle.hasBacklight
            enabled: Prefs.idleDim
            disabledReason: I18n.tr("Dimming is off.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.idleDim
                from: 0
                to: Idle.steps.length - 1
                stepSize: 1
                stepLabels: Idle.stepLabels
                value: Idle.stepIndex(Prefs.idleDimAfter)
                onMoved: (v) => {
                    return Prefs.idleDimAfter = Idle.stepAt(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Dim to")
            resetKey: "idleDimLevel"
            visible: Idle.hasBacklight
            enabled: Prefs.idleDim
            disabledReason: I18n.tr("Dimming is off.")
            description: I18n.tr("How far down the backlight goes. Never all the way to nothing — a black OLED panel looks broken.")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.idleDim
                from: 1
                to: 50
                stepSize: 1
                suffix: " %"
                value: Prefs.idleDimLevel
                onMoved: (v) => {
                    return Prefs.idleDimLevel = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Turn the keyboard backlight off too")
            resetKey: "idleDimKeyboard"
            visible: Idle.hasBacklight && Idle.hasKbdBacklight
            enabled: Prefs.idleDim
            disabledReason: I18n.tr("Dimming is off.")
            description: I18n.tr("Uses %1, and restores it on the way back.", Idle.kbdBacklight)

            M3Switch {
                checked: Prefs.idleDimKeyboard
                enabled: Prefs.idleDim
                onToggled: (v) => {
                    return Prefs.idleDimKeyboard = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Lock the screen")
            resetKey: "idleLock"
            description: I18n.tr("Runs Lucid's own lock screen. Your password gets you back in.")

            M3Switch {
                checked: Prefs.idleLock
                onToggled: (v) => {
                    return Prefs.idleLock = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Lock after")
            resetKey: "idleLockAfter"
            enabled: Prefs.idleLock
            disabledReason: I18n.tr("Locking is off.")
            warning: page.orderWarning("lock")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.idleLock
                from: 0
                to: Idle.steps.length - 1
                stepSize: 1
                stepLabels: Idle.stepLabels
                value: Idle.stepIndex(Prefs.idleLockAfter)
                onMoved: (v) => {
                    return Prefs.idleLockAfter = Idle.stepAt(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Turn the screen off")
            resetKey: "idleScreenOff"
            description: I18n.tr("Puts the monitors to sleep. The machine keeps running, so anything downloading carries on.")

            M3Switch {
                checked: Prefs.idleScreenOff
                onToggled: (v) => {
                    return Prefs.idleScreenOff = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Screen off after")
            resetKey: "idleScreenOffAfter"
            enabled: Prefs.idleScreenOff
            disabledReason: I18n.tr("Turning the screen off is off.")
            warning: page.orderWarning("screen")
            stacked: true

            M3Slider {
                width: parent.width
                enabled: Prefs.idleScreenOff
                from: 0
                to: Idle.steps.length - 1
                stepSize: 1
                stepLabels: Idle.stepLabels
                value: Idle.stepIndex(Prefs.idleScreenOffAfter)
                onMoved: (v) => {
                    return Prefs.idleScreenOffAfter = Idle.stepAt(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Suspend")
            resetKey: "idleSuspend"
            description: I18n.tr("Sleeps the whole machine. Everything stops until you press a key.")

            M3Switch {
                checked: Prefs.idleSuspend
                onToggled: (v) => {
                    return Prefs.idleSuspend = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Suspend after")
            resetKey: "idleSuspendAfter"
            enabled: Prefs.idleSuspend
            disabledReason: I18n.tr("Suspending is off.")
            warning: page.orderWarning("suspend")
            stacked: true
            showDivider: Idle.hasBattery && Idle.acOnline !== ""

            M3Slider {
                width: parent.width
                enabled: Prefs.idleSuspend
                from: 0
                to: Idle.steps.length - 1
                stepSize: 1
                stepLabels: Idle.stepLabels
                value: Idle.stepIndex(Prefs.idleSuspendAfter)
                onMoved: (v) => {
                    return Prefs.idleSuspendAfter = Idle.stepAt(v);
                }
            }

        }

        SettingRow {
            title: I18n.tr("Suspend on mains power too")
            resetKey: "idleSuspendOnAc"
            visible: Idle.hasBattery && Idle.acOnline !== ""
            enabled: Prefs.idleSuspend
            disabledReason: I18n.tr("Suspending is off.")
            description: I18n.tr("Off means the machine only sleeps on battery. Lucid reads %1 to tell.", Idle.acOnline)
            showDivider: false

            M3Switch {
                checked: Prefs.idleSuspendOnAc
                enabled: Prefs.idleSuspend
                onToggled: (v) => {
                    return Prefs.idleSuspendOnAc = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("SLEEP AND WAKE")

        SettingRow {
            title: I18n.tr("Lock before sleeping")
            resetKey: "idleLockBeforeSleep"
            description: I18n.tr("Whenever the machine suspends — from here, the power menu, or a closed lid — the lock screen goes up first, so it is already there when you open it again.")

            M3Switch {
                checked: Prefs.idleLockBeforeSleep
                onToggled: (v) => {
                    return Prefs.idleLockBeforeSleep = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Wake the screen on resume")
            resetKey: "idleWakeAfterSleep"
            description: I18n.tr("Turns the monitors back on the moment the machine wakes, instead of waiting for a key press.")
            showDivider: false

            M3Switch {
                checked: Prefs.idleWakeAfterSleep
                onToggled: (v) => {
                    return Prefs.idleWakeAfterSleep = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("EXCEPTIONS")

        SettingRow {
            title: I18n.tr("Let applications keep the screen on")
            resetKey: "idleRespectInhibitors"
            description: I18n.tr("A video player or a browser playing full screen can ask the system to stay awake. Off means Lucid ignores every one of those requests.")

            M3Switch {
                checked: Prefs.idleRespectInhibitors
                onToggled: (v) => {
                    return Prefs.idleRespectInhibitors = v;
                }
            }

        }

        SettingRow {
            title: I18n.tr("Never interrupt something playing")
            resetKey: "idleWhileMedia"
            description: I18n.tr("Checks with playerctl before each step, and skips it if a player is playing. The check happens once, when that timer runs out — stopping the music later does not start the countdown again.")
            showDivider: false

            M3Switch {
                checked: Prefs.idleWhileMedia
                onToggled: (v) => {
                    return Prefs.idleWhileMedia = v;
                }
            }

        }

    }

    SettingCard {
        title: I18n.tr("THE CONFIG FILE")

        SettingRow {
            title: I18n.tr("Written to")
            monoTitle: true
            description: I18n.tr("Lucid owns this file while idle management is on. Anything that was in it first was copied to hypridle.conf.pre-lucid.")

            M3Button {
                variant: "text"
                text: page.showConf ? I18n.tr("Hide") : I18n.tr("Show")
                onClicked: page.showConf = !page.showConf
            }

        }

        SettingRow {
            title: Idle.confPath
            monoTitle: true
            visible: page.showConf
            stacked: true

            Rectangle {
                width: parent.width
                implicitHeight: confText.implicitHeight + Theme.dp(28)
                radius: Theme.radiusSm
                color: Theme.bgSunken

                Text {
                    id: confText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.dp(14)
                    text: Idle.conf
                    color: Theme.subtext
                    font.family: "monospace"
                    font.pixelSize: Theme.fontLabel
                    font.features: ({
                        "liga": 0,
                        "calt": 0
                    })
                    wrapMode: Text.WrapAnywhere
                }

            }

        }

        SettingRow {
            title: I18n.tr("Reset the idle steps")
            description: I18n.tr("Puts every timing and switch on this page back to the value it ships with. The daemon switch and keep-awake are left alone.")
            showDivider: false

            M3Button {
                variant: "text"
                destructive: true
                text: I18n.tr("Reset")
                onClicked: Prefs.askReset(I18n.tr("Reset the idle steps?"), I18n.tr("Every timing and switch on this page goes back to the value it ships with."), Prefs.resetIdleToken)
            }

        }

    }

}
