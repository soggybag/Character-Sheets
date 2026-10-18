import AppKit
import SwiftUI

/// Plain text editing with its own undo history.
///
/// SwiftUI's `TextEditor` puts its typing on the window's undo stack, which
/// still points at the text view after it's gone (Edit as Text → Cancel,
/// then Undo, crashed). Here typing is undone inside the editor while you're
/// in it; the document's own undo steps are separate.
struct PlainTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .preferredFont(forTextStyle: .body)
    var inset = CGSize(width: 8, height: 8)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        let textView = scrollView.documentView as! NSTextView
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.font = font
        textView.textContainerInset = inset
        // Smart quotes and dashes would corrupt YAML.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.font != font { textView.font = font }
        // Changed from outside (document undo, Edit as Text): the editor's
        // own history no longer matches the text.
        if textView.string != text {
            textView.string = text
            context.coordinator.undoManager.removeAllActions()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlainTextEditor
        let undoManager = UndoManager()

        init(_ parent: PlainTextEditor) {
            self.parent = parent
        }

        func undoManager(for view: NSTextView) -> UndoManager? { undoManager }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
