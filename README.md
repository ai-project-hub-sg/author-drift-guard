# author-drift-guard

防止「名单外作者身份」被不知情 push 到远端的**双层守卫**。

场景：一台设备、一个项目，前后贡献者不同——换过 `git config`、多人共用机器、cherry-pick 他人提交、bot 代提交。push 时历史混着多个作者，用户未必知情。

| 层 | 实现 | 强度 |
|---|---|---|
| 行为约定 | `skill/author-drift-guard/SKILL.md` — agent 在 push 前自查 | 依赖 agent 遵循 |
| Git 强制 | `hooks/pre-push` — git 本机钩子，agent 无法绕过 | 硬性拦截 |

合法身份 = 当前 `git config user.name/user.email` + `AGENTS.md` 中每行 `允许身份：…`。检出名单外作者且仓库 `AGENTS.md` 无约定时：SKILL 层暂停 push 向用户确认；hook 层直接阻止 `git push`。用户决定以 `⚠️ 贡献者身份约定` 块写入 `AGENTS.md` 顶部，之后免问。

只查 **author**，不查 committer（rebase/cherry-pick 天然改写 committer，查了会误报）。

## 安装

```powershell
# 1. 技能挂载到各 agent 技能库（junction 指向本项目，单份文件多处生效）
powershell -File install.ps1

# 2. 给某个仓库装 git 强制钩子
powershell -File install.ps1 -Repo <repo路径>
```

Git Bash / Linux / macOS 用 `./install.sh`（`-r <repo>` / `-u` 卸载）。

## 约定语法（AGENTS.md 顶部，hook 按 `约定：` 字段解析）

```markdown
> ⚠️ **贡献者身份约定**（Author Identity Policy）
> 约定：允许任意贡献者推送      # 放行
> 约定：push 前必须统一作者     # 检出名单外作者即拦截
> 约定：每次单独询问            # 交互式确认（无 tty 则拦截）
> 允许身份：someone <a@b.com>  # 可有多行；也可只写邮箱 a@b.com
```

## 手动等价操作（不用脚本时）

```powershell
mklink /J "%USERPROFILE%\.agents\skills\author-drift-guard" "E:\github\author-drift-guard\skill\author-drift-guard"
copy hooks\pre-push <repo>\.git\hooks\pre-push
```

支持的技能库目录：`~/.agents/skills`、`%APPDATA%/devin/skills`、`~/.codex/skills`、`~/.claude/skills`。

## 统一作者的历史改写（选「统一改写」时）

```bash
git filter-branch -f --env-filter '
export GIT_AUTHOR_NAME="name" GIT_AUTHOR_EMAIL="a@b.com"
export GIT_COMMITTER_NAME="name" GIT_COMMITTER_EMAIL="a@b.com"
' -- --all
```

已推过远端的需要 `--force`（先确认无协作者基于旧历史）。
