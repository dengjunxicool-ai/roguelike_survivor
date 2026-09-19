# 项目工程规范

日期：2026-06-27

本文档用于约束后续新增角色、技能、怪物、状态、装备、UI 和配置时的工程边界。目标不是为了形式化架构，而是让当前能运行的系统长期保持可维护。

## 目录规范

| 目录 | 职责 | 约束 |
| --- | --- | --- |
| `scenes/app/` | App 启动、主运行场景、自动流程场景 | 只放顶层组合场景，不放具体战斗逻辑 |
| `scenes/characters/` | 玩家/角色相关场景 | 场景挂载组件，逻辑放 `scripts/characters` 或 `scripts/player` |
| `scenes/combat/` | 投射物、区域、环绕物等战斗对象场景 | 场景只定义节点结构和表现默认值 |
| `scenes/enemies/` | 敌人、Boss、敌方投射物场景 | 具体行为由配置和 `scripts/enemies` 驱动 |
| `scenes/effects/` | 可实例化特效场景 | 不写业务规则，最多暴露 configure/setter |
| `scenes/drops/` | 掉落物场景 | 掉落规则不要写在场景脚本中 |
| `scenes/ui/` | UI 原型或复用场景 | 主 UI 当前多由脚本构建，新增页面优先走 UI 状态系统 |
| `scripts/core/` | 数据路径、JSON 加载、autoload 基础设施、元数据 key | 不依赖战斗、UI、怪物等上层系统 |
| `scripts/game/` | 单局编排、存档、结算、统计、进度服务 | 可以协调系统，但不要承载具体技能或怪物规则 |
| `scripts/characters/` | 角色定义、loadout、runtime、trait | 不直接操作 UI，不直接生成怪物或掉落 |
| `scripts/player/` | 玩家节点聚合根、移动、受击、升级入口 | 新功能优先拆到子系统，避免继续扩大 Player |
| `scripts/skills/` | 技能定义、实例、执行、事件、特殊规则、目标选择 | 技能通过配置和 action 表达，少写 ID 分支 |
| `scripts/combat/` | 伤害、状态、投射物、区域、伤害应用、反应 | 不直接处理 UI、奖励和存档 |
| `scripts/enemies/` | 怪物聚合根、行为、技能、生成、波次、死亡 | 新行为走 `behaviors/`，新动作走 registry |
| `scripts/upgrades/` | 局内升级和奖励选项生成 | 生成选项与应用效果分离 |
| `scripts/relics/` | 遗物、协同、局内遗物事件 | 遗物通过事件和 modifier 接入，不直接改 UI |
| `scripts/ui/` | UI 状态机、页面、HUD、弹窗、主题、文本 | UI 只展示状态或发命令，不直接改战斗内部状态 |
| `scripts/debug/` | 开发者面板、调试 overlay、系统检查 | 只用于开发期，不进入正式玩法依赖 |
| `scripts/visual/` | 视觉配置应用、通用视觉辅助 | 不写伤害、掉落、成长逻辑 |
| `data/characters/` | 角色和角色文本配置 | 角色 ID、起始技能、trait、基础属性 |
| `data/skills/` | 神系、起始技能、可学习技能 | 技能 ID、school、type、components、actions、offer_rule |
| `data/combat/` | 状态和通用战斗对象配置 | status/combat object 不直接引用 UI |
| `data/enemies/` | 怪物和敌方技能配置 | 新怪物优先配置化，必要时再扩 behavior/action |
| `data/waves/` | 波次、Boss 事件、奖励事件 | 不写具体技能公式 |
| `data/upgrades/` | 局内升级、诅咒、永久升级配置 | 应用入口仍回到 Player/SkillManager/ModifierStore |
| `data/relics/` | 遗物和协同配置 | 不重复写技能 action |
| `data/maps/` | 地图和背景/变量配置 | 地图机制通过 map runtime 或 spawner 服务接入 |
| `data/ui/` | UI theme 配置 | 不放玩法数值 |
| `data/localization/` | UI 文本 | UI 文案从这里或明确页面 view model 读取 |
| `resources/` | Shader、Material、可复用 Resource | 不放 JSON 数据 |
| `assets/` | 图片、音频等原始资源 | 资源路径被配置引用时必须有验证 |
| `tools/validate/` | 开发期配置校验 | 不依赖 Godot 运行时即可跑的检查放这里 |
| `tools/verify/` | 行为验证、headless 场景验证、契约测试 | 新系统或新 schema 必须补相应验证 |

## 命名规范

| 类型 | 规则 | 示例 |
| --- | --- | --- |
| GDScript 文件 | `snake_case.gd`，文件名表达职责 | `skill_action_executor.gd` |
| 场景文件 | `snake_case.tscn`，与挂载脚本或对象类型对应 | `fireball_projectile.tscn` |
| 配置文件 | 主题复数名或明确系统名 | `skills.json`、`status_effects.json` |
| 配置 ID | 小写 `snake_case`，全项目语义唯一 | `fire_attack_searing` |
| 角色 ID | 小写 `snake_case`，不要包含等级或临时标签 | `knight` |
| 技能 ID | `<school>_<type>_<effect>` 或已有神系约定 | `frost_attack_frostbite` |
| 状态 ID | 小写状态名，避免 UI 文案式命名 | `burning`、`frozen` |
| 怪物 ID | 小写 `snake_case`，普通、精英、Boss 可由字段表达 | `dungeon_heart` |
| UI 节点名 | `PascalCase`，表达用途 | `CharacterCardList` |
| 函数名 | 动词开头，私有函数 `_` 前缀 | `_build_level_up_upgrade_options` |
| signal | 过去式或事件名，携带必要上下文 | `boss_defeated`、`status_applied` |

不要在新增文件名、类名、配置 ID 中使用 `old`、`backup`、`temp`、`test`、`deprecated`。测试文件必须放在 `tools/verify/` 或明确的开发目录中。

## 系统边界规范

| 边界 | 规则 |
| --- | --- |
| UI -> 游戏逻辑 | UI 不直接修改血量、技能冷却、怪物列表、伤害配置。UI 只能调用公开命令入口或发出选择结果。 |
| 技能 -> UI | 技能不直接操作 UI 节点。需要展示时通过事件、统计或 HUD state provider。 |
| 技能 -> 伤害 | 技能构建 DamagePacket 或调用目标 `take_damage()`，不直接扣 `current_health`。 |
| 投射物/区域 -> 伤害 | 战斗对象只负责命中、tick、生命周期，伤害仍走 packet 和目标受击入口。 |
| 怪物 -> 掉落/经验 | 怪物死亡必须走 `EnemyDeathPipeline`/`EnemyRewardController`，不要在行为脚本里直接生成奖励。 |
| 状态 -> 技能事件 | 状态可通过 `SkillEventBus` 或状态管理器事件发射，不要直接调用具体技能 ID 分支。 |
| 配置 -> 运行逻辑 | JSON 不写脚本逻辑，只表达数据、action、trigger、引用和数值。 |
| 存档 -> UI | UI 可请求 SaveManager 服务，不直接写 `ConfigFile`。 |
| Debug -> Runtime | Debug 面板可调用公开开发入口，不应让正式 runtime 反向依赖 debug 脚本。 |
| 资源路径 | 新路径优先集中到配置或 DataPaths，避免到处 `load("res://...")`。 |

## 新增内容流程

### 新增角色

需要创建或修改：

- `data/characters/characters.json`
- 必要时修改 `data/characters/character_texts.json`
- 起始技能引用 `data/skills/skills.json.starting_skills`
- 必要时新增 trait 脚本到 `scripts/characters/traits/`

检查点：

- `id` 唯一。
- `starting_skill_id` 存在。
- 基础属性字段有默认值或被 `CharacterRuntime` 支持。
- trait 不直接操作 UI、怪物生成或奖励。
- 运行 `verify:character-select-ui`、`verify:map-select-ui` 和相关角色验证。

### 新增技能或神系词条

需要创建或修改：

- `data/skills/skills.json`
- 必要时修改 `data/skills/gods.json`
- 如需新 action，修改 `scripts/skills/skill_action_executor.gd` 或拆分后的 action executor
- 如需新特殊规则，修改 `scripts/skills/skill_special_rule_executor.gd` 或对应规则模块
- 同步 `tools/verify/` 契约测试

检查点：

- `id` 唯一，`school/type/tags/offer_rule` 清晰。
- 普通效果优先用已有 action 表达。
- 伤害使用 DamagePacket 语义，不写裸数值扣血。
- 状态引用必须存在于 `data/combat/status_effects.json`。
- 投射物/区域引用必须存在于对应场景或 combat object 配置。

### 新增怪物

需要创建或修改：

- `data/enemies/enemies.json`
- 必要时修改 `data/enemies/enemy_skills.json`
- 波次接入修改 `data/waves/waves.json`
- 新行为放 `scripts/enemies/behaviors/` 并注册到 behavior registry
- 新敌方 action 扩展 `scripts/enemies/actions/`

检查点：

- 怪物 ID 唯一。
- 掉落、经验、Boss/Elite 分类字段明确。
- 死亡奖励不绕过 `EnemyDeathPipeline`。
- 运行 `validate_enemy_configs` 和相关敌人运行时验证。

### 新增状态效果

需要创建或修改：

- `data/combat/status_effects.json`
- 如需新运行语义，修改 `scripts/combat/status_effect_manager.gd`
- 如涉及元素反应，检查 `ReactionLimiter`、`ReactionService`、`ReactionDamageBuilder`

检查点：

- `id` 唯一。
- duration、max_stack、tick_interval、damage、vulnerability 等字段语义明确。
- DOT 小数池需要稳定 source identity。
- max stack 行为必须有验证。

### 新增装备或遗物

当前项目没有正式 `data/equipment/` 运行时目录。新增装备前先确认它是：

- 局内遗物：放 `data/relics/relics.json`，通过 `RelicManager` 接入。
- 局内升级：放 `data/upgrades/upgrades.json`，通过 `Player.apply_upgrade()` 接入。
- 未来装备系统：先设计 `EquipmentConfig`，不要复活旧武器绑定系统。

检查点：

- 装备效果优先表达为 modifier、trigger_rule 或技能 action。
- 不直接改 UI 或敌人内部字段。
- 有最小验证覆盖获得、应用和结算展示。

### 新增 UI 页面

需要创建或修改：

- `scripts/ui/ui_state_registry.gd`
- `scripts/ui/ui_screen_registry.gd`
- `scripts/ui/ui_state_prepare_router.gd`
- `scripts/ui/ui_pause_policy.gd`
- 新 controller 放 `scripts/ui/screens/`
- 必要时新增 view model builder

检查点：

- 页面状态能从允许状态跳转进入。
- pause 规则明确。
- UI 只发命令或展示 view model。
- 新页面有 headless UI 验证。

## 禁止事项

- 不要在 Manager 或聚合根里继续塞不相关逻辑。
- 不要在 UI 脚本里直接修改战斗数值、血量、怪物列表或技能实例内部字段。
- 不要在技能脚本里直接生成 UI 或写存档。
- 不要在怪物行为脚本里直接处理经验、掉落、结算或胜利。
- 不要绕过 `take_damage()`、`DamageApplicationService` 或死亡 pipeline。
- 不要用裸字符串路径到处 `load()` 新资源；路径必须可验证。
- 不要为每个怪物复制一套伤害逻辑。
- 不要为每个技能写 ID 专属硬分支，除非已有通用 action 无法表达并且有验证。
- 不要把配置数据和运行时可变状态混在同一个 Dictionary 里长期持有。
- 不要删除疑似废弃代码，除非已有无引用、无调用、已替代的明确证据。

## 推荐开发流程

### 新功能

1. 先判断归属系统和数据入口。
2. 先改配置和最小验证。
3. 再改运行时公开入口或专用服务。
4. 跑对应 `tools/validate` 和 `tools/verify`。
5. 更新系统文档或本规范中对应新增流程。

### 重构

1. 先确认现有验证能覆盖目标行为。
2. 保持外部 API、节点名、配置 ID 不变。
3. 每次只拆一个职责。
4. 拆完先跑局部验证，再跑相关全量验证。
5. 高风险系统必须保留回滚路径。

### 删除代码

1. 先证明无引用、无调用、无配置引用、无场景引用。
2. 对不确定项标记为疑似废弃，不删除。
3. 删除前后都跑路径扫描和相关验证。
4. 删除报告必须写清依据和回滚方式。

### 新增资源

1. 放到对应 `assets/`、`resources/` 或 `scenes/` 主题目录。
2. 不确定视觉资源可用 `res://icon.svg` 临时兜底，但必须在备注中标出。
3. 配置中引用路径后运行路径存在性验证。
4. 新特效场景必须有最小 runtime instantiate 验证。

### 修改配置

1. 修改前确认由哪个系统消费。
2. 新配置路径先登记到 `DataPaths`。
3. 正常运行数据由 `DataManager` 加载、索引并通过深拷贝 accessor 输出。
4. `GameData` 作为稳定门面优先委托给 `DataManager`；兼容 fallback 在迁移证据充分前保留。
5. 每个数据域必须验证 manager、facade 与 fallback 的 ID、顺序、字段和值一致。
6. validator 和文档必须与真实读取路径同步。
7. 数值或 schema 变化不得混入读取路径重构；schema 变更必须另附迁移说明。

### 上线前检查

```powershell
node tools/validate/check_text_encoding.js
node tools/validate/validate_enemy_configs.js
node tools/validate/validate_modifier_effects.js
npm run verify:coverage-report
```

涉及核心系统时还要跑对应 `package.json` 中的 `verify:*` 脚本。合并前至少保证本次影响范围内的 Godot headless 验证通过。

### Windows 受控沙箱运行说明

Godot 4.6.3 在当前 Windows 受控沙箱中存在已复现的子进程兼容性问题：经 `npm`、Node.js、Python、`cmd /c` 或二级 PowerShell 启动 Godot 时，可能在 headless 初始化早期以 `signal 11` / `0xC0000005` 崩溃。该现象在未显式指定 `--path` 并使用 `--disable-file-logging` 的最小 headless 命令中仍可发生；同一 Godot 命令直接启动正常，同一 npm 命令在沙箱外也正常，因此不能仅凭该崩溃认定项目代码回归。

受控沙箱中的验证流程：

1. 从 `package.json` 读取目标 `verify:*` 的 Godot 参数。
2. 在沙箱内直接调用 Godot 可执行文件，保持原工作目录、参数和验证入口不变。
3. 如果本次目标包含 npm 包装入口本身，则在获得所需授权后，于沙箱外复跑完全相同的 npm 命令。
4. 沙箱内二级启动崩溃只记录为环境兼容性失败，不作为业务测试结果；直接调用或沙箱外复核仍失败时，才进入项目回归诊断。
5. 不得通过跳过测试、删除断言、放宽阈值或修改生产逻辑规避该问题。

普通本地终端和 CI 不受此规则影响，仍以 `package.json` 中的 `npm run verify:*` 作为标准入口。

## 后续工程化优先级

1. 统一内容校验工具：检查重复 ID、引用存在、路径存在、非法数值、空字段。
2. Debug 面板页面拆分：降低 2882 行开发工具文件的维护成本。
3. SkillActionExecutor action family 拆分：先拆 projectile/area/status/summon 的构建和执行辅助。
4. UpgradePool learn skill builder 拆分：降低新增神系和技能时的耦合。
5. DataManager/GameData 读取路径收口：Stage 5A 先收口状态池，其余数据域继续按契约测试逐项迁移。
6. StatusEffectManager 小步拆分：把 tick、查询、事件发射分离。
7. 最后才处理 DamageSystem、EnemyBase、EnemySpawner 的深层行为重构。
