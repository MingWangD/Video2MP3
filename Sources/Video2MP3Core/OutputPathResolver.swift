import Foundation

public struct OutputPathResolver {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func outputURL(for item: ConversionItem, settings: ConversionSettings) throws -> URL {
        guard let outputDirectory = settings.outputDirectory else {
            throw Video2MP3Error.outputDirectoryMissing
        }

        let relativePath = settings.preserveFolderStructure ? item.relativePath : item.sourceURL.lastPathComponent
        let relativeWithoutExtension = (relativePath as NSString).deletingPathExtension
        let desiredURL = outputDirectory
            .appendingPathComponent(relativeWithoutExtension, isDirectory: false)
            .appendingPathExtension("mp3")

        switch settings.conflictPolicy {
        case .appendNumber:
            return uniqueURL(for: desiredURL)
        }
    }

    public func createParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        } catch {
            throw Video2MP3Error.outputDirectoryNotWritable(error.localizedDescription)
        }
    }

    private func uniqueURL(for desiredURL: URL) -> URL {
        let desiredPath = desiredURL.path(percentEncoded: false)
        guard fileManager.fileExists(atPath: desiredPath) else {
            return desiredURL
        }

        let directory = desiredURL.deletingLastPathComponent()
        let baseName = desiredURL.deletingPathExtension().lastPathComponent
        let pathExtension = desiredURL.pathExtension

        var index = 1
        while true {
            let candidate = directory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(pathExtension)
            if !fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
            index += 1
        }
    }
}
