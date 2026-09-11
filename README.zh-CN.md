# MacBook Duo

[English](README.md) · **简体中文**

[![CI](https://github.com/songoao25/MacBook-Duo/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/songoao25/MacBook-Duo/actions/workflows/ci.yml)
[![CodeQL](https://github.com/songoao25/MacBook-Duo/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/songoao25/MacBook-Duo/actions/workflows/codeql.yml)
[![Release](https://img.shields.io/github/v/release/songoao25/MacBook-Duo?include_prereleases)](https://github.com/songoao25/MacBook-Duo/releases)
[![最后提交](https://img.shields.io/github/last-commit/songoao25/MacBook-Duo)](https://github.com/songoao25/MacBook-Duo/commits/main)
[![平台](https://img.shields.io/badge/平台-macOS%2015%2B-blue)](https://www.apple.com.cn/macos/)
[![架构](https://img.shields.io/badge/架构-Apple%20Silicon%20%28arm64%29-6f42c1)](https://support.apple.com/zh-cn/116943)
[![状态](https://img.shields.io/badge/状态-测试版%200.6-orange)](CHANGELOG.md)
[![许可证：未指定](https://img.shields.io/badge/许可证-未指定-lightgrey)](docs/license-status.md)

> 作者：江灵夏草（JLXC）

MacBook Duo 是一款 macOS 桌面视觉实验软件。它根据 MacBook 铰链角度，让桌面截图或实时桌面捕获产生透视、悬浮玻璃和毛玻璃过渡效果。

本仓库包含源码快照、构建脚本、测试、图标和发布文档。可分发的开发版安装包作为 GitHub Release 资产发布；当前不是正式签名或公证版本。

## 下载

[从 GitHub Releases 下载当前测试版](https://github.com/songoao25/MacBook-Duo/releases)

Release 页面提供版本化的 `MacBook Duo.app.zip` 安装包资产。下载后解压即可得到 `MacBook Duo.app`。当前安装包为 Apple Silicon（`arm64`）测试版 0.6。由于使用临时的 ad-hoc 开发签名，Gatekeeper 可能拒绝打开；如果系统安全策略不接受安装包，请审阅源码后自行构建。

## 功能

- 导入桌面截图，手动模拟铰链角度。
- 使用 ScreenCaptureKit 和 Metal 的实时桌面模式。
- 在 MacBook 提供兼容 HID 通路时读取铰链传感器。
- 保存展开终点和快捷键操作。
- 图像在本机处理，不上传桌面画面，也不写入录像文件。
- 可从菜单栏启用或停止全局覆盖层。

## 环境要求

- macOS 15.0 或更高版本。
- Apple Silicon Mac（`arm64`）。
- 支持 Metal 的 Mac。
- 实时模式面向 MacBook 内置屏幕，并不保证所有机型兼容。

没有铰链传感器时，仍可使用截图手动模拟模式。

## 安装与使用

1. 从上面的 Release 页面下载 `MacBook Duo.app.zip` 并解压。
2. 打开 `MacBook Duo.app`。
3. 在截图模式导入完整桌面截图，点击“开始测试”。
4. 调整模拟角度、深度和毛玻璃强度，按 `⌘K` 保存展开终点。
5. 使用实时模式时，按照 macOS 提示授予屏幕录制权限；画面在本机处理。

分发包是 ad-hoc 开发签名版本。若 Gatekeeper 或本机安全策略不接受该包，请检查源码并在本机重新构建。

## 快捷键

| 快捷键 | 操作 |
| --- | --- |
| `⌘H` | 隐藏或恢复截图模式控制界面 |
| `Esc` | 显示截图模式控制界面 |
| `⌘K` | 保存当前角度为展开终点 |
| `⌘B` | 切换原图对比 |
| `⌘Q` | 退出 |
| `⌘⇧G` | 切换实时桌面效果 |
| `⌘⇧K` | 保存实时铰链终点 |
| `⌘⇧Esc` | 停止实时模式并返回设置 |

## 从源码构建

安装 Apple Command Line Tools 后运行：

```sh
./test.sh
./build.sh
open "MacBook Duo.app"
```

项目没有 Xcode 工程文件，也不依赖第三方库。`build.sh` 调用系统 Swift 编译器，固定生成 `arm64-apple-macosx15.0` 目标，复制资源并执行本机 ad-hoc 签名。`test.sh` 编译并运行权限迁移测试，不会启动应用，也不会修改屏幕录制权限。

## 项目结构

| 路径 | 作用 |
| --- | --- |
| `Sources/` | SwiftUI/AppKit 界面、Metal 渲染、实时捕获和铰链传感器代码 |
| `Tests/` | 屏幕录制权限准备逻辑测试 |
| `Assets/` | 应用图标和设计记录 |
| `Info.plist` | Bundle 元数据和隐私用途说明 |
| `build.sh` | 本地应用构建入口 |
| `test.sh` | 轻量源码测试入口 |
| `GLOBAL-README.md` | 实时全局覆盖层说明 |
| `PERMISSIONS.md` | 屏幕录制权限迁移说明 |
| `docs/` | 许可证、仓库和发布维护指南 |

## 隐私与权限

实时模式需要用户授予屏幕录制权限。当前实现使用 ScreenCaptureKit 和 Metal 在本机处理；源码注释和开发文档说明画面不会通过网络发送，也不会保存为录像。校准值存储在应用自己的本地 `UserDefaults` 域中。

权限准备辅助逻辑只重置本应用自己的屏幕录制授权，并且每个代码签名身份只执行一次。这是开发版本迁移辅助，不是绕过授权。详见 [PERMISSIONS.md](PERMISSIONS.md)。

## 已知限制

- 铰链 HID 支持取决于具体 MacBook 机型。
- 实时模式主要面向内置屏幕，尚未覆盖所有全屏应用、Space、受保护视频或外接显示器场景。
- 下载的应用是 ad-hoc 签名，未经过公证。
- 当前项目没有新增开源许可证，详见[许可证状态](docs/license-status.md)。

## 参考与署名

渲染器为独立实现。开发文档中保留了参考项目链接，包括 [Duo-animation](https://github.com/Atomicx7/Duo-animation) 和 [LidAngleSensor](https://github.com/samhenrigold/LidAngleSensor)。任何衍生使用者应自行核对相关项目的许可证和署名要求。

## 仓库管理

- [English README](README.md)
- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)
- [支持与反馈](SUPPORT.md)
- [Agent 使用说明](AGENTS.md)
- [发布检查清单](docs/release-checklist.md)

## 许可证与作者

版权所有 © 2026 江灵夏草（JLXC）。本仓库目前没有授予新的开源许可证。未经作者另行许可，请勿重新分发、重新授权或将源码作为开源项目复用。
