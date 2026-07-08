# Video2MP3

Video2MP3 是一个 macOS 可视化小工具，用于从常见视频文件中提取音频，并保存为 MP3。

它是一个真正的 Mac app，不需要打开终端，不需要写代码，也不需要手动安装 ffmpeg。下载 DMG 后拖入“应用程序”，打开软件即可使用。

## 功能

- 拖拽导入视频或文件夹。
- 通过按钮选择视频文件或文件夹。
- 文件夹导入会递归扫描子文件夹。
- 支持 `.mp4`、`.mov`、`.m4v`、`.avi`、`.mkv`、`.webm`、`.flv`、`.wmv`、`.mpeg`、`.mpg`、`.3gp`。
- 支持批量转换。
- 可以指定 MP3 输出文件夹。
- 递归导入文件夹时，输出目录会保留原来的子文件夹结构。
- 输出 MP3 时不会覆盖已有文件，重名时会自动追加序号。
- 默认输出 MP3 码率为 `192k`。
- app 内置 ffmpeg，用户不需要额外安装转换工具。
- 提供包含 `V23` 标识的 macOS app 图标。

## 下载

打开 GitHub Releases 页面：

[https://github.com/MingWangD/Video2MP3/releases](https://github.com/MingWangD/Video2MP3/releases)

优先下载与你的 Mac 芯片匹配的 DMG：

- Apple Silicon，M1/M2/M3/M4 等芯片：下载 `Video2MP3-macOS-arm64.dmg`
- Intel Mac：下载 `Video2MP3-macOS-x86_64.dmg`

如果不确定自己的 Mac 是哪种芯片，可以点击屏幕左上角 Apple 标志，然后选择“关于本机”查看。

## 安装

1. 打开下载好的 `.dmg` 文件。
2. 将 `Video2MP3.app` 拖到 `Applications` 文件夹。
3. 打开 Finder。
4. 进入“应用程序”。
5. 打开 `Video2MP3`。

zip 文件也作为备用下载方式保留。解压后同样可以得到 `Video2MP3.app`，再把它拖到“应用程序”即可。

## 首次打开提示

当前版本暂未进行 Apple Developer ID 签名和 Apple notarization 公证。第一次在某台 Mac 上打开时，系统可能提示：

```text
未打开 “Video2MP3”
Apple 无法验证 “Video2MP3” 是否包含可能危害 Mac 安全或泄漏隐私的恶意软件。
```

这是 macOS Gatekeeper 的安全提示，不代表软件损坏。只想在单台电脑上使用时，可以手动允许一次。

## 推荐打开方式

1. 将 `Video2MP3.app` 拖到“应用程序”。
2. 在 Finder 中打开“应用程序”。
3. 右键点击 `Video2MP3.app`。
4. 选择“打开”。
5. 系统再次弹窗时，点击“打开”。

成功打开一次后，这台 Mac 通常就可以正常双击打开了。

## 如果仍然被拦截

可以在系统设置中允许打开：

1. 打开“系统设置”。
2. 进入“隐私与安全性”。
3. 向下滚动到“安全性”区域。
4. 找到关于 `Video2MP3` 被阻止的提示。
5. 点击“仍要打开”。
6. 输入密码或使用 Touch ID 确认。

也可以参考下面的位置，在“隐私与安全性”的“安全性”区域允许对应来源的应用：

![macOS 隐私与安全性中的任何来源选项](docs/images/macos-privacy-anywhere.png)

如果系统里没有“任何来源”选项，可以在终端执行下面命令让它显示出来：

```bash
sudo spctl --global-disable
```

旧版 macOS 如果不支持上面的参数，可以尝试：

```bash
sudo spctl --master-disable
```

执行后重新打开“系统设置 > 隐私与安全性”，在“允许以下来源的应用程序”中选择“任何来源”。完成测试后，建议改回更安全的选项，例如“App Store 与已知开发者”。如果只是为了打开 Video2MP3，一般优先使用“右键 > 打开”或“仍要打开”，不建议长期保持“任何来源”。

如果已经把 app 拖到“应用程序”，也可以只移除这个 app 的下载隔离标记：

```bash
xattr -dr com.apple.quarantine /Applications/Video2MP3.app
```

这个操作只影响本机的这个 app。换另一台 Mac 下载时，仍然需要重新允许一次。

## 使用方法

1. 打开 `Video2MP3`。
2. 拖入视频或文件夹，也可以点击“选择视频”或“选择文件夹”。
3. 点击“输出到”，选择 MP3 保存目录。
4. 点击“开始转换”。
5. 转换完成后，点击“在 Finder 中显示”查看输出文件。

如果导入的是文件夹，Video2MP3 会递归扫描其中的视频文件，并在输出目录中保留原来的子文件夹结构。

## 当前限制

- 当前只输出 MP3。
- MP3 码率固定为 `192k`。
- 暂未上架 App Store。
- 暂未进行 Apple notarization 公证，首次打开可能需要手动允许。

## License

MIT。内置 ffmpeg 的授权信息见 `THIRD_PARTY_NOTICES.md`。
