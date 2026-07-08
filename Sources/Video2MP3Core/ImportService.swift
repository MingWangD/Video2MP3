import Foundation

public struct ImportService {
    public static let supportedVideoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "flv", "wmv", "mpeg", "mpg", "3gp"
    ]

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static func isSupportedVideo(_ url: URL) -> Bool {
        supportedVideoExtensions.contains(url.pathExtension.lowercased())
    }

    public func importFiles(_ urls: [URL], existingSourceURLs: Set<URL> = []) -> [ConversionItem] {
        var seen = existingSourceURLs
        return urls.compactMap { url in
            guard Self.isSupportedVideo(url) else {
                return nil
            }
            let normalized = url.standardizedFileURL
            guard seen.insert(normalized).inserted else {
                return nil
            }
            return ConversionItem(
                sourceURL: normalized,
                sourceRootURL: nil,
                relativePath: normalized.lastPathComponent
            )
        }
    }

    public func importFolder(_ rootURL: URL, existingSourceURLs: Set<URL> = []) -> [ConversionItem] {
        let normalizedRoot = rootURL.standardizedFileURL
        guard let enumerator = fileManager.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var seen = existingSourceURLs
        var items: [ConversionItem] = []

        for case let fileURL as URL in enumerator {
            guard Self.isSupportedVideo(fileURL) else {
                continue
            }
            let normalized = fileURL.standardizedFileURL
            guard seen.insert(normalized).inserted else {
                continue
            }

            items.append(
                ConversionItem(
                    sourceURL: normalized,
                    sourceRootURL: normalizedRoot,
                    relativePath: Self.relativePath(from: normalizedRoot, to: normalized)
                )
            )
        }

        return items.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    public func importDropURLs(_ urls: [URL], existingSourceURLs: Set<URL> = []) -> [ConversionItem] {
        var seen = existingSourceURLs
        var items: [ConversionItem] = []

        for url in urls {
            let normalized = url.standardizedFileURL
            if isDirectory(normalized) {
                let folderItems = importFolder(normalized, existingSourceURLs: seen)
                items.append(contentsOf: folderItems)
                seen.formUnion(folderItems.map(\.sourceURL))
            } else if Self.isSupportedVideo(normalized), seen.insert(normalized).inserted {
                items.append(
                    ConversionItem(
                        sourceURL: normalized,
                        sourceRootURL: nil,
                        relativePath: normalized.lastPathComponent
                    )
                )
            }
        }

        return items
    }

    public static func relativePath(from rootURL: URL, to fileURL: URL) -> String {
        let rootPath = rootURL.standardizedFileURL.path(percentEncoded: false)
        let filePath = fileURL.standardizedFileURL.path(percentEncoded: false)

        guard filePath.hasPrefix(rootPath) else {
            return fileURL.lastPathComponent
        }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        let relative = filePath[start...].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? fileURL.lastPathComponent : relative
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
