# 寒霜神系特效

已接入 14 个寒霜基础技能（`school=frost` 且 `fusion_school=null`）。使用程序化几何、Canvas Shader 与 GPU 雪尘；无需新增位图素材。双神系融合技能的独立设计不在本次范围内，但使用相同战斗对象的冰片、冰矛、霜环会获得更新。

| 技能 | 展示与实际触发来源 |
| --- | --- |
| 寒霜攻击 | 确认主攻击伤害的晶光；实际寒冷层数驱动薄霜轮廓 |
| 冰片突袭 | 六向切面冰片、方向一致的短霜尾 |
| 冰霜领域 | 低遮挡冻土、裂纹、边缘冰晶及雪尘；实际衍生霜径更淡 |
| 极寒冰矛 | 长形切面冰矛与霜尾；真正生成的碎冰溅射负责爆裂 |
| 暴雪云团 | 保留已验收的流动云雾、地面霜环及三层 GPU 粒子 |
| 霜狼 | 狼形晶体、四肢步态、尾部摆动，真实攻击触发咬合前扑 |
| 冰晶守卫 | 悬浮晶核、六枚旋转碎晶，真实攻击脉冲同步 |
| 碎冰处决 | 确认处决／首领补伤后的晶体破裂；失败判定不播放 |
| 冰封易伤 | 真实伤害事件携带的冻结／定身／眩晕快照触发裂纹闪光 |
| 寒意延展 | 原有冷状态及区域按真实延长寿命持续展示，无新增伤害表现 |
| 霜环反冲 | 实际生成的霜环展示快速扩散冰锋与碎晶 |
| 冰裂连锁 | 真正派生的冰裂碎片使用短、小的切面轮廓 |
| 冰雾护身 | 确认授盾形成最多三层霜雾与轨道冰晶；实际破盾清理并闪裂 |
| 绝对零度 | 大半径使用低遮挡寒流扫过；死亡残留使用局部冻土 |

## 生命周期与边界

展示节点不计算伤害、不施加状态、不改变碰撞和技能数值。范围与弹体的时钟来自宿主；状态与护盾时钟随场景暂停。范围变化、升级后的寿命和延长持续时间直接同步。

- `AreaEffect` 的 `visual_effect_scene` 接口：`configure(radius,duration,phase)`、`update_state(radius,age,duration)`、`set_effect_radius(radius)`、`deactivate()`。
- `Projectile` 接口：`configure_projectile(params)`、`update_projectile(age)`、`deactivate()`；树外工厂初始化也可用。
- 召唤配置 `visual.effect_scene`：`configure_summon(visual)`、`update_summon(delta,motion,remaining)`、`face_direction(direction)`、`play_attack()`。
- 状态配置 `visual.effect_scene`：`configure_status(snapshot)`、`deactivate()`；同状态叠层更新复用节点，高优先级冻结覆盖薄霜，状态移除立即隐藏。
- `FrostCombatPresentation` 监听确认伤害、授盾和破盾事件；命中节点固定在世界位置，最多 32 个同时存活，空闲节点复用，随本局事件总线释放。

目前玩法护盾共用 `fire_passive_shield` 储量与期限，吸收阶段不提供各类型的消费拆分。冰雾表现保留已确认的冰雾授盾层，透明度受实际共用剩余储量约束，并按共用储量真正到期／耗尽清理；新授盾延长旧层与实际共享期限一致。本次没有引入独立的冷护盾吸收或修改叠层数值规则。

GPU 粒子上限：领域 48、霜径 24、绝对零度 48、霜狼 18、守卫 24、暴雪 192；霜环、碎冰和弹体无粒子节点。弹体碎光数量为 8／12，范围冰锋 18／24，冻结状态只使用一张程序化四边形。配置、更新不调用全局随机；Godot GPU 粒子节点首次构造的引擎内部种子行为与暴雪验收文档中的限制相同。

兼容 `configure_projectile`／`deactivate` 契约的弹体效果在宿主回池后保留节点与独立材质，同场景重新配置时重置年龄、寿命、轮廓和尾长；切换场景或空场景立即停用并释放旧效果。宿主保留已加载场景以免重复解析。原有附加型特效保留其既有绘制与释放方式。弹体碎光共用一份 72 顶点网格，由独立材质的权威年龄推进；持续领域的冰晶几何只在重配置、半径或瞬时／持续分类变化时重建，动态霜环与碎冰继续更新几何。

## 验收

新增自动检查：`verify:frost-projectile-visual`、`verify:frost-summon-visual`、`verify:frost-school-visual`、`verify:frost-feedback-runtime`。覆盖生产工厂、树外配置、实际伤害／处决、状态叠层、护盾、池化、跨风格清理和暂停。

GPU 脚本 `tools/verify/verify_frost_school_rendered.gd` 在真实游戏场景施放领域与两种召唤物，再通过生产工厂展示衍生对象。逐层隐藏比较证明材质真实产生像素，暂停前后像素完全一致。报告只保存到 `E:/codex/frost-vfx/`，启动前必须将 `APPDATA`、`LOCALAPPDATA`、`TEMP`、`TMP` 指向 E 盘隔离目录。

验收设备：RTX 5060，Godot 4.6.3 Mobile/Vulkan，1280×720，关闭垂直同步。最终混合寒霜同屏采样 2 秒的帧间隔 p95 为 1.481 ms，基线 p95 为 0.476 ms；这些是受控场景的帧间隔，不是独立 GPU 耗时，也不代表低端移动设备保证。实际截图与测量位于 `E:/codex/frost-vfx/accepted/`。

另以 `verify_frost_stress_ab.gd` 运行真实命中对照：8 个活动区域、16 个敌人、4 秒内 128 个弹体，峰值 56 个弹体，区域雪尘 288 个。隐藏组只关闭 Canvas 绘制，保留宿主、时钟与伤害；两组敌人最终血量完全一致。最终显示组帧间隔 p50/p95 为 1.360/8.730 ms，隐藏组为 0.471/4.473 ms。显示组生成一轮 8 弹体的 p95 为 4.048 ms。报告分别位于 `E:/codex/frost-vfx/stress-ab/cached-final/stress_ab.json` 与 `hidden-final/stress_ab.json`。

这些结果包含场景／材质复用、共享碎光网格与区域静态几何缓存。显示组仍有 31/1114 帧超过 16.67 ms，最大 221.57 ms；隐藏组也有 30 个长帧、最大 240.405 ms。隐藏组某个 79.86 ms 帧中，原有区域伤害 tick 占 69.02 ms，弹体更新占 1.65 ms，状态展示更新占 0.161 ms，因此当前整体战斗不能据此宣称稳定 60 FPS。本次未修改伤害结算和敌人调度；特效验收与完整战斗性能保证需分开判断。

最终独立复跑 `verify_frost_stress_rendered.gd`：8 个活动区域、128 次弹体生成、峰值 56 个弹体，16 个目标均发生真实掉血，命中池使用 16/32 个节点。4 秒帧间隔 p50/p95 为 1.241/7.787 ms，28/1325 帧超过 16.67 ms，零脚本／验收错误。报告与截图位于 `E:/codex/frost-vfx/stress-accepted/`。最终 27 项相关回归全部通过，报告位于 `E:/codex/canonical-refactor/frost-vfx-optimized/results.json`；配置、Modifier、敌人数据及 UTF-8 检查通过。独立代码审查未发现 P1/P2。

霜狼真实伤害回归 `verify:frost-wolf-damage-runtime` 使用正式技能施放、召唤控制器及实际敌人受击管线，核对连续咬击掉血、冷却、寒冷叠层、扑咬展示、超距追逐及引擎暂停。原配置将 `frost` 直接传入严格伤害包的元素字段，伤害会因未登记元素被拒绝；已将霜狼配置改为登记元素 `ice`，保留原伤害倍率和攻击规则。修复前两次咬击血量仍为 1000，修复后为 978。原特效测试仅证明攻击发起，不能替代真实敌人的掉血验证。相关 8 项回归零失败，报告位于 `E:/codex/canonical-refactor/frost-wolf-damage/results.json`。
