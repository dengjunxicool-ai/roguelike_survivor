# Dev Tools 神系技能卡设计

## 背景

Dev Debug Tool 当前有独立的 `Skill Cards` 和 `Fire Skills` 分类。`Skill Cards` 主要显示运行时升级卡，`Fire Skills` 负责火系技能的调试链路。后续技能系统会扩展到六个神系，因此神系技能入口需要归并到 `Skill Cards` 页面内，避免每个神系都新增独立分类。

当前 `data/gods.json` 已定义六个神系，`data/skills.json` 当前只有火系 60 个技能。未实现技能数据的神系应显示明确空状态。

## 目标

1. 移除 Dev Tools 分类区里的独立 `Fire Skills` 按钮。
2. 在 `Skill Cards` 页面中加入六个神系按钮：火焰、雷霆、寒霜、诅咒、神圣、混沌。
3. 选择神系后，在按钮下方显示该神系技能卡。
4. 每张神系技能卡展示技能名称、技能描述、特效描述和技能效果。
5. 点击神系技能卡沿用现有火系技能调试链路：生成/选择技能卡、授予技能、生成目标、施放一次、观察粒子/伤害/跳字反馈。

## 非目标

1. 不实现火系以外神系的实际技能逻辑。
2. 不改变正式升级池的稀有度权重和可学习过滤。
3. 不重做 Runtime Skill Cards 的现有升级卡对比功能。

## UI 结构

`Skill Cards` 页面保留现有顶部按钮：

- `Refresh Cards`
- `Clear Skill Cards`
- `Clear Chart`

在现有升级对比图表和 Runtime Skill Cards 列表之间加入神系技能区。神系技能区包含：

- 一行六个按钮，按钮文本来自 `gods.json.display_name`，如果文本缺失则使用神系 id。
- 当前选中的神系按钮使用高亮状态。
- 一个神系技能卡滚动列表。
- 一个链路结果日志，复用当前 Fire Skills 的结果字段：选项生成、授予、目标生成、施放次数、伤害记录数、粒子数、跳字数。

## 数据流

1. DevDebugPanel 从 `data/gods.json` 读取神系列表。
2. DevDebugPanel 从 `data/skills.json` 读取技能列表。
3. 选择神系后，按 `skill.god_id == selected_god_id` 过滤技能。
4. 只展示 `offer_in_upgrade_pool == true` 的技能卡。
5. 当前火系技能调试仍通过 `UpgradePool.generate_debug_fire_skill_options(player, god_id)` 生成可点击调试选项。
6. 其他神系在没有技能数据时显示空状态：`No skill cards for this god yet.`

## 技能卡展示字段

每张神系技能卡展示：

- 技能名称：`display_name`，缺失时使用 `id`。
- 技能描述：`description`。
- 特效描述：`vfx_description`。
- 技能效果：优先读取 `effect_description`；如果数据中没有该字段，则用 `runtime_family`、`category`、`rarity`、`tags`、主要事件动作摘要生成一行简短效果说明。

## 交互行为

1. 默认选中第一个神系，当前应为火焰。
2. 点击神系按钮刷新下方技能卡列表。
3. 点击技能卡执行现有调试链路，相当于当前 `Fire Skills -> Run Chain` 的单卡版本。
4. 如果神系没有技能卡，列表显示空状态，按钮仍可选。
5. 如果某个非火系神系未来加入技能数据，调试入口无需改 UI 即可显示该神系卡片；实际施放是否成功由技能运行时实现决定。

## 错误处理

- `gods.json` 读取失败：显示六个内置 fallback 神系按钮。
- `skills.json` 读取失败：神系技能卡区域显示空状态和错误日志。
- 技能卡缺少展示字段：使用空字符串或 id fallback，不阻塞列表渲染。
- 调试链路失败：在链路日志中显示失败字段，不吞掉失败。

## 验证

1. 静态验证：
   - `Fire Skills` 分类按钮不再存在。
   - `Skill Cards` 页面包含六神按钮区域。
   - 神系技能卡从 `gods.json` 和 `skills.json` 驱动。
   - 卡片文本包含名称、描述、特效描述和技能效果字段。

2. Godot smoke：
   - Dev Tools 打开后 `Skill Cards` 页面存在六个神系按钮。
   - 选择火焰后至少显示 `mars_spark_missile` 技能卡。
   - 点击火系技能卡能完成选择技能卡、授予技能、施放、生效、粒子反馈、伤害记录和伤害跳字验证。
   - 选择暂无技能的神系时显示空状态，不报错。

## 自查

- 没有未定义的占位项。
- 设计只改 Dev Tools UI 和调试数据展示，不改变正式战斗平衡。
- 六神按钮是用户确认过的交互形式。
- 火系现有调试链路被复用，不重复造新链路。
