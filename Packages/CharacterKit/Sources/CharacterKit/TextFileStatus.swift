/// What a file's text reads as, for the status bar under Edit as Text.
public enum TextFileStatus: Equatable, Sendable {
    /// A character: name, class and level, e.g. "Ronk · Fighter · level 1".
    case character(summary: String)
    /// An equipment list, with what it changes and any problems in it.
    case equipmentList(summary: String, problems: [String])
    /// Text without a character header.
    case notACharacter
    /// A header that can't be read.
    case error(String)

    /// `fileName` (without its extension) stands in for a missing name.
    public init(text: String, fileName: String?) {
        if EquipmentList.isEquipmentList(text), let list = try? EquipmentList(text: text) {
            let name = list.name ?? fileName ?? "Equipment list"
            self = .equipmentList(summary: "Equipment list: \(name) · \(list.summary)", problems: list.allProblems())
            return
        }
        do {
            let file = try CharacterFile(text: text)
            guard file.isCharacter else {
                self = .notACharacter
                return
            }
            let name = file.name ?? fileName ?? "Unnamed character"
            let details = [file.string(["class"]), file.int(["level"]).map { "level \($0)" }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            self = .character(summary: ([name] + details).joined(separator: " · "))
        } catch let error as CharacterFileError {
            self = error == .noFrontMatter ? .notACharacter : .error(error.description)
        } catch {
            self = .error(String(describing: error))
        }
    }
}
