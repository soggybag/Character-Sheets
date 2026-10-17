import AppKit
import CharacterKit
import PDFKit
import SwiftUI

/// Lays the printed sheet's blocks onto pages and draws them as a PDF.
@MainActor
enum SheetPDF {
    static let margin: CGFloat = 36
    static let footerHeight: CGFloat = 16

    /// A PDF of the sheet on the given paper size (in points).
    static func make(_ sheet: PrintedSheet, paperSize: CGSize) -> Data {
        let contentWidth = paperSize.width - margin * 2
        let contentHeight = paperSize.height - margin * 2 - footerHeight
        let pages = paginate(sheet.blocks, width: contentWidth, height: contentHeight)

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: paperSize)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
        for (index, page) in pages.enumerated() {
            let view = PageView(blocks: page, title: sheet.title, number: index + 1, of: pages.count,
                                contentWidth: contentWidth)
                .frame(width: paperSize.width, height: paperSize.height, alignment: .topLeading)
            let renderer = renderer(for: view)
            context.beginPDFPage(nil)
            renderer.render { _, draw in draw(context) }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Packs blocks onto pages in order. A heading moves to the next page
    /// rather than end one. A block taller than a page gets a page of its own
    /// (and is cut at the bottom).
    static func paginate(_ blocks: [PrintBlock], width: CGFloat, height: CGFloat) -> [[PrintBlock]] {
        let heights = blocks.map { measure($0.view, width: width) }
        var pages: [[PrintBlock]] = [[]]
        var used: CGFloat = 0
        for (index, block) in blocks.enumerated() {
            let isFirst = pages[pages.count - 1].isEmpty
            var needed = (isFirst ? 0 : block.spacing) + heights[index]
            if block.keepWithNext, index + 1 < blocks.count, !blocks[index + 1].newPage {
                needed += blocks[index + 1].spacing + heights[index + 1]
            }
            if !isFirst, block.newPage || used + needed > height {
                pages.append([])
                used = 0
            }
            used += (pages[pages.count - 1].isEmpty ? 0 : block.spacing) + heights[index]
            pages[pages.count - 1].append(block)
        }
        return pages
    }

    private static func measure(_ view: AnyView, width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        let renderer = renderer(for: view.frame(width: width, alignment: .leading).fixedSize(horizontal: false, vertical: true))
        renderer.render { size, _ in height = size.height }
        return height
    }

    private static func renderer(for view: some View) -> ImageRenderer<some View> {
        ImageRenderer(content: view
            .environment(\.colorScheme, .light)
            .foregroundStyle(PrintStyle.ink))
    }

    private struct PageView: View {
        let blocks: [PrintBlock]
        let title: String
        let number: Int
        let of: Int
        let contentWidth: CGFloat

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(blocks.indices, id: \.self) { index in
                        blocks[index].view
                            .frame(width: contentWidth, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, index == 0 ? 0 : blocks[index].spacing)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Text(title)
                    Spacer()
                    if of > 1 { Text("Page \(number) of \(of)") }
                }
                .font(.system(size: 7.5))
                .foregroundStyle(PrintStyle.faint)
                .frame(width: contentWidth, height: SheetPDF.footerHeight, alignment: .bottom)
            }
            .padding(SheetPDF.margin)
            .background(Color.white)
        }
    }

    // MARK: Print and export

    /// The paper size from Page Setup (Letter or A4, depending on region).
    static var paperSize: CGSize { NSPrintInfo.shared.paperSize }

    static func print(_ sheet: PrintedSheet) {
        guard let document = PDFDocument(data: make(sheet, paperSize: paperSize)) else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 0
        info.bottomMargin = 0
        info.leftMargin = 0
        info.rightMargin = 0
        info.jobDisposition = .spool
        guard let operation = document.printOperation(for: info, scalingMode: .pageScaleDownToFit, autoRotate: false) else {
            return
        }
        operation.jobTitle = sheet.title
        if let window = NSApp.keyWindow {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    static func export(_ sheet: PrintedSheet) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = sheet.title + ".pdf"
        let data = make(sheet, paperSize: paperSize)
        let save = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        if let window = NSApp.keyWindow {
            panel.beginSheetModal(for: window, completionHandler: save)
        } else {
            save(panel.runModal())
        }
    }
}
