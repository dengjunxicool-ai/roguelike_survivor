# 诅咒神系特效

本轮完成 14 个基础诅咒技能的程序化展示，完成后停下；神圣、混沌尚未开始。技能名称取自 `data/skills/skills.json` 的 `display_name`，以下机制以正式运行配置与实际战斗入口为准。统一使用暗紫咒纹、幽绿魂火、骨白轮廓及烟状拖尾，区分延迟预警、实际结算与资源就绪。

## 技能映射

| 技能与 ID | 展示与实际战斗依据 |
| --- | --- |
| 诅咒攻击 `curse_attack_cursing` | 已确认主攻击命中的短咒印，实际诅咒层数的纵向锁链与魂印；低血额外伤害走正式伤害管线 |
| 魂链疾行 `curse_dash_soul_chain` | 冲刺动作选取附近目标，优先带诅咒敌人；实际落点魂阵与端点魂链，伤害降低目标生命后播放链，实际恢复生命后播放吸收反馈 |
| 黑蛇追猎 `curse_cast_black_serpent_hunt` | 黑紫蛇身、幽绿眼睛和摆动烟尾；真实弹体启用追踪，重选目标时优先未被诅咒的敌人，命中执行实际伤害与诅咒施加 |
| 死镰回旋 `curse_cast_death_scythe` | 旋转骨白镰刃、紫色残影与绿魂轴心；展示旋转不改变弹体轨迹。启用既有一次回程机制，回程开始时朝施法者当时位置飞行，实际返回阶段继续执行命中与等级条件 |
| 终末法阵 `curse_cast_doom_circle` | 实际延迟区域的符刻、收缩魂纹与倒计时蓄积；宿主到期后生成独立爆发区域，展示实际范围，伤害与诅咒层数消费由正式动作执行 |
| 亡骸仆从 `curse_summon_bone_servant` | 肋骨、颅骨、骨刃和关节步态，绿魂眼火；正式规则累计五次带诅咒敌人死亡后创建召唤，目标、攻击冷却、近战与寿命驱动姿态 |
| 魂鸦 `curse_summon_soul_crow` | 宽翼、垂羽、长尾和胸部魂火；正式召唤攻击从魂鸦实际位置发射魂弹。附近诅咒敌人实际死亡后显示朝魂鸦汇聚的吸魂丝缕；另有累计三次带诅咒敌人死亡的实际魂弹输出；环绕魂珠只作待机装饰 |
| 吸血仪式 `curse_passive_vampiric_ritual` | 诅咒结算或带诅咒敌人死亡触发正式治疗；仅实际恢复生命值大于零时显示向内收拢的魂火，满生命治疗不播放恢复反馈 |
| 疫咒扩散 `curse_passive_plague_spread` | 带诅咒敌人死亡后的实际邻近目标扩散；施加诅咒确实改变层数后，使用死亡目标与扩散目标的真实端点播放紫绿丝缕 |
| 临终加深 `curse_passive_deathbed_deepen` | 低生命目标的诅咒结算增益通过正式伤害计算体现；结算反馈尺寸读取实际 `resolved_damage`，不额外制造攻击 |
| 恐惧低语 `curse_power_fear_whisper` | 玩家周围实际短寿命区域的暗紫外扩前沿；正式配置对带诅咒目标造成伤害与击退，展示跟随该范围和寿命 |
| 灵魂收割 `curse_power_soul_harvest` | 读取真实十二点计数显示部分充能；只有精确来源 `skill:curse_power_soul_harvest:next_cast` 存在时显示就绪，正式施法消耗后停用 |
| 死亡契约 `curse_power_death_pact` | 实际五秒契约目标的菱形魂印与期限圆环；目标死亡或到期由正式契约结算一次并产生实际灵魂爆炸区域，标记随目标移动与清除 |
| 万咒归棺 `curse_core_grand_coffin` | 真实死亡扩散端点、二十点灵魂债务光环与达到阈值后实际发射的十发灵魂风暴弹；目标选择使用玩家周围指定范围内的正式随机敌人选择 |

亡骸仆从当前规则是五次死亡计数阈值，恐惧低语当前动作是伤害与击退，万咒归棺当前输出是指定范围内选取目标的弹体。既有描述中的概率召唤、恐惧逃离、全屏低生命收割不作为本轮已实现的战斗行为。

## 生产边界

- 投射物、区域、召唤展示由实际宿主年龄、方向、范围、目标、攻击和寿命驱动；所有诅咒材质不用 `TIME`。状态、短反馈和魂链通过随场景暂停的 `delta` 推进。
- 投射物共用固定 24 枚、144 顶点的魂尾网格；魂链共用固定 16 枚、96 顶点魂珠网格，折线配置为 24 段、四层 Line2D。区域固定四个绘制节点、24 条魂丝和 18 条魂焰批次；年龄更新不重建网格，配置或实际范围变动时更新几何。
- 每个实例保留独立材质和实时 uniform。重配恢复年龄、方向、透明度、轮廓与各层显隐，不改变全局战斗随机序列。
- 每个诅咒展示管理器最多保留 24 个命中、12 个结算／治疗反馈、24 条魂链、8 个契约标记。池满省略该次装饰，正式战斗动作继续执行；命中节流记录最多 128 项。
- 契约目标通过弱引用跟踪；目标释放、排队删除或契约元数据清除时停用标记。局内重置停用全部反馈、清除契约引用与节流记录。
- 命中读取真实正伤害；规范 `status_dot` 被排除在直接命中展示之外，诅咒结算只由实际正 `resolved_damage` 触发。链反馈需要目标生命下降或诅咒层数实际改变；治疗反馈读取 `PlayerHealing.apply()` 返回的实际恢复量。
- 灵魂收割读取 `soul_harvest_cursed_kills` 与精确下一次施法来源；棺债读取 `grand_coffin_soul_debt`。展示刷新不增加、消费或修改资源，也不进入技能事件队列或增加触发预算。
- 状态管理器在暂停／恢复时刷新视觉快照，传递 `duration_paused` 与 `host_controls_lifetime`。诅咒暂停结算时展示不扣剩余时间；宿主控制生命周期时，即使展示本地时间归零也不能隐藏仍存在的诅咒，正式移除状态才停用咒印。

## 同步修复与真实伤害

亡骸仆从的旧 `curse` 元素不在严格伤害元素登记表内，直接近战伤害被拒绝；现两种诅咒召唤都配置规范 `arcane` 元素，魂鸦不再依赖弹体构建时的旧名称转换。真实 EnemyBase 回归记录：亡骸仆从使目标生命 `10000→9992`、诅咒一层；魂鸦实际魂弹命中使同一目标 `9992→9973`、诅咒从一层变为两层。实际冷却防止重复伤害，暂停冻结攻击冷却与展示年龄，宿主真实寿命到期后释放召唤。

黑蛇追猎新增正式追踪参数与未诅咒优先重选，死镰回旋启用正式一次回程并朝开始回程时施法者的实际位置求方向。此回程不持续追踪随后移动的施法者，也不新增围绕玩家公转的战斗阶段。

魂弹发射使用实际召唤物位置求方向与起点，目标和玩家重合时仍可正确发射；伤害发生在正式弹体命中入口。诅咒状态结算修正为规范 `status_dot` 来源过滤，避免同一结算同时显示普通命中。诅咒冻结修正由真实状态期限控制显示生命周期。

## 验证证据（2026-10-11）

Godot 4.6.3 无界面回归矩阵 35 项全部通过，报告为 `E:/codex/canonical-refactor/curse-school-vfx-final/results.json`。覆盖诅咒各展示模块、真实召唤伤害、实际黑蛇追踪与死镰回程、正式技能契约及运行回归、队列边界、寒霜／火焰／雷霆相关回归。真实反馈回归最终 80 项 PASS，包含零伤害／满生命不播放反馈、真实技能来源诅咒结算、暂停超过原期限仍保持咒印、恢复后由宿主到期移除、实际资源获得与消费，以及两只魂鸦吸收真实诅咒尸体、未诅咒死亡不触发且不追加伤害或资源。

魂鸦真实吸魂接入后的 8 项相关回归再次全部通过，报告为 `E:/codex/canonical-refactor/curse-school-vfx-followup/results.json`；游戏内 GPU 吸魂真实端点像素检查也通过。独立召唤轮廓／攻击姿态／精确暂停检查通过，截图为 `E:/codex/curse-summons/rendered/curse_summon_profiles.png`。最后编辑器无界面导入退出码 0，无解析或引擎错误；内容、Modifier、UTF-8 及差异空白检查通过。两处既有非致命编码提示未修改。

GPU 验证设备为 NVIDIA GeForce RTX 5060，Vulkan Forward Mobile，1280×720。独立投射物 GPU／生命周期验证 93 项通过；实际场景安装全部十四项基础技能的 GPU 检查全部通过，包含区域、弹体、召唤、状态、契约、结算、魂链及收割就绪。截图目录：`E:/codex/curse-vfx/rendered/`；独立弹体对照：`E:/codex/curse-projectiles/render/projectile_profiles.png`。

受控压力工作负载为 8 个区域、128 个保留弹体宿主、16 个召唤展示、16 个真实带诅咒敌人、24 条魂链。最终两组在无其他测试竞争下串行测量，敌人生命数组完全一致。

| 受控压力指标 | 可见组 | 隐藏受控特效组 |
| --- | --- | --- |
| P50／P95 帧间隔 | 2.913／4.030 ms | 0.928／1.445 ms |
| 展示更新 P95 | 0.676 ms | 0.514 ms |
| 16 个召唤 CPU 姿态更新 P95 | 0.162 ms | 0.164 ms |

压力报告入口：`E:/codex/curse-vfx/stress/{shown,hidden}/metrics.json`。这是冻结背景并显式推进展示时钟的受控开销测量，未模拟完整敌人 AI、寻路与连续技能派生，不构成完整实战 FPS 结论。

## 维护入口

- 配置：`data/combat/combat_objects.json`、`data/combat/status_effects.json`、`data/summons/summons.json`、`data/skills/skills.json`。
- 展示：`scripts/effects/curse_*_effect.gd`、`resources/effects/curse_*.gdshader`、`scripts/visual/curse_combat_presentation.gd`。
- 无界面：`verify:curse-area-effect`、`verify:curse-projectile-effect`、`verify:curse-summon-effect`、`verify:curse-summon-damage-runtime`、`verify:curse-presentation`、`verify:curse-feedback-runtime`、`verify:curse-projectile-trajectories`。
- GPU 整体：`tools/verify/verify_curse_school_rendered.gd`；GPU 压力：`tools/verify/verify_curse_vfx_stress.gd`，分别串行运行可见／隐藏模式。
- 所有日志、用户数据、截图与性能报告保存至 `E:/codex`，不写入 C 盘。
