---
name: frpc-agent
description: >
  用 Frpc Desktop 的 agent CLI 直接操作渠道、隧道、连接和日志。
  触发：/frpc-agent、frpc-agent、agent 操作 frp、CLI 连隧道、给 agent 用的 frpc 命令。
---

# frpc-agent

CLI：`/Users/pan/Desktop/frp/frpc_macos/tool/frpc-agent`（也可 `python3` 跑它）。

应用在跑时走 unix socket：
`~/Library/Application Support/net.bytenote.frpcMacos/FrpcDesktop/agent.sock`

写操作（add/update/rm/connect）若 app 没开，会尝试 `open` `dist/Frpc Desktop.app`。只读命令在 app 没开时读 `config.json`。

输出永远是 JSON。`ok: false` 时进程退出码为 1。

## 命令

```bash
frpc-agent status
frpc-agent servers list
frpc-agent servers add --name oracle --addr 213.35.120.5 --port 7000 --token TOKEN
frpc-agent servers update ID --name prod
frpc-agent servers rm ID
frpc-agent tunnels list --server ID
frpc-agent tunnels add --server ID --type tcp --local 8888 --remote 16888 --name site
frpc-agent tunnels add --server ID --type http --local 8080 --domain app.example.com
frpc-agent tunnels update TID --local 9999
frpc-agent tunnels rm TID
frpc-agent connect [ID]
frpc-agent disconnect [ID]
frpc-agent logs --tail 80 --server ID
```

`connect` / `disconnect` 不传 ID 表示全部就绪渠道。

## 规则

- 渠道是 frps（`servers`），隧道挂在渠道下（`tunnels --server`）。
- 先 `status` 拿 id，再用 id 操作。不要猜端口。
- 远程 TCP 端口习惯 16000–16999。
- 不要默认开 SSH 22。
- 改完用 `status` 看 `connected`、`error`、每个 proxy 的 `status`。
