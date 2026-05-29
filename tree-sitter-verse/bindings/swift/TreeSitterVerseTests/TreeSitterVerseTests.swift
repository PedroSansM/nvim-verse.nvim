import XCTest
import SwiftTreeSitter
import TreeSitterVerse

final class TreeSitterVerseTests: XCTestCase {
    func testCanLoadGrammar() throws {
        let parser = Parser()
        let language = Language(language: tree_sitter_verse())
        XCTAssertNoThrow(try parser.setLanguage(language),
                         "Error loading Verse grammar")
    }
}
