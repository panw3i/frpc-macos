# Frpc Desktop（Flutter macOS）

独立的 macOS 风格 FRP 客户端。产品模型参考 [luckjiawei/frpc-desktop](https://github.com/luckjiawei/frpc-desktop)，实现是 Flutter + `macos_ui`，不包含 Electron / Vue。

## 运行

```bash
cd frpc_macos
flutter pub get
flutter run -d macos
```

## 打包

```bash
flutter build macos --release
# 产物：
# build/macos/Build/Products/Release/Frpc Desktop.app
```

应用包内置最新 darwin universal `frpc`（当前 v0.71.0）。打开后填 frps、开隧道即可连接。

更新内置二进制：

```bash
bash tool/fetch_frpc.sh
flutter build macos --release
```

`config.json` 和展开后的 frpc 在 Application Support/`FrpcDesktop`。

## Agent CLI

应用运行时在数据目录监听 `agent.sock`。Agent 用同一套 JSON CLI 增删渠道/隧道、连接、看日志：

```bash
python3 tool/frpc-agent status
python3 tool/frpc-agent servers add --name oracle --addr 213.35.120.5 --port 7000 --token TOKEN
python3 tool/frpc-agent tunnels add --server ID --type tcp --local 8888 --remote 16888 --name site
python3 tool/frpc-agent connect ID
python3 tool/frpc-agent logs --tail 50
```

可执行文件：`tool/frpc-agent`。Skill：仓库内 `.grok/skills/frpc-agent`。
