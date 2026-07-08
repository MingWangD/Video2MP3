import Foundation
import XCTest
@testable import Video2MP3Core

final class FFmpegServiceTests: XCTestCase {
    func testBuildsFFmpegCommandForMP3Extraction() throws {
        let ffmpegURL = URL(fileURLWithPath: "/usr/local/bin/ffmpeg")
        let service = FFmpegService(executableURLProvider: { ffmpegURL })

        let command = try service.command(
            inputURL: URL(fileURLWithPath: "/input/video.mp4"),
            outputURL: URL(fileURLWithPath: "/output/video.mp3"),
            bitrate: "192k",
            title: "video"
        )

        XCTAssertEqual(command.executableURL, ffmpegURL)
        XCTAssertTrue(command.arguments.contains("-vn"))
        XCTAssertTrue(command.arguments.contains("libmp3lame"))
        XCTAssertTrue(command.arguments.contains("192k"))
        XCTAssertTrue(command.arguments.contains("title=video"))
        XCTAssertEqual(command.arguments.last, "/output/video.mp3")
    }

    func testParsesProgressAcrossSeparateFFmpegChunks() {
        let parser = FFmpegProgressParser()

        XCTAssertNil(parser.append("Duration: 00:02:00.00, start: 0.000000, bitrate: 1024 kb/s"))
        let progress = parser.append("size=512kB time=00:01:00.00 bitrate=128.0kbits/s speed=12x")

        XCTAssertEqual(progress ?? 0, 0.5, accuracy: 0.001)
    }

    func testHumanizesNoAudioErrors() {
        let error = Video2MP3Error.conversionFailed("Stream map '0:a:0' matches no streams.")

        XCTAssertEqual(error.localizedDescription, "未找到音轨。这个视频可能没有可提取的音频。")
    }
}
