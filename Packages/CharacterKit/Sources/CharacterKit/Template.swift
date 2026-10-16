extension CharacterFile {
    /// Text of a brand-new character document.
    public static let newCharacterTemplate = """
    ---
    formatVersion: 1
    rules:
      system: ose
      variant: classic
      options:
        ascendingAC: false
        encumbrance: basic
    name: ""
    class: ""
    level: 1
    xp: 0
    ---

    # Notes

    """
}
