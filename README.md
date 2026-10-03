# Frpc Desktop

Flutter macOS FRP 客户端。界面用 `macos_ui`，内置 darwin universal `frpc`（fatedier/frp）。

仓库：[panw3i/frpc-macos](https://github.com/panw3i/frpc-macos)

## 本地运行

```bash
cd frpc_macos
flutter pub get
flutter run -d macos
```

Release 包：

```bash
cd frpc_macos
flutter build macos --release
```

产物在 `frpc_macos/build/macos/Build/Products/Release/Frpc Desktop.app`。未公证，本机打开前可 `xattr -cr`。

更新内置 frpc：`bash frpc_macos/tool/fetch_frpc.sh`

配置和展开后的二进制在 `~/Library/Application Support/net.bytenote.frpcMacos/FrpcDesktop`。

## GitHub Actions

- `ci.yml`：push / PR 在 Ubuntu 上跑 `flutter test` 和 `analyze`
- `release.yml`：打 `v*` tag 后用 **GitHub-hosted macOS runner** 打包 `Frpc-Desktop-macos.zip` 并发布 Release；也可 `workflow_dispatch` 只出 artifact

```bash
git tag v1.0.1
git push origin v1.0.1
```

## Agent CLI

应用运行时监听 `agent.sock`。JSON CLI：

```bash
python3 frpc_macos/tool/frpc-agent status
python3 frpc_macos/tool/frpc-agent servers add --name oracle --addr HOST --port 7000 --token TOKEN
python3 frpc_macos/tool/frpc-agent tunnels add --server ID --type tcp --local 8888 --remote 16888
python3 frpc_macos/tool/frpc-agent connect ID
```
