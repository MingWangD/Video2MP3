# Third Party Notices

## FFmpeg

Video2MP3 can bundle FFmpeg for video/audio decoding and MP3 encoding.

- Project: https://ffmpeg.org/
- Source: https://git.ffmpeg.org/ffmpeg.git
- License: FFmpeg may be built under LGPL or GPL depending on enabled codecs and build options.

Video2MP3 does not commit an FFmpeg binary to this repository. Release builds copy an FFmpeg executable into the app bundle during packaging.

When distributing a build that includes FFmpeg, verify the exact FFmpeg binary's license terms and provide any required source, notices, and license text. The GitHub Actions workflow installs FFmpeg from Homebrew for convenience; release maintainers must confirm whether that binary and configuration are appropriate for their distribution requirements before publishing a public release.

If you replace the packaged FFmpeg binary, update this notice to match the exact source, version, build configuration, and license obligations of the binary you distribute.
