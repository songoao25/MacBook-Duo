# 仓库维护规范

这份清单将本仓库与作者其他项目使用的 README、CI、安全和 Agent 管理约定对齐。

## 对外入口

- `README.md` 使用英文，`README.zh-CN.md` 使用简体中文；用户可见变化必须同步。
- README 顶部的徽章必须对应真实存在的工作流、版本状态、平台、架构和许可证状态。
- Release 徽章只能对应真实存在的 GitHub Release；README 的官方安装包入口统一指向 Release 页面。
- README 必须明确测试版状态、系统版本、Apple Silicon 限制、权限、隐私、Gatekeeper/公证边界和已知兼容性限制。

## 源码与构建

- `build.sh` 固定目标 `arm64-apple-macosx15.0`，生成的 app bundle 和编译产物不提交。
- `test.sh` 是不启动应用的轻量测试入口；源码或构建脚本变更后必须运行。
- `MacBook Duo.app.zip` 只作为 GitHub Release 的版本化资产上传，不提交到仓库根目录、`dist/` 或其他源码目录；本地候选包应放在仓库外的临时目录或交付输出目录。
- GitHub 的 `Code → Download ZIP` 负责源码快照，不能把源码压缩包和应用安装包混为同一个发行物。
- 替换 Release 安装包时，必须重新校验 ZIP、架构、Info.plist、签名和 SHA-256，并在 Release 页面保留明确的版本标签。
- 不把一次成功构建描述为真实设备、所有机型、Gatekeeper、公证或 App Store 验收。

## 贡献与安全

- 使用 Conventional Commits：`feat:`、`fix:`、`docs:`、`test:`、`chore:`。
- Issue/PR 表单要收集复现证据，同时提醒用户移除桌面内容、凭据、日志和本地路径。
- 安全问题走 Private vulnerability reporting，不在公开 Issue 发布可利用细节。
- 不提交密钥、Cookie、权限数据库、屏幕截图、构建产物或个人路径。
- 当前无开源许可证；所有 README、贡献指南和发布说明必须保持这一边界。

## 推送后回读

每次请求远程发布时，维护者应回读：

1. 远程提交 SHA 和作者署名；
2. 仓库可见性、默认分支和仓库 URL；
3. 目标文件清单与下载链接；
4. GitHub Actions 的 CI/CodeQL 状态；
5. 若是安装包，Release 资产的下载链接、大小和 SHA-256。
