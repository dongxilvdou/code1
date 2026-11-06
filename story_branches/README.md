# 地下室分支视觉组件

本目录按用户提供的《地下室建模修改执行指南》v1.2 制作。当前工程还没有该文档引用的分支 State 服务；因此新分支的维修、身体核对、档案提交和 K-2 状态采用会话预览，不写正式任务进度。原第十一天结局仍可正常进行。

双击项目根目录「预览地下室改造.cmd」进入真实主场景中的无存档预览。Esc 返回猫视角。七个子场景可以单独打开修改；运行验证从主场景进行。

| 子场景 | 内容 |
| --- | --- |
| `conversion_retrofit.tscn` | 台侧控制盒、独立三灯、拨钮、端口、抽屉、耦合模块、镜头及交互锚点 |
| `vent_service.tscn` | 原位置格栅、左扣、锈断右扣、弯边、铰轴、近景锚点 |
| `recovery_bay.tscn` | 独立维持舱、低细节男性、呼吸、弧形舱盖、观察和苏醒机位 |
| `rescue_stage.tscn` | 分站门口、猫狗视觉演员、担架、鼠运输盒及演员定位点 |
| `memory_vignette.tscn` | 纯视觉笼、当前猫外观、研究员衣袖与手、旧毯子 |
| `maintenance_box.tscn` | 电脑桌下维修盒、吊条、三位数字窗、左开门及 K-2 托槽 |
| `k2_device.tscn` | 独立设备壳、按键、三灯、接触点及挂带锚点 |

`data.gd` 保存叙事文字；`visual_state.gd` 接收快照并更新可见性与姿态。`inspection.gd` 提供四页终端及开发预览；`memory_player.gd` 播放第九天护理短闪回；`k2_attachment.gd` 是未缩放 Miso 根下的胸前预览挂点。

`apply_visual_state(snapshot)` 可重复调用，会清除上次未完成的动画。`play_action(action)` 支持 drawer、module、emergency、vent、hatch、box、k2_press、care。视觉组件不自行消费物品或设置任务标志。终端预览发出 `submission_requested(action, preview_snapshot)`，正式分支控制器接入前不连接存档提交。

在 Godot 中运行 `tools/build_branch_basement_models.gd` 可重建上述七个新场景。它不会重写旧实验室、笼子或别墅。生成器保留明确的尺寸和命名部件，正式编辑需同步 `model_builder.gd`，避免重建时丢失修改。

完整评估、验收与待接线内容见 [交接记录](../docs/BASEMENT_GUIDE_REVIEW.md)。
