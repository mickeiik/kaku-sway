import QtQuick
import QtQuick.Shapes

// An icon drawn from an SVG path in a 24×24 box (e.g. a brand logo from Simple
// Icons, simpleicons.org), in one color like the font icons
Item {
    id: root

    required property string path
    property color color: Theme.fg
    property real size: Theme.fontSize

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            strokeWidth: -1
            PathSvg { path: root.path }
        }
    }
}
