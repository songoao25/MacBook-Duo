# 贡献指南

感谢你关注 MacBook Duo。这个项目仍处于测试阶段，欢迎提交可复现的 Bug、兼容性反馈和小范围改进。

## 提交前

- 先搜索现有 Issues，避免重复报告。
- 不要在 Issue、截图或日志中上传桌面内容、个人路径、账号信息或其他敏感数据。
- 说明 macOS 版本、Mac 型号、芯片架构、运行模式（截图/实时）和复现步骤。
- 涉及权限、全局覆盖层或渲染的改动，要明确写出实际验证范围和未覆盖的场景。

## 开发与验证

项目使用系统 Swift 编译器，没有 Xcode 工程文件和第三方依赖：

```sh
./test.sh
./build.sh
codesign --verify --deep --strict "MacBook Duo.app"
git diff --check
```

如果修改了应用元数据、构建脚本或安装包，还要检查 arm64 架构、macOS 15.0 最低版本和 ZIP 内容。不要把静态构建结果描述成已经完成真实设备或所有机型验证。

## 提交代码

1. 从 `main` 创建清晰命名的分支，例如 `fix/live-overlay-timeout`。
2. 使用 Conventional Commits：`feat:`、`fix:`、`docs:`、`test:`、`chore:`。
3. 用户可见的行为、权限或兼容性变化要同步更新中英文 README 和 CHANGELOG。
4. 通过 Pull Request 提交，说明变更、风险、测试命令和未验证内容。

## 许可证

本仓库当前没有授予新的开源许可证。贡献前请确认你有权提交相关代码、图标和文档，并接受其最终是否合并由作者决定。详见 [许可证状态](docs/license-status.md)。
