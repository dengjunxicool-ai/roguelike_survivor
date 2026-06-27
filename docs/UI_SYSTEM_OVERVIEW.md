# UI System Overview

更新日期：2026-06-13

本文档是后续改造项目 UI 的主入口。目标不是记录某一次改动，而是让每个 UI 相关功能都能快速定位、低风险修改，并且不反向影响战斗、数据、存档和运行场景。

当前 UI 的总原则：

- `UIManager` 只作为顶层门面，负责装配、转发、跨屏上下文和运行场景调度。
- UI 状态流统一走 `UIManager.transition_to()`。
- 子屏幕只发信号或 UI command，不主动查找其他屏幕，不直接切换其他屏幕。
- 展示数据优先由 ViewModel builder 汇总，controller 只构建节点、渲染字段、发出用户意图。
- 涉及存档、奖励、升级、解锁、运行统计的副作用，优先走 `UICommandDispatcher`、`ResultUnlockService` 或运行时 service。
- 新 UI 改动完成后必须跑当前存在的 UI smoke（至少 `tools/verify/verify_title_screen_runtime.gd`、`tools/verify/verify_character_select_ui.gd`，涉及地图页时加 `tools/verify/verify_map_select_ui.gd`），涉及运行中 UI 时还要人工走完整战斗链路。

## 0. 快速定位地图

后续接到任何 UI 需求时，先按这个表定位，不要从 `UIManager` 里硬找：

| 需求类型 | 第一入口 | 常见第二入口 | 不要碰/少碰 |
| --- | --- | --- | --- |
| 新增/修改页面 | `scripts/ui/screens/*_controller.gd` | `*_view_model_builder.gd`、`UIStateRegistry`、`UIStatePrepareRouter` | 不要让页面直接启动战斗或找其他页面 |
| 新增状态流 | `scripts/ui/ui_state_registry.gd` | `scripts/ui/ui_state_prepare_router.gd`、`scripts/ui/ui_manager.gd` 的 `_build_xxx()` | 不要绕过 `UIManager.transition_to()` |
| 运行中弹窗 | `scripts/ui/modals/modal_flow_controller.gd` | `scripts/ui/modals/run_choice_modal_controller.gd`、`scripts/ui/ui_state_registry.gd` | 不要让弹窗自己控制 pause |
| HUD 字段/布局 | `scripts/ui/hud/run_hud_state_provider.gd` | `scripts/ui/hud/run_hud_controller.gd`、`RunSceneUIBridge` | 不要把 HUD 数据拼回 `UIManager._process()` |
| 角色选择 | `CharacterLoadoutViewModelBuilder` | `CharacterLoadoutController`、`CharacterLoadoutText`、`CharacterLoadoutService` | 不要在 controller 复制解锁/起始技能规则 |
| 地图选择 | `MapSelectViewModelBuilder` | `MapSelectController`、`MapRuntime`、`data/maps.json` | 不要在地图页实例化战斗场景 |
| 结算页 | `ResultScreenViewModelBuilder` | `RunResultStateBuilder`、`ResultUnlockService`、`RunDiagnosticService` | 不要在结果页 controller 直接写存档 |
| 奖励/购买/升级副作用 | `UICommand` + `UICommandDispatcher` | 独立 service 或 `SaveManager`/运行时对象 | 不要把副作用写在按钮回调里 |
| 主题/按钮/卡牌样式 | `data/ui/ui_theme.json` | `UIThemeService`、`UIButtonSkin` | 不要为每个按钮手写一套 stylebox |
| 文案/语言 | `data/localization/ui_text.json` | `LocalizationService`、`UISettingsService` | 不要新增无 fallback 的硬编码 UI 文案 |
| 响应式/小屏 | `UIResponsiveLayout` | 页面 controller 的 `update_layout()` | 不要散落自定义断点 |
| 启动/运行场景生命周期 | `RunSceneCoordinator` | `UIManager._start_run()`、`_teardown_run_scene()` | 不要让普通 screen 管理 `main.tscn` |

优先级判断：

1. 能在 ViewModel builder 解决的展示问题，不改 controller。
2. 能在 command/service 解决的副作用问题，不改点击回调。
3. 能在 state descriptor 解决的暂停/可见性/跳转问题，不写特殊分支。
4. 只有跨屏上下文、顶层状态切换、运行场景启动清理，才留在 `UIManager`。

## 1. 当前完成度

| 分项 | 当前状态 | 完成度 |
| --- | --- | ---: |
| UI 状态收口 | `UIManager.transition_to()` 是统一入口，状态合法性由 `UIStateMachine` / `UIStateRegistry` 判断 | 100% |
| 状态 descriptor | `UIStateDescriptor` 已承载 `allowed_to`、running child、fullscreen choice、pause mode、build method、prepare method | 100% |
| 屏幕注册与显示 | `UIScreenRegistry` 保存状态到节点映射，`UIScreenHost` 统一显示隐藏和 HUD 可见性 | 100% |
| 暂停策略 | `UIPausePolicy` 根据 state descriptor 控制 `get_tree().paused` | 100% |
| 运行场景桥接 | `RunSceneUIBridge` 负责连接玩家、刷怪器、敌人死亡等运行时信号 | 90% |
| HUD 状态 | `RunHudStateProvider` 统一采集 HUD Dictionary，`RunHudController` 消费它刷新节点 | 85% |
| 运行中弹窗 | `ModalFlowController` 统一弹窗刷新、pending 检查和 `ModalRequest` 队列 | 90% |
| UI 副作用命令 | `UICommand` + `UICommandDispatcher` 已覆盖升级/奖励、局外升级、角色购买、调试加魂石 | 85% |
| 结算解锁副作用 | `ResultUnlockService` 已从结果页迁出解锁写存档逻辑 | 95% |
| 主要页面 ViewModel | 角色、地图、局外升级、图鉴、结算已接入 builder | 90% |
| 主题系统 | `UIThemeService` 和 `data/ui/ui_theme.json.tokens` 已有，按钮和选择卡背景已接入 | 70% |
| 本地化 | `LocalizationService` 已接入标题页、设置页、主面板标题和弹窗标题 | 65% |
| 响应式布局 | `UIResponsiveLayout` 已有 scale、breakpoint、compact 和 panel layout | 75% |
| 自动验证 | 标题页、角色选择、地图选择等 UI smoke 覆盖主要入口；完整架构断言需随新状态补对应验证 | 80% |

整体判断：

- 架构拆分分项：100%。
- 可持续 UI 改造能力：约 85%。
- 产品级 UI 完成度：约 80%，剩余主要是视觉主题迁移、本地化全量迁移、复杂页面 compact polish 和完整战斗人工验证。

## 2. 启动与运行层级

启动入口：

- `project.godot` 的 `run/main_scene` 指向 `res://scenes/app_bootstrap.tscn`。
- `app_bootstrap.tscn` 只挂载 `UIManager`，实例来自 `res://scenes/ui/ui_prototype.tscn`。
- `ui_prototype.tscn` 是薄场景，只声明 `CanvasLayer` 和 `scripts/ui/ui_manager.gd`。
- 战斗主场景 `res://scenes/main.tscn` 不在启动时常驻，而是在 `UIManager._start_run()` 中通过 `RunSceneCoordinator.start_run()` 动态实例化到 `AppBootstrap` 下。

运行时层级：

```text
AppBootstrap
  UIManager(CanvasLayer, layer 200)
  Main(Node2D, run scene, dynamic)
    Player
    EnemySpawner
    DevDebugPanel(CanvasLayer)
```

关键约束：

- 菜单 UI 和运行场景生命周期解耦。
- 返回标题页、进入角色选择、进入局外升级时会清理运行场景。
- 战斗中 HUD 是独立 `CanvasLayer`，layer 199，低于 `UIManager` layer 200。

## 2.1 关键链路速查

### 启动到标题页

```text
project.godot run/main_scene
  -> scenes/app_bootstrap.tscn
  -> scenes/ui/ui_prototype.tscn
  -> UIManager._ready()
  -> _build_screens()
  -> transition_to(BOOT)
  -> _finish_boot()
  -> transition_to(TITLE)
```

风险点：

- `UIManager._ready()` 会创建所有常驻 screen，新增状态但忘记注册 build order 会导致启动验证失败。
- `TITLE` 的输入只在 `UIManager._input()` 中转发给 `TitleScreenController.handle_input()`。

### 角色到地图到开局

```text
TitleScreenController.state_requested(CHARACTER_SELECT)
  -> UIManager.transition_to(CHARACTER_SELECT)
  -> CharacterLoadoutController.refresh(selected_character_id)
  -> loadout_confirmed(character_id)
  -> UIManager._on_loadout_confirmed()
  -> transition_to(MAP_SELECT)
  -> MapSelectController.refresh(character_id)
  -> start_requested(map_id)
  -> UIManager._start_run(map_id)
  -> CharacterLoadoutService.build_loadout()
  -> RunSceneCoordinator.start_run()
  -> transition_to(RUNNING)
```

风险点：

- 角色选择只保存 `character_id`，真正运行时上下文要通过 `RunLoadout` 传入，不要恢复旧的散字段传参。
- 地图页只发 `start_requested(map_id)`，战斗场景实例化必须留在 `UIManager._start_run()` / `RunSceneCoordinator`。

### 运行时信号到 HUD/弹窗/结算

```text
RunSceneCoordinator.start_run()
  -> main.tscn 动态挂到 AppBootstrap
  -> UIManager._connect_runtime_sources()
  -> RunSceneUIBridge.connect_runtime_sources()
  -> player/spawner signals
  -> UIManager callbacks
  -> RunHudStateProvider.build()
  -> RunHudController.update()
```

运行中弹窗：

```text
player.leveled_up 或 timeline reward
  -> UIManager callback
  -> RunChoiceModalController pending / ModalFlowController queue
  -> transition_to(LEVEL_UP_MODAL/RUN_REWARD_MODAL/...)
  -> UIStateRegistry descriptor 决定 pause 与 HUD 可见性
  -> RunChoiceModalController refresh_xxx()
  -> UICommandDispatcher.dispatch()
  -> transition_to(RUNNING)
```

结算：

```text
player.died / spawner.boss_defeated / pause give up
  -> transition_to(RESULT_DEFEAT/RESULT_VICTORY)
  -> RunProgressionService.record_run_result()
  -> RunResultStateBuilder.build_result_state()
  -> ResultUnlockService
  -> ResultScreenViewModelBuilder
  -> ResultScreenController.refresh()
```

风险点：

- `RunSceneUIBridge` 只负责连接信号，不放业务。
- HUD 数据统一由 `RunHudStateProvider` 汇总，HUD 节点只消费字典。
- 结算页展示、进度记录、解锁、副作用是四条边界，别合回一个 controller。

## 3. 状态系统

### 状态列表

| State | 内容 | 构建入口 | 进入状态准备 |
| --- | --- | --- | --- |
| `BOOT` | 加载占位 | `UIManager._build_boot()` | 无 |
| `TITLE` | 标题页和主菜单 | `TitleScreenController` | `_reset_title_screen()`，并清理运行场景 |
| `CHARACTER_SELECT` | 角色选择 | `CharacterLoadoutController` | `_refresh_character_select_screen()`，并清理运行场景 |
| `MAP_SELECT` | 地图选择和战斗准备 | `MapSelectController` | `_refresh_map_select_screen()` |
| `RUNNING` | 战斗 HUD | `RunHudController` | 连接运行时信号，更新 HUD，检查 pending modal |
| `LEVEL_UP_MODAL` | 升级三选一 | `RunChoiceModalController` | `refresh_level_up_modal()` |
| `RUN_REWARD_MODAL` | 精英/Boss 奖励 | `RunChoiceModalController` | `refresh_reward_modal()` |
| `CURSE_CHOICE_MODAL` | 诅咒选择 | `RunChoiceModalController` | `refresh_curse_choice_modal()` |
| `PAUSE_MENU` | 暂停菜单 | `UIManager._build_pause_menu()` | 无 |
| `RESULT_DEFEAT` | 失败结算 | `ResultScreenController` | `_refresh_result_screen(state)` |
| `RESULT_VICTORY` | 胜利结算 | `ResultScreenController` | `_refresh_result_screen(state)` |
| `META_UPGRADE` | 局外升级 | `MetaUpgradeController` | `_refresh_meta_upgrade_screen()`，并清理运行场景 |
| `CODEX` | 图鉴 | `CodexScreenController` | 清理运行场景 |
| `SETTINGS` | 设置 | `SettingsScreenController` | 清理运行场景 |
| `DEVELOPER_MODE` | 开发者直入战斗 | `UIManager.start_developer_debug_run()` | 特例，不注册为普通 screen |

### 迁移规则

迁移定义集中在 `scripts/ui/ui_state_registry.gd`。

当前关键迁移：

- `BOOT -> TITLE`
- `TITLE -> CHARACTER_SELECT / META_UPGRADE / CODEX / SETTINGS`
- `CHARACTER_SELECT -> MAP_SELECT / TITLE`
- `MAP_SELECT -> RUNNING / CHARACTER_SELECT`
- `RUNNING -> LEVEL_UP_MODAL / RUN_REWARD_MODAL / CURSE_CHOICE_MODAL / PAUSE_MENU / RESULT_DEFEAT / RESULT_VICTORY / TITLE`
- running child modal 可回到 `RUNNING`，也可进入 `TITLE`、`CHARACTER_SELECT`、`META_UPGRADE`、结算页。
- `META_UPGRADE / CODEX / SETTINGS -> TITLE`

维护规则：

- 新状态先改 `UIStateRegistry._register_defaults()`，补 descriptor。
- descriptor 至少写 `id`、`allowed_to`、`build_method`、`pause_mode`。
- 需要进入状态刷新数据时，补 `prepare_method` 并在 `UIStatePrepareRouter` 中实现。
- 运行中 overlay 要判断是否 `is_running_child`。
- 全屏选择类弹窗要判断是否 `is_fullscreen_choice`，它会隐藏 HUD。
- 不要在 controller 内直接调用其他 controller 或其他 screen。

### 可见性与暂停

可见性由 `UIScreenHost.apply_visible_hierarchy(state)` 统一处理：

- 非 running child：隐藏全部 screen，只显示当前 screen。
- running child：默认保留 `RUNNING` HUD，同时显示 child screen。
- fullscreen choice：隐藏 `RUNNING` HUD，只显示选择弹窗。

暂停由 `UIPausePolicy.apply(tree, state_registry, state)` 统一处理：

- `RUNNING` 的 `pause_mode` 是 running，不暂停。
- 其他状态默认 pause。
- 新 running overlay 如果不应暂停，必须在 descriptor 中显式声明 `pause_mode = "running"`。

## 4. UIManager 当前职责边界

位置：`scripts/ui/ui_manager.gd`

`UIManager` 仍然是顶层门面，当前承担：

- 初始化状态机、屏幕 host、窗口/音量/语言设置。
- 构建所有常驻菜单屏幕和运行中弹窗。
- 保存跨屏上下文：角色、地图、运行统计、波次、结算缓存。
- 调用 `RunSceneCoordinator.start_run()` 和 `teardown()`。
- 将运行时信号连接交给 `RunSceneUIBridge`。
- 将 HUD 数据构建交给 `RunHudStateProvider`。
- 将结算状态汇总交给 `RunResultStateBuilder`。
- 将结算解锁副作用交给 `ResultUnlockService`。

后续改造时，不要继续扩大 `UIManager`：

- 新页面逻辑放到 `scripts/ui/screens/*_controller.gd`。
- 新页面数据汇总放到 `*_view_model_builder.gd`。
- 新运行时信号连接放到 `RunSceneUIBridge` 或运行场景 service。
- 新 HUD 字段放到 `RunHudStateProvider`。
- 新奖励/升级/购买/解锁副作用放到 `UICommandDispatcher` 或独立 service。
- 新状态策略放到 `UIStateRegistry` descriptor。

可以保留在 `UIManager` 的内容：

- 跨屏选择上下文。
- 顶层状态切换。
- 运行场景启动/清理。
- 简单 panel screen 的装配。
- 与运行场景相关的最薄事件转发。

## 5. 屏幕控制器

### TitleScreenController

位置：`scripts/ui/screens/title_screen_controller.gd`

职责：

- 构建标题页、按任意键展开主菜单。
- 发出 `state_requested(state)` 和 `quit_requested`。
- 使用 `LocalizationService` 读取标题页和菜单文案。

改造入口：

- 主菜单按钮：`_build_action_menu()`
- 标题布局：`build()`、`update_layout()`
- 文案：`data/localization/ui_text.json`

边界：

- 输入由 `UIManager._input()` 只在 `TITLE` 状态转发。
- 不直接调用 `UIManager` 以外的业务对象。

### CharacterLoadoutController

位置：`scripts/ui/screens/character_loadout_controller.gd`

职责：

- 角色轮播、详情面板、角色购买、出发确认。
- 渲染 `CharacterLoadoutViewModelBuilder` 的输出。
- 购买角色走 `UICommandDispatcher.purchase_character()`。
- 出发只发 `loadout_confirmed(character_id)`。

数据入口：

- `CharacterLoadoutViewModelBuilder`
- `CharacterLoadoutText`
- `CharacterLoadoutService`
- `UIDisplayHelper`
- `GameData` 和 `SaveManager` 只应优先在 builder/service/text helper 内消费。

改造入口：

- 布局常量：文件顶部常量。
- 角色卡：`_add_character_card()`
- 详情字段：`CharacterLoadoutViewModelBuilder._build_character_details()`
- 购买/出发按钮状态：`CharacterLoadoutViewModelBuilder._build_action()`

边界：

- 不在 controller 中复制角色解锁规则。
- 不在 controller 中硬编码某个角色起始技能。
- 新增详情字段先扩展 ViewModel，再渲染。

### MapSelectController

位置：`scripts/ui/screens/map_select_controller.gd`

职责：

- 地图列表、预览、敌人预览、地图详情、loadout 摘要、开始按钮。
- 渲染 `MapSelectViewModelBuilder` 的输出。
- 开始战斗只发 `start_requested(map_id)`。

数据入口：

- `MapSelectViewModelBuilder`
- `MapRuntime`
- `GameData`
- `SaveManager`

改造入口：

- 地图卡：`_refresh_map_cards()`、`_add_map_card()`
- 地图详情：`_refresh_selected_map_details()`
- 敌人预览：`_refresh_enemy_preview()`
- 开始按钮：`MapSelectViewModelBuilder` 的 `start_button`
- 地图配置：`data/maps.json`

边界：

- 不在开始按钮中实例化战斗场景。
- 运行场景启动只走 `UIManager._start_run()`。
- 地图背景应用在 `RunSceneCoordinator.start_run()` 中处理。

### RunHudController

位置：

- `scripts/ui/hud/run_hud_controller.gd`
- `scripts/ui/hud/run_hud_state_provider.gd`

职责：

- `RunHudController` 构建并刷新 HUD 节点。
- `RunHudStateProvider` 从 SceneTree、player、boss、RunStatsTracker 采集 HUD Dictionary。
- HUD 不应自己到处连接运行时信号。

已覆盖模块：

- 玩家血条、等级、状态摘要。
- Boss 血条。
- 计时器、波次、击杀、资源。
- 当前起始技能和主动技能等级。
- 经验条。
- 公告和提示。
- debug 统计。

改造入口：

- 新 HUD 字段：先改 `RunHudStateProvider.build()`。
- 新 HUD 节点：再改 `RunHudController._build_xxx()`。
- 更新逻辑：最后改 `RunHudController._update_xxx()`。
- 公告：`UIManager._show_announcement()` -> `RunHudController.show_announcement()`。

边界：

- HUD 字段不要直接写进 `UIManager._process()`。
- HUD controller 尽量只消费 ViewModel 字段。
- 复杂小屏布局还需要人工检查。

### RunChoiceModalController

位置：

- `scripts/ui/modals/run_choice_modal_controller.gd`
- `scripts/ui/modals/modal_flow_controller.gd`
- `scripts/ui/modals/modal_request.gd`

职责：

- 管理升级、奖励、诅咒选择的渲染。
- 维护旧的 `pending_level_up_count` 和 `pending_reward_kinds`。
- `ModalFlowController` 负责状态到刷新函数的映射和 `ModalRequest` 队列。
- 选择后通过 `UICommandDispatcher.apply_choice_option()` 应用副作用，再请求回到目标状态。

改造入口：

- 卡牌布局：`RunChoiceModalController._add_upgrade_choice_card()`。
- 卡牌尺寸：`CARD_DESIGN_SIZE`、`CARD_COMPACT_SIZE`。
- 选项标题/效果：`_get_option_title()`、`_get_option_effect_text()`。
- 背景图：选项 `background_texture` / `card_background_texture`，否则 `data/ui/ui_theme.json.choice_cards.default_background_texture`。
- 新弹窗优先通过 `ModalFlowController.request_modal()`。

边界：

- 新奖励副作用不要写到卡牌点击回调里。
- 新副作用先补 `UICommand` 构造函数，再补 `UICommandDispatcher` handler。
- 新运行中弹窗需要同步补 `UIStateRegistry` descriptor。

### ResultScreenController

位置：

- `scripts/ui/screens/result_screen_controller.gd`
- `scripts/ui/screens/result_screen_view_model_builder.gd`
- `scripts/ui/result_unlock_service.gd`
- `scripts/ui/run_result_state_builder.gd`

职责：

- 结果页构建和渲染。
- 结算展示标签由 `ResultScreenViewModelBuilder` 生成。
- 运行结果上下文由 `RunResultStateBuilder` 生成。
- 解锁副作用由 `ResultUnlockService` 执行并缓存。

改造入口：

- 展示字段：`ResultScreenViewModelBuilder.build()`。
- 运行数据汇总：`RunResultStateBuilder.build_result_state()`。
- 诊断和推荐：`RunDiagnosticService`。
- 解锁规则：`ResultUnlockService`。
- 按钮入口：`ResultScreenController.build()`。

边界：

- 不要在结果页 controller 里直接写存档解锁。
- 推荐配装只发 `recommended_loadout_requested()`，由 `UIManager` 应用跨屏选择。

### MetaUpgradeController

位置：

- `scripts/ui/screens/meta_upgrade_controller.gd`
- `scripts/ui/screens/meta_upgrade_view_model_builder.gd`

职责：

- 局外升级列表和购买按钮。
- 展示数据来自 `MetaUpgradeViewModelBuilder`。
- 购买走 `UICommandDispatcher.purchase_meta_upgrade()`。
- debug 加魂石走 `UICommandDispatcher.add_soul_stones()`。

边界：

- 不要在 controller 里直接调用 `SaveManager.purchase_permanent_upgrade()`。
- 新增升级展示字段先改 builder。

### CodexScreenController

位置：

- `scripts/ui/screens/codex_screen_controller.gd`
- `scripts/ui/screens/codex_view_model_builder.gd`

职责：

- 用 `TabContainer` 展示角色、技能、怪物、状态、遗物等资料。
- 展示数据由 `CodexViewModelBuilder` 汇总。
- 解锁类资料受 `SaveManager.is_unlocked(...)` 控制。

边界：

- 新增图鉴分类先改 builder。
- 排序、筛选、锁定状态都应进入 ViewModel，不要散在 UI 节点构建逻辑里。

### SettingsScreenController

位置：

- `scripts/ui/screens/settings_screen_controller.gd`
- `scripts/ui/ui_settings_service.gd`
- `scripts/ui/localization_service.gd`

职责：

- 主音量、全屏、语言选择、控制说明。
- 读写 `SaveManager` 的 `settings` section。
- 应用逻辑委托给 `UISettingsService`。
- 语言选项来自 `LocalizationService.get_language_options()`。

边界：

- 新设置项如果有副作用，优先加到 `UISettingsService`。
- 新文案优先进入 `data/localization/ui_text.json`。

## 6. 共享基础设施

| 模块 | 文件 | 用途 | 后续优先改法 |
| --- | --- | --- | --- |
| `UIScreenFactory` | `scripts/ui/ui_screen_factory.gd` | 创建全屏 screen 和通用 panel screen | 简单页面优先复用 |
| `UINodeFactory` | `scripts/ui/ui_node_factory.gd` | 快速创建 Label、Button、Scroll、VBox、HBox、ProgressBar | 简单页面通用节点优先复用 |
| `UIButtonSkin` | `scripts/ui/ui_button_skin.gd` | 从 `UIThemeService` 读取按钮主题 | 新按钮 variant 先改 `data/ui/ui_theme.json` |
| `UIThemeService` | `scripts/ui/ui_theme_service.gd` | 读取主题、token、颜色、贴图 | 常用颜色/间距/圆角继续迁入 `tokens` |
| `LocalizationService` | `scripts/ui/localization_service.gd` | 读取语言选项和文案 key | 新 UI 文案使用 key + fallback |
| `UIResponsiveLayout` | `scripts/ui/ui_responsive_layout.gd` | 设计尺寸缩放、breakpoint、panel 布局 | 复杂页面不要自写断点 |
| `UIDisplayHelper` | `scripts/ui/ui_display_helper.gd` | display name、视觉贴图、颜色、数组/字典转换、清子节点 | 数据驱动 UI 优先复用 |

### 6.1 文件级职责边界

| 文件 | 允许承担 | 不应承担 |
| --- | --- | --- |
| `scripts/ui/ui_manager.gd` | 顶层装配、状态切换、跨屏选择上下文、运行场景启动/清理、薄事件转发 | 页面内部业务、复杂展示数据拼装、奖励/购买/解锁细节 |
| `scripts/ui/ui_state_registry.gd` | 状态合法跳转、build/prepare 方法、running child、fullscreen choice、pause mode | 具体 UI 节点构建、运行时业务判断 |
| `scripts/ui/ui_state_prepare_router.gd` | 进入状态前调用刷新方法、触发 modal refresh | 复杂数据计算、直接改存档 |
| `scripts/ui/ui_screen_host.gd` | screen 显隐层级、running child 与 HUD 显示关系 | 具体状态跳转、暂停控制 |
| `scripts/ui/ui_pause_policy.gd` | 根据 descriptor 应用 `get_tree().paused` | 弹窗内部控制 pause |
| `scripts/ui/modals/modal_flow_controller.gd` | pending modal 队列、优先级、state 到 refresh 的映射 | 卡牌渲染、奖励应用 |
| `scripts/ui/modals/run_choice_modal_controller.gd` | 选择弹窗 UI、pending level/reward、点击后发 command | 奖励/升级/存档副作用实现 |
| `scripts/ui/ui_command.gd` | UI 意图的数据结构与构造函数 | 执行业务 |
| `scripts/ui/ui_command_dispatcher.gd` | 统一执行 UI command，必要时委托运行时对象/服务 | 控制节点布局、主动切换 screen |
| `scripts/ui/run_scene_ui_bridge.gd` | 连接 player/spawner/enemy 信号到 UIManager callback | 业务规则、HUD 字段构建 |
| `scripts/ui/hud/run_hud_state_provider.gd` | 采集并归一化 HUD 字典 | 创建/摆放 HUD 节点 |
| `scripts/ui/hud/run_hud_controller.gd` | HUD 节点构建、布局、渲染字典字段 | 连接运行时信号、读取复杂业务规则 |
| `scripts/ui/run_result_state_builder.gd` | 汇总结算上下文 | 渲染结果页、写解锁 |
| `scripts/ui/result_unlock_service.gd` | 根据结算结果写入解锁/通关进度 | 结果页布局、诊断文案 |
| `scripts/ui/screens/*_view_model_builder.gd` | 页面展示数据、按钮可用状态、排序/筛选/锁定文案 | 创建 Control 节点、连接按钮 |
| `scripts/ui/screens/*_controller.gd` | 构建节点、消费 ViewModel、发信号/command | 复制系统业务规则、跨屏查找节点 |
| `scripts/game/run_scene_coordinator.gd` | 加载/销毁 `main.tscn`、注入 loadout/map、返回运行时节点 | UI 状态切换、菜单页面刷新 |

### 6.2 改造准入清单

每次动 UI 前先判断：

- 是否需要新增状态：需要就先改 `UIStateRegistry`，再改 build/prepare。
- 是否只是展示字段：优先改 ViewModel builder，再改 controller 渲染。
- 是否有副作用：先补 `UICommand` / `UICommandDispatcher` 或独立 service。
- 是否发生在战斗中：同步确认 `pause_mode`、`is_running_child`、`is_fullscreen_choice`、HUD 可见性。
- 是否依赖运行时信号：先接 `RunSceneUIBridge`，再由 HUD/弹窗消费。
- 是否影响存档/解锁/奖励：必须避开 controller 直写，优先 command/service。
- 是否有新文案或样式：补 localization/theme，再保留 fallback。
- 是否可能影响小屏：补 `update_layout()` 或复用 `UIResponsiveLayout`，并人工看桌面/窄屏。

## 7. 数据和资源依赖

UI 主要消费：

- `GameData`：角色、技能、神系、怪物、状态、遗物、地图、升级池。
- `SaveManager`：灵魂石、设置、角色解锁、局外升级等级、地图通关、图鉴解锁。
- `RunStatsTracker`：战斗统计，用于 HUD 和结算。
- `RunDiagnosticService`：结算诊断和推荐。
- `MapRuntime`：地图默认 ID、解锁、背景图、锁定描述。
- `CharacterLoadoutService`：角色和起始技能 loadout 校验。

资源字段约定：

- 角色/怪物/技能视觉通常读配置中的 `visual.icon`、`visual.portrait`、`visual.texture`。
- 地图预览和运行背景读 `maps.json` 的 `visual.background_texture`，由 `MapRuntime` 消费。
- 选择卡牌背景优先读 option 的 `background_texture` / `card_background_texture`，否则读 `data/ui/ui_theme.json`。
- 本地化 UI 文案读 `data/localization/ui_text.json`。

## 8. 最快改造路径

### 新增主菜单页面

1. 新建 `scripts/ui/screens/xxx_controller.gd`。
2. 如页面有复杂数据，新增 `xxx_view_model_builder.gd`。
3. 在 `UIManager` 增加 state 常量和 `_build_xxx()`。
4. 在 `UIStateRegistry` 增加 descriptor：`allowed_to`、`build_method`、`pause_mode`。
5. 如进入页面要刷新数据，在 descriptor 加 `prepare_method`，并在 `UIStatePrepareRouter` 实现。
6. 来源页面按钮只发 `state_requested`。
7. 更新或新增对应 UI smoke 覆盖新状态。

不要做：

- 不要在旧 controller 里直接 `get_node()` 找新页面。
- 不要绕过 `UIManager.transition_to()`。
- 不要在页面按钮里启动/清理战斗场景。

### 新增运行中弹窗

1. 定义新 state。
2. 在 `UIStateRegistry` descriptor 中声明 running child、fullscreen choice、pause mode。
3. 新建 modal controller 或复用 `RunChoiceModalController`。
4. 在 `ModalFlowController.refresh_modal_for_state()` 注册刷新入口。
5. 如弹窗来自异步事件，使用 `request_modal(modal_type, target_state, payload, priority, hide_hud)`。
6. 选择结果只发 `UICommand` 或状态返回。
7. 更新冒烟测试。

不要做：

- 不要让 modal 自己 `get_tree().paused = true`。
- 不要让 modal 直接切换其他屏幕。
- 不要把奖励、升级、存档写入放进卡牌点击回调。

### 新增 HUD 字段

1. 在 `RunHudStateProvider.build()` 输出字段。
2. 在 `RunHudController._build_xxx()` 创建节点。
3. 在 `RunHudController._update_xxx()` 消费字段。
4. 如果字段来自新运行时信号，先接入 `RunSceneUIBridge`。
5. 人工走战斗链路确认布局和数据。

不要做：

- 不要让 HUD 到处连接 player/spawner 信号。
- 不要把字段拼装塞回 `UIManager._process()`。

### 新增奖励、升级、购买或解锁副作用

1. 在 `UICommand` 增加构造函数。
2. 在 `UICommandDispatcher` 增加 command type 和 handler。
3. 如果副作用复杂，handler 再委托独立 service。
4. Controller 只发 command。
5. 更新对应 UI smoke 的 command contract。

不要做：

- 不要在 controller 直接写 `SaveManager`。
- 不要在 UI 中复制战斗/奖励/解锁业务规则。

### 修改角色选择

优先改：

- 数据和按钮状态：`CharacterLoadoutViewModelBuilder`
- 文案：`CharacterLoadoutText` 或 localization key
- 视觉资源：`characters.json` 的 `visual`，以及 `skills.json` 中起始技能展示字段
- 渲染：`CharacterLoadoutController`

检查：

- `CharacterLoadoutService.validate_loadout()`
- `SaveManager.is_character_unlocked()`
- `UICommandDispatcher.purchase_character()`

### 修改地图选择

优先改：

- 地图配置：`data/maps.json`
- 地图运行/解锁：`MapRuntime`
- ViewModel：`MapSelectViewModelBuilder`
- 渲染：`MapSelectController`

检查：

- 开始按钮只发 `start_requested(map_id)`。
- 战斗场景只在 `UIManager._start_run()` 启动。

### 修改结算页

优先改：

- 结算展示：`ResultScreenViewModelBuilder`
- 运行结果上下文：`RunResultStateBuilder`
- 诊断和推荐：`RunDiagnosticService`
- 解锁副作用：`ResultUnlockService`
- 按钮和布局：`ResultScreenController`

检查：

- 不要绕过 `ResultUnlockService` 写存档。
- 推荐配装走 `recommended_loadout_requested()`。

### 修改主题

优先改：

- 按钮：`data/ui/ui_theme.json.buttons`
- 通用 token：`data/ui/ui_theme.json.tokens`
- 读取工具：`UIThemeService`
- 按钮皮肤：`UIButtonSkin`

长期迁移顺序：

1. 通用面板。
2. 选择卡牌。
3. 角色卡、技能展示、地图卡。
4. HUD 面板和进度条。
5. 图鉴和结算卡片。

### 修改本地化

优先改：

- 文案 key：`data/localization/ui_text.json`
- 读取：`LocalizationService.translate(key, params, fallback)`
- 设置应用：`UISettingsService.apply_language()`

当前已接入：

- 标题页。
- 设置页。
- 主 panel 标题。
- 运行中弹窗标题。

仍建议逐步迁移：

- 角色选择详情。
- 地图选择详情。
- 结算页诊断。
- 图鉴内容。
- HUD 文案。

## 9. 当前风险与保护点

1. HUD 已接入完整模块，但仍需要人工跑战斗流确认重叠、实时数据和小屏布局。
2. 响应式系统有 scale/compact，但角色选择、地图选择、HUD、结算这类复杂页面仍需要逐屏 polish。
3. 主题 token 已有，但大量历史 stylebox 仍在 controller 中，做全局视觉升级前要逐步迁移。
4. 本地化服务已接入入口文案，但业务数据和专用 text builder 中仍有大量中文硬编码。
5. `UICommandDispatcher` 统一了入口，但 handler 内仍直接调用部分运行时对象和 `SaveManager`，复杂化后应拆 application service。
6. `UIManager` 已瘦身，但仍承担运行场景调度和运行事件回调。继续拆分时要小步做，避免影响开局、暂停、结算链路。

## 10. 验证清单

每次 UI 相关改动后至少执行：

```powershell
D:\nodejs\node.exe tools\check_text_encoding.js
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --quit
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_title_screen_runtime.gd
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tools/verify/verify_character_select_ui.gd
```

涉及运行中 UI、HUD、奖励、升级、结算时，还要人工走：

```text
启动 -> 标题 -> 角色选择 -> 地图选择 -> 战斗 -> 升级弹窗 -> 奖励弹窗 -> 暂停 -> 失败/胜利结算 -> 返回主菜单
```

建议新增测试覆盖：

- 新状态：补对应 UI smoke 的 build order 和 transition 断言。
- 新 command：补 command dispatch 断言。
- 新 ViewModel：补 builder smoke 断言。
- 新本地化 key：补语言切换断言。
- 新主题 token：补 token resolve 断言。

## 11. 最小影响原则

- UI 状态入口只走 `UIManager.transition_to()`。
- 子屏幕只发信号或 command，不主动找其他屏幕。
- 展示数据只读 ViewModel，不在 controller 里复制业务规则。
- 新运行时 UI 先确认 pause、HUD 可见性和返回状态。
- 新副作用先进入 command/service，再由 UI 触发。
- 新样式先复用 `UIButtonSkin`、`UIThemeService`、`UIScreenFactory`、`UINodeFactory`、`UIDisplayHelper`。
- 新文案先补 localization key，并保留 fallback。
- 新数据驱动 UI 先补 JSON 字段和配置文档，再让 UI 消费字段。
- 做大改时先加验证，再改链路。
