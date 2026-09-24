import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// the matugen templates: the apps that follow the palette. what the config
// wires comes from templates.py, which also edits it; how the last change of
// theme or wallpaper rendered each one comes from render-templates.sh's record.
// Settings -> Theme shows and edits both through this
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: root.home + "/.config/lucid/templates.py"
    readonly property string renderer: root.home + "/.config/lucid/render-templates.sh"
    readonly property string configPath: root.home + "/.config/matugen/config.toml"
    readonly property string recordPath: root.home + "/.cache/lucid/templates.json"
    readonly property string coloursPath: root.home + "/.cache/lucid/colours.json"

    // templates.py list: what the config holds, and what else could be wired
    property var configured: []
    property var catalog: []
    property bool loaded: false
    // render-templates.sh's record of the last change, and the colours it used
    property var record: ({})
    property var colours: ({})
    // the template being worked on, "*" while everything renders again
    property string busy: ""
    property string lastError: ""

    // what the record says about each template, by name
    readonly property var states: {
        var out = {};
        var list = root.record.templates || [];
        for (var i = 0; i < list.length; i++)
            out[list[i].name] = list[i];
        return out;
    }
    // every configured template with how it went: ok, failed, skipped, off, or
    // new (added since the last change)
    readonly property var items: {
        var out = [];
        for (var i = 0; i < root.configured.length; i++) {
            var t = root.configured[i];
            var s = root.states[t.name];
            var item = Object.assign({}, t);
            item.state = !t.enabled ? "off" : (s ? s.state : "new");
            item.error = s && t.enabled ? (s.error || "") : "";
            out.push(item);
        }
        return out;
    }
    readonly property int failedCount: root.items.filter((t) => {
        return t.state === "failed";
    }).length
    readonly property int renderedCount: root.items.filter((t) => {
        return t.state === "ok";
    }).length
    // the roles the last change had, in the order a template author reads them
    readonly property var roles: {
        var c = root.colours;
        var lead = ["primary", "on_primary", "primary_container", "on_primary_container", "secondary", "on_secondary", "secondary_container", "on_secondary_container", "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container", "error", "on_error", "error_container", "on_error_container", "background", "on_background", "surface", "on_surface", "surface_variant", "on_surface_variant", "surface_dim", "surface_bright", "surface_container_lowest", "surface_container_low", "surface_container", "surface_container_high", "surface_container_highest", "outline", "outline_variant", "shadow", "scrim", "inverse_surface", "inverse_on_surface", "inverse_primary"];
        var out = [];
        for (var i = 0; i < lead.length; i++) {
            if (c[lead[i]] !== undefined)
                out.push(lead[i]);

        }
        var rest = Object.keys(c).filter((k) => {
            return lead.indexOf(k) === -1;
        }).sort();
        return out.concat(rest);
    }

    function refresh() {
        root.run(["python3", root.helper, "list"], (r) => {
            if (!r)
                return ;

            root.configured = r.templates || [];
            root.catalog = r.catalog || [];
            root.loaded = true;
        });
    }

    // a template switched on renders at once, with the last colours
    function setEnabled(name, on) {
        root.busy = name;
        root.run(["python3", root.helper, "set", name, on ? "on" : "off"], (r) => {
            if (!root.check(r)) {
                root.busy = "";
                return ;
            }
            if (on)
                root.renderOnly(name);
            else
                root.busy = "";
            root.refresh();
        });
    }

    // then(result): result.ok, and result.error when it is not
    function add(name, input, output, hook, then) {
        var cmd = ["python3", root.helper, "add", name, input, output];
        if (hook.trim() !== "")
            cmd.push("--hook", hook.trim());

        root.busy = name;
        root.run(cmd, (r) => {
            if (r && r.ok) {
                root.renderOnly(r.name);
                root.refresh();
            } else {
                root.busy = "";
            }
            if (then)
                then(r || {
                "ok": false,
                "error": "templates.py did not answer"
            });

        });
    }

    function addFromCatalog(entry) {
        root.add(entry.name, entry.input, entry.output, entry.hook || "", null);
    }

    function remove(name) {
        root.busy = name;
        root.run(["python3", root.helper, "remove", name], (r) => {
            root.check(r);
            root.busy = "";
            root.refresh();
        });
    }

    function renderAll() {
        root.busy = "*";
        root.run(["sh", "-c", "\"$0\" --again >/dev/null 2>&1; echo \"{\\\"code\\\": $?}\"", root.renderer], (r) => {
            root.busy = "";
        });
    }

    function renderOnly(name) {
        root.busy = name;
        root.run(["sh", "-c", "\"$0\" --again --only \"$1\" >/dev/null 2>&1; echo \"{\\\"code\\\": $?}\"", root.renderer, name], (r) => {
            root.busy = "";
        });
    }

    // then(result): result.text (what it rendered) or result.error
    function tryTemplate(input, then) {
        root.run(["python3", root.helper, "try", input], (r) => {
            then(r || {
                "ok": false,
                "error": "templates.py did not answer"
            });
        });
    }

    function openFile(path) {
        if (path !== "")
            Quickshell.execDetached(["xdg-open", path]);

    }

    function check(r) {
        root.lastError = r && r.ok ? "" : (r && r.error ? r.error : "templates.py did not answer");
        return root.lastError === "";
    }

    // runs a command and hands its json answer (or null) to then
    function run(cmd, then) {
        var job = jobComponent.createObject(root, {
            "command": cmd,
            "then": then
        });
        job.running = true;
    }

    Component.onCompleted: root.refresh()

    Component {
        id: jobComponent

        Process {
            id: job

            property var then: null

            stdout: StdioCollector {
                id: answer

                onStreamFinished: {
                    var r = null;
                    try {
                        r = JSON.parse(answer.text);
                    } catch (e) {
                    }
                    if (job.then)
                        job.then(r);

                    job.destroy();
                }
            }

        }

    }

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: root.refresh()
    }

    FileView {
        id: recordFile

        path: root.recordPath
        watchChanges: true
        printErrors: false
        onFileChanged: recordFile.reload()
        onLoaded: {
            try {
                root.record = JSON.parse(recordFile.text());
            } catch (e) {
            }
        }
    }

    FileView {
        id: coloursFile

        path: root.coloursPath
        watchChanges: true
        printErrors: false
        onFileChanged: coloursFile.reload()
        onLoaded: {
            try {
                var c = JSON.parse(coloursFile.text()).colors || {};
                var flat = {};
                for (var k in c) {
                    var v = c[k].default || c[k].dark || {};
                    if (v.color)
                        flat[k] = v.color;

                }
                root.colours = flat;
            } catch (e) {
            }
        }
    }

}
