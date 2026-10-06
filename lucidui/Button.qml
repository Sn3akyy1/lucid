import QtQuick
import qs

// m3 expressive common button. round at rest, corners tighten under press;
// a checkable button squares off once selected
Item {
    id: btn

    // "filled" | "tonal" | "outlined" | "text" | "elevated"
    property string variant: "filled"
    // "xs" | "s" | "m"
    property string size: "s"
    property string text: ""
    property string icon: ""
    property bool checkable: false
    property bool checked: false
    property bool disabled: false
    property bool danger: false
    property color containerOverride: "transparent"
    property color contentOverride: "transparent"

    signal clicked()
    signal toggled(bool value)

    readonly property int h: btn.size === "xs" ? Theme.dp(30) : (btn.size === "m" ? Theme.dp(48) : Theme.dp(36))
    readonly property int pad: btn.size === "xs" ? Theme.dp(12) : (btn.size === "m" ? Theme.dp(24) : Theme.dp(16))
    readonly property int iconPx: btn.size === "m" ? Theme.dp(22) : (btn.size === "xs" ? Theme.dp(17) : Theme.dp(19))
    readonly property bool selected: btn.checkable && btn.checked
    readonly property real restRadius: btn.selected ? (btn.size === "m" ? Theme.dp(16) : Theme.dp(12)) : btn.h / 2
    readonly property real pressRadius: btn.size === "m" ? Theme.dp(12) : Theme.dp(8)

    readonly property color container: {
        if (btn.containerOverride.a > 0)
            return btn.containerOverride;

        if (btn.disabled)
            return (btn.variant === "text" || btn.variant === "outlined") ? "transparent" : Theme.alpha(Theme.text, Theme.disabledContainer);

        if (btn.danger)
            return btn.variant === "filled" ? Theme.error : (btn.variant === "tonal" ? Theme.errorContainer : "transparent");

        if (btn.checkable) {
            if (btn.variant === "filled")
                return btn.checked ? Theme.primary : Theme.surfaceHighest;

            if (btn.variant === "tonal")
                return btn.checked ? Theme.secondary : Theme.secondaryContainer;

            if (btn.variant === "outlined")
                return btn.checked ? Theme.inverseSurface : "transparent";

        }
        switch (btn.variant) {
        case "filled":
            return Theme.primary;
        case "tonal":
            return Theme.secondaryContainer;
        case "elevated":
            return Theme.surfaceLow;
        }
        return "transparent";
    }
    readonly property color content: {
        if (btn.contentOverride.a > 0)
            return btn.contentOverride;

        if (btn.disabled)
            return Theme.alpha(Theme.text, Theme.disabledContent);

        if (btn.danger)
            return btn.variant === "filled" ? Theme.fgError : (btn.variant === "tonal" ? Theme.fgErrorContainer : Theme.error);

        if (btn.checkable) {
            if (btn.variant === "filled")
                return btn.checked ? Theme.fgPrimary : Theme.subtext;

            if (btn.variant === "tonal")
                return btn.checked ? Theme.fgSecondary : Theme.fgSecondaryContainer;

            if (btn.variant === "outlined")
                return btn.checked ? Theme.fgInverseSurface : Theme.subtext;

        }
        switch (btn.variant) {
        case "filled":
            return Theme.fgPrimary;
        case "tonal":
            return Theme.fgSecondaryContainer;
        case "outlined":
            return Theme.subtext;
        }
        return Theme.primary;
    }

    implicitHeight: btn.h
    implicitWidth: row.implicitWidth + btn.pad * 2 - (btn.icon !== "" && btn.text !== "" ? Theme.dp(4) : 0)
    opacity: btn.disabled ? 1 : 1

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? btn.pressRadius : btn.restRadius
        color: btn.container
        border.width: btn.variant === "outlined" && !btn.selected ? 1 : 0
        border.color: btn.disabled ? Theme.alpha(Theme.text, Theme.disabledContainer) : Theme.outline

        Behavior on radius {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveDefaultSpatial
            }

        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.durDefaultEffects
            }

        }

        StateLayer {
            id: area

            radius: box.radius
            tint: btn.content
            disabled: btn.disabled
            onClicked: {
                if (btn.checkable)
                    btn.toggled(!btn.checked);

                btn.clicked();
            }
        }

    }

    Row {
        id: row

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: btn.icon !== "" && btn.text !== "" ? -Theme.dp(2) : 0
        spacing: Theme.dp(8)

        Icon {
            visible: btn.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            name: btn.icon
            size: btn.iconPx
            color: btn.content
            fill: btn.selected ? 1 : 0
        }

        LText {
            visible: btn.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: btn.text
            role: btn.size === "m" ? "titleSmall" : "labelLarge"
            color: btn.content
        }

    }

}
