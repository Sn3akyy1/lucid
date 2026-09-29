import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the apps picked in settings, rendered into lucid-specials.lua for modules/specials.lua
Singleton {
    id: root

    readonly property string dataPath: Quickshell.env("HOME") + "/.config/hypr/lucid-specials.lua"
    readonly property string modulePath: Quickshell.env("HOME") + "/.config/hypr/modules/specials.lua"
    property bool moduleInstalled: false
    property bool moduleProbed: false

    // the keys match modules/binds.lua, and show until keybinds.json is read
    readonly property var builtinSpaces: [
        { "key": "special", "glyph": "layers", "label": "Scratchpad", "pref": "specialScratchpad", "apps": "", "keys": ["Super", "Shift", "S"] },
        { "key": "music", "glyph": "music_note", "label": "Music", "pref": "specialMusic", "apps": "specialMusicApps", "keys": ["Super", "Shift", "M"] },
        { "key": "comms", "glyph": "chat", "label": "Comms", "pref": "specialComms", "apps": "specialCommsApps", "keys": ["Super", "Shift", "D"] },
        { "key": "todo", "glyph": "checklist", "label": "To-do", "pref": "specialTodo", "apps": "specialTodoApps", "keys": ["Super", "Shift", "R"] },
        { "key": "sysmon", "glyph": "monitor_heart", "label": "System", "pref": "specialSysmon", "apps": "specialSysmonApps", "keys": ["Ctrl", "Shift", "Escape"] }
    ]
    readonly property var stashKeys: ["Super", "Alt", "S"]
    // the ones made in settings, after the ones lucid ships
    readonly property var ownSpaces: {
        let list = [];
        try {
            list = JSON.parse(Prefs.specialCustom || "[]");
        } catch (e) {
            list = [];
        }
        if (!Array.isArray(list))
            return [];

        const seen = {};
        return list.filter((w) => {
            if (!w || typeof w.key !== "string" || !root.keyPattern.test(w.key) || root.reserved.indexOf(w.key) !== -1 || seen[w.key])
                return false;

            seen[w.key] = true;
            return true;
        }).map((w) => {
            return {
                "key": w.key,
                "glyph": root.glyphs[w.glyph] ? w.glyph : "apps",
                "label": String(w.label || w.key),
                "on": w.on !== false,
                "apps": typeof w.apps === "string" ? w.apps : "",
                "own": true
            };
        });
    }
    readonly property var spaces: root.builtinSpaces.concat(root.ownSpaces)
    // a key is also the lua table key and the hyprland name, special:<key>
    readonly property var keyPattern: /^[a-z][a-z0-9_]{0,23}$/
    readonly property var reserved: ["special", "music", "comms", "todo", "sysmon", "minimized", "scratchpad"]
    // apps the catalogue below does not know are stored as entry:<desktop id>
    readonly property string customPrefix: "entry:"
    // wrappers, so an added app's class guess does not take the launcher for the app
    readonly property var execWrappers: ["flatpak", "snap", "env", "sh", "bash", "zsh", "dbus-run-session", "systemd-run", "gtk-launch", "python", "python3", "wine"]

    // material symbols rounded, converted to a 24dp grid
    readonly property var glyphs: ({
        "web": "M4 20q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4h16q0.825 0 1.4125 0.5875T22 6v12q0 0.825-0.5875 1.4125T20 20H4Zm0-2h10.5v-3.5H4v3.5Zm12.5 0h3.5v-9H16.5v9ZM4 12.5h10.5v-3.5H4v3.5Z",
        "mail": "M4 20q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4h16q0.825 0 1.4125 0.5875T22 6v12q0 0.825-0.5875 1.4125T20 20H4Zm8-7.175q0.125 0 0.2625-0.0375T12.525 12.675l7.075-4.425q0.2-0.125 0.3-0.3125t0.1-0.4125q0-0.5-0.425-0.75t-0.875 0.025L12 11L5.3 6.8q-0.45-0.275-0.875-0.0125T4 7.525q0 0.25 0.1 0.4375t0.3 0.2875l7.075 4.425q0.125 0.075 0.2625 0.1125T12 12.825Z",
        "chat": "M6 18l-2.3 2.3q-0.475 0.475-1.0875 0.2125T2 19.575v-15.575q0-0.825 0.5875-1.4125T4 2h16q0.825 0 1.4125 0.5875T22 4v12q0 0.825-0.5875 1.4125T20 18H6Zm1-4h6q0.425 0 0.7125-0.2875T14 13q0-0.425-0.2875-0.7125T13 12H7q-0.425 0-0.7125 0.2875T6 13q0 0.425 0.2875 0.7125T7 14Zm0-3h10q0.425 0 0.7125-0.2875T18 10q0-0.425-0.2875-0.7125T17 9H7q-0.425 0-0.7125 0.2875T6 10q0 0.425 0.2875 0.7125T7 11Zm0-3h10q0.425 0 0.7125-0.2875T18 7q0-0.425-0.2875-0.7125T17 6H7q-0.425 0-0.7125 0.2875T6 7q0 0.425 0.2875 0.7125T7 8Z",
        "print": "M8 21q-0.825 0-1.4125-0.5875T6 19v-2h-2q-0.825 0-1.4125-0.5875T2 15v-4q0-1.275 0.875-2.1375t2.125-0.8625h14q1.275 0 2.1375 0.8625T22 11v4q0 0.825-0.5875 1.4125T20 17h-2v2q0 0.825-0.5875 1.4125T16 21H8Zm10-14H6v-2q0-0.825 0.5875-1.4125T8 3h8q0.825 0 1.4125 0.5875T18 5v2Zm0 5.5q0.425 0 0.7125-0.2875T19 11.5q0-0.425-0.2875-0.7125T18 10.5q-0.425 0-0.7125 0.2875T17 11.5q0 0.425 0.2875 0.7125T18 12.5ZM8 19h8v-4H8v4Z",
        "security": "M12 19.9q2.425-0.75 4.05-2.9625T17.95 12H12v-7.875l-6 2.25v5.175q0 0.175 0.05 0.45h5.95v7.9Zm0 2q-0.175 0-0.325-0.025t-0.3-0.075q-3.375-1.125-5.375-4.1625T4 11.1v-4.725q0-0.625 0.3625-1.125t0.9375-0.725l6-2.25q0.35-0.125 0.7-0.125t0.7 0.125l6 2.25q0.575 0.225 0.9375 0.725t0.3625 1.125v4.725q0 3.5-2 6.5375T12.625 21.8q-0.15 0.05-0.3 0.075t-0.325 0.025Z",
        "archive": "M5 21q-0.825 0-1.4125-0.5875T3 19v-12.475q0-0.35 0.1125-0.675t0.3375-0.6l1.25-1.525q0.275-0.35 0.6875-0.5375T6.25 3h11.5q0.45 0 0.8625 0.1875T19.3 3.725l1.25 1.525q0.225 0.275 0.3375 0.6t0.1125 0.675v12.475q0 0.825-0.5875 1.4125T19 21H5Zm0.4-15h13.2l-0.85-1H6.25l-0.85 1Zm6.6 4q-0.425 0-0.7125 0.2875T11 11v3.2l-0.9-0.9q-0.275-0.275-0.7-0.275t-0.7 0.275q-0.275 0.275-0.275 0.7t0.275 0.7l2.6 2.6q0.3 0.3 0.7 0.3t0.7-0.3l2.6-2.6q0.275-0.275 0.275-0.7t-0.275-0.7q-0.275-0.275-0.7-0.275t-0.7 0.275l-0.9 0.9v-3.2q0-0.425-0.2875-0.7125T12 10Z",
        "code": "M4.825 12.025l3.875 3.875q0.275 0.275 0.275 0.7t-0.275 0.7q-0.275 0.275-0.7 0.275t-0.7-0.275L2.7 12.7q-0.15-0.15-0.2125-0.325T2.425 12q0-0.2 0.0625-0.375t0.2125-0.325l4.6-4.6q0.3-0.3 0.7125-0.3t0.7125 0.3q0.3 0.3 0.3 0.7125T8.725 8.125L4.825 12.025Zm14.35-0.05L15.3 8.1q-0.275-0.275-0.275-0.7t0.275-0.7q0.275-0.275 0.7-0.275t0.7 0.275l4.6 4.6q0.15 0.15 0.2125 0.325t0.0625 0.375q0 0.2-0.0625 0.375t-0.2125 0.325L16.7 17.3q-0.3 0.3-0.7 0.2875T15.3 17.275q-0.3-0.3-0.3-0.7125t0.3-0.7125l3.875-3.875Z",
        "edit_note": "M5 14q-0.425 0-0.7125-0.2875T4 13q0-0.425 0.2875-0.7125T5 12h5q0.425 0 0.7125 0.2875T11 13q0 0.425-0.2875 0.7125T10 14H5Zm0-4q-0.425 0-0.7125-0.2875T4 9q0-0.425 0.2875-0.7125T5 8h9q0.425 0 0.7125 0.2875T15 9q0 0.425-0.2875 0.7125T14 10H5Zm0-4q-0.425 0-0.7125-0.2875T4 5q0-0.425 0.2875-0.7125T5 4h9q0.425 0 0.7125 0.2875T15 5q0 0.425-0.2875 0.7125T14 6H5Zm8 13v-1.65q0-0.2 0.075-0.3875t0.225-0.3375l5.225-5.2q0.225-0.225 0.5-0.325t0.55-0.1q0.3 0 0.575 0.1125t0.5 0.3375l0.925 0.925q0.2 0.225 0.3125 0.5t0.1125 0.55q0 0.275-0.1 0.5625T21.575 14.5L16.375 19.7q-0.15 0.15-0.3375 0.225t-0.3875 0.075h-1.65q-0.425 0-0.7125-0.2875T13 19Zm6.575-4.6l0.925-0.975l-0.925-0.925l-0.95 0.95l0.95 0.95ZM14.5 18.5h0.95l3.025-3.05l-0.45-0.475l-0.475-0.45l-3.05 3.025v0.95Zm0 0v-0.95l3.05-3.025l0.925 0.925l-3.025 3.05h-0.95Z",
        "music_note": "M10 21q-1.65 0-2.825-1.175t-1.175-2.825q0-1.65 1.175-2.825t2.825-1.175q0.575 0 1.0625 0.1375T12 13.55v-9.55q0-0.425 0.2875-0.7125T13 3h4q0.425 0 0.7125 0.2875T18 4v2q0 0.425-0.2875 0.7125T17 7H14v10q0 1.65-1.175 2.825t-2.825 1.175Z",
        "mic": "M12 14q-1.25 0-2.125-0.875t-0.875-2.125v-6q0-1.25 0.875-2.125t2.125-0.875q1.25 0 2.125 0.875t0.875 2.125v6q0 1.25-0.875 2.125t-2.125 0.875Zm-1 6v-2.075q-2.3-0.325-3.9375-1.95T5.075 12.025q-0.05-0.425 0.225-0.725t0.7-0.3q0.425 0 0.7125 0.2875T7.1 12q0.35 1.75 1.7375 2.875T12 16q1.8 0 3.175-1.1375T16.9 12q0.1-0.425 0.3875-0.7125T18 11q0.425 0 0.7 0.3t0.225 0.725q-0.35 2.275-1.975 3.925t-3.95 1.975v2.075q0 0.425-0.2875 0.7125T12 21q-0.425 0-0.7125-0.2875T11 20Z",
        "sports_esports": "M4.55 19q-1.275 0-1.975-0.8875T2.05 15.95l1.05-7.5q0.225-1.5 1.3375-2.475T7.05 5h9.9q1.5 0 2.6125 0.975t1.3375 2.475l1.05 7.5q0.175 1.275-0.525 2.1625T19.45 19q-0.525 0-0.975-0.1875T17.65 18.25l-2.25-2.25H8.6l-2.25 2.25q-0.375 0.375-0.825 0.5625t-0.975 0.1875Zm12.45-6q0.425 0 0.7125-0.2875T18 12q0-0.425-0.2875-0.7125T17 11q-0.425 0-0.7125 0.2875T16 12q0 0.425 0.2875 0.7125T17 13Zm-2-3q0.425 0 0.7125-0.2875T16 9q0-0.425-0.2875-0.7125T15 8q-0.425 0-0.7125 0.2875T14 9q0 0.425 0.2875 0.7125T15 10Zm-7.25 1.25v1q0 0.325 0.2125 0.5375T8.5 13q0.325 0 0.5375-0.2125T9.25 12.25v-1h1q0.325 0 0.5375-0.2125T11 10.5q0-0.325-0.2125-0.5375T10.25 9.75h-1v-1q0-0.325-0.2125-0.5375T8.5 8q-0.325 0-0.5375 0.2125T7.75 8.75v1h-1q-0.325 0-0.5375 0.2125T6 10.5q0 0.325 0.2125 0.5375T6.75 11.25h1Z",
        "folder": "M4 20q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4h5.175q0.4 0 0.7625 0.15t0.6375 0.425l1.425 1.425h8q0.825 0 1.4125 0.5875T22 8v10q0 0.825-0.5875 1.4125T20 20H4Z",
        "settings": "M10.825 22q-0.675 0-1.1625-0.45T9.075 20.45l-0.225-1.65q-0.325-0.125-0.6125-0.3T7.675 18.125l-1.55 0.65q-0.625 0.275-1.25 0.05t-0.975-0.8l-1.175-2.05q-0.35-0.575-0.2-1.225t0.675-1.075l1.325-1q-0.025-0.175-0.025-0.3375v-0.675q0-0.1625 0.025-0.3375l-1.325-1q-0.525-0.425-0.675-1.075t0.2-1.225l1.175-2.05q0.35-0.575 0.975-0.8t1.25 0.05l1.55 0.65q0.275-0.2 0.575-0.375t0.6-0.3l0.225-1.65q0.1-0.65 0.5875-1.1t1.1625-0.45h2.35q0.675 0 1.1625 0.45t0.5875 1.1l0.225 1.65q0.325 0.125 0.6125 0.3t0.5625 0.375l1.55-0.65q0.625-0.275 1.25-0.05t0.975 0.8l1.175 2.05q0.35 0.575 0.2 1.225t-0.675 1.075l-1.325 1q0.025 0.175 0.025 0.3375v0.675q0 0.1625-0.05 0.3375l1.325 1q0.525 0.425 0.675 1.075t-0.2 1.225l-1.2 2.05q-0.35 0.575-0.975 0.8t-1.25-0.05l-1.5-0.65q-0.275 0.2-0.575 0.375t-0.6 0.3l-0.225 1.65q-0.1 0.65-0.5875 1.1T13.175 22h-2.35Zm1.225-6.5q1.45 0 2.475-1.025t1.025-2.475q0-1.45-1.025-2.475t-2.475-1.025q-1.475 0-2.4875 1.025T8.55 12q0 1.45 1.0125 2.475t2.4875 1.025Z",
        "monitor_heart": "M4 20q-0.825 0-1.4125-0.5875T2 18v-4q0-0.425 0.2875-0.7125T3 13h4.375l1.725 3.45q0.125 0.275 0.375 0.4125t0.525 0.1375q0.275 0 0.525-0.1375t0.375-0.4125l3.1-6.2l1.1 2.2q0.125 0.275 0.375 0.4125t0.525 0.1375h5q0.425 0 0.7125 0.2875T22 14v4q0 0.825-0.5875 1.4125T20 20H4ZM2 6q0-0.825 0.5875-1.4125T4 4h16q0.825 0 1.4125 0.5875T22 6v4q0 0.425-0.2875 0.7125T21 11H16.625l-1.725-3.45q-0.125-0.275-0.375-0.3875t-0.525-0.1125q-0.275 0-0.525 0.1125T13.1 7.55L10 13.75l-1.1-2.2q-0.125-0.275-0.375-0.4125t-0.525-0.1375H3q-0.425 0-0.7125-0.2875T2 10v-4Z",
        "terminal": "M4 20q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4h16q0.825 0 1.4125 0.5875T22 6v12q0 0.825-0.5875 1.4125T20 20H4Zm0-2h16v-10H4v10Zm4.675-5l-1.9-1.9q-0.3-0.3-0.2875-0.7t0.3125-0.7q0.3-0.275 0.7-0.2875t0.7 0.2875l2.6 2.6q0.3 0.3 0.3 0.7t-0.3 0.7L8.2 16.3q-0.275 0.275-0.6875 0.2875T6.8 16.3q-0.275-0.275-0.275-0.7t0.275-0.7l1.875-1.9Zm4.325 4q-0.425 0-0.7125-0.2875T12 16q0-0.425 0.2875-0.7125T13 15h4q0.425 0 0.7125 0.2875T18 16q0 0.425-0.2875 0.7125T17 17H13Z",
        "build": "M9 15q-2.5 0-4.25-1.75t-1.75-4.25q0-0.5 0.075-1t0.275-0.95q0.125-0.25 0.3125-0.375t0.4125-0.175q0.225-0.05 0.4625 0.0125T4.975 6.775l2.625 2.625l1.8-1.8l-2.625-2.625q-0.2-0.2-0.2625-0.4375T6.5 4.075q0.05-0.225 0.175-0.4125t0.375-0.3125q0.45-0.2 0.95-0.275t1-0.075q2.5 0 4.25 1.75t1.75 4.25q0 0.575-0.1 1.0875T14.6 11.1l5.05 5q0.725 0.725 0.725 1.775t-0.725 1.775q-0.725 0.725-1.775 0.725t-1.775-0.75L11.1 14.6q-0.5 0.2-1.0125 0.3t-1.0875 0.1Z",
        "graphic_eq": "M7 17v-10q0-0.425 0.2875-0.7125T8 6q0.425 0 0.7125 0.2875T9 7v10q0 0.425-0.2875 0.7125T8 18q-0.425 0-0.7125-0.2875T7 17Zm4 4v-18q0-0.425 0.2875-0.7125T12 2q0.425 0 0.7125 0.2875T13 3v18q0 0.425-0.2875 0.7125T12 22q-0.425 0-0.7125-0.2875T11 21ZM3 13v-2q0-0.425 0.2875-0.7125T4 10q0.425 0 0.7125 0.2875T5 11v2q0 0.425-0.2875 0.7125T4 14q-0.425 0-0.7125-0.2875T3 13Zm12 4v-10q0-0.425 0.2875-0.7125T16 6q0.425 0 0.7125 0.2875T17 7v10q0 0.425-0.2875 0.7125T16 18q-0.425 0-0.7125-0.2875T15 17Zm4-4v-2q0-0.425 0.2875-0.7125T20 10q0.425 0 0.7125 0.2875T21 11v2q0 0.425-0.2875 0.7125T20 14q-0.425 0-0.7125-0.2875T19 13Z",
        "movie": "M4 4l1.625 3.25q0.175 0.35 0.5 0.55t0.7 0.2q0.75 0 1.15-0.6375t0.05-1.3125l-1.025-2.05h2l1.625 3.25q0.175 0.35 0.5 0.55t0.7 0.2q0.75 0 1.15-0.6375t0.05-1.3125l-1.025-2.05h2l1.625 3.25q0.175 0.35 0.5 0.55t0.7 0.2q0.75 0 1.15-0.6375t0.05-1.3125l-1.025-2.05h3q0.825 0 1.4125 0.5875T22 6v12q0 0.825-0.5875 1.4125T20 20H4q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4Z",
        "videocam": "M4 20q-0.825 0-1.4125-0.5875T2 18v-12q0-0.825 0.5875-1.4125T4 4h12q0.825 0 1.4125 0.5875T18 6v4.5l3.15-3.15q0.25-0.25 0.55-0.125t0.3 0.475v8.6q0 0.35-0.3 0.475t-0.55-0.125L18 13.5v4.5q0 0.825-0.5875 1.4125T16 20H4Z",
        "photo_library": "M9 14h10L15.55 9.5l-2.3 3l-1.55-2l-2.7 3.5Zm-1 4q-0.825 0-1.4125-0.5875T6 16v-12q0-0.825 0.5875-1.4125T8 2h12q0.825 0 1.4125 0.5875T22 4v12q0 0.825-0.5875 1.4125T20 18H8Zm0-2h12v-12H8v12ZM4 22q-0.825 0-1.4125-0.5875T2 20v-14h2v14h14v2H4Zm4-18h12v12H8v-12Z",
        "tv": "M4 19q-0.825 0-1.4125-0.5875T2 17v-12q0-0.825 0.5875-1.4125T4 3h16q0.825 0 1.4125 0.5875T22 5v12q0 0.825-0.5875 1.4125T20 19H16v1q0 0.425-0.2875 0.7125T15 21H9q-0.425 0-0.7125-0.2875T8 20v-1H4Z",
        "host": "M4 21q-0.825 0-1.4125-0.5875T2 19v-14q0-0.825 0.5875-1.4125T4 3h5q0.825 0 1.4125 0.5875T11 5v14q0 0.825-0.5875 1.4125T9 21H4Zm11 0q-0.825 0-1.4125-0.5875T13 19v-14q0-0.825 0.5875-1.4125T15 3h5q0.825 0 1.4125 0.5875T22 5v14q0 0.825-0.5875 1.4125T20 21H15ZM8 14q0-0.425-0.2875-0.7125T7 13h-1q-0.425 0-0.7125 0.2875T5 14q0 0.425 0.2875 0.7125T6 15h1q0.425 0 0.7125-0.2875T8 14Zm11 0q0-0.425-0.2875-0.7125T18 13h-1q-0.425 0-0.7125 0.2875T16 14q0 0.425 0.2875 0.7125T17 15h1q0.425 0 0.7125-0.2875T19 14ZM8 11q0-0.425-0.2875-0.7125T7 10h-1q-0.425 0-0.7125 0.2875T5 11q0 0.425 0.2875 0.7125T6 12h1q0.425 0 0.7125-0.2875T8 11Zm11 0q0-0.425-0.2875-0.7125T18 10h-1q-0.425 0-0.7125 0.2875T16 11q0 0.425 0.2875 0.7125T17 12h1q0.425 0 0.7125-0.2875T19 11ZM8 8q0-0.425-0.2875-0.7125T7 7h-1q-0.425 0-0.7125 0.2875T5 8q0 0.425 0.2875 0.7125T6 9h1q0.425 0 0.7125-0.2875T8 8Zm11 0q0-0.425-0.2875-0.7125T18 7h-1q-0.425 0-0.7125 0.2875T16 8q0 0.425 0.2875 0.7125T17 9h1q0.425 0 0.7125-0.2875T19 8Z",
        "content_paste": "M5 21q-0.825 0-1.4125-0.5875T3 19v-14q0-0.825 0.5875-1.4125T5 3h4.175q0.275-0.875 1.075-1.4375t1.75-0.5625q1 0 1.7875 0.5625T14.85 3h4.15q0.825 0 1.4125 0.5875T21 5v14q0 0.825-0.5875 1.4125T19 21H5Zm0-2h14v-14h-2v2q0 0.425-0.2875 0.7125T16 8H8q-0.425 0-0.7125-0.2875T7 7v-2h-2v14Zm7-14q0.425 0 0.7125-0.2875T13 4q0-0.425-0.2875-0.7125T12 3q-0.425 0-0.7125 0.2875T11 4q0 0.425 0.2875 0.7125T12 5Z",
        "checklist": "M5.525 16.175l3.55-3.55q0.3-0.3 0.7-0.2875t0.7 0.3125q0.275 0.3 0.275 0.7t-0.275 0.7L6.25 18.3q-0.3 0.3-0.7 0.3t-0.7-0.3l-2.15-2.15q-0.275-0.275-0.275-0.7t0.275-0.7q0.275-0.275 0.7-0.275t0.7 0.275l1.425 1.425Zm0-8l3.55-3.55q0.3-0.3 0.7-0.2875t0.7 0.3125q0.275 0.3 0.275 0.7t-0.275 0.7L6.25 10.3q-0.3 0.3-0.7 0.3t-0.7-0.3l-2.15-2.15q-0.275-0.275-0.275-0.7t0.275-0.7q0.275-0.275 0.7-0.275t0.7 0.275l1.425 1.425Zm8.475 8.825q-0.425 0-0.7125-0.2875T13 16q0-0.425 0.2875-0.7125T14 15h7q0.425 0 0.7125 0.2875T22 16q0 0.425-0.2875 0.7125T21 17H14Zm0-8q-0.425 0-0.7125-0.2875T13 8q0-0.425 0.2875-0.7125T14 7h7q0.425 0 0.7125 0.2875T22 8q0 0.425-0.2875 0.7125T21 9H14Z",
        "layers": "M4.025 14.85q-0.4-0.3-0.3875-0.7875T4.05 13.275q0.275-0.2 0.6-0.2t0.6 0.2l6.75 5.225l6.75-5.225q0.275-0.2 0.6-0.2t0.6 0.2q0.4 0.3 0.4125 0.7875T19.975 14.85L13.225 20.1q-0.55 0.425-1.225 0.425t-1.225-0.425L4.025 14.85Zm6.75 0.2L5.025 10.575q-0.775-0.6-0.775-1.575t0.775-1.575l5.75-4.475q0.55-0.425 1.225-0.425t1.225 0.425l5.75 4.475q0.775 0.6 0.775 1.575t-0.775 1.575L13.225 15.05q-0.55 0.425-1.225 0.425t-1.225-0.425Z",
        "apps": "M6 20q-0.825 0-1.4125-0.5875T4 18q0-0.825 0.5875-1.4125T6 16q0.825 0 1.4125 0.5875T8 18q0 0.825-0.5875 1.4125T6 20Zm6 0q-0.825 0-1.4125-0.5875T10 18q0-0.825 0.5875-1.4125T12 16q0.825 0 1.4125 0.5875T14 18q0 0.825-0.5875 1.4125T12 20Zm6 0q-0.825 0-1.4125-0.5875T16 18q0-0.825 0.5875-1.4125T18 16q0.825 0 1.4125 0.5875T20 18q0 0.825-0.5875 1.4125T18 20ZM6 14q-0.825 0-1.4125-0.5875T4 12q0-0.825 0.5875-1.4125T6 10q0.825 0 1.4125 0.5875T8 12q0 0.825-0.5875 1.4125T6 14Zm6 0q-0.825 0-1.4125-0.5875T10 12q0-0.825 0.5875-1.4125T12 10q0.825 0 1.4125 0.5875T14 12q0 0.825-0.5875 1.4125T12 14Zm6 0q-0.825 0-1.4125-0.5875T16 12q0-0.825 0.5875-1.4125T18 10q0.825 0 1.4125 0.5875T20 12q0 0.825-0.5875 1.4125T18 14ZM6 8q-0.825 0-1.4125-0.5875T4 6q0-0.825 0.5875-1.4125T6 4q0.825 0 1.4125 0.5875T8 6q0 0.825-0.5875 1.4125T6 8Zm6 0q-0.825 0-1.4125-0.5875T10 6q0-0.825 0.5875-1.4125T12 4q0.825 0 1.4125 0.5875T14 6q0 0.825-0.5875 1.4125T12 8Zm6 0q-0.825 0-1.4125-0.5875T16 6q0-0.825 0.5875-1.4125T18 4q0.825 0 1.4125 0.5875T20 6q0 0.825-0.5875 1.4125T18 8Z"
    })
    // a window's desktop-entry Categories pick its glyph, first match wins, so
    // the order is the priority. ported from caelestia's Icons.qml categoryIcons
    readonly property var categoryGlyphs: [
        ["WebBrowser", "web"],
        ["Email", "mail"],
        ["InstantMessaging", "chat"],
        ["IRCClient", "chat"],
        ["Printing", "print"],
        ["Security", "security"],
        ["Network", "chat"],
        ["Archiving", "archive"],
        ["Compression", "archive"],
        ["Development", "code"],
        ["IDE", "code"],
        ["TextEditor", "edit_note"],
        ["Audio", "music_note"],
        ["Music", "music_note"],
        ["Player", "music_note"],
        ["Recorder", "mic"],
        ["Game", "sports_esports"],
        ["FileTools", "folder"],
        ["FileManager", "folder"],
        ["Filesystem", "folder"],
        ["FileTransfer", "folder"],
        ["Settings", "settings"],
        ["DesktopSettings", "settings"],
        ["HardwareSettings", "settings"],
        // ahead of the terminal rows: btop and htop are System;Monitor;ConsoleOnly
        ["Monitor", "monitor_heart"],
        ["TerminalEmulator", "terminal"],
        ["ConsoleOnly", "terminal"],
        ["ProjectManagement", "checklist"],
        ["Utility", "build"],
        ["Midi", "graphic_eq"],
        ["Mixer", "graphic_eq"],
        ["AudioVideoEditing", "movie"],
        ["AudioVideo", "movie"],
        ["Video", "videocam"],
        ["Building", "build"],
        ["Graphics", "photo_library"],
        ["2DGraphics", "photo_library"],
        ["RasterGraphics", "photo_library"],
        ["TV", "tv"],
        ["System", "host"],
        ["Office", "content_paste"]
    ]

    // ids: desktop entries, native before flatpak. class: case-blind. title: builds with no class
    readonly property var catalog: ({
        "music": [
            { "id": "spotify", "name": "Spotify", "ids": ["spotify", "com.spotify.Client", "spotify-launcher"], "class": ["spotify"], "title": ["Spotify", "Spotify Free", "Spotify Premium"] },
            { "id": "feishin", "name": "Feishin", "ids": ["feishin", "org.jeffvli.feishin"], "class": ["feishin"] },
            { "id": "supersonic", "name": "Supersonic", "ids": ["supersonic-desktop", "supersonic", "io.github.dweymouth.supersonic"], "class": ["supersonic"] },
            { "id": "cider", "name": "Cider", "ids": ["cider", "sh.cider.Cider", "sh.cider.genten"], "class": ["cider"] },
            { "id": "ytmusic", "name": "YouTube Music", "ids": ["youtube-music", "com.github.th-ch.youtube-music", "youtube-music-desktop-app"], "class": ["com.github.th-ch.youtube-music", "youtube-music", "youtube music"] },
            { "id": "tidal", "name": "TIDAL Hi-Fi", "ids": ["tidal-hifi", "com.mastermindzh.tidal-hifi"], "class": ["tidal-hifi"] },
            { "id": "plexamp", "name": "Plexamp", "ids": ["plexamp", "com.plexamp.Plexamp"], "class": ["plexamp"] },
            { "id": "amberol", "name": "Amberol", "ids": ["io.bassi.Amberol"], "class": ["io.bassi.amberol"] },
            { "id": "rhythmbox", "name": "Rhythmbox", "ids": ["org.gnome.Rhythmbox3"], "class": ["rhythmbox", "org.gnome.rhythmbox3"] },
            { "id": "strawberry", "name": "Strawberry", "ids": ["org.strawberrymusicplayer.strawberry"], "class": ["strawberry", "org.strawberrymusicplayer.strawberry"] },
            { "id": "elisa", "name": "Elisa", "ids": ["org.kde.elisa"], "class": ["elisa", "org.kde.elisa"] }
        ],
        "comms": [
            { "id": "discord", "name": "Discord", "ids": ["discord", "com.discordapp.Discord"], "class": ["discord"] },
            { "id": "vesktop", "name": "Vesktop", "ids": ["vesktop", "dev.vencord.Vesktop"], "class": ["vesktop"] },
            { "id": "equibop", "name": "Equibop", "ids": ["equibop", "io.github.equicord.equibop"], "class": ["equibop"] },
            { "id": "legcord", "name": "Legcord", "ids": ["legcord", "app.legcord.Legcord"], "class": ["legcord"] },
            { "id": "telegram", "name": "Telegram", "ids": ["org.telegram.desktop", "telegramdesktop"], "class": ["org.telegram.desktop", "telegramdesktop", "telegram-desktop"] },
            { "id": "signal", "name": "Signal", "ids": ["signal-desktop", "org.signal.Signal", "signal"], "class": ["signal", "signal-desktop"] },
            { "id": "element", "name": "Element", "ids": ["element-desktop", "im.riot.Riot", "io.element.Element"], "class": ["element"] },
            { "id": "zapzap", "name": "ZapZap", "ids": ["com.rtosta.zapzap", "zapzap"], "class": ["com.rtosta.zapzap", "zapzap"] },
            { "id": "wasistlos", "name": "WasIstLos", "ids": ["com.github.xeco23.WasIstLos", "wasistlos", "whatsapp-for-linux"], "class": ["wasistlos", "com.github.xeco23.wasistlos", "whatsapp-for-linux"] },
            { "id": "slack", "name": "Slack", "ids": ["slack", "com.slack.Slack"], "class": ["slack"] },
            { "id": "teams", "name": "Teams for Linux", "ids": ["teams-for-linux", "com.github.IsmaelMartinez.teams_for_linux"], "class": ["teams-for-linux"] },
            { "id": "thunderbird", "name": "Thunderbird", "ids": ["org.mozilla.Thunderbird", "thunderbird"], "class": ["thunderbird", "org.mozilla.thunderbird"] }
        ],
        "todo": [
            { "id": "todoist", "name": "Todoist", "ids": ["todoist", "com.todoist.Todoist"], "class": ["todoist"] },
            { "id": "planify", "name": "Planify", "ids": ["io.github.alainm23.planify"], "class": ["io.github.alainm23.planify"] },
            { "id": "errands", "name": "Errands", "ids": ["io.github.mrvladus.Errands"], "class": ["io.github.mrvladus.errands"] },
            { "id": "endeavour", "name": "Endeavour", "ids": ["org.gnome.Todo"], "class": ["org.gnome.todo", "gnome-todo"] },
            { "id": "superproductivity", "name": "Super Productivity", "ids": ["superproductivity", "com.super_productivity.SuperProductivity"], "class": ["superproductivity"] },
            { "id": "obsidian", "name": "Obsidian", "ids": ["obsidian", "md.obsidian.Obsidian"], "class": ["obsidian"] },
            { "id": "logseq", "name": "Logseq", "ids": ["logseq", "com.logseq.Logseq"], "class": ["logseq"] }
        ],
        "sysmon": [
            { "id": "btop", "name": "btop", "ids": ["btop"], "term": "btop", "class": ["lucid.btop"] },
            { "id": "htop", "name": "htop", "ids": ["htop"], "term": "htop", "class": ["lucid.htop"] },
            { "id": "missioncenter", "name": "Mission Center", "ids": ["io.missioncenter.MissionCenter"], "class": ["io.missioncenter.missioncenter"] },
            { "id": "resources", "name": "Resources", "ids": ["net.nokyan.Resources"], "class": ["net.nokyan.resources"] },
            { "id": "gnomesysmon", "name": "System Monitor", "ids": ["org.gnome.SystemMonitor", "gnome-system-monitor"], "class": ["gnome-system-monitor", "org.gnome.systemmonitor"] },
            { "id": "plasmasysmon", "name": "System Monitor", "ids": ["org.kde.plasma-systemmonitor"], "class": ["org.kde.plasma-systemmonitor", "plasma-systemmonitor"] }
        ]
    })

    // touch this in a binding that calls a lookup, so it re-runs as entries land
    readonly property int entryCount: DesktopEntries.applications.values.length

    // desktop entries arrive over a few seconds, so this settles late
    readonly property var available: {
        void DesktopEntries.applications.values.length;
        const out = {};
        for (const ws in root.catalog) {
            out[ws] = root.catalog[ws].filter((app) => {
                return root.entryOf(app) !== null;
            });
        }
        return out;
    }

    function entryOf(app) {
        for (const id of app.ids) {
            const e = DesktopEntries.byId(id);
            if (e)
                return e;

        }
        return null;
    }

    function space(key) {
        return root.spaces.find((s) => {
            return s.key === key;
        }) || null;
    }

    function appById(ws, id) {
        if (root.isCustom(id))
            return root.customApp(id);

        return (root.catalog[ws] || []).find((a) => {
            return a.id === id;
        }) || null;
    }

    function isCustom(id) {
        return String(id).indexOf(root.customPrefix) === 0;
    }

    // a terminal app takes the class the launcher is told to give it, dotted so
    // ghostty accepts it as an app id
    function termClass(entryId) {
        return "lucid." + String(entryId).toLowerCase().replace(/[^a-z0-9]+/g, "-");
    }

    // any installed app in the shape of a catalogue one. the class is a guess:
    // the desktop id for most toolkits, the program name otherwise, and
    // StartupWMClass on top of both in appLua
    function customApp(id) {
        const entryId = String(id).slice(root.customPrefix.length);
        const e = DesktopEntries.byId(entryId);
        if (!e)
            return null;

        const classes = [entryId];
        const prog = (e.command || [])[0];
        if (prog) {
            const base = String(prog).split("/").pop();
            if (base !== "" && root.execWrappers.indexOf(base) === -1 && base.toLowerCase() !== entryId.toLowerCase())
                classes.push(base);

        }
        return {
            "id": id,
            "name": e.name || entryId,
            "ids": [entryId],
            "class": e.runInTerminal ? [root.termClass(entryId)] : classes,
            "custom": true
        };
    }

    function runsInTerm(app, entry) {
        return app.term ? true : (app.custom === true && entry.runInTerminal === true);
    }

    // everything installed that the page does not already list for this workspace
    function installedApps(ws) {
        const taken = {};
        for (const a of root.catalog[ws] || []) {
            const e = root.entryOf(a);
            if (e)
                taken[e.id] = true;

        }
        for (const id of root.chosen(ws)) {
            if (root.isCustom(id))
                taken[String(id).slice(root.customPrefix.length)] = true;

        }
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay || taken[e.id])
                continue;

            out.push({
                "id": e.id,
                "name": e.name || e.id,
                "icon": e.icon ? Quickshell.iconPath(e.icon, true) : "",
                "note": e.genericName || e.comment || ""
            });
        }
        out.sort((a, b) => {
            const x = a.name.toLowerCase();
            const y = b.name.toLowerCase();
            return x < y ? -1 : (x > y ? 1 : 0);
        });
        return out;
    }

    function addApp(ws, entryId) {
        root.setChosen(ws, root.customPrefix + entryId, true);
    }

    function isOn(key) {
        const s = root.space(key);
        if (s && s.own)
            return s.on;

        return s ? Prefs[s.pref] !== false : true;
    }

    function setOn(key, on) {
        const s = root.space(key);
        if (s && s.own)
            root.editOwn(key, {
            "on": on
        });
        else if (s)
            Prefs.set(s.pref, on);
    }

    function isOwn(key) {
        const s = root.space(key);
        return s !== null && s.own === true;
    }

    function saveOwn(list) {
        Prefs.specialCustom = JSON.stringify(list.map((w) => {
            return {
                "key": w.key,
                "label": w.label,
                "glyph": w.glyph,
                "on": w.on,
                "apps": w.apps
            };
        }));
    }

    function editOwn(key, change) {
        root.saveOwn(root.ownSpaces.map((w) => {
            return w.key === key ? Object.assign({}, w, change) : w;
        }));
    }

    // Música -> musica; anything with no latin letters falls back to space
    function keyFor(label) {
        let base = String(label || "");
        try {
            base = base.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        } catch (e) {
        }
        base = base.toLowerCase().replace(/[^a-z0-9]+/g, "_").substring(0, 20).replace(/^[^a-z]+|_+$/g, "");
        if (base === "")
            base = "space";

        let key = base;
        for (let n = 2; root.space(key) !== null || root.reserved.indexOf(key) !== -1; n++) key = base + n
        return key;
    }

    // returns the new workspace's key
    function create(label, glyph) {
        const name = String(label || "").trim();
        if (name === "")
            return "";

        const key = root.keyFor(name);
        root.saveOwn(root.ownSpaces.concat([{
            "key": key,
            "label": name,
            "glyph": root.glyphs[glyph] ? glyph : "apps",
            "on": true,
            "apps": ""
        }]));
        return key;
    }

    // the key stays, so the workspace and its bind carry over a rename
    function rename(key, label, glyph) {
        const name = String(label || "").trim();
        if (name === "" || !root.isOwn(key))
            return ;

        const old = root.space(key).label;
        root.editOwn(key, {
            "label": name,
            "glyph": root.glyphs[glyph] ? glyph : "apps"
        });
        // a description you wrote yourself is left alone
        const b = root.bindOf(key);
        if (b && b.desc === root.bindDesc(old))
            Keybinds.upsert(Object.assign({}, b, {
            "desc": root.bindDesc(name)
        }));

    }

    // its windows come back to the workspace you are on, and its key goes with it
    function remove(key) {
        if (!root.isOwn(key))
            return ;

        Quickshell.execDetached(["hyprctl", "eval", "if LucidSpecials then LucidSpecials.release(" + root.luaStr(key) + ") end"]);
        const b = root.bindOf(key);
        if (b)
            Keybinds.remove(b.id);

        root.saveOwn(root.ownSpaces.filter((w) => {
            return w.key !== key;
        }));
    }

    function bindDesc(label) {
        return label + " workspace";
    }

    function bindLua(key) {
        return key === "special" ? "specials.scratchpad()" : "specials.toggle(" + JSON.stringify(key) + ")";
    }

    // the bind that opens a workspace, found by what it runs so an edited or
    // hand-written one counts too
    function bindOf(key) {
        const want = root.bindLua(key).replace(/\s+/g, "").replace(/'/g, "\"");
        for (const b of Keybinds.binds) {
            if (b.type === "lua" && String(b.lua || "").replace(/\s+/g, "").replace(/'/g, "\"") === want)
                return b;

        }
        return null;
    }

    // a bind for the key editor to start from, keys still to be pressed
    function newBind(key) {
        const s = root.space(key);
        return {
            "keys": "",
            "desc": root.bindDesc(s ? s.label : key),
            "category": "Workspaces",
            "type": "lua",
            "lua": root.bindLua(key)
        };
    }

    // what opens it, as keycaps: [] when nothing does
    function keysOf(key) {
        const s = root.space(key);
        if (!Keybinds.loaded || Keybinds.missing)
            return s && s.keys ? s.keys : [];

        const b = root.bindOf(key);
        return b && b.enabled !== false && b.keys ? Keybinds.tokens(b.keys) : [];
    }

    // "auto" means the first one installed
    function chosen(ws) {
        const s = root.space(ws);
        if (!s || (s.apps === "" && !s.own))
            return [];

        const raw = s.own ? s.apps : Prefs[s.apps];
        const avail = root.available[ws] || [];
        if (raw === "auto")
            return avail.length > 0 ? [avail[0].id] : [];

        return Prefs.splitList(raw).filter((id) => {
            if (root.isCustom(id))
                return root.customApp(id) !== null;

            return avail.some((a) => {
                return a.id === id;
            });
        });
    }

    function isChosen(ws, id) {
        return root.chosen(ws).indexOf(id) !== -1;
    }

    function setChosen(ws, id, on) {
        const s = root.space(ws);
        if (!s || (s.apps === "" && !s.own))
            return ;

        const list = root.chosen(ws).filter((x) => {
            return x !== id;
        });
        if (on)
            list.push(id);

        const order = (root.catalog[ws] || []).map((a) => {
            return a.id;
        });
        const known = list.filter((x) => {
            return order.indexOf(x) !== -1;
        }).sort((a, b) => {
            return order.indexOf(a) - order.indexOf(b);
        });
        const added = list.filter((x) => {
            return order.indexOf(x) === -1;
        });
        const value = known.concat(added).join(",");
        if (s.own)
            root.editOwn(ws, {
            "apps": value
        });
        else
            Prefs.set(s.apps, value);
    }

    function chosenNames(ws) {
        return root.chosen(ws).map((id) => {
            const a = root.appById(ws, id);
            return a ? a.name : id;
        });
    }

    function iconOf(ws, id) {
        const a = root.appById(ws, id);
        const e = a ? root.entryOf(a) : null;
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    function keysText(keys) {
        return keys.join(" + ");
    }

    // special:music -> Music
    function label(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const s = root.space(bare);
        return s ? s.label : (bare === "" ? "special" : bare);
    }

    // special:music -> the workspace's own mark
    function glyph(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const s = root.space(bare);
        return s && s.glyph ? s.glyph : "apps";
    }

    // terminal apps run under a forced lucid.<id> class
    function entryForClass(cls) {
        const c = String(cls || "");
        if (c === "")
            return null;

        const bare = c.indexOf("lucid.") === 0 ? c.slice(6) : c;
        return DesktopEntries.heuristicLookup(bare) || DesktopEntries.heuristicLookup(c) || null;
    }

    // a stashed window's mark: its entry's category, else the workspace's own
    function appGlyph(cls, wsName) {
        const e = root.entryForClass(cls);
        const cats = e && e.categories ? e.categories : [];
        if (cats.length > 0) {
            for (const pair of root.categoryGlyphs) {
                if (cats.indexOf(pair[0]) !== -1)
                    return pair[1];

            }
        }
        return root.glyph(wsName);
    }

    function glyphPath(name) {
        return root.glyphs[name] || root.glyphs["apps"];
    }

    function order(name) {
        const bare = String(name).indexOf("special:") === 0 ? String(name).slice(8) : String(name);
        const i = root.spaces.findIndex((s) => {
            return s.key === bare;
        });
        return i === -1 ? root.spaces.length : i;
    }

    function luaStr(s) {
        return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n").replace(/\r/g, "\\r") + "\"";
    }

    function luaList(list) {
        return "{ " + list.map(root.luaStr).join(", ") + " }";
    }

    function shQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function termCommand(argv, cls) {
        const p = argv.map(root.shQuote).join(" ");
        const c = root.shQuote(cls);
        return "if command -v kitty >/dev/null 2>&1; then exec kitty --class " + c + " -e " + p + "; " + "elif command -v foot >/dev/null 2>&1; then exec foot --app-id=" + c + " " + p + "; " + "elif command -v alacritty >/dev/null 2>&1; then exec alacritty --class " + c + " -e " + p + "; " + "elif command -v ghostty >/dev/null 2>&1; then exec ghostty --class=" + c + " -e " + p + "; fi";
    }

    // exec keeps the pid that launch rules go by; drops flags a field code left empty (--uri=)
    function launchCommand(app, entry) {
        if (app.term)
            return root.termCommand([app.term], app.class[0]);

        const argv = (entry.command || []).filter((a) => {
            return !/^--?[A-Za-z0-9_-]+=$/.test(a);
        });
        if (argv.length === 0)
            return "";

        if (root.runsInTerm(app, entry))
            return root.termCommand(argv, app.class[0]);

        return "exec " + argv.map(root.shQuote).join(" ");
    }

    function appLua(ws, id) {
        const app = root.appById(ws, id);
        const entry = app ? root.entryOf(app) : null;
        if (!entry)
            return "";

        const classes = app.class.slice();
        if (!root.runsInTerm(app, entry) && entry.startupClass && !classes.some((c) => {
            return c.toLowerCase() === entry.startupClass.toLowerCase();
        }))
            classes.push(entry.startupClass);

        let out = "{ name = " + root.luaStr(app.name) + ", cmd = " + root.luaStr(root.launchCommand(app, entry)) + ", class = " + root.luaList(classes);
        if (app.title && app.title.length > 0)
            out += ", title = " + root.luaList(app.title);

        return out + " }";
    }

    readonly property string rendered: {
        let out = "-- written by Lucid Settings > Workspaces, and rewritten on every change there\n";
        out += "return {\n";
        out += "    keep = " + (Prefs.specialKeepApps ? "true" : "false") + ",\n";
        out += "    hide_on_switch = " + (Prefs.specialHideOnSwitch ? "true" : "false") + ",\n";
        out += "    dim = " + Math.round(Prefs.specialDim * 100) / 100 + ",\n";
        out += "    blur = " + (Prefs.specialBlur ? "true" : "false") + ",\n";
        out += "    gaps = " + Math.max(0, Math.round(Prefs.specialGaps)) + ",\n";
        out += "    workspaces = {\n";
        for (const s of root.spaces) {
            const apps = root.chosen(s.key).map((id) => {
                return root.appLua(s.key, id);
            }).filter((x) => {
                return x !== "";
            });
            out += "        " + s.key + " = { enabled = " + (root.isOn(s.key) ? "true" : "false") + ", apps = {";
            out += apps.length > 0 ? "\n" + apps.map((a) => {
                return "            " + a + ",\n";
            }).join("") + "        } },\n" : "} },\n";
        }
        out += "    },\n}\n";
        return out;
    }

    function write() {
        if (!Prefs.loaded || !dataFile.ready || root.rendered === dataFile.current)
            return ;

        dataFile.current = root.rendered;
        dataFile.setText(root.rendered);
    }

    Timer {
        id: writeDebounce

        interval: 1200
        repeat: false
        onTriggered: root.write()
    }

    onRenderedChanged: writeDebounce.restart()

    Connections {
        function onLoadedChanged() {
            writeDebounce.restart();
        }

        target: Prefs
    }

    FileView {
        id: dataFile

        property bool ready: false
        property string current: ""

        path: root.dataPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            dataFile.current = dataFile.text();
            dataFile.ready = true;
            writeDebounce.restart();
        }
        onLoadFailed: {
            dataFile.current = "";
            dataFile.ready = true;
            writeDebounce.restart();
        }
        // routing rules live in hyprland, so it re-reads once the file is on disk
        onSaved: Quickshell.execDetached(["hyprctl", "eval", "if LucidSpecials then LucidSpecials.apply() end"])
    }

    // missing after --no-hypr, and the page says so
    FileView {
        path: root.modulePath
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.moduleInstalled = true;
            root.moduleProbed = true;
        }
        onLoadFailed: {
            root.moduleInstalled = false;
            root.moduleProbed = true;
        }
    }

}
