---
name: author-drift-guard
description: 在任何会向远端仓库推送提交的 git push 执行前拦截检查——不限 remote 名、不限分支/tag（push origin 任意分支、push 到其他 remote、-u、首次发布、强推、推 tag 均触发，绝非仅 push origin main）：先查 AGENTS.md 是否已有贡献者身份约定；无约定则扫描待推送提交的作者身份（author name/email），发现与当前 git config 身份及「允许身份」名单均不符者，即暂停 push 并询问用户知情与处置方式，将决定以显著标记写入 AGENTS.md 顶部。防止同一设备/项目中前后贡献者不同的提交在不知情下被推到远端。
---

# 贡献者身份漂移守卫（Author Drift Guard）

目的：同一台设备、同一个项目，不同时期可能用不同 git 身份提交（换过 `git config`、多人共用机器、cherry-pick 他人提交、CI/AI bot 代提交）。push 时历史里混着多个作者，用户可能未注意。本 skill 保证 push 前用户必然知情并留下书面约定。

**两层防护**：本 SKILL.md 是 agent 行为约定层；本仓库 `hooks/pre-push` 是 git 强制层（安装后由 git 本身拦截，agent 无法绕过）。两者建议同时启用——见 `install.ps1` / `install.sh`。

## 触发时机

**判定标准只有一个：命令是否会向远端仓库推送提交。** 与 remote 名、分支名、是否已设 upstream 无关——绝非只有 `push origin main` 才触发。即将执行以下任一操作时，必须先走完本流程再执行 push，不可跳过：

- `git push` 的任意形态：`push`、`push origin`、`push origin <任意分支>`、`push <其他 remote> <分支>`、`push -u`、`push --all`
- 推 tag：`push --tags`、`push origin v1.0`
- 强推 `--force` / `--force-with-lease`；新仓库或新分支的首次 push
- 替用户执行或指导用户执行 push

不触发：`push --delete` / `push origin :<ref>`（只删远端 ref、不推提交，hook 层同样跳过）；`fetch` / `pull` / `commit` 等纯本地操作。

**例外**：AGENTS.md 已有明确约定且用户本次未要求变更 → 直接按约定执行，不再询问。

## 流程

### 1. 查 AGENTS.md 约定

- 读仓库根 `AGENTS.md`（有 `AGENTS.override.md` 也读）。
- 搜索 `身份约定`、`作者约定`、`author`、`contributor` 等关键词。
- 找到约定 → 按约定处理（放行 / 拦截 / 需先统一），结束本 skill。
- 未找到 → 进入第 2 步。

### 2. 扫描待推送提交的作者身份

**范围**：待推送提交（按本次 push 实际涉及的 ref 计算：当前分支用 `git log @{u}..HEAD`，push 其他分支/无 upstream 时用 `git log <远端ref>..<本地ref>`）。

**期望身份**：当前 `git config user.name` 与 `user.email` 拼成的 `name <email>`，外加 AGENTS.md 中每行 `允许身份：<name <email> 或 email>`。

```bash
git log @{u}..HEAD --format='%an <%ae>' | sort -u   # 本次 push 涉及的全部作者
git config user.name; git config user.email         # 期望身份基准
```

- 全部作者 ∈ {期望身份} ∪ {允许身份} → 未命中，进第 4 步"无漂移"分支。
- 存在名单外作者（换过 config 的旧身份、他人代提交、bot 身份等）→ 命中，第 3 步。

注意：**只查 author，不查 committer**——rebase / cherry-pick / amend 天然改写 committer，查它会大量误报。

### 3. 拦截并向用户确认

命中且 AGENTS.md 无约定时，**不得执行 push**。向用户呈现：

- 检出几个名单外身份：逐一列出 `name <email>` 及各自提交数
- 明确询问选项：
  1. **允许任意贡献者推送**（我知晓并同意，这些身份都合理）
  2. **将检出身份加入「允许身份」名单后推送**（合法协作者 / 自己其他设备的身份）
  3. **统一改写为当前身份再推**（历史改写，需确认远端是否已含该历史 / 强推风险）
  4. **本次不推**
- 等用户答复后再行动；用户选 3 时给出或执行统一命令（`git filter-branch --env-filter 'export GIT_AUTHOR_NAME=… GIT_AUTHOR_EMAIL=… GIT_COMMITTER_NAME=… GIT_COMMITTER_EMAIL=…'`），并提示已推送需 `--force`。

### 4. 将决定写入 AGENTS.md 显著位置

无论用户选哪项（含"无漂移"场景），都在 `AGENTS.md` **文件顶部第一行标题之后、其余内容之前**插入：

```markdown
> ⚠️ **贡献者身份约定**（Author Identity Policy）：<用户决定>。
> 记录于 YYYY-MM-DD，触发场景：<push 对象 + 检出数量，不写具体身份>。
> 约定：<允许任意贡献者推送 | push 前必须统一作者 | 每次单独询问>。
> 允许身份：<name <email>>（可有多行，也可只写 email；无此行则仅当前 git config 身份合法）。
> 修改约定请直接编辑本行。
```

- AGENTS.md 不存在 → 创建并只含该约定块。
- 已有约定但用户本次变更 → 更新该行，不改其他内容。
- **防回泄（重要）**：检出详情只在对话中展示给用户，不得写入任何会被提交的内容。用户选「统一改写」或「本次不推」时，AGENTS.md 约定块与相关 commit message 只写"检出 N 个名单外作者，已统一/已处理"，绝不写被抹除/被拒的具体 `name <email>`——把刚抹掉的身份写进会提交的文件等于重新泄漏。仅当用户选「加入允许身份」时，该身份才可写入 `允许身份：` 行。
- 写入后告知用户："约定已记录，下次 push 将按此执行，不再询问"。

**注意**：`约定：` 行与 `允许身份：` 行是 `hooks/pre-push` 解析的关键字段，`约定：` 的三个枚举值须原样使用，不要改写措辞。

## 边界

- 只读/写 AGENTS.md（或等价指令文件），不动 git config、不擅自改写历史、不推送。
- 统一作者属于历史改写：必须先确认远端是否已含该历史，避免误伤协作者。
- 「允许身份」逐行记录具体 `name <email>`，换机器/换人后可追溯是谁。
- 若用户明确表示"本仓库永远允许多贡献者"，同样记录为约定，后续免问。
