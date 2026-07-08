# Video2MP3

Video2MP3 是一个原生 macOS 小工具，用于从常见视频文件中提取音频并保存为 MP3。

## 功能

- 拖拽导入视频或文件夹。
- 通过按钮选择视频文件或文件夹。
- 文件夹导入会递归扫描子文件夹。
- 支持 `.mp4`、`.mov`、`.m4v`、`.avi`、`.mkv`、`.webm`、`.flv`、`.wmv`、`.mpeg`、`.mpg`、`.3gp`。
- 批量串行转换，避免同时运行多个 ffmpeg 占满 CPU。
- 用户指定输出文件夹。
- 递归导入时保留原目录结构。
- 输出 MP3，不覆盖已有文件，重名时自动追加序号。
- 默认使用 `libmp3lame`、`192k`，并将 title 元数据写为源视频文件名。

## 下载

在 GitHub Releases 中下载与你的 Mac 芯片匹配的版本：

- `Video2MP3-macOS-arm64.zip`：Apple Silicon，M 系列芯片。
- `Video2MP3-macOS-x86_64.zip`：Intel Mac。

解压后把 `Video2MP3.app` 拖到“应用程序”文件夹即可。

v0.1.0 使用 ad-hoc signing，尚未 notarize。如果首次打开时 macOS 阻止启动，可以：

1. 打开“系统设置 > 隐私与安全性”，在安全提示处允许打开。
2. 或在 Finder 中右键 `Video2MP3.app`，选择“打开”。

## 使用

1. 打开 app。
2. 拖入视频或文件夹，也可以点击“选择视频”或“选择文件夹”。
3. 点击“输出到”选择 MP3 保存目录。
4. 点击“开始转换”。
5. 转换完成后点击“在 Finder 中显示”查看输出文件。

文件夹导入会递归扫描子文件夹，并在输出目录中保留原目录结构。

## 开发

当前项目使用 Swift Package Manager 组织代码：

```bash
swift build
swift run Video2MP3
```

开发环境可以通过以下任一方式提供 ffmpeg：

1. 将 macOS 版 ffmpeg 放到 `Resources/ffmpeg/ffmpeg`。
2. 设置环境变量：

```bash
export VIDEO2MP3_FFMPEG_PATH=/path/to/ffmpeg
```

3. 使用 Homebrew 安装：

```bash
brew install ffmpeg
```

测试在完整 Xcode 或 GitHub Actions macOS runner 上运行：

```bash
swift test
```

某些精简 Command Line Tools 环境可能缺少 `XCTest` 模块，此时可先用 `swift build` 验证编译。

## 打包

打包当前机器架构：

```bash
scripts/package_app.sh
```

指定架构：

```bash
scripts/package_app.sh --arch arm64
scripts/package_app.sh --arch x86_64
```

生成 universal 包需要完整 Xcode：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
scripts/package_app.sh --universal
```

产物会生成到 `dist/`：

- `dist/Video2MP3.app`
- `dist/Video2MP3-macOS-arm64.zip`
- `dist/Video2MP3-macOS-x86_64.zip`
- `dist/Video2MP3-macOS-universal.zip`

具体文件取决于打包参数。

## 发布

仓库包含 GitHub Actions workflow。推送 `v*` tag 时会：

- 在 `macos-26` 构建 arm64 包。
- 在 `macos-26-intel` 构建 x86_64 包。
- 安装并内置 ffmpeg。
- 运行构建和测试。
- 对 app 做 ad-hoc signing。
- 上传两个 zip 到 GitHub Release。

示例：

```bash
git tag v0.1.0
git push origin v0.1.0
```

## v0.1.0 已知限制

- 只输出 MP3。
- MP3 码率固定为 `192k`。
- 暂不提供 App Store 版本。
- 暂未 notarize，首次打开可能需要用户手动允许。
- ffmpeg 授权取决于发布包中内置 ffmpeg 的构建配置，维护者发布前必须核对对应授权义务。

## License

MIT。内置 ffmpeg 的授权信息见 `THIRD_PARTY_NOTICES.md`。
