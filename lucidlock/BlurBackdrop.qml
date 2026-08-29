import QtQuick
import QtQuick.Effects
import qs

Item {
    id: backdrop

    required property Item wallpaper
    property real cardRadius: 0
    readonly property real blurMargin: 32

    anchors.fill: parent
    visible: Theme.blurAmount > 0

    Item {
        id: crop
        x: -backdrop.blurMargin
        y: -backdrop.blurMargin
        width: backdrop.width + backdrop.blurMargin * 2
        height: backdrop.height + backdrop.blurMargin * 2
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: backdropMask
        }

        ShaderEffectSource {
            id: cropSource
            anchors.fill: parent
            sourceItem: backdrop.wallpaper
            live: true
            hideSource: false
            sourceRect: Qt.rect(backdrop.mapToItem(backdrop.wallpaper, -backdrop.blurMargin, -backdrop.blurMargin).x, backdrop.mapToItem(backdrop.wallpaper, -backdrop.blurMargin, -backdrop.blurMargin).y, crop.width, crop.height)
        }

        MultiEffect {
            anchors.fill: parent
            source: cropSource
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: Theme.blurAmount
        }
    }

    Item {
        id: backdropMask
        x: crop.x
        y: crop.y
        width: crop.width
        height: crop.height
        visible: false
        layer.enabled: true

        Rectangle {
            x: backdrop.blurMargin
            y: backdrop.blurMargin
            width: backdrop.width
            height: backdrop.height
            radius: backdrop.cardRadius
        }
    }
}
