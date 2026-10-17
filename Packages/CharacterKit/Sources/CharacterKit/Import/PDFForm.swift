import Foundation
import PDFKit

extension SheetImport {
    /// Imports a fillable PDF character sheet.
    public init(contentsOf url: URL, rules: OSERuleset = .classic) throws {
        guard let document = PDFDocument(url: url) else { throw SheetImportError.unreadable }
        do {
            try self.init(fields: Self.formFields(in: document), rules: rules)
        } catch SheetImportError.noFormFields
            where document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String
                == SheetImportError.exportCreator {
            throw SheetImportError.exportedByThisApp
        }
    }

    /// Every form field's name and value. Fields that appear more than once
    /// keep their first non-empty value.
    static func formFields(in document: PDFDocument) -> [String: String] {
        var fields: [String: String] = [:]
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                guard let name = annotation.fieldName else { continue }
                let value = annotation.widgetStringValue ?? ""
                if fields[name]?.isEmpty ?? true { fields[name] = value }
            }
        }
        return fields
    }
}
