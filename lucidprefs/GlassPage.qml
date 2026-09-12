import QtQuick
import Quickshell
import qs

Column {
    id: page

    readonly property var blurSteps: [0, 0.2, 0.5, 0.8, 1]
    readonly property var blurLabels: ["Off", "Light", "Balanced", "Heavy", "Full"]
    readonly property int blurIndex: {
        var best = 0, dist = 999;
        for (var i = 0; i < page.blurSteps.length; i++) {
            var d = Math.abs(page.blurSteps[i] - Theme.blurAmount);
            if (d < dist) {
                dist = d;
                best = i;
            }
        }
        return best;
    }
    // what is open that the catalog has no row for, so it can still be set
    readonly property var unlisted: {
        const known = [];
        for (const a of Glass.catalog)
            for (const c of a.class)
                known.push(String(c).toLowerCase());

        return Glass.openClasses.filter((c) => {
            const l = String(c).toLowerCase();
            // the shell's own windows are not something to frost from here
            return l.indexOf("quickshell") === -1 && known.indexOf(l) === -1 && !Glass.isChosen("@" + c);
        });
    }

    function pct(v) {
        return Math.round(v * 100) + "%";
    }

    spacing: 26
    Component.onCompleted: Glass.scan()

    SettingCard {
        visible: Glass.moduleProbed && !Glass.moduleInstalled

        SettingRow {
            title: "Per-app glass is not set up"
            warning: "The window rules come with Lucid's Hyprland config, and yours does not load it. Run the installer with --with-hypr, or copy modules/glass.lua into your own and require it. The slider below still works: it is the shell's own surfaces and kitty."
            showDivider: false
        }

    }

    SettingCard {
        title: "GLASS"
        subtitle: "One slider for the whole desktop. Everything below follows it."

        SettingRow {
            title: "Glass"
            resetAction: Prefs.resetBlurToken
            resetVisible: Theme.blurAmount !== 0
            description: "How far the desktop shows through what is in front of it."
            warning: "Frosting is handled by the compositor, not the shell, and is buggy — expect visual artefacts. Set this to Off to avoid them."
            stacked: true

            M3Slider {
                width: parent.width
                from: 0
                to: 4
                stepSize: 1
                stepLabels: page.blurLabels
                value: page.blurIndex
                onMoved: (v) => {
                    return Theme.setBlurAmount(page.blurSteps[Math.round(v)]);
                }
            }

        }

        SettingRow {
            title: "Where it lands"
            description: "Each surface is let through as far as it can take. A window's opacity dims its text along with its background; kitty's own does not, so the terminal can go all the way."
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 10

                Repeater {
                    model: [
                        { "label": "Shell surfaces", "value": page.pct(1 - Theme.blurAmount * Glass.surfaceWeight), "note": "bar, dock, panels" },
                        { "label": "Terminal", "value": page.pct(Glass.kittyOpacity), "note": Glass.present ? "kitty's background" : "kitty is not installed" },
                        { "label": "App windows", "value": page.pct(Glass.appFollow), "note": Glass.shown.length > 0 ? "the apps below, unless set apart" : "no apps picked yet" }
                    ]

                    Item {
                        required property var modelData

                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                        }

                        Text {
                            anchors.right: readout.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.note
                            color: Theme.subtextDim
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                        }

                        Text {
                            id: readout

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 46
                            horizontalAlignment: Text.AlignRight
                            text: modelData.value
                            color: Theme.accent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBodyMd
                            font.weight: Font.Medium
                        }

                    }

                }

            }

        }

    }

    SettingCard {
        title: "APPS"
        subtitle: "kitty is set through its own config. The rest become Hyprland window rules, which fade the whole window, text included, so they sit far shallower."

        SettingRow {
            title: "Apps under glass"
            resetKey: "glassApps"
            resetAction: Prefs.resetGlassToken
            resetVisible: Prefs.isModified("glassApps") || Prefs.isModified("glassValues")
            resetTitle: "Apps under glass"
            description: Glass.installed.length > 0 ? "" : "None of the applications Lucid recognises are installed. Anything you have open can still be added below."
            stacked: Glass.installed.length > 0

            Column {
                width: parent.width
                spacing: 14
                visible: Glass.installed.length > 0

                Repeater {
                    model: Glass.installed

                    CheckLine {
                        required property string modelData

                        label: Glass.nameOf(modelData)
                        icon: Glass.iconOf(modelData)
                        checked: Glass.isChosen(modelData)
                        onToggled: Glass.setChosen(modelData, !checked)
                    }

                }

            }

        }

        Repeater {
            model: Glass.shown

            SettingRow {
                required property string modelData
                readonly property bool own: Glass.hasOwnValue(modelData)
                readonly property bool self: Glass.isSelfManaged(modelData)
                readonly property string route: self ? " Through kitty's own background, so the text stays sharp however far it goes." : ""

                title: Glass.nameOf(modelData)
                description: (own ? "Set apart from the slider, at " + page.pct(Glass.opacityOf(modelData)) + "." : "Follows Glass — " + page.pct(Glass.followFor(modelData)) + " while it is " + page.blurLabels[page.blurIndex] + ".") + route
                stacked: true

                Row {
                    spacing: 16
                    width: parent.width

                    M3Slider {
                        width: parent.width - follow.width - 16
                        // a window rule takes the text with it; kitty does not
                        from: self ? 0 : 0.3
                        to: 1
                        stepSize: 0.05
                        decimals: 2
                        value: Glass.opacityOf(modelData)
                        onMoved: (v) => {
                            return Glass.setOpacity(modelData, v);
                        }
                    }

                    M3Button {
                        id: follow

                        anchors.verticalCenter: parent.verticalCenter
                        text: own ? "Follow" : "Following"
                        variant: own ? "filled" : "tonal"
                        onClicked: Glass.setOpacity(modelData, own ? -1 : Glass.followFor(modelData))
                    }

                }

            }

        }

    }

    SettingCard {
        title: "OPEN WINDOWS"
        subtitle: "Whatever else is running right now, by the class Hyprland knows it as. Adding one keeps it here after the window closes. Another terminal in here is better set through its own opacity setting than from here, the way kitty is."
        visible: page.unlisted.length > 0

        SettingRow {
            title: "Add a window"
            showDivider: false
            stacked: true

            Column {
                width: parent.width
                spacing: 14

                Repeater {
                    model: page.unlisted

                    CheckLine {
                        required property string modelData

                        label: modelData
                        icon: Quickshell.iconPath(modelData, true)
                        checked: false
                        onToggled: Glass.setChosen("@" + modelData, true)
                    }

                }

            }

        }

    }

}
