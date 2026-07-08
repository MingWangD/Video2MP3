import Foundation
import XCTest
@testable import Video2MP3Core

final class ImportServiceTests: XCTestCase {
    func testRecognizesSupportedExtensionsCaseInsensitively() {
        XCTAssertTrue(ImportService.isSupportedVideo(URL(fileURLWithPath: "/tmp/demo.MP4")))
        XCTAssertTrue(ImportService.isSupportedVideo(URL(fileURLWithPath: "/tmp/demo.mkv")))
        XCTAssertFalse(ImportService.isSupportedVideo(URL(fileURLWithPath: "/tmp/demo.txt")))
    }

    func testImportsFilesAndRemovesDuplicates() {
        let service = ImportService()
        let url = URL(fileURLWithPath: "/tmp/video.mp4")
        let items = service.importFiles([url, url, URL(fileURLWithPath: "/tmp/readme.md")])

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.relativePath, "video.mp4")
    }

    func testRecursivelyImportsFoldersAndPreservesRelativePaths() throws {
        let root = try TemporaryDirectory()
        try root.writeFile("Course/lesson1.mp4")
        try root.writeFile("Course/Sub/lesson2.MOV")
        try root.writeFile("Course/notes.txt")

        let service = ImportService()
        let items = service.importFolder(root.url)

        XCTAssertEqual(items.map(\.relativePath), ["Course/lesson1.mp4", "Course/Sub/lesson2.MOV"])
        XCTAssertTrue(items.allSatisfy { $0.sourceRootURL == root.url.standardizedFileURL })
    }
}
