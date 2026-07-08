import AppKit
import Foundation
import UniformTypeIdentifiers
import Video2MP3Core

@MainActor
final class ConversionQueueViewModel: ObservableObject {
    @Published var items: [ConversionItem] = []
    @Published var settings = ConversionSettings()
    @Published var isConverting = false
    @Published var isDropTargeted = false
    @Published var lastMessage: String?

    private let importService = ImportService()
    private let ffmpegService = FFmpegService()
    private var conversionTask: Task<Void, Never>?

    var canStart: Bool {
        !isConverting && settings.outputDirectory != nil && items.contains { $0.status == .queued || $0.status == .failed || $0.status == .cancelled }
    }

    var completedCount: Int {
        items.filter { $0.status == .succeeded }.count
    }

    var totalCount: Int {
        items.count
    }

    var overallProgress: Double {
        guard !items.isEmpty else {
            return 0
        }
        let total = items.reduce(0) { partial, item in
            partial + (item.status == .succeeded ? 1 : item.progress)
        }
        return total / Double(items.count)
    }

    func chooseVideos() {
        let panel = NSOpenPanel()
        panel.title = "选择视频"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ImportService.supportedVideoExtensions.compactMap {
            UTType(filenameExtension: $0)
        }

        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let folderURL = panel.url {
            addFolder(folderURL)
        }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "输出到"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK {
            settings.outputDirectory = panel.url
        }
    }

    func addFiles(_ urls: [URL]) {
        let newItems = importService.importFiles(urls, existingSourceURLs: existingSourceURLs)
        append(newItems)
    }

    func addFolder(_ url: URL) {
        let newItems = importService.importFolder(url, existingSourceURLs: existingSourceURLs)
        append(newItems)
    }

    func addDropURLs(_ urls: [URL]) {
        let newItems = importService.importDropURLs(urls, existingSourceURLs: existingSourceURLs)
        append(newItems)
    }

    func remove(_ item: ConversionItem) {
        items.removeAll { $0.id == item.id }
    }

    func clearQueue() {
        guard !isConverting else {
            return
        }
        items.removeAll()
        lastMessage = nil
    }

    func openOutputDirectory() {
        guard let outputDirectory = settings.outputDirectory else {
            return
        }
        NSWorkspace.shared.open(outputDirectory)
    }

    func startConversion() {
        guard canStart else {
            return
        }

        isConverting = true
        lastMessage = nil

        conversionTask = Task { [weak self] in
            await self?.runQueue()
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        ffmpegService.cancel()
        for index in items.indices where items[index].status == .queued || items[index].status == .running {
            items[index].status = .cancelled
            items[index].errorMessage = "用户已取消。"
        }
        isConverting = false
        lastMessage = "已取消转换。"
    }

    private var existingSourceURLs: Set<URL> {
        Set(items.map(\.sourceURL))
    }

    private func append(_ newItems: [ConversionItem]) {
        guard !newItems.isEmpty else {
            lastMessage = "没有找到可导入的视频，或视频已经在队列中。"
            return
        }
        items.append(contentsOf: newItems)
        lastMessage = "已加入 \(newItems.count) 个视频。"
    }

    private func runQueue() async {
        defer {
            isConverting = false
        }

        for index in items.indices {
            guard !Task.isCancelled else {
                return
            }

            guard items[index].status == .queued || items[index].status == .failed || items[index].status == .cancelled else {
                continue
            }

            items[index].status = .running
            items[index].progress = 0
            items[index].errorMessage = nil

            let item = items[index]

            do {
                let outputURL = try await ffmpegService.convert(item: item, settings: settings) { [weak self] progress in
                    Task { @MainActor in
                        guard let self, let liveIndex = self.items.firstIndex(where: { $0.id == item.id }) else {
                            return
                        }
                        self.items[liveIndex].progress = progress
                    }
                }

                if let liveIndex = items.firstIndex(where: { $0.id == item.id }) {
                    items[liveIndex].status = .succeeded
                    items[liveIndex].progress = 1
                    items[liveIndex].outputURL = outputURL
                }
            } catch is CancellationError {
                markFailedOrCancelled(id: item.id, status: .cancelled, message: "用户已取消。")
            } catch let error as Video2MP3Error {
                let status: ConversionStatus = error == .cancelled ? .cancelled : .failed
                markFailedOrCancelled(id: item.id, status: status, message: error.localizedDescription)
            } catch {
                markFailedOrCancelled(id: item.id, status: .failed, message: error.localizedDescription)
            }
        }

        let failedCount = items.filter { $0.status == .failed }.count
        let successCount = items.filter { $0.status == .succeeded }.count
        lastMessage = "转换完成：成功 \(successCount) 个，失败 \(failedCount) 个。"
    }

    private func markFailedOrCancelled(id: UUID, status: ConversionStatus, message: String) {
        guard let liveIndex = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[liveIndex].status = status
        items[liveIndex].errorMessage = message
        items[liveIndex].progress = 0
    }
}
