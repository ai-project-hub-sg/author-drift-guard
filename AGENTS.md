# author-drift-guard

> ⚠️ **贡献者身份约定**（Author Identity Policy）
> 记录于 2026-11-22。
> 约定：每次单独询问
> 修改约定请直接编辑本行。

## 项目说明

- 双层守卫：`skill/author-drift-guard/SKILL.md`（agent 行为层）+ `hooks/pre-push`（git 强制层）。
- 场景：同一设备/项目中前后贡献者不同（换 git config、多人共用、cherry-pick、bot 代提交），push 时检出名单外作者即提醒是否知情。
- 合法身份 = 当前 `git config user.name/user.email` + 每行 `允许身份：name <email>`（也可只写 email）。只查 author，不查 committer。
- 安装：`install.ps1`（junction 挂载技能、`-Repo` 装钩子）；`install.sh` 等价。
- 约定解析字段为 `约定：<允许任意贡献者推送|push 前必须统一作者|每次单独询问>`；`允许身份：` 每行一个。修改 SKILL.md 说明文本时勿改动此枚举措辞。

姊妹项目：`../ai-signature-guard`（防 AI 署名泄漏，同一套双层结构）。
