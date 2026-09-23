import QtQuick
pragma Singleton

QtObject {
    id: icons

    // material symbol names, drawn by DockGlyph

    readonly property string search: "search"
    readonly property string close: "close"
    readonly property string check: "check"
    readonly property string arrowBack: "arrow_back"

    readonly property string wallpaper: "wallpaper"
    readonly property string palette: "palette"
    readonly property string settings: "settings"

    readonly property string widgets: "widgets"

    readonly property string visible: "visibility"
    readonly property string hidden: "visibility_off"
    readonly property string camera: "photo_camera"

    readonly property string power: "power_settings_new"
    readonly property string lock: "lock"
    readonly property string logout: "logout"
    readonly property string suspend: "bedtime"
    readonly property string hibernate: "mode_standby"
    readonly property string reboot: "restart_alt"

    readonly property string pin: "keep"
    readonly property string unpin: "keep_off"
    readonly property string newWindow: "open_in_new"
    readonly property string closeWindow: "close"

    readonly property string equals: "equal"
    readonly property string shuffle: "shuffle"
    readonly property string clipboard: "content_paste"
    readonly property string link: "link"
    readonly property string notes: "notes"
    readonly property string mail: "mail"
    readonly property string keyboard: "keyboard"
    readonly property string trash: "delete"
    readonly property string brokenImage: "broken_image"
}
