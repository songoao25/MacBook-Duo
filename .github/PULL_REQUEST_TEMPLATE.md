## 变更说明

<!-- 说明做了什么、为什么需要。用户可见内容请同步 README.md 和 README.zh-CN.md。 -->

## 用户可见变化

<!-- 如涉及安装、权限、UI、渲染、兼容性或下载行为，请写清楚；没有则留空。 -->

## 验证

- [ ] `./test.sh`
- [ ] `./build.sh`
- [ ] `codesign --verify --deep --strict "MacBook Duo.app"`
- [ ] `git diff --check`
- [ ] 如涉及安装包，已运行 `unzip -t` 并核对架构和 SHA-256
- [ ] 已注明真实验证的 macOS、Mac 型号和模式
- [ ] 已使用 Conventional Commit 前缀

## 安全与隐私

- [ ] 没有提交屏幕截图、凭据、权限数据库、日志或个人路径
- [ ] 没有增加未经说明的网络上传、遥测或权限
- [ ] 没有绕过屏幕录制授权、访问控制或 Gatekeeper
- [ ] 没有复制未经授权的第三方代码、图标或资源
