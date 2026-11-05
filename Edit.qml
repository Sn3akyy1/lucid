import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// edit mode: the wallpaper shaded, the bar's modules dragged along it or pulled off
// it, the dock lifted or pushed into the edge, and a sheet of options for whatever
// was right-clicked. changes apply as they are made; revert puts back what was
// there when edit mode began
Singleton {
    id: root

    property bool active: false
    // the display the toolbar sits on
    property string screenName: ""
    // "" | "bar" | "module" | "dock"
    property string sheet: ""
    property string module: ""
    // "left" | "right", the side away from what the sheet is about
    property string side: "right"
    property string sheetScreen: ""
    // the sheet a module's was opened from, for its back arrow
    property string back: ""
    // a module is in hand on one of the bars, or the dock is being moved
    property bool dragging: false
    // the edit layer's windows: a panel opened to try a look stays open while they are used
    property var windows: []
    property var snapshot: ({})
    // every step taken in edit mode, oldest first: the prefs as they were before it
    property var steps: []
    property var recorded: ({})
    property bool replaying: false
    readonly property bool canUndo: root.active && root.steps.length > 0
    // the settings page edit mode was started from, opened again when it ends
    property string returnPage: ""
    // the dock's style to go back to once it is pulled out of the edge
    property string dockFloatStyle: "island"
    // a module's own editor over a whole display (the control centre's): which
    // module, on which display, the module it reads from, and the rect on that
    // display it rose from, to go back into
    property string studio: ""
    property string studioScreen: ""
    property var studioHost: null
    property rect studioFrom: Qt.rect(0, 0, 0, 0)
    // edit mode was started for the studio alone, so it ends with it
    property bool studioOwnsEdit: false

    // every pref the bar and the dock read, the modules' own options and looks with them
    readonly property var keys: {
        const out = [];
        for (const k in Prefs.defaults) {
            if (/^(bar|dock|show)/.test(k))
                out.push(k);

        }
        for (const m of Prefs.barModules) {
            for (const k of [m.key, m.style, m.panelStyle].concat(m.options || [])) {
                if (k && out.indexOf(k) === -1 && Prefs.defaults[k] !== undefined)
                    out.push(k);

            }
        }
        return out;
    }
    readonly property bool changed: {
        if (!root.active)
            return false;

        for (const k of root.keys) {
            if (root.snapshot[k] !== undefined && Prefs[k] !== root.snapshot[k])
                return true;

        }
        return false;
    }
    readonly property string toolbarScreen: root.screenName !== "" ? root.screenName : (Monitors.popupScreen ? Monitors.popupScreen.name : "")
    // all of them at once, so a change anywhere starts a step
    readonly property string current: {
        if (!root.active)
            return "";

        const out = ({});
        for (const k of root.keys)
            out[k] = Prefs[k];
        return JSON.stringify(out);
    }

    onCurrentChanged: {
        if (root.active)
            stepTimer.restart();

    }

    // asks the bar on that display to open a module, so the sheet can show its panel
    signal moduleOpenRequested(string id, string screen)
    // asks the module on that display to open its studio, so it can say where from
    signal studioRequested(string id, string screen)
    signal launcherRequested()

    function enter(screen) {
        if (screen)
            root.screenName = screen;

        if (root.active)
            return ;

        if (!screen)
            root.screenName = Monitors.popupScreen ? Monitors.popupScreen.name : "";

        const snap = ({});
        for (const k of root.keys)
            snap[k] = Prefs[k];
        root.snapshot = snap;
        root.recorded = snap;
        root.steps = [];
        root.replaying = false;
        root.dockFloatStyle = Prefs.dockNotch ? "island" : Prefs.dockStyle;
        root.active = true;
    }

    // from a settings page: the window steps aside, and comes back when edit mode ends
    function enterFromSettings(page, sheet) {
        const first = !root.active;
        root.enter("");
        if (first)
            root.returnPage = page || "";

        if (sheet)
            root.openSheet(sheet, "", "right", "");

    }

    function exit() {
        if (!root.active)
            return ;

        // a studio goes back into the bar first, and edit mode ends once it has
        if (root.studio !== "") {
            root.studio = "";
            root.studioOwnsEdit = false;
            studioExit.restart();
            return ;
        }

        root.sheet = "";
        root.back = "";
        root.studio = "";
        root.studioOwnsEdit = false;
        root.active = false;
        root.dragging = false;
        const page = root.returnPage;
        root.returnPage = "";
        if (page !== "")
            Prefs.settingsRequested(page);

    }

    function toggle(screen) {
        if (root.active)
            root.exit();
        else
            root.enter(screen);
    }

    // a sheet keeps to the half of the screen away from x
    function sideFor(x, width) {
        return x < width / 2 ? "right" : "left";
    }

    function openSheet(kind, id, side, screen) {
        root.enter(screen);
        root.back = kind === "module" && root.sheet === "bar" ? "bar" : (kind === root.sheet ? root.back : "");
        root.module = id || "";
        if (side)
            root.side = side;

        root.sheetScreen = screen || root.toolbarScreen;
        root.sheet = kind;
    }

    function toggleSheet(kind, screen) {
        if (root.sheet === kind)
            root.closeSheet();
        else
            root.openSheet(kind, "", "right", screen);
    }

    function closeSheet() {
        root.sheet = "";
        root.back = "";
    }

    function goBack() {
        if (root.back === "bar") {
            root.back = "";
            root.sheet = "bar";
        } else {
            root.closeSheet();
        }
    }

    function openStudio(id, screen, host, from) {
        if (!root.active)
            root.studioOwnsEdit = true;

        root.enter(screen);
        root.studioScreen = screen || root.toolbarScreen;
        root.studioHost = host || null;
        root.studioFrom = from || Qt.rect(0, 0, 0, 0);
        root.studio = id;
    }

    // from a sheet or a settings page: the module on that display answers with
    // where it is; with none in the bar, the studio opens on its own
    function requestStudio(id, screen) {
        root.studioRequested(id, screen);
        Qt.callLater(() => {
            if (root.studio === "")
                root.openStudio(id, screen, null, null);

        });
    }

    function closeStudio() {
        root.studio = "";
        if (root.studioOwnsEdit) {
            root.studioOwnsEdit = false;
            studioExit.restart();
        }
    }

    // escape: the studio, then the sheet, then edit mode itself
    function backOut() {
        if (root.studio !== "")
            root.closeStudio();
        else if (root.sheet !== "")
            root.goBack();
        else
            root.exit();
    }

    // a burst of changes, a slider dragged or a module carried, is one step
    function record() {
        if (!root.active || root.dragging) {
            if (root.dragging)
                stepTimer.restart();

            return ;
        }
        const now = ({});
        for (const k of root.keys)
            now[k] = Prefs[k];
        if (JSON.stringify(now) === JSON.stringify(root.recorded))
            return ;

        if (!root.replaying)
            root.steps = root.steps.concat([root.recorded]).slice(-60);

        root.recorded = now;
        root.replaying = false;
    }

    function undo() {
        if (!root.canUndo)
            return ;

        const prev = root.steps[root.steps.length - 1];
        root.steps = root.steps.slice(0, -1);
        root.replaying = true;
        root.restore(prev);
        stepTimer.restart();
    }

    function revert() {
        root.replaying = true;
        root.steps = [];
        root.restore(root.snapshot);
        stepTimer.restart();
    }

    function restore(snap) {
        // the arrangement eases back as any rearrangement does
        if (snap.barLayout !== undefined && Prefs.barLayout !== snap.barLayout)
            Prefs.setBarLayout(Prefs.parseBarLayout(snap.barLayout));

        if (snap.barJoins !== undefined && Prefs.barJoins !== snap.barJoins) {
            Prefs.barReorderTick++;
            Prefs.barJoins = snap.barJoins;
        }
        // a module going off keeps its slot as it leaves
        for (const m of Prefs.barModules) {
            if (snap[m.key] !== undefined && Prefs[m.key] !== snap[m.key])
                Prefs.setBarModuleShown(m.id, snap[m.key]);

        }
        for (const k of root.keys) {
            if (snap[k] !== undefined && Prefs[k] !== snap[k])
                Prefs.set(k, snap[k]);

        }
    }

    Timer {
        id: stepTimer

        interval: 450
        onTriggered: root.record()
    }

    // after the studio has gone back into the bar
    Timer {
        id: studioExit

        interval: Theme.durLong + 60
        onTriggered: {
            if (root.studio === "")
                root.exit();

        }
    }

    IpcHandler {
        target: "edit"

        function toggle(): void {
            root.toggle("");
        }

        function on(): void {
            root.enter("");
        }

        function off(): void {
            root.exit();
        }

        function bar(): void {
            root.openSheet("bar", "", "right", "");
        }

        function dock(): void {
            root.openSheet("dock", "", "right", "");
        }

        // qs ipc call -- edit open clock
        function open(id: string): void {
            if (Prefs.barModuleById[id] !== undefined)
                root.openSheet("module", id, "", "");

        }

        function close(): void {
            root.closeSheet();
        }

        function revert(): void {
            root.revert();
        }

        function undo(): void {
            root.undo();
        }

        function status(): string {
            return JSON.stringify({
                "active": root.active,
                "sheet": root.sheet,
                "module": root.module,
                "changed": root.changed,
                "steps": root.steps.length,
                "dragging": root.dragging
            });
        }

    }

}
