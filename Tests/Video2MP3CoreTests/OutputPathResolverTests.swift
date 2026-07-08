import Foundation
import XCTest
@testable import Video2MP3Core

final class OutputPathResolverTests: XCTestCase {
    func testCreatesMP3PathPreservingRelativeFolderStructure() throws {
        let root = try TemporaryDirectory()
        let output = root.url.appendingPathComponent("out")
        let item = ConversionItem(
            sourceURL: URL(fileURLWithPath: "/input/Course/lesson1.mp4"),
            sourceRootURL: URL(fileURLWithPath: "/input"),
            relativePath: "Course/lesson1.mp4"
        )
        let settings = ConversionSettings(outputDirectory: output)

        let resolved = try OutputPathResolver().outputURL(for: item, settings: settings)

        XCTAssertTrue(resolved.path(percentEncoded: false).hasSuffix("/out/Course/lesson1.mp3"))
    }

    func testAppendsNumbersInsteadOfOverwritingExistingFiles() throws {
        let root = try TemporaryDirectory()
        let output = root.url.appendingPathComponent("out")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let existing = output.appendingPathComponent("video.mp3")
        FileManager.default.createFile(atPath: existing.path(percentEncoded: false), contents: Data())

        let item = ConversionItem(
            sourceURL: URL(fileURLWithPath: "/input/video.mp4"),
            sourceRootURL: nil,
            relativePath: "video.mp4"
        )
        let settings = ConversionSettings(outputDirectory: output)

        let resolved = try OutputPathResolver().outputURL(for: item, settings: settings)

        XCTAssertEqual(resolved.lastPathComponent, "video 1.mp3")
    }
}
