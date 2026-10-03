#!/usr/bin/env bash
# 把 GitHub 上最新的 darwin frpc 打成 universal，写入 assets/frpc/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/frpc"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TAG="$(gh api repos/fatedier/frp/releases/latest --jq .tag_name)"
VER="${TAG#v}"
echo "fetch $TAG"
cd "$TMP"
gh release download "$TAG" --repo fatedier/frp \
  --pattern "frp_${VER}_darwin_arm64.tar.gz" \
  --pattern "frp_${VER}_darwin_amd64.tar.gz"
tar -xzf "frp_${VER}_darwin_arm64.tar.gz"
tar -xzf "frp_${VER}_darwin_amd64.tar.gz"
mkdir -p "$OUT"
lipo -create \
  "frp_${VER}_darwin_arm64/frpc" \
  "frp_${VER}_darwin_amd64/frpc" \
  -output "$OUT/frpc"
chmod +x "$OUT/frpc"
printf '%s\n' "$TAG" > "$OUT/VERSION"
file "$OUT/frpc"
ls -lh "$OUT/frpc"
echo "wrote $OUT ($TAG)"
