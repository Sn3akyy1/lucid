import QtQuick
import qs

QtObject {
    id: ph

    property string wtype: ""
    property string wvariant: ""
    property bool hovered: false

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
        var sample = ph.samples[ph.wtype];
        if (sample && sample[key] !== undefined)
            return sample[key];

        return Widgets.defaultOptions(ph.wtype)[key];
    }

    function setOpt(key, value) {
    }

}
