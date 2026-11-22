#!/usr/bin/env bash
# author-drift-guard 安装脚本（Git Bash / Linux/macOS 通用）
# 用法:
#   ./install.sh                  # 仅挂载技能到各 agent 技能库
#   ./install.sh -r <repo>        # 同时把 pre-push 钩子装入该仓库
#   ./install.sh -u               # 移除挂载点
set -euo pipefail
project="$(cd "$(dirname "$0")" && pwd)"
skill_src="$project/skill/author-drift-guard"
name='author-drift-guard'
home_dir="${USERPROFILE:-$HOME}"
appdata="${APPDATA:-$home_dir/.config}"
targets=(
  "$home_dir/.agents/skills/$name"
  "$appdata/devin/skills/$name"
  "$home_dir/.codex/skills/$name"
  "$home_dir/.claude/skills/$name"
)

link_dir() {  # $1=target $2=src —— Windows 用 junction，否则 symlink
  local t="$1" s="$2"
  mkdir -p "$(dirname "$t")"
  if [ -d "$t" ] && [ ! -L "$t" ]; then
    [ -f "$t/SKILL.md" ] && rm -rf "$t" || { echo "skip(已存在非本技能目录): $t"; return; }
  fi
  [ -L "$t" ] && rm -f "$t"
  if ln -s "$s" "$t" 2>/dev/null; then echo "symlink: $t -> $s";
  else cmd //c mklink //J "$(cygpath -w "$t")" "$(cygpath -w "$s")" >/dev/null && echo "junction: $t -> $s"; fi
}

repo=''; uninstall=0
while [ $# -gt 0 ]; do case "$1" in -r|--repo) repo="$2"; shift;; -u|--uninstall) uninstall=1;; esac; shift; done

if [ "$uninstall" = 1 ]; then for t in "${targets[@]}"; do rm -rf "$t" && echo "removed: $t"; done; exit 0; fi
for t in "${targets[@]}"; do link_dir "$t" "$skill_src"; done

if [ -n "$repo" ]; then
  dst="$repo/.git/hooks/pre-push"
  [ -d "$repo/.git" ] || { echo "不是 git 仓库: $repo" >&2; exit 1; }
  if [ -e "$dst" ]; then echo "pre-push 已存在: $dst（未覆盖）";
  else mkdir -p "$(dirname "$dst")"; ln "$project/hooks/pre-push" "$dst" 2>/dev/null || cp "$project/hooks/pre-push" "$dst"; chmod +x "$dst" 2>/dev/null || true; echo "hook installed: $dst"; fi
fi
echo done.
