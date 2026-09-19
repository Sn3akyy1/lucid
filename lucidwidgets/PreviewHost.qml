import QtQuick
import qs

QtObject {
    id: ph

    property string wtype: ""
    property string wvariant: ""
    property bool hovered: false
    // options a preset sets, drawn in place of the defaults
    property var opts: ({})

    readonly property string uid: ""
    readonly property bool preview: true
    readonly property real zoom: 1
    readonly property real bodyRadius: Theme.radiusXl
    readonly property int radius: Theme.radiusXl
    readonly property bool pinned: false
    // stand-ins so a tile shows a filled-in widget rather than an empty one
    readonly property var samples: ({
        "notes": {
            "text": "Pick up the parcel.\nRing the landlord about\nthe radiator."
        },
        "todo": {
            "items": "[{\"t\":\"Reply to Ana\",\"d\":false},{\"t\":\"Book the train\",\"d\":false},{\"t\":\"Water the plants\",\"d\":true}]"
        }
    })

    function opt(key) {
        // a preset's own options, and whatever is already written in a card, but an
        // empty note still gets the sample so the tile never shows a blank card
        var own = ph.opts ? ph.opts[key] : undefined;
        if (own !== undefined && (!Widgets.isContentKey(ph.wtype, key) || own !== Widgets.defaultOptions(ph.wtype)[key]))
            return own;

        var sample = ph.samples[ph.wtype];
        if (sample && sample[key] !== undefined)
            return sample[key];

        return Widgets.defaultOptions(ph.wtype)[key];
    }

    function setOpt(key, value) {
    }

    function setOpts(changes) {
    }

}
