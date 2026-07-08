import Foundation

public enum VideoImportSource: Equatable, Sendable {
    case files
    case folder(rootURL: URL)
    case dragAndDrop(rootURL: URL?)
}

public enum ConversionStatus: String, CaseIterable, Equatable, Sendable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled

    public var localizedTitle: String {
        switch self {
        case .queued:
            "等待中"
        case .running:
            "转换中"
        case .succeeded:
            "已完成"
        case .failed:
            "失败"
        case .cancelled:
            "已取消"
        }
    }
}

public enum ConflictPolicy: Equatable, Sendable {
    case appendNumber
}

public struct ConversionSettings: Equatable, Sendable {
    public var outputDirectory: URL?
    public var bitrate: String
    public var preserveFolderStructure: Bool
    public var conflictPolicy: ConflictPolicy

    public init(
        outputDirectory: URL? = nil,
        bitrate: String = "192k",
        preserveFolderStructure: Bool = true,
        conflictPolicy: ConflictPolicy = .appendNumber
    ) {
        self.outputDirectory = outputDirectory
        self.bitrate = bitrate
        self.preserveFolderStructure = preserveFolderStructure
        self.conflictPolicy = conflictPolicy
    }
}

public struct ConversionItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceURL: URL
    public let sourceRootURL: URL?
    public let relativePath: String
    public var outputURL: URL?
    public var status: ConversionStatus
    public var progress: Double
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sourceURL: URL,
        sourceRootURL: URL?,
        relativePath: String,
        outputURL: URL? = nil,
        status: ConversionStatus = .queued,
        progress: Double = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.sourceRootURL = sourceRootURL
        self.relativePath = relativePath
        self.outputURL = outputURL
        self.status = status
        self.progress = progress
        self.errorMessage = errorMessage
    }
}

public enum Video2MP3Error: LocalizedError, Equatable, Sendable {
    case outputDirectoryMissing
    case ffmpegNotFound
    case processLaunchFailed(String)
    case outputDirectoryNotWritable(String)
    case conversionFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .outputDirectoryMissing:
            "请选择输出文件夹。"
        case .ffmpegNotFound:
            "缺少转换引擎。请重新下载发布版 app，或在开发环境设置 VIDEO2MP3_FFMPEG_PATH。"
        case let .processLaunchFailed(message):
            "无法启动 ffmpeg：\(message)"
        case let .outputDirectoryNotWritable(message):
            "无法写入输出文件夹：\(message)"
        case let .conversionFailed(message):
            Self.humanReadableConversionMessage(from: message)
        case .cancelled:
            "转换已取消。"
        }
    }

    private static func humanReadableConversionMessage(from message: String) -> String {
        let lowercased = message.lowercased()
        if lowercased.contains("matches no streams") || lowercased.contains("stream map '0:a:0'") {
            return "未找到音轨。这个视频可能没有可提取的音频。"
        }
        if lowercased.contains("permission denied") || lowercased.contains("operation not permitted") {
            return "无法写入输出文件夹。请检查文件夹权限后重试。"
        }
        if lowercased.contains("no such file or directory") {
            return "找不到输入文件或输出路径。请确认文件仍然存在。"
        }
        if message.isEmpty {
            return "转换失败。"
        }
        return String(message.prefix(800))
    }
}
