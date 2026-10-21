import SwiftUI

/// View → Zoom In / Zoom Out / Actual Size: the sheet's text size. The
/// fonts and box widths grow together, so the layout keeps its shape and
/// text stays sharp (scaling the view itself would blur it). One setting
/// for every sheet, remembered between launches. Printing isn't affected.
enum SheetZoom {
    static let key = "sheetZoom"
    static let steps: [Double] = [0.85, 1, 1.15, 1.3, 1.5, 1.75, 2]

    static func larger(than zoom: Double) -> Double? { steps.first { $0 > zoom + 0.001 } }
    static func smaller(than zoom: Double) -> Double? { steps.last { $0 < zoom - 0.001 } }

    /// macOS's sizes for the text styles, in points.
    static func pointSize(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .body, .headline: 13
        case .callout: 12
        case .subheadline: 11
        default: 10 // footnote, caption, caption2
        }
    }
}

extension EnvironmentValues {
    @Entry var sheetZoom: Double = 1
}

/// A font that grows with the sheet's zoom.
private struct ZoomedFont: ViewModifier {
    @Environment(\.sheetZoom) private var zoom
    let size: CGFloat
    var weight: Font.Weight?
    var design: Font.Design?
    var monospacedDigit = false

    func body(content: Content) -> some View {
        let font = Font.system(size: size * zoom, weight: weight, design: design)
        content.font(monospacedDigit ? font.monospacedDigit() : font)
    }
}

/// A width that grows with the sheet's zoom.
private struct ZoomedFrame: ViewModifier {
    @Environment(\.sheetZoom) private var zoom
    var width: CGFloat?
    var minWidth: CGFloat?
    var alignment: Alignment = .center

    @ViewBuilder
    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width * zoom, alignment: alignment)
        } else {
            content.frame(minWidth: (minWidth ?? 0) * zoom, alignment: alignment)
        }
    }
}

extension View {
    /// `.font(.caption)`, sized for the sheet's zoom.
    func zoomFont(_ style: Font.TextStyle, weight: Font.Weight? = nil, monospacedDigit: Bool = false) -> some View {
        modifier(ZoomedFont(size: SheetZoom.pointSize(style), weight: weight ?? (style == .headline ? .semibold : nil),
                            monospacedDigit: monospacedDigit))
    }

    /// A font of `size` points at actual size.
    func zoomFont(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> some View {
        modifier(ZoomedFont(size: size, weight: weight, design: design))
    }

    /// `.frame(width:)` or `.frame(minWidth:)`, scaled with the sheet's zoom.
    func zoomFrame(width: CGFloat? = nil, minWidth: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        modifier(ZoomedFrame(width: width, minWidth: minWidth, alignment: alignment))
    }
}

/// View → Zoom In, Zoom Out, Actual Size.
struct ZoomCommands: View {
    @AppStorage(SheetZoom.key) private var zoom = 1.0

    var body: some View {
        Button("Zoom In") { zoom = SheetZoom.larger(than: zoom) ?? zoom }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(SheetZoom.larger(than: zoom) == nil)
        Button("Zoom Out") { zoom = SheetZoom.smaller(than: zoom) ?? zoom }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(SheetZoom.smaller(than: zoom) == nil)
        Button("Actual Size") { zoom = 1 }
            .keyboardShortcut("0", modifiers: .command)
            .disabled(zoom == 1)
    }
}
