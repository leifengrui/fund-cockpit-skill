#!/usr/bin/env bash
# fund-cockpit 安装脚本：把本仓库的 4 个 skill 软链进 ~/.claude/skills/
# 用法: bash install.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.claude/skills"
mkdir -p "$SKILLS_DIR"

link_skill () {
  local src="$1" name="$2"
  local dst="$SKILLS_DIR/$name"
  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -d "$dst" ]; then
    echo "!! $dst 已存在且不是软链，跳过（如需覆盖请手动删除）" >&2
    return
  fi
  ln -s "$src" "$dst"
  echo "✓ $name  ->  $src"
}

# 主 skill
link_skill "$REPO/skills/fund-cockpit" "fund-cockpit"
# 三个被 vendor 的依赖
link_skill "$REPO/vendor/fund_analysis" "fund_analysis"
link_skill "$REPO/vendor/FAMAS-Skill/.claude/skills/famas-analyze-fund" "famas-analyze-fund"
link_skill "$REPO/vendor/zhengxi-views" "zhengxi-views"

echo
echo "完成。重启 Claude Code 会话后即可用：fund-cockpit <基金代码>"
echo "依赖：python3、curl；zhengxi-views 可选依赖见 vendor/zhengxi-views/requirements.txt"
