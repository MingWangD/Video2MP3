import AppKit
import SwiftUI
import UniformTypeIdentifiers
import Video2MP3Core

struct ContentView: View {
    @StateObject private var viewModel = ConversionQueueViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            mainContent
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.chooseVideos()
            } label: {
                Label("选择视频", systemImage: "film")
            }

            Button {
                viewModel.chooseFolder()
            } label: {
                Label("选择文件夹", systemImage: "folder")
            }

            Divider()
                .frame(height: 22)

            Button {
                viewModel.chooseOutputDirectory()
            } label: {
                Label("输出到", systemImage: "folder.badge.gearshape")
            }

            Text(viewModel.settings.outputDirectory?.path(percentEncoded: false) ?? "未选择输出文件夹")
                .font(.callout)
                .foregroundStyle(viewModel.settings.outputDirectory == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(role: .destructive) {
                viewModel.clearQueue()
            } label: {
                Label("清空", systemImage: "trash")
            }
            .disabled(viewModel.items.isEmpty || viewModel.isConverting)
        }
        .padding(14)
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            dropZone
                .frame(width: 310)
                .padding(16)

            Divider()

            queueList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(viewModel.isDropTargeted ? Color.accentColor : Color.secondary)

            Text("拖拽视频或文件夹到这里")
                .font(.title3.weight(.semibold))

            Text("支持 mp4、mov、mkv、avi、webm 等常见视频格式。文件夹会递归扫描，输出时保留目录结构。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 8) {
                Button {
                    viewModel.chooseVideos()
                } label: {
                    Label("选择视频", systemImage: "film")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)

                Button {
                    viewModel.chooseFolder()
                } label: {
                    Label("选择文件夹", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(viewModel.isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    viewModel.isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor),
                    style: StrokeStyle(lineWidth: viewModel.isDropTargeted ? 2 : 1, dash: [8, 6])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            loadDroppedURLs(providers)
            return true
        }
    }

    private var queueList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("转换队列")
                    .font(.headline)
                Text("\(viewModel.items.count) 个视频")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding([.top, .horizontal], 16)
            .padding(.bottom, 8)

            if viewModel.items.isEmpty {
                emptyQueueView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.items) { item in
                        QueueRow(item: item) {
                            viewModel.remove(item)
                        }
                        .disabled(viewModel.isConverting)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var emptyQueueView: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("队列为空")
                .font(.title3.weight(.semibold))
            Text("添加视频后会在这里显示转换状态。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                ProgressView(value: viewModel.overallProgress)
                    .frame(width: 240)
                Text(viewModel.lastMessage ?? "成功后会生成 MP3 文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("已完成 \(viewModel.completedCount)/\(viewModel.totalCount)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                viewModel.openOutputDirectory()
            } label: {
                Label("在 Finder 中显示", systemImage: "magnifyingglass")
            }
            .disabled(viewModel.settings.outputDirectory == nil)

            if viewModel.isConverting {
                Button(role: .destructive) {
                    viewModel.cancelConversion()
                } label: {
                    Label("取消", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.cancelAction)
            } else {
                Button {
                    viewModel.startConversion()
                } label: {
                    Label("开始转换", systemImage: "play.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canStart)
            }
        }
        .padding(14)
    }

    private func loadDroppedURLs(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let droppedURLs = LockedURLs()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    droppedURLs.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let urls = droppedURLs.values()
            guard !urls.isEmpty else {
                return
            }
            viewModel.addDropURLs(urls)
        }
    }
}

private final class LockedURLs: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    func values() -> [URL] {
        lock.lock()
        let snapshot = storage
        lock.unlock()
        return snapshot
    }
}

private struct QueueRow: View {
    let item: ConversionItem
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.sourceURL.lastPathComponent)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Text(item.status.localizedTitle)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }

                Text(item.sourceURL.path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.status == .running {
                    ProgressView(value: item.progress)
                } else if let outputURL = item.outputURL {
                    Text(outputURL.path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if let errorMessage = item.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Button(action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help("从队列移除")
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: some View {
        Group {
            switch item.status {
            case .queued:
                Image(systemName: "clock")
            case .running:
                ProgressView()
                    .controlSize(.small)
            case .succeeded:
                Image(systemName: "checkmark.circle.fill")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
            }
        }
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch item.status {
        case .queued:
            .secondary
        case .running:
            .accentColor
        case .succeeded:
            .green
        case .failed:
            .red
        case .cancelled:
            .orange
        }
    }
}
