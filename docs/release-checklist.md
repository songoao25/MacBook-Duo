# 发布与安装包检查清单

## 版本与内容

- [ ] `Info.plist` 的 `CFBundleShortVersionString`、`CFBundleVersion`、最低 macOS 版本与 README/CHANGELOG 一致。
- [ ] README.md 与 README.zh-CN.md 都更新了功能、权限、隐私、限制和下载说明。
- [ ] 作者署名为江灵夏草（JLXC）。
- [ ] 源码中没有凭据、桌面截图、个人路径、日志或其他私有数据。
- [ ] 许可证状态没有被误写成 MIT、Apache、GPL 或其他开源许可证。

## 本地验证

- [ ] `./test.sh`
- [ ] `./build.sh`
- [ ] `codesign --verify --deep --strict "MacBook Duo.app"`
- [ ] `file "MacBook Duo.app/Contents/MacOS/HingeGlass"` 确认 `arm64`
- [ ] `plutil -extract LSMinimumSystemVersion raw -o - Info.plist` 返回 `15.0`
- [ ] `git diff --check`
- [ ] 如替换安装包，运行 `unzip -t "MacBook Duo.app.zip"` 并记录 SHA-256

## 远程发布

- [ ] 先审阅精确的 staged 文件清单和 diff。
- [ ] 推送后回读远程 commit SHA、作者、仓库可见性、文件清单和 Actions 状态。
- [ ] Raw 下载链接返回 ZIP，而不是 HTML 或错误页。
- [ ] 未宣称公证、App Store 上架或所有机型兼容，除非有独立证据。
