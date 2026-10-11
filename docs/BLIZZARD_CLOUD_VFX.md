# 暴雪云团视觉实现与验收

2026-10-11，Godot 4.6.3。

`blizzard_cloud` 使用现有 `visual_effect_scene` 字段挂载 `scenes/effects/blizzard_cloud_effect.tscn`。云雾与地面霜层由无纹理四边形 Shader 绘制，雪花、冰晶和落地闪光使用三组 GPU 粒子，共 192 个粒子/云团。保持现有技能、伤害、状态、目标选择、移动和持续时间逻辑。

## 生命周期契约

`AreaEffect` 驱动视觉场景的四个公开方法：

- `configure(radius, duration, visual_phase)`：初始化一次生成，清理旧粒子并重设相位。
- `update_state(radius, age, duration)`：消费宿主时钟与寿命，控制云流及生成/消散透明度。
- `set_effect_radius(radius)`：同步几何、发射范围和裁剪矩形。
- `deactivate()`：回池时隐藏表现并停止发射；复用保留节点及材质。

显式 `visual_mode = asset` 优先使用既有资源路径。切换到其他区域风格会停用残留暴雪表现。Shader 不读取 `TIME`，粒子继承宿主暂停策略并采用固定种子；材质为每场景实例独有。

不在视觉运行逻辑调用全局随机函数。Godot 的 `GPUParticles2D` 构造函数自身会取全局种子，首次创建三组粒子会影响全局随机序列；固定种子保证随后配置、更新和回池复用不额外消耗全局 RNG。本实现不提供与旧视觉版本逐随机数一致的回放承诺。

## 可复跑验证

执行前必须将 APPDATA、LOCALAPPDATA、TEMP、TMP 指向 E:/codex 下独立目录，避免访问正式存档。项目的 `run_verification_matrix.ps1` 已自动设置这些路径；部分现有入口使用 `godot` 短名称，需确保它解析到实际可执行文件。

```powershell
# 标准无窗口入口
npm run verify:blizzard-cloud-visual

# 真实 GPU 画面入口，在上述 E 盘环境变量已配置后直接启动
& 'D:\Godot\Godot_v4.6.3-stable_win64_console.exe' --path . --disable-file-logging --script res://tools/verify/verify_blizzard_cloud_rendered.gd -- --capture-dir=E:/codex/blizzard-vfx/rendered
```

无窗口验证检查生产工厂装配、隐藏兜底精灵、范围/时长/移动同步、192 粒子预算、运行阶段 RNG、材质隔离、回池重置及跨风格复用。

真实渲染验证使用正式开局与技能施放入口，检查伤害/Chilled、云层与霜层实际像素贡献、暂停前后暴雪区域像素完全一致、到期回池以及八云团压力，并输出生成/持续/暂停/消散截图和指标。

## 本次证据与限制

最终真实渲染：Mobile/Vulkan，NVIDIA RTX 5060，1280×720，关闭 VSync，八云团共 1536 个 GPU 粒子，3 秒受控采样。空场基线帧间隔 P95 0.498 ms，八云团 P95 1.772 ms；这是当前机器的短时整帧间隔，不能解释为单独 GPU 着色耗时，不能推广到低端设备或长期高密度战斗。

真实渲染输出：`E:/codex/blizzard-vfx/rendered-final/`。相关回归矩阵输出：`E:/codex/canonical-refactor/blizzard-vfx-final-verified/`。截图检查捕获并修复了无纹理 Polygon2D 的 UV 不可用问题，改为由顶点坐标插值获得云层平面坐标。

独立代码审查未发现确认的 P1/P2。真实开局仍会输出项目原有的 player/damage_area `icon.svg` UID 回退警告，资源通过文本路径成功加载；本次不修改这些无关场景。
