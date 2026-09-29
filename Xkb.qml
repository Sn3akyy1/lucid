import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

// keyboard layouts, their variants and the xkb options, with the names the
// system gives them, read from the evdev rules list
Singleton {
    id: root

    readonly property string rulesPath: "/usr/share/X11/xkb/rules/evdev.lst"
    property bool loaded: false
    // code -> name
    property var layoutNames: ({})
    // "layout(variant)" -> name
    property var variantNames: ({})
    // option -> description
    property var optionNames: ({})
    // every layout and variant, for a picker: { id, layout, variant, name, note }
    property var entries: []

    function parse(text) {
        const layouts = {};
        const variants = {};
        const options = {};
        const list = [];
        let section = "";
        for (const line of text.split("\n")) {
            const head = /^!\s*(\w+)/.exec(line);
            if (head) {
                section = head[1];
                continue;
            }
            const m = /^\s+(\S+)\s+(.*)$/.exec(line);
            if (!m)
                continue;

            if (section === "layout") {
                layouts[m[1]] = m[2];
                list.push({
                    "id": m[1],
                    "layout": m[1],
                    "variant": "",
                    "name": m[2],
                    "note": m[1]
                });
            } else if (section === "variant") {
                // "  dvorak          latam: Spanish (Latin American, Dvorak)"
                const v = /^(\S+):\s*(.*)$/.exec(m[2]);
                if (!v)
                    continue;

                variants[v[1] + "(" + m[1] + ")"] = v[2];
                list.push({
                    "id": v[1] + "(" + m[1] + ")",
                    "layout": v[1],
                    "variant": m[1],
                    "name": v[2],
                    "note": v[1] + " · " + m[1]
                });
            } else if (section === "option") {
                options[m[1]] = m[2];
            }
        }
        list.sort((a, b) => {
            const x = a.name.toLowerCase();
            const y = b.name.toLowerCase();
            return x < y ? -1 : (x > y ? 1 : 0);
        });
        root.layoutNames = layouts;
        root.variantNames = variants;
        root.optionNames = options;
        root.entries = list;
        root.loaded = true;
    }

    // "latam" + "dvorak" -> Spanish (Latin American, Dvorak)
    function nameOf(layout, variant) {
        if (variant && root.variantNames[layout + "(" + variant + ")"])
            return root.variantNames[layout + "(" + variant + ")"];

        return root.layoutNames[layout] || layout;
    }

    function optionName(option) {
        return root.optionNames[option] || option;
    }

    FileView {
        path: root.rulesPath
        printErrors: false
        onLoaded: root.parse(text())
    }

}
