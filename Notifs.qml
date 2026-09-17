pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications
import qs

// the whole notification centre's state: the server, the history, the
// grouping, and the popup queue. the bar pill and the popup window are both
// views onto this.
Singleton {
    id: root

    // material symbols rounded, converted to a 24dp grid
    readonly property var icons: ({
        "notifications": "M5 19q-0.425 0 -0.713 -0.288T4 18q0 -0.425 0.288 -0.713T5 17h1v-7q0 -2.075 1.25 -3.688T10.5 4.2v-0.7q0 -0.625 0.438 -1.062T12 2q0.625 0 1.062 0.438T13.5 3.5v0.7q2 0.5 3.25 2.113T18 10v7h1q0.425 0 0.713 0.288T20 18q0 0.425 -0.288 0.713T19 19H5ZM12 22q-0.825 0 -1.413 -0.588T10 20h4q0 0.825 -0.588 1.413T12 22Z",
        "notifications_off": "M16.15 19H5q-0.425 0 -0.713 -0.288T4 18q0 -0.425 0.288 -0.713T5 17h1v-7q0 -0.825 0.213 -1.625t0.638 -1.525l3.15 3.15H7.2L2.1 4.9q-0.275 -0.275 -0.275 -0.7t0.275 -0.7q0.275 -0.275 0.7 -0.275t0.7 0.275l17 17q0.275 0.275 0.288 0.688T20.5 21.9q-0.275 0.275 -0.7 0.275t-0.7 -0.275L16.15 19Zm1.85 -6.275q0 0.3 -0.175 0.55t-0.45 0.375q-0.275 0.125 -0.575 0.062T16.3 13.45L9.175 6.325q-0.175 -0.175 -0.25 -0.375t-0.075 -0.425q0 -0.275 0.138 -0.537T9.375 4.6q0.275 -0.125 0.55 -0.225t0.575 -0.175v-0.7q0 -0.625 0.438 -1.062T12 2q0.625 0 1.062 0.438T13.5 3.5v0.7q2 0.5 3.25 2.125t1.25 3.675v2.725ZM12 22q-0.75 0 -1.338 -0.413T10.075 20.475q0 -0.2 0.163 -0.338T10.6 20h2.8q0.2 0 0.363 0.138T13.925 20.475q0 0.7 -0.588 1.113T12 22Z",
        "notifications_active": "M5 19q-0.425 0 -0.713 -0.288T4 18q0 -0.425 0.288 -0.713T5 17h1v-7q0 -2.075 1.25 -3.688T10.5 4.2v-0.7q0 -0.625 0.438 -1.062T12 2q0.625 0 1.062 0.438T13.5 3.5v0.7q2 0.5 3.25 2.113T18 10v7h1q0.425 0 0.713 0.288T20 18q0 0.425 -0.288 0.713T19 19H5ZM12 22q-0.825 0 -1.413 -0.588T10 20h4q0 0.825 -0.588 1.413T12 22ZM3 10q-0.425 0 -0.713 -0.325T2.05 8.925q0.2 -1.875 1.05 -3.488T5.275 2.625q0.325 -0.275 0.738 -0.25t0.663 0.375q0.25 0.35 0.2 0.75t-0.375 0.7q-0.975 0.925 -1.6 2.15t-0.825 2.65q-0.05 0.425 -0.35 0.713T3 10Zm18 0q-0.425 0 -0.725 -0.288T19.925 9q-0.2 -1.425 -0.825 -2.65t-1.6 -2.15q-0.325 -0.3 -0.375 -0.7t0.2 -0.75q0.25 -0.35 0.663 -0.375t0.738 0.25q1.325 1.2 2.175 2.812T21.95 8.925q0.05 0.425 -0.238 0.75T21 10Z",
        "close": "M12 13.4L7.1 18.3q-0.275 0.275 -0.7 0.275t-0.7 -0.275q-0.275 -0.275 -0.275 -0.7t0.275 -0.7l4.9 -4.9l-4.9 -4.9q-0.275 -0.275 -0.275 -0.7t0.275 -0.7q0.275 -0.275 0.7 -0.275t0.7 0.275l4.9 4.9l4.9 -4.9q0.275 -0.275 0.7 -0.275t0.7 0.275q0.275 0.275 0.275 0.7t-0.275 0.7L13.4 12l4.9 4.9q0.275 0.275 0.275 0.7t-0.275 0.7q-0.275 0.275 -0.7 0.275t-0.7 -0.275L12 13.4Z",
        "expand_more": "M12 14.95q-0.2 0 -0.375 -0.062t-0.325 -0.213L6.7 10.075q-0.275 -0.275 -0.275 -0.7t0.275 -0.7q0.275 -0.275 0.7 -0.275t0.7 0.275l3.9 3.9l3.9 -3.9q0.275 -0.275 0.7 -0.275t0.7 0.275q0.275 0.275 0.275 0.7t-0.275 0.7L12.7 14.675q-0.15 0.15 -0.325 0.213t-0.375 0.062Z",
        "expand_less": "M12 10.775L8.1 14.675q-0.275 0.275 -0.7 0.275t-0.7 -0.275q-0.275 -0.275 -0.275 -0.7t0.275 -0.7l4.6 -4.6q0.15 -0.15 0.325 -0.213t0.375 -0.062q0.2 0 0.375 0.062t0.325 0.213l4.6 4.6q0.275 0.275 0.275 0.7t-0.275 0.7q-0.275 0.275 -0.7 0.275t-0.7 -0.275L12 10.775Z",
        "reply": "m6.825 -12l2.9 2.9q0.3 0.3 0.288 0.7T9.7 16.3q-0.3 0.275 -0.7 0.288T8.3 16.3L3.7 11.7q-0.3 -0.3 -0.3 -0.7t0.3 -0.7l4.6 -4.6q0.275 -0.275 0.688 -0.275t0.713 0.275q0.3 0.3 0.3 0.713T9.7 7.125L6.825 10h9.175q2.075 0 3.538 1.463T21 15v3q0 0.425 -0.288 0.713T20 19q-0.425 0 -0.713 -0.288T19 18v-3q0 -1.25 -0.875 -2.125t-2.125 -0.875H6.825Z",
        "send": "M4.4 19.425q-0.5 0.2 -0.95 -0.088T3 18.5v-4.5l8 -2l-8 -2v-4.5q0 -0.55 0.45 -0.838t0.95 -0.088l15.4 6.5q0.625 0.275 0.625 0.925t-0.625 0.925L4.4 19.425Z",
        "volume_off": "M16.775 19.575q-0.275 0.175 -0.55 0.325t-0.575 0.275q-0.375 0.175 -0.763 0T14.35 19.6q-0.15 -0.375 0.038 -0.738T14.95 18.325q0.175 -0.075 0.325 -0.163t0.3 -0.188L12 14.8v2.775q0 0.675 -0.613 0.938T10.3 18.3L7 15H4q-0.425 0 -0.713 -0.288T3 14v-4q0 -0.425 0.288 -0.713T4 9h2.2L2.1 4.9q-0.275 -0.275 -0.275 -0.7t0.275 -0.7q0.275 -0.275 0.7 -0.275t0.7 0.275l17 17q0.275 0.275 0.275 0.7t-0.275 0.7q-0.275 0.275 -0.7 0.275t-0.7 -0.275l-2.325 -2.325Zm2.225 -7.6q0 -2.075 -1.1 -3.788T14.95 5.625q-0.375 -0.175 -0.55 -0.537t-0.05 -0.738q0.15 -0.4 0.537 -0.575t0.788 0q2.425 1.075 3.875 3.275t1.45 4.925q0 0.825 -0.15 1.638T20.425 15.175q-0.2 0.55 -0.613 0.688t-0.763 0.013q-0.35 -0.125 -0.562 -0.45t-0.013 -0.75q0.275 -0.65 0.4 -1.312t0.125 -1.388ZM14.775 8.425q0.825 0.525 1.275 1.575t0.45 2v0.25q0 0.125 -0.025 0.25q-0.05 0.325 -0.35 0.425t-0.55 -0.15l-1.275 -1.275q-0.15 -0.15 -0.225 -0.338t-0.075 -0.388v-1.925q0 -0.3 0.263 -0.438t0.513 0.013Zm-5.025 -1.475q-0.15 -0.15 -0.15 -0.35t0.15 -0.35l0.55 -0.55q0.475 -0.475 1.088 -0.213T12 6.425v1.575q0 0.35 -0.3 0.475t-0.55 -0.125l-1.4 -1.4Z",
        "bedtime": "M13.1 23q-2.1 0 -3.938 -0.8t-3.2 -2.163Q4.6 18.675 3.8 16.838T3 12.9q0 -3.2 1.8 -5.8t4.825 -3.65q0.55 -0.2 1.025 0.138t0.45 0.913q-0.075 2.125 0.675 4.05t2.25 3.425q1.5 1.5 3.425 2.25t4.05 0.675q0.65 -0.025 0.963 0.438T22.575 16.375q-1.1 3 -3.688 4.812T13.1 23Z",
        "do_not_disturb_on": "M8 13h8q0.425 0 0.713 -0.288T17 12q0 -0.425 -0.288 -0.713T16 11H8q-0.425 0 -0.713 0.288T7 12q0 0.425 0.288 0.713T8 13ZM12 22q-2.075 0 -3.9 -0.788T4.925 19.075q-1.35 -1.35 -2.138 -3.175T2 12q0 -2.075 0.788 -3.9T4.925 4.925q1.35 -1.35 3.175 -2.138T12 2q2.075 0 3.9 0.788T19.075 4.925q1.35 1.35 2.138 3.175T22 12q0 2.075 -0.788 3.9T19.075 19.075q-1.35 1.35 -3.175 2.138T12 22Z",
        "delete_sweep": "M5 19q-0.825 0 -1.413 -0.588T3 17v-9q-0.425 0 -0.713 -0.288T2 7q0 -0.425 0.288 -0.713T3 6h3v-0.5q0 -0.425 0.288 -0.713T7 4.5h2q0.425 0 0.713 0.288T10 5.5v0.5h3q0.425 0 0.713 0.288T14 7q0 0.425 -0.288 0.713T13 8v9q0 0.825 -0.588 1.413T11 19H5Zm11 -1q-0.425 0 -0.713 -0.288T15 17q0 -0.425 0.288 -0.713T16 16h2q0.425 0 0.713 0.288T19 17q0 0.425 -0.288 0.713T18 18h-2Zm0 -4q-0.425 0 -0.713 -0.288T15 13q0 -0.425 0.288 -0.713T16 12h4q0.425 0 0.713 0.288T21 13q0 0.425 -0.288 0.713T20 14H16Zm0 -4q-0.425 0 -0.713 -0.288T15 9q0 -0.425 0.288 -0.713T16 8h5q0.425 0 0.713 0.288T22 9q0 0.425 -0.288 0.713T21 10H16Z",
        "schedule": "M13 11.6v-3.6q0 -0.425 -0.288 -0.713T12 7q-0.425 0 -0.713 0.288T11 8v3.975q0 0.2 0.075 0.388t0.225 0.338l3.3 3.3q0.275 0.275 0.7 0.275t0.7 -0.275q0.275 -0.275 0.275 -0.7t-0.275 -0.7L13 11.6ZM12 22q-2.075 0 -3.9 -0.788T4.925 19.075q-1.35 -1.35 -2.138 -3.175T2 12q0 -2.075 0.788 -3.9T4.925 4.925q1.35 -1.35 3.175 -2.138T12 2q2.075 0 3.9 0.788T19.075 4.925q1.35 1.35 2.138 3.175T22 12q0 2.075 -0.788 3.9T19.075 19.075q-1.35 1.35 -3.175 2.138T12 22Zm0 -10Zm0 8q3.325 0 5.663 -2.337T20 12q0 -3.325 -2.337 -5.663T12 4q-3.325 0 -5.663 2.337T4 12q0 3.325 2.337 5.663T12 20Z",
        "settings": "M10.825 22q-0.675 0 -1.163 -0.45T9.075 20.45l-0.225 -1.65q-0.325 -0.125 -0.613 -0.3T7.675 18.125l-1.55 0.65q-0.625 0.275 -1.25 0.05t-0.975 -0.8l-1.175 -2.05q-0.35 -0.575 -0.2 -1.225t0.675 -1.075l1.325 -1q-0.025 -0.175 -0.025 -0.338v-0.675q0 -0.163 0.025 -0.338l-1.325 -1q-0.525 -0.425 -0.675 -1.075t0.2 -1.225l1.175 -2.05q0.35 -0.575 0.975 -0.8t1.25 0.05l1.55 0.65q0.275 -0.2 0.575 -0.375t0.6 -0.3l0.225 -1.65q0.1 -0.65 0.588 -1.1t1.163 -0.45h2.35q0.675 0 1.163 0.45t0.588 1.1l0.225 1.65q0.325 0.125 0.613 0.3t0.562 0.375l1.55 -0.65q0.625 -0.275 1.25 -0.05t0.975 0.8l1.175 2.05q0.35 0.575 0.2 1.225t-0.675 1.075l-1.325 1q0.025 0.175 0.025 0.338v0.675q0 0.163 -0.05 0.338l1.325 1q0.525 0.425 0.675 1.075t-0.2 1.225l-1.2 2.05q-0.35 0.575 -0.975 0.8t-1.25 -0.05l-1.5 -0.65q-0.275 0.2 -0.575 0.375t-0.6 0.3l-0.225 1.65q-0.1 0.65 -0.588 1.1T13.175 22h-2.35Zm1.225 -6.5q1.45 0 2.475 -1.025t1.025 -2.475q0 -1.45 -1.025 -2.475t-2.475 -1.025q-1.475 0 -2.488 1.025T8.55 12q0 1.45 1.012 2.475t2.488 1.025Z",
        "more_vert": "M12 20q-0.825 0 -1.413 -0.588T10 18q0 -0.825 0.588 -1.413T12 16q0.825 0 1.413 0.588T14 18q0 0.825 -0.588 1.413T12 20Zm0 -6q-0.825 0 -1.413 -0.588T10 12q0 -0.825 0.588 -1.413T12 10q0.825 0 1.413 0.588T14 12q0 0.825 -0.588 1.413T12 14Zm0 -6q-0.825 0 -1.413 -0.588T10 6q0 -0.825 0.588 -1.413T12 4q0.825 0 1.413 0.588T14 6q0 0.825 -0.588 1.413T12 8Z",
        "done_all": "M1.75 13.05q-0.3 -0.3 -0.288 -0.7T1.775 11.65q0.3 -0.275 0.7 -0.288t0.7 0.288l3.55 3.55l0.35 0.35l0.35 0.35q0.3 0.3 0.288 0.7T7.4 17.3q-0.3 0.275 -0.7 0.288T6 17.3L1.75 13.05Zm10.6 2.125l8.5 -8.5q0.3 -0.3 0.7 -0.288t0.7 0.312q0.275 0.3 0.288 0.7T22.25 8.1L13.05 17.3q-0.3 0.3 -0.7 0.3t-0.7 -0.3L7.4 13.05q-0.275 -0.275 -0.275 -0.688t0.275 -0.713q0.3 -0.3 0.713 -0.3t0.713 0.3l3.525 3.525Zm4.225 -7.05L13.05 11.65q-0.275 0.275 -0.688 0.275T11.65 11.65q-0.3 -0.3 -0.3 -0.713t0.3 -0.713l3.525 -3.525q0.275 -0.275 0.688 -0.275t0.713 0.275q0.3 0.3 0.3 0.713T16.575 8.125Z",
        "priority_high": "M12 21q-0.825 0 -1.413 -0.588T10 19q0 -0.825 0.588 -1.413T12 17q0.825 0 1.413 0.588T14 19q0 0.825 -0.588 1.413T12 21Zm0 -6q-0.825 0 -1.413 -0.588T10 13v-8q0 -0.825 0.588 -1.413T12 3q0.825 0 1.413 0.588T14 5v8q0 0.825 -0.588 1.413T12 15Z",
        "chevron_right": "M12.6 12L8.7 8.1q-0.275 -0.275 -0.275 -0.7t0.275 -0.7q0.275 -0.275 0.7 -0.275t0.7 0.275l4.6 4.6q0.15 0.15 0.213 0.325t0.062 0.375q0 0.2 -0.062 0.375t-0.213 0.325L10.1 17.3q-0.275 0.275 -0.7 0.275t-0.7 -0.275q-0.275 -0.275 -0.275 -0.7t0.275 -0.7l3.9 -3.9Z",
        "sync": "M6 12.05q0 1.125 0.425 2.188t1.325 1.963l0.25 0.25v-1.45q0 -0.425 0.288 -0.713T9 14q0.425 0 0.713 0.288T10 15v4q0 0.425 -0.288 0.713T9 20H5q-0.425 0 -0.713 -0.288T4 19q0 -0.425 0.288 -0.713T5 18h1.75l-0.4 -0.35q-1.3 -1.15 -1.825 -2.625t-0.525 -2.975q0 -2.35 1.2 -4.263T8.425 4.85q0.35 -0.2 0.738 -0.025t0.513 0.575q0.125 0.375 -0.013 0.75T9.175 6.725q-1.45 0.8 -2.312 2.212T6 12.05Zm12 -0.1q0 -1.125 -0.425 -2.188T16.25 7.8l-0.25 -0.25v1.45q0 0.425 -0.288 0.713T15 10q-0.425 0 -0.713 -0.288T14 9v-4q0 -0.425 0.288 -0.713T15 4h4q0.425 0 0.713 0.288T20 5q0 0.425 -0.288 0.713T19 6h-1.75l0.4 0.35q1.225 1.225 1.788 2.663T20 11.95q0 2.35 -1.2 4.263T15.575 19.15q-0.35 0.2 -0.738 0.025T14.325 18.6q-0.125 -0.375 0.013 -0.75t0.488 -0.575q1.45 -0.8 2.312 -2.212T18 11.95Z",
        "download": "M12 15.575q-0.2 0 -0.375 -0.062t-0.325 -0.213L7.7 11.7q-0.3 -0.3 -0.288 -0.7t0.288 -0.7q0.3 -0.3 0.713 -0.312T9.125 10.275l1.875 1.875v-7.15q0 -0.425 0.288 -0.713T12 4q0.425 0 0.713 0.288T13 5v7.15l1.875 -1.875q0.3 -0.3 0.713 -0.288T16.3 10.3q0.275 0.3 0.288 0.7T16.3 11.7L12.7 15.3q-0.15 0.15 -0.325 0.213t-0.375 0.062ZM6 20q-0.825 0 -1.413 -0.588T4 18v-2q0 -0.425 0.288 -0.713T5 15q0.425 0 0.713 0.288T6 16v2h12v-2q0 -0.425 0.288 -0.713T19 15q0.425 0 0.713 0.288T20 16v2q0 0.825 -0.588 1.413T18 20H6Z",
        "arrow_upward": "M11 7.825L6.1 12.725q-0.3 0.3 -0.7 0.288T4.7 12.7q-0.275 -0.3 -0.288 -0.7t0.288 -0.7l6.6 -6.6q0.15 -0.15 0.325 -0.213t0.375 -0.062q0.2 0 0.375 0.062t0.325 0.213l6.6 6.6q0.275 0.275 0.275 0.688T19.3 12.7q-0.3 0.3 -0.713 0.3T17.875 12.7L13 7.825v11.175q0 0.425 -0.288 0.713T12 20q-0.425 0 -0.713 -0.288T11 19v-11.175Z"
    })

    // ---- gating ----------------------------------------------------------
    readonly property bool dnd: Prefs.doNotDisturb
    property int quietTick: 0
    readonly property bool quietNow: {
        root.quietTick;
        return Prefs.inQuietWindow(Loc.now());
    }
    readonly property bool fullscreenUp: {
        var t = Hyprland.activeToplevel;
        if (!t || !t.lastIpcObject)
            return false;

        return (t.lastIpcObject.fullscreen || 0) > 0;
    }
    // anything that should hold a popup back, however it was asked for
    readonly property bool silenced: root.dnd || root.quietNow || (Prefs.dndFullscreen && root.fullscreenUp)

    // dnd is derived, so callers cannot assign it — they go through here
    function toggleDnd() {
        Prefs.doNotDisturb = !Prefs.doNotDisturb;
    }

    function setDnd(v) {
        Prefs.doNotDisturb = v === true;
    }

    // ---- history ---------------------------------------------------------
    property var entries: []
    readonly property int count: root.entries.length
    readonly property int criticalCount: {
        var c = 0;
        for (var i = 0; i < root.entries.length; i++) {
            if (root.entries[i].urgency === NotificationUrgency.Critical)
                c++;

        }
        return c;
    }
    // id -> arrival ms, so cards can age
    property var arrivals: ({})
    property int timeTick: 0
    property bool trimming: false
    property bool ready: false

    signal shadeRequested()
    signal shadeCloseRequested()
    signal shadeToggleRequested()
    signal settingsRequested()

    // a card only plays its arrival once, and never for the backlog on startup
    property var shownIds: ({})
    property bool shownSeeded: false

    function markShown(id) {
        if (!root.shownSeeded) {
            for (const n of root.entries) root.shownIds[n.id] = true
            root.shownSeeded = true;
        }
        if (root.shownIds[id])
            return false;

        root.shownIds[id] = true;
        return true;
    }

    function stamp(n) {
        if (root.arrivals[n.id] === undefined)
            root.arrivals[n.id] = Loc.nowMs();

    }

    function rebuild() {
        if (root.trimming)
            return ;

        var v = notifServer.trackedNotifications ? notifServer.trackedNotifications.values.slice() : [];
        v.sort((a, b) => b.id - a.id);
        // dismissing re-enters this through onValuesChanged, so hold it off
        if (v.length > Prefs.notifMaxHistory) {
            root.trimming = true;
            for (const old of v.slice(Prefs.notifMaxHistory)) old.dismiss()
            root.trimming = false;
            v.length = Prefs.notifMaxHistory;
        }
        for (var i = 0; i < v.length; i++) root.stamp(v[i])
        root.entries = v;
        Prefs.liveNotifCount = v.length;
        root.regroup();
    }

    // ---- grouping --------------------------------------------------------
    property var expandedKeys: ({})
    property var rows: []

    function groupKey(n) {
        return (n.appName || n.desktopEntry || "Unknown").toLowerCase();
    }

    function isExpanded(key) {
        return root.expandedKeys[key] === true;
    }

    function expandAll() {
        var next = {};
        var anyCollapsed = false;
        for (var i = 0; i < root.rows.length; i++) {
            var r = root.rows[i];
            if (r.kind !== "group" || r.count < 2)
                continue;

            if (!root.isExpanded(r.key))
                anyCollapsed = true;

        }
        for (var j = 0; j < root.rows.length; j++) {
            var g = root.rows[j];
            if (g.kind === "group" && g.count > 1)
                next[g.key] = anyCollapsed;

        }
        root.expandedKeys = next;
        root.regroup();
    }

    function toggleGroup(key) {
        var next = {};
        for (var k in root.expandedKeys) next[k] = root.expandedKeys[k]
        next[key] = !next[key];
        root.expandedKeys = next;
        root.regroup();
    }

    // "new" is anything that landed while you were not looking
    function sectionOf(ms) {
        var now = Loc.nowMs();
        var age = now - ms;
        if (age < 300000)
            return 0;

        var d = new Date(ms);
        var today = Loc.now();
        if (d.toDateString() === today.toDateString())
            return 1;

        var y = new Date(today.getTime() - 86400000);
        if (d.toDateString() === y.toDateString())
            return 2;

        return 3;
    }

    readonly property var sectionNames: ["New", "Earlier today", "Yesterday", "Older"]

    function regroup() {
        root.timeTick;
        var out = [];
        var groups = [];
        if (Prefs.notifGrouping) {
            var byKey = ({});
            for (var i = 0; i < root.entries.length; i++) {
                var n = root.entries[i];
                var k = root.groupKey(n);
                if (byKey[k] === undefined) {
                    byKey[k] = groups.length;
                    groups.push({
                        "kind": "group",
                        "key": k,
                        "appName": n.appName || "Unknown",
                        "items": [n],
                        "newestMs": root.arrivals[n.id] || 0
                    });
                } else {
                    groups[byKey[k]].items.push(n);
                }
            }
        } else {
            for (var j = 0; j < root.entries.length; j++) {
                var e = root.entries[j];
                groups.push({
                    "kind": "group",
                    "key": "n" + e.id,
                    "appName": e.appName || "Unknown",
                    "items": [e],
                    "newestMs": root.arrivals[e.id] || 0
                });
            }
        }
        var lastSection = -1;
        for (var g = 0; g < groups.length; g++) {
            var grp = groups[g];
            grp.count = grp.items.length;
            grp.expanded = grp.count > 1 && root.isExpanded(grp.key);
            var s = root.sectionOf(grp.newestMs);
            if (s !== lastSection) {
                out.push({
                    "kind": "header",
                    "key": "h" + s,
                    "label": root.sectionNames[s],
                    "section": s
                });
                lastSection = s;
            }
            grp.section = s;
            out.push(grp);
        }
        root.rows = out;
    }

    // ---- actions ---------------------------------------------------------
    function dismiss(n) {
        if (!n)
            return ;

        root.popupDrop(n.id);
        n.dismiss();
    }

    function clearAll() {
        root.popupClear();
        root.trimming = true;
        for (const n of root.entries.slice()) n.dismiss()
        root.trimming = false;
        root.rebuild();
    }

    function clearGroup(key) {
        root.trimming = true;
        for (const n of root.entries.slice()) {
            if (root.groupKey(n) === key) {
                root.popupDrop(n.id);
                n.dismiss();
            }
        }
        root.trimming = false;
        root.rebuild();
    }

    // muting an app also clears what it has already put up
    function muteApp(name) {
        Prefs.setMuted(name, true);
        root.clearGroup((name || "Unknown").toLowerCase());
    }

    function relLabel(id) {
        root.timeTick;
        var t = root.arrivals[id];
        if (!t)
            return "";

        var s = Math.max(0, Math.floor((Loc.nowMs() - t) / 1000));
        if (s < 45)
            return "now";

        if (s < 3600)
            return Math.max(1, Math.round(s / 60)) + "m";

        if (s < 86400)
            return Math.floor(s / 3600) + "h";

        if (s < 604800)
            return Math.floor(s / 86400) + "d";

        return new Date(t).toLocaleDateString(Qt.locale(), Locale.ShortFormat);
    }

    // freedesktop progress lives in a hint, under two spellings
    function progressOf(n) {
        if (!n || !n.hints)
            return -1;

        var v = n.hints["value"];
        if (v === undefined)
            v = n.hints["x-kde-value"];

        if (v === undefined)
            return -1;

        var f = Number(v);
        return isNaN(f) ? -1 : Math.max(0, Math.min(100, f));
    }

    function hasProgress(n) {
        return Prefs.notifProgress && root.progressOf(n) >= 0;
    }

    function invokeAction(a) {
        // an action activates an application; the lock screen is not allowed to
        if (Lockscreen.locked)
            return ;

        try {
            if (a)
                a.invoke();

        } catch (e) {
        }
    }

    function canReply(n) {
        return Prefs.notifInlineReply && n && n.hasInlineReply;
    }

    function reply(n, text) {
        if (!n || !text || Lockscreen.locked)
            return ;

        n.sendInlineReply(text);
        root.popupDrop(n.id);
    }

    // ---- popup queue -----------------------------------------------------
    property var popups: []
    property var popupLeft: ({})
    property bool popupsPaused: false
    property int replyingId: -1
    readonly property bool replying: root.replyingId >= 0

    function popupLimit() {
        return Math.max(1, Math.min(6, Prefs.toastMaxVisible));
    }

    // 0 means it waits for you
    function toastMsFor(n) {
        if (!n)
            return Prefs.toastTimeout * 1000;

        if (Prefs.toastCriticalSticky && n.urgency === NotificationUrgency.Critical)
            return 0;

        if (n.expireTimeout === 0)
            return 0;

        if (Prefs.toastUseAppTimeout && n.expireTimeout > 0)
            return n.expireTimeout;

        return Prefs.toastTimeout * 1000;
    }

    function popupPush(n) {
        var ms = root.toastMsFor(n);
        var left = {};
        for (var k in root.popupLeft) left[k] = root.popupLeft[k]
        left[n.id] = ms <= 0 ? -1 : ms;
        var v = root.popups.filter((p) => p.id !== n.id);
        v.unshift(n);
        // the oldest falls off rather than the stack growing forever
        var limit = root.popupLimit();
        if (v.length > limit) {
            for (const gone of v.slice(limit)) delete left[gone.id]
            v.length = limit;
        }
        root.popupLeft = left;
        root.popups = v;
    }

    function popupDrop(id) {
        if (!root.popups.some((p) => p.id === id))
            return ;

        var left = {};
        for (var k in root.popupLeft) {
            if (Number(k) !== id)
                left[k] = root.popupLeft[k];

        }
        root.popupLeft = left;
        root.popups = root.popups.filter((p) => p.id !== id);
        if (root.replyingId === id)
            root.replyingId = -1;

    }

    function popupClear() {
        root.popupLeft = ({});
        root.popups = [];
        root.replyingId = -1;
    }

    // the bar pill takes over once the shade is open
    function popupSuspend() {
        root.popupClear();
    }

    NotificationServer {
        id: notifServer

        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        Component.onCompleted: root.rebuild()
        onNotification: (notification) => {
            Prefs.noteApp(notification.appName);
            // a muted application is turned away outright, never tracked
            if (Prefs.isMuted(notification.appName))
                return ;

            notification.tracked = true;
            root.stamp(notification);
            if (!root.ready)
                return ;

            const urgent = notification.urgency === NotificationUrgency.Critical;
            if (root.silenced && !(Prefs.dndAllowCritical && urgent))
                return ;

            root.playSound(notification);
            if (!Prefs.toastEnabled || root.shadeOpen)
                return ;

            root.popupPush(notification);
        }
    }

    // set by the bar pill while its panel is up
    property bool shadeOpen: false

    onShadeOpenChanged: {
        if (root.shadeOpen)
            root.popupSuspend();

    }

    function playSound(n) {
        if (!Prefs.notifSound || root.silenced)
            return ;

        if (Prefs.notifSoundUrgentOnly && n.urgency !== NotificationUrgency.Critical)
            return ;

        soundProc.running = false;
        soundProc.running = true;
    }

    Process {
        id: soundProc

        command: ["paplay", "--volume=" + Prefs.notifSoundPaVolume, Prefs.notifSoundPath]
    }

    // startup is noisy: let the session settle before anything pops
    Timer {
        interval: 300
        running: true
        onTriggered: root.ready = true
    }

    // one ticker drains every popup, so hovering can freeze them all at once
    Timer {
        id: popupTick

        readonly property int step: 100

        interval: popupTick.step
        repeat: true
        running: root.popups.length > 0
        onTriggered: {
            if (root.popupsPaused || root.replying)
                return ;

            var left = {};
            var expired = [];
            for (var i = 0; i < root.popups.length; i++) {
                var id = root.popups[i].id;
                var v = root.popupLeft[id];
                if (v === undefined || v < 0) {
                    left[id] = v === undefined ? -1 : v;
                    continue;
                }
                var nv = v - popupTick.step;
                if (nv <= 0)
                    expired.push(id);
                else
                    left[id] = nv;
            }
            root.popupLeft = left;
            if (expired.length > 0)
                root.popups = root.popups.filter((p) => expired.indexOf(p.id) < 0);

        }
    }

    // relative stamps and the section split both move on this
    Timer {
        interval: 20000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.timeTick++;
            root.regroup();
        }
    }

    Timer {
        interval: 20000
        repeat: true
        running: Prefs.quietHours
        triggeredOnStart: true
        onTriggered: root.quietTick++
    }

    // lastIpcObject only moves when something asks it to
    Timer {
        id: fullscreenPoll

        interval: 120
        onTriggered: Hyprland.refreshToplevels()
    }

    Connections {
        function onRawEvent(event) {
            if (event.name === "fullscreen" || event.name === "activewindowv2" || event.name === "closewindow")
                fullscreenPoll.restart();

        }

        enabled: Prefs.dndFullscreen
        target: Hyprland
    }

    Connections {
        function onNotificationsClearRequested() {
            root.clearAll();
        }

        target: Prefs
    }

    Connections {
        function onValuesChanged() {
            root.rebuild();
        }

        target: notifServer.trackedNotifications
    }

    Connections {
        function onNotifGroupingChanged() {
            root.regroup();
        }

        target: Prefs
    }

    IpcHandler {
        function toggleDnd(): void {
            root.toggleDnd();
        }

        function clear(): void {
            root.clearAll();
        }

        function open(): void {
            root.shadeRequested();
        }

        function close(): void {
            root.shadeCloseRequested();
        }

        function toggle(): void {
            root.shadeToggleRequested();
        }

        function settings(): void {
            root.settingsRequested();
        }

        function expandAll(): void {
            root.expandAll();
        }

        function count(): int {
            return root.count;
        }

        target: "notifs"
    }

}
