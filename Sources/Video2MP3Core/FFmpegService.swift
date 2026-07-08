import Foundation

public struct FFmpegCommand: Equatable, Sendable {
    public let executableURL: URL
    public let arguments: [String]

    public init(executableURL: URL, arguments: [String]) {
        self.executableURL = executableURL
        self.arguments = arguments
    }
}

public final class FFmpegService: @unchecked Sendable {
    private let executableURLProvider: @Sendable () -> URL?
    private let outputPathResolver: OutputPathResolver
    private let processLock = NSLock()
    private var currentProcess: Process?

    public init(
        executableURLProvider: @escaping @Sendable () -> URL? = FFmpegService.defaultExecutableURL,
        outputPathResolver: OutputPathResolver = OutputPathResolver()
    ) {
        self.executableURLProvider = executableURLProvider
        self.outputPathResolver = outputPathResolver
    }

    public static func defaultExecutableURL() -> URL? {
        if let bundledURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            return bundledURL
        }

        if let envPath = ProcessInfo.processInfo.environment["VIDEO2MP3_FFMPEG_PATH"], !envPath.isEmpty {
            return URL(fileURLWithPath: envPath)
        }

        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        return commonPaths
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path(percentEncoded: false)) }
    }

    public func command(
        inputURL: URL,
        outputURL: URL,
        bitrate: String = "192k",
        title: String
    ) throws -> FFmpegCommand {
        guard let executableURL = executableURLProvider() else {
            throw Video2MP3Error.ffmpegNotFound
        }

        return FFmpegCommand(
            executableURL: executableURL,
            arguments: [
                "-hide_banner",
                "-nostdin",
                "-y",
                "-i", inputURL.path(percentEncoded: false),
                "-vn",
                "-map", "0:a:0",
                "-codec:a", "libmp3lame",
                "-b:a", bitrate,
                "-metadata", "title=\(title)",
                outputURL.path(percentEncoded: false)
            ]
        )
    }

    public func convert(
        item: ConversionItem,
        settings: ConversionSettings,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        let outputURL = try outputPathResolver.outputURL(for: item, settings: settings)
        try outputPathResolver.createParentDirectory(for: outputURL)
        let command = try command(
            inputURL: item.sourceURL,
            outputURL: outputURL,
            bitrate: settings.bitrate,
            title: item.sourceURL.deletingPathExtension().lastPathComponent
        )

        return try await run(command: command, outputURL: outputURL, progress: progress)
    }

    public func cancel() {
        processLock.lock()
        let process = currentProcess
        processLock.unlock()
        process?.terminate()
    }

    private func run(
        command: FFmpegCommand,
        outputURL: URL,
        progress: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                let process = Process()
                let pipe = Pipe()
                let stderrBuffer = LockedData()
                let resumeGate = ResumeGate()
                let progressParser = FFmpegProgressParser()

                let resumeOnce: @Sendable (Result<URL, Error>) -> Void = { result in
                    guard resumeGate.tryResume() else {
                        return
                    }
                    switch result {
                    case let .success(url):
                        continuation.resume(returning: url)
                    case let .failure(error):
                        continuation.resume(throwing: error)
                    }
                }

                process.executableURL = command.executableURL
                process.arguments = command.arguments
                process.standardError = pipe
                process.standardOutput = Pipe()

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        return
                    }
                    stderrBuffer.append(data)
                    if let chunk = String(data: data, encoding: .utf8),
                       let parsedProgress = progressParser.append(chunk) {
                        progress(parsedProgress)
                    }
                }

                process.terminationHandler = { [weak self] terminatedProcess in
                    pipe.fileHandleForReading.readabilityHandler = nil
                    self?.clearCurrentProcess(terminatedProcess)

                    if terminatedProcess.terminationReason == .uncaughtSignal {
                        resumeOnce(.failure(Video2MP3Error.cancelled))
                        return
                    }

                    if terminatedProcess.terminationStatus == 0 {
                        progress(1)
                        resumeOnce(.success(outputURL))
                    } else {
                        let message = stderrBuffer.stringValue()
                        resumeOnce(.failure(Video2MP3Error.conversionFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))))
                    }
                }

                do {
                    try process.run()
                    setCurrentProcess(process)
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    resumeOnce(.failure(Video2MP3Error.processLaunchFailed(error.localizedDescription)))
                }
            }
        }, onCancel: {
            cancel()
        })
    }

    private func setCurrentProcess(_ process: Process) {
        processLock.lock()
        currentProcess = process
        processLock.unlock()
    }

    private func clearCurrentProcess(_ process: Process) {
        processLock.lock()
        if currentProcess === process {
            currentProcess = nil
        }
        processLock.unlock()
    }

    static func parseProgress(from text: String) -> Double? {
        let parser = FFmpegProgressParser()
        return parser.append(text)
    }

    fileprivate static func timestamp(after label: String, in text: String) -> String? {
        let pattern = #"\#(label)\s*(\d+):(\d+):(\d+(?:\.\d+)?)"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        let match = String(text[range])
        guard let timestampRange = match.range(of: #"(\d+):(\d+):(\d+(?:\.\d+)?)"#, options: .regularExpression) else {
            return nil
        }
        return String(match[timestampRange])
    }

    fileprivate static func seconds(from timestamp: String) -> Double? {
        let parts = timestamp.split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else {
            return nil
        }
        return hours * 3600 + minutes * 60 + seconds
    }
}

final class FFmpegProgressParser: @unchecked Sendable {
    private let lock = NSLock()
    private var durationSeconds: Double?

    func append(_ text: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        if let duration = FFmpegService.timestamp(after: "Duration:", in: text),
           let seconds = FFmpegService.seconds(from: duration) {
            durationSeconds = seconds
        }

        guard let time = FFmpegService.timestamp(after: "time=", in: text),
              let currentSeconds = FFmpegService.seconds(from: time),
              let durationSeconds,
              durationSeconds > 0 else {
            return nil
        }

        return min(max(currentSeconds / durationSeconds, 0), 1)
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasResumed = false

    func tryResume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasResumed else {
            return false
        }
        hasResumed = true
        return true
    }
}
