# 整体游戏 QA 修复计划

> 按 superpowers:executing-plans 在当前会话逐项执行，先失败回归，再最小修复与复测。

**Goal:** 修复问题清单 QA01 至 QA10，并修复外部自动采样的退出码误判。

**Architecture:** 沿用现有事件总线、技能替换事务、ModifierStore、页面控制器及结算服务。升级应用返回真实成功结果；奖励等待替换时不提交其他效果，确认后才消费。奖励保底以最终可见候选为准，语言切换刷新已创建的支持翻译的控件。

**Tech Stack:** Godot 4.6 GDScript、JSON 内容、PowerShell、Node 内容校验。

**Spec:** `docs/qa/整体游戏问题修复清单.md`，用户已要求执行其中修复。

## 全局约束

- 不写 C 盘；所有缓存、存档、执行日志在 `E:/codex/game-qa-fix-20261011`。
- 当前新建修复分支 `fix/game-qa-20261011`；保留既有未跟踪问题文档。
- 不修改技能槽容量、品质规则和波次难度。QA06 保留实际护甲效果，修正文案；QA04 用合法的 Boss 作用域升级分别补强输出及 DOT 与反应。
- 不将辅助胜利及自动驾驶样本声明为真人平衡或完整 Boss 体验验收。

## 审查重点

失效来源和失效目标、重复点击与取消、部分奖励提交、目标及伤害来源作用域、语言切换保留控件状态和实际持久化。对应测试覆盖在以下任务中。

## 任务 1 QA01 事件上下文

文件：`scripts/skills/skill_event_context.gd`；测试 `tools/verify/verify_qa_event_lifetime.gd`。

- [x] 用真实 AreaEffect 跳伤释放来源，并测试已释放 target 及嵌套快照，观察基线错误。
- [x] 在首次对象类型转换前清理失效引用，保留原输入与来源数值。
- [x] 隔离运行测试，要求事件派发成功、无脚本错误。

## 任务 2 QA02 QA03 选择事务

文件：`player_controller.gd`、`ui_command_dispatcher.gd`、`run_choice_modal_controller.gd`、`skill_replacement_view.gd`；测试 `verify_qa_choice_transactions.gd`。

- [x] 真实启动场景复现满槽奖励、普通替换鼠标穿透和取消。
- [x] `Player.apply_upgrade(StringName) -> bool` 提供应用成功；奖励共用普通升级替换检查并返回等待或失败。
- [x] 确认后提交奖励副作用及统计、再消费队列；模态阻挡输入、防重复创建，清理过期窗口与事务。
- [x] 真实鼠标测试确认、取消和无效复合奖励不部分提交，要求无吞卡和遗留窗口。

## 任务 3 QA04 QA05 QA06 奖励定义

文件：`run_reward_pool.gd`、`data/upgrades/upgrades.json`；测试 `verify_qa_rewards.gd`，注册内容校验。

- [x] 测基线缺失 Boss 升级、100 种子保底及护甲文案不符。
- [x] 配置合法、有限且不进入普通随机池的 Boss 输出与状态补强；按目标和来源作用域验证。
- [x] 最终三张卡执行保底，护甲卡统一名称与说明，最大等级不生成不可应用候选。
- [x] 要求种子回归与边界成立、所有生成引用有效、实际伤害加成只影响规定范围。

## 任务 4 QA07 QA08 设置和输入

文件：设置控制器、UIManager/标题控制器的翻译刷新、`project.godot`；测试 `verify_qa_settings_input.gd`。

- [x] 真实场景切英文并核对现有及随后页面；检查四个方向移动动作和玩家输入。
- [x] 刷新现有可翻译控件并保留设置值；添加方向键移动绑定。
- [x] 中文英文往返、重新进入设置、实际移动与松键、菜单行为通过。

## 任务 5 QA09 QA10 结算

文件：`run_progression_service.gd`；测试 `verify_qa_progression.gd`。

- [x] 生产 tracker 100% DOT、35% 边界、失败和零伤害；早到 Boss 与长时间未到 Boss。
- [x] 使用 `status_dot` 常量，并仅在现键缺失时兼容旧 `dot`；Boss 标志取实际阶段统计或胜利。
- [x] 验证保存后重新读取、计数与原辅助全流程。

## 任务 6 工具与最终验证

- [x] 修复外部 `run_matrix.ps1` 的退出码传播，错误/缺结果/超时不得通过。
- [x] 将新增断言注册到 package 验证命令，重跑全套回归。
- [x] 复跑原诊断、5 个原报错组合、辅助胜利及实际渲染选择/设置截图。
- [x] 更新问题清单状态与修复验收记录，保留原始报告作为历史证据。

执行日志与逐项状态保存在 `E:/codex/game-qa-fix-20261011/progress.md`。修复后保持可审查本地改动，不自动发布或合并。
