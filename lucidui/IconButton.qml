import QtQuick
import qs

// m3 expressive icon button. toggles fill their glyph and square off when on
Item {
    id: ib

    // "standard" | "filled" | "tonal" | "outlined"
    property string variant: "standard"
    // "xs" | "s" | "m"
    property string size: "s"
    // "narrow" | "default" | "wide"
    property string widthKind: "default"
    property string icon: ""
    property bool checkable: false
    property bool checked: false
    property bool disabled: false
    property real iconFill: -1
    property color tintOverride: "transparent"
    property color containerOverride: "transparent"
    property string tooltip: ""

    signal clicked()
    signal rightClicked()
    signal toggled(bool value)

    readonly property int btnH: ib.size === "xs" ? Theme.dp(30) : (ib.size === "m" ? Theme.dp(48) : Theme.dp(36))
    readonly property int iconPx: ib.size === "xs" ? Theme.dp(18) : (ib.size === "m" ? Theme.dp(24) : Theme.dp(20))
    readonly property int btnW: ib.widthKind === "narrow" ? Math.round(ib.btnH * 0.78) : (ib.widthKind === "wide" ? Math.round(ib.btnH * 1.3) : ib.btnH)
    readonly property bool on: ib.checkable && ib.checked

    readonly property color container: {
        if (ib.containerOverride.a > 0)
            return ib.containerOverride;

        if (ib.disabled)
            return ib.variant === "standard" || ib.variant === "outlined" ? "transparent" : Theme.alpha(Theme.text, Theme.disabledContainer);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? Theme.primary : Theme.surfaceHighest) : Theme.primary;
        case "tonal":
            return ib.checkable ? (ib.checked ? Theme.secondary : Theme.secondaryContainer) : Theme.secondaryContainer;
        case "outlined":
            return ib.on ? Theme.inverseSurface : "transparent";
        }
        return "transparent";
    }
    readonly property color content: {
        if (ib.tintOverride.a > 0)
            return ib.tintOverride;

        if (ib.disabled)
            return Theme.alpha(Theme.text, Theme.disabledContent);

        switch (ib.variant) {
        case "filled":
            return ib.checkable ? (ib.checked ? Theme.fgPrimary : Theme.subtext) : Theme.fgPrimary;
        case "tonal":
            return ib.checkable ? (ib.checked ? Theme.fgSecondary : Theme.fgSecondaryContainer) : Theme.fgSecondaryContainer;
        case "outlined":
            return ib.on ? Theme.fgInverseSurface : Theme.subtext;
        }
        return ib.on ? Theme.primary : Theme.subtext;
    }

    implicitWidth: ib.btnW
    implicitHeight: ib.btnH

    Rectangle {
        id: box

        anchors.fill: parent
        radius: area.pressed ? Math.min(ib.btnH / 2, Theme.dp(10)) : (ib.on && ib.variant !== "standard" ? Math.min(ib.btnH / 2, Theme.dp(12)) : ib.btnH / 2)
        color: ib.container
        border.width: ib.variant === "outlined" && !ib.on ? 1 : 0
        border.color: Theme.outline

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
            tint: ib.content
            disabled: ib.disabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    ib.rightClicked();
                    return ;
                }
                if (ib.checkable)
                    ib.toggled(!ib.checked);

                ib.clicked();
            }
        }

    }

    Icon {
        anchors.centerIn: parent
        name: ib.icon
        size: ib.iconPx
        color: ib.content
        fill: ib.iconFill >= 0 ? ib.iconFill : (ib.on ? 1 : 0)
        scale: area.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durFastSpatial
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveFastSpatial
            }

        }

    }

}
