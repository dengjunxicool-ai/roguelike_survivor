# 合并后稳定性收尾

日期：2026-10-08。合并基线 main=6726527（PR #11）；工作分支 codex/post-merge-stability。

计划：[执行步骤](superpowers/plans/2026-10-08-post-merge-stability.md)。第一阶段覆盖稳定性收尾，未变更相机缩放、战斗数值、波次或持久化 ID。其后的刷怪与结算修改及验证在本报告末尾记录；前阶段性能对比仅代表当时有敌人数上限的版本。

## 根因与修复

### 1. 相机检查使用过期的产品假设

旧检查要求 zoom.x/y > 1。Git 提交 bb02c7b 于 2026-06-25 删除了场景的固定 zoom=1.35，当前默认缩放为 1；本次契约重构没有修改场景相机。恢复旧缩放会改变玩家视野，因此改检查当前可见行为。

新检查覆盖活跃相机、有限正缩放、背景与相机 limits 一致，以及 1280×720、1920×1080、900×1440 三种视口下中心和四角可视矩形不越界。原玩家边界、波次数量、上限、经验与 timeout 断言保留。

RED：E:/codex/post-merge-stability/camera-red/result.log。
GREEN：E:/codex/canonical-refactor/post-merge-camera-green/results.json。
变异验证：仅 E 盘临时检查副本将右限位设为 left+1，检查真实失败；生产相机未改。E:/codex/post-merge-stability/camera-mutation/result.log。

### 2. 晶体删除与经验到账发生在不同阶段

首次复跑发现 deferred 晶体的到账断言偶发失败。ExpGem 收集后交给 PickupManager.queue_experience_reward，后者在物理帧 flush_rewards；原检查只等待 process_frame，可能在发布之前读取 XP。

夹具关闭其自行驱动的玩家/刷怪器自动更新，继续使用真实波次与拾取服务，最多等待 8 个物理帧直到经验/等级增加；随后重复收集，确认不重复发奖。未修改生产经验金额或队列时序。

### 3. 显形 Tween 持有已释放怪物参数

真实 Vulkan 渲染局发现 CallbackTweener 无法把已释放怪物转换为 Node2D。旧回调在进入方法前就失败，警示环也无法清除；截图可见大量残留警示。

回调改绑定 WeakRef，取到存活对象后再激活；Tween 绑定 warning 节点，warning 被重开/清理移除时取消未完成工作。保留存活怪物的显形时长、颜色、缩放、碰撞与处理模式恢复。

新生命周期检查验证存活显形、提前释放怪物、提前移除 warning。RED：E:/codex/post-merge-stability/spawn-reveal-red/result.log；GREEN：spawn-reveal-green/result.log，exit 0 / 0 脚本错误 / 0 engine ERROR。

重复检查又捕获固定计时器的同帧竞态：SceneTree timer 在 Tween 前处理，大启动 delta 可让计时器先于显形回调结束。夹具改最多等待 2 秒观察真实 warning 清理，保留全部原行为断言；取消用例进一步断言 Tween 已失效且敌人仍待显形。两项新门禁在 post-merge-repeat-final-1..5 连续 5 批全部通过。

### 4. 验收工具补充可观测性

- 两个 PowerShell 入口同时检查脚本错误和普通 ERROR:，exit 0 不能遮蔽运行错误。
- 自动驾驶与采样提供 seed/revision/report-dir，首次波次之前固定刷怪 RNG，真实装配完成后固定地图、选择、升级、奖励及嵌套升级池 RNG，并记录七条随机流。
- 测量前等待异步 _start_run 完成；Windows 从默认最大化恢复窗口需要异步处理，工具先等待恢复，再 resize，确认窗口与实际根视口都为 1280×720 后才继续。2 秒渲染 smoke 已验证输出元数据为 1280×720；未收敛时失败退出。
- 存档初始化与清理限定 E:/codex；结束真实场景 teardown，等待协程/节点释放；报告或截图写出失败返回失败。
- 自动驾驶选择后清除已处理弹窗标志，能够处理连续相同类型的奖励页面；Boss/HUD 截图最多等待 2 秒，在绘制后再次确认 RUNNING；Boss 图还确认显形完成、实际 Boss 面板可见。Boss 直接扣血辅助等待首张 Boss 战斗图完成，避免截图前就结束 Boss。
- 截图协程每次 await 恢复后重新检查结束状态和 UI 存活；退出时仍有待完成截图则明确失败。真实继承夹具的隔离 probe 先复现已释放 UI 访问（exit 0 / 1 SCRIPT ERROR），修复后为明确 exit 1 / 0 SCRIPT ERROR / 1 预期 ERROR，日志在 capture-race-red / capture-race-green。

## 渲染验收

真实渲染：Godot 4.6.3，Vulkan / Mobile，NVIDIA GeForce RTX 5060，1280×720。完整局使用 5 倍时间、750 HP 存活辅助及 Boss 扣血辅助；属于流程压力与画面验收，不代表无辅助通关或平衡性结论。

完整局最终到达 VICTORY，游戏时间 260.5 秒，exit 0 / 0 脚本错误 / 0 engine ERROR。最终角色、活动 HUD、Boss 战斗及结算四张 1280×720 图片在 E:/codex/post-merge-stability/rendered-full-run-delivery-final，已实际逐张查看。早期 green、final、accepted 与 viewport-final 目录保留作审计资料；viewport-final 的 Boss/HUD 图片曾拍到奖励弹窗，不作为活动战斗画面的通过证据。

真实渲染死亡→结算→同场景重开→第二次结算通过；四张最终阶段截图在 E:/codex/post-merge-stability/rendered-restart-final。截图最多等待 2 秒，并断言生产加载遮罩实际消失，避免把 0.18 秒淡出过程误当成重开失败。重复结果保持首个终局，重开恢复生命/起始技能、清理状态/冷却/掉落/统计，第二局只记录一次。

重开夹具为确定性断言禁用 Main 自主更新，使用真实装配、伤害与终局入口；截图确认加载和结果页面，并不证明被冻结背景 HUD/伤害浮字的刷新状态。活动 HUD 与 Boss 画面另由自动驾驶完整局覆盖。

本报告的视觉结论基于实际渲染截图检查；不称为真人输入游玩，不替代各神系全部视觉体验。

剩余画面项：1280×720 时 Boss 顶栏与左上玩家 HP 面板局部重叠，结算长摘要的操作区需要滚动查看。本次保留既有布局，不宣称全界面视觉无缺陷；后续 UI 维护应增加面板不相交与结果操作可达性门禁。

## 受控性能对比

前版本：45facd3 + 与后版本相同的显形生命周期修复；后版本：6726527 + 本次稳定性修复。仅 E:/codex 副本补前版本修复，未改原 Git 提交，原始服务源码保存在 baseline-spawn-service-original.txt。避免旧 Tween 错误本身造成测量偏差。

两个副本使用 SHA256 相同的采样与环境脚本，同角色 mage、地图 abandoned_dungeon、基础种子 618、七条固定随机流、1280×720、Mobile/Vulkan、关闭 VSync、time_scale=1、每份 180 秒，串行执行，存活辅助相同，无 Boss 扣血辅助。最终数据和日志分别在 perf-before-final / perf-after-final。

采样脚本 SHA256：4FE7950C93B5676C3EA32D16089780B59FFAAF23D6BFA918195A2A977791CA3B。
环境脚本 SHA256：4810DDBFB22422C941FD947A765EBB8BDB0F9ADC61F7851323D1C15C3B9BA80E。

早期 perf-before / perf-after 的实际根视口为 2560×1369，暴露了窗口异步问题，不计入下表的最终对比。该对样本均值 0.513→0.609 ms、P95 1.257→1.429 ms、P99 2.995→4.338 ms；保留不利结果，不能宣称重构收益。

最终元数据确认上述条件一致，两份运行均 PASS / 0 脚本错误 / 0 engine ERROR。可版本管理的指标摘要：[性能数据](perf/POST_MERGE_STABILITY_PERFORMANCE.json)。

| 指标 | 重构前 + 同显形修复 | 合并后 + 稳定性修复 |
| --- | ---: | ---: |
| 实际采样时长（秒） | 180.000 | 180.000 |
| 均值帧耗时（ms） | 0.618 | 0.610 |
| P95（ms） | 1.345 | 1.330 |
| P99（ms） | 4.918 | 4.939 |
| 最大帧（ms，含采样开销） | 131.869 | 115.217 |
| ≥33.333 ms / ≥50 ms 帧数 | 39 / 29 | 37 / 26 |
| 采样峰值怪物 / 节点 | 41 / 1182 | 41 / 1192 |
| 采样峰值对象 / 资源 | 5709 / 467 | 5732 / 480 |
| 采样峰值静态内存（MiB） | 145.73 | 145.55 |
| 采样孤儿节点最大值 / 最终等级 | 0 / 7 | 0 / 7 |

两份最终样本的均值和主要分位接近，不据此宣称性能收益。固定随机流不能消除实时模拟、战斗结果和负载差异；单次样本不能证明因果性能收益，不将历史长局或其他分辨率结果直接用于收益宣称。本次 180 秒不涵盖长时间 Boss 压力。夹具每 5 秒遍历节点并复制排序累计帧数组，采样开销包含在下一帧，最大帧与慢帧数不宜直接归因于生产战斗。

## 最终验收

最终 package 矩阵：155 项 / 0 失败 / 0 脚本错误 / 0 engine ERROR，E:/codex/canonical-refactor/post-merge-final/results.json。较合并前增加完整波次/相机和显形生命周期两项长期门禁。新门禁另连续复跑 5 批，全部通过。

真实渲染重开：60 项断言通过，exit 0 / 0 脚本错误 / 0 engine ERROR，rendered-restart-final/result.log。导入检查、content/enemy/modifier 校验通过；独立审查中私有 RNG、报告写出失败、截图协程释放竞态均已修复，窗口/加载遮罩/显形等待已复核。

三个环境拒绝 probe 均按预期 exit 1 / 0 脚本错误 / 1 明确 engine ERROR：非法 seed、规范化后越界的 report-dir、已有隔离存档。已有存档 sentinel 的 SHA256 保持，随后仅删除该 probe 文件。记录在 guard-invalid-seed / guard-invalid-output / guard-existing-save；另有截图取消 probe 的预期失败，不与正常验收的零错误计数混用。

测试存档检查覆盖 post-merge-final 矩阵与 E:/codex/post-merge-stability，save.cfg 残留为 0。最终文本编码检查：1309 份文本为合法 UTF-8；git diff --check 与新增文件尾部空白检查通过。不操作正式存档。

## 复跑

```powershell
& tools/verify/run_verification_matrix.ps1 -Batch post-merge-final
& tools/verify/run_isolated_godot.ps1 -OutputRoot E:/codex/post-merge-stability/rendered-full-run-delivery-final -Script res://tools/verify/verify_mage_full_run_autoplay.gd -Rendered -UserArguments '--seed=618','--report-dir=E:/codex/post-merge-stability/rendered-full-run-delivery-final','--revision=6726527+stability'
& tools/verify/run_isolated_godot.ps1 -OutputRoot E:/codex/post-merge-stability/rendered-restart-final -Script res://tools/verify/verify_run_restart_contract.gd -Rendered -UserArguments '--capture-dir=E:/codex/post-merge-stability/rendered-restart-final'
& tools/verify/run_isolated_godot.ps1 -OutputRoot E:/codex/post-merge-stability/perf-after-final -Script res://tools/verify/verify_performance_run.gd -Rendered -UserArguments '--duration=180','--seed=618','--report-dir=E:/codex/post-merge-stability/perf-after-final','--revision=6726527+stability'
```

隔离路径必须新鲜；如存在旧 save.cfg，采样/完整局工具会拒绝启动，避免读取既有存档。报告路径或 seed 参数非法时，在加载 SaveManager 前拒绝。所有主动写入在 E 盘。

## 后续刷怪与结算修复（2026-10-08）

用户反馈空场等待、警示后未显现、波次成长不明显和结算数据缺失。本节覆盖这些追加修改；此前的 40 只存活上限及性能数据属于旧版本事实。

### 刷怪与成长

- 删除普通怪全局存活上限、波次 `max_alive`、Boss 小怪 `max_alive`，配置校验拒绝重新引入。保留每批 15 只作为投放节奏，不限制场上存活数量。
- 未投完本波预算且场上为空时，跳过剩余冷却；新波不继承上一波冷却。精英、Boss 和警示中的怪物均计入占场，已死亡或排队释放的实体不计入，避免每帧连续补怪。
- 距离清理跳过警示中的实体，保证承诺的显现完成；显现后仍可正常清理远处敌人。警示时长 1.5 秒、玩家安全距离和待显形实体不可选敌/不可碰撞保持原规则。
- 波次只读明确的 `total_count`，删除 `fixed_count` 与旧 `spawn_interval` 推算及批次容量裁剪。每波数量受本局密度 Modifier 缩放，增加预算时缩短投放间隔，给最后一批留出警示时间。
- 普通波默认批次间隔 3 秒，最后一波 2 秒；Boss 小怪使用自己的 15 秒间隔。波次超时仍保留已生成敌人，地图额外刷怪继续使用原生成服务。

| 波次 | 生成预算 | HP 倍率 | 伤害倍率 | 附加护甲 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 35 | 1.00 | 0.90 | 0 |
| 2 | 50 | 1.15 | 1.00 | 0 |
| 3 | 65 | 1.30 | 1.12 | 1 |
| 4 | 80 | 1.55 | 1.28 | 1 |
| 5 | 95 | 1.85 | 1.45 | 2 |
| 6 | 110 | 2.20 | 1.65 | 2 |
| 7 | 125 | 2.50 | 1.82 | 3 |
| 8 | 140 | 2.75 | 2.00 | 3 |

预算包括本波成功生成的精英；地图和 Boss 仆从不占普通波预算。现有 HP、伤害、护甲倍率已在 `_ready` 前设置并生效，本次不叠加第二条数值成长。回归用同一种真实怪物验证八波实际生命和接触伤害，避免把怪物品种差异误当成倍率效果。

### 结算数据与学习链路

诊断服务此前仅返回推荐角色/地图/摘要/原因，界面读取的 DPS、构筑、升级、伤害占比等字段全部落入默认值。现在从真实 tracker 摘要提供完整字段；tracker 从 `DamagePacket` 读取来源，不再把区域/特殊伤害误归初始技能。构筑快照包括独立主攻、闪避、主动和被动技能及最终等级。

原“高贡献升级”改为“已选升级”，按实际选取次数显示中文名称；现有统计没有升级伤害归因，不能将次数冒充伤害贡献。无伤/无输出/无技能记录有明确文案；胜利、死亡、存活主动结束与缺玩家状态分别处理。毒雾、远程和区域来源使用中文。

真实渲染又发现动态 `learn_skill_*` 卡被静态升级表查询拒绝，导致选择后技能未学习、统计未记录。Player 的应用入口改用已有 `SkillLearnDefinitionRepository.resolve_upgrade`，普通定义仍从 GameData 读取，动态定义由学习仓库解析；未恢复 DataManager 历史 fallback。实际命令分发到学习、稀有度、选取事件、最终快照和中文名称均有运行回归。

### 追加验收

- 新门禁 `verify:wave-population-progression`：先复现 21 条失败，再验证空场提前、超过旧上限继续生成、增加密度后的完整预算、八波实际属性、真实 100 个警示全部显现，以及死/待释放实体不占场。
- 新门禁 `verify:run-result-diagnostics`：真实伤害管线到结果页面，40 条断言通过。直接修改 Boss HP 的自动驾驶辅助不计为玩家伤害；真实样例总伤 54、Boss DPS 5.4、区域/特殊伤害和 Boss 受伤来源均正确。
- 最终完整矩阵 157 项，0 失败、0 脚本错误、0 engine ERROR：`E:/codex/canonical-refactor/wave-result-final/results.json`。content/enemy/modifier 校验及 UTF-8、Git 差异空白检查通过。独立审查的主动结束和来源中文问题已修补复核。
- 实际 1280×720 / Vulkan / Mobile 渲染：750 HP 辅助局在 212.1 秒失败，日志无运行错误，失败页确认技能、选择次数和伤害/受伤结构；目录 `E:/codex/wave-result-fix/rendered-final`。保留该失败结果，不将其算为通关通过。
- 10000 HP 存活辅助及 Boss 扣血辅助压力局在 261.8 秒胜利，exit 0 / 0 脚本错误 / 0 engine ERROR；目录 `E:/codex/wave-result-fix/rendered-stress`。实际查看活动技能与结果截图，最终构筑包含熔岩裂涌和流星火雨，数据由真实事件产生。该局证明完整流程可运行，不作为无辅助通关或玩家平衡性结论；Boss DPS 为零时表示本局未记录实际 Boss 伤害。
- 自动驾驶支持 `--survival-health=<正整数>`，记录辅助生命值；回血仅在 RUNNING 且生命大于零时执行，避免死亡后复活污染结果。终局快照附真实结果状态，便于追踪界面数据。
- 新密度独立性能采样：1280×720、RTX 5060 / Mobile、time_scale=1、种子 618、10000 HP 存活辅助，180.034 秒 PASS，0 脚本/引擎错误。均值 0.976 ms、P95 3.290 ms、P99 8.096 ms；采样峰值敌人 73、节点 1539、对象 7660、资源 495、静态内存 150.99 MiB、孤儿节点 0，最终等级 14。最大帧 215.137 ms，≥33.333 ms / ≥50 ms 帧数 137 / 64；采样遍历/排序及特效预热仍包含在帧耗时内。
- 性能数据已追加至 [版本管理摘要](perf/POST_MERGE_STABILITY_PERFORMANCE.json) 的 `wave_population_followup`，原始样本与日志在 `E:/codex/wave-result-fix/performance`。本次修复学习、增加密度并更改辅助生命值，负载条件与旧对比不同，不能据此计算重构性能收益；180 秒及每 5 秒采样不能证明所有波次/Boss 的最坏压力。
- 本轮完整矩阵与渲染/性能输出目录中的测试 `save.cfg` 残留为 0；未操作正式存档，所有主动写入均在 E 盘。
- 提交前再次完整复跑 157 项全部通过，0 脚本错误 / 0 engine ERROR，日志在 `E:/codex/canonical-refactor/wave-result-pre-pr/results.json`；content/enemy/modifier、UTF-8 与 Git 差异检查同步通过。

追加门禁和渲染流程可按下列命令复跑，输出目录须使用新的隔离目录：

```powershell
& tools/verify/run_verification_matrix.ps1 -Batch wave-result-final
& tools/verify/run_isolated_godot.ps1 -Script res://tools/verify/verify_mage_full_run_autoplay.gd -Rendered -OutputRoot E:/codex/wave-result-fix/rendered-stress -UserArguments '--report-dir=E:/codex/wave-result-fix/rendered-stress','--seed=618','--survival-health=10000'
& tools/verify/run_isolated_godot.ps1 -Script res://tools/verify/verify_performance_run.gd -Rendered -OutputRoot E:/codex/wave-result-fix/performance -UserArguments '--report-dir=E:/codex/wave-result-fix/performance','--duration=180','--seed=618','--survival-health=10000'
```
