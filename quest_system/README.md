# 可配置任务系统

适用于当前猫屋日记别墅工程。已在 Godot 4.7.2 实际运行。功能由主场景中的一个 `QuestSystem` 实例挂载，不需要注册 Autoload，不需要修改玩家、门或地图脚本。

## 玩一下

- 当前任务显示在左侧小地图下方，显示目标计数、完成勾选和探索积分。
- 面板按目标、提示和页脚的实际换行高度自动伸展。屏幕空间不足时整条收起目标，显示“更多目标请按 J 查看”，避免出现半行文字。
- 按 J 打开任务日志。可查看所有任务、前置条件和结果，接取可用的支线。
- J / Esc 返回；从暂停状态打开日志时，关闭后返回暂停。
- 日志中的“重新开始任务…”会先弹出确认。确认后重置任务进度、任务标记和任务积分，不重置角色位置或门的状态。
- 大地图、暂停、设置、看猫及房屋总览期间隐藏任务栏。任务日志打开时停止移动。
- 每次任务进度、状态或任务变量改变后自动保存。游戏的位置、门、音量等不属于这份任务存档。

默认主线：

| 任务 | 目标 | 结果 |
| --- | --- | --- |
| 初来乍到 | 到达客厅；按 Q 喵叫一次 | 5 分，开启一楼巡游 |
| 一楼巡游 | 到达餐厅和厨房 | 10 分，设置 downstairs_done，开启楼上任务 |
| 楼上的风景 | 到达书房和露台 | 15 分，设置 upstairs_done，开启花园任务 |
| 去花园走走 | 接取后用 E 打开一扇门；到达北侧花园 | 20 分，设置 villa_explored |
| 回应这座家（支线） | 在日志接取后，按 Q 喵叫三次 | 5 分，设置 home_greeted |

第五项任务展示 ANY 前置、额外标记条件和手动接取。主线共 50 分，全部任务共 55 分。积分会实际累计到任务系统内，任务标记也会实际保存；当前工程没有消费积分的商店。

## 修改现有任务

1. 在 Godot 的 FileSystem 中打开 `res://quest_system/definitions/`。
2. 双击任意任务 `.tres`，在 Inspector 中编辑 Title、Description、Result Text。
3. 展开“前置条件 / Prerequisites”。在 Prerequisite Quests 数组中增加槽位，把已有任务 `.tres` 拖入。
4. Prerequisite Mode 选择 ALL 表示全部完成，ANY 表示完成其中任意一个。数组为空表示无需前置任务。
5. Extra Conditions 可以增加 CalicoQuestCondition。FLAG_EQUALS 检查标记值，VALUE_AT_LEAST 检查任务数值达到门槛。全部额外条件与前置任务组同时满足才可接取。
6. Auto Accept 勾选表示满足条件后自动接取；取消勾选则在 J 日志中显示“接取任务”按钮。
7. 展开 Objectives，修改目标文字 Text、类型 Kind、数量 Target Count。
8. 展开 Success Results，配置完成时执行的结果；Failure Results 配置失败时的结果。填写 Result Text 只改变说明文字，不代替实际结果条目。
9. 保存资源，重新运行。调整已运行任务的目标或条件后，使用 J → 重新开始任务，避免旧进度影响验证。

`ID` 用于稳定存档身份，标题可自由修改。已有存档发布后，不应直接更换任务或目标 ID。重复任务 ID、重复目标 ID、空目标、缺失的前置引用和循环依赖会在初始化时报错。

## 新增一个任务

1. 在 definitions 文件夹右键 → 新建资源 → 搜索 **CalicoQuest**。
2. 保存为新的 `.tres`，填写唯一 ID（例如 `q06`）、标题和说明。
3. 在 Objectives 中新建 CalicoQuestObjective，填写该任务内唯一的目标 ID、Text、Kind，以及类型对应的对象字段。
4. 按需要设置前置任务和结果。
5. 打开 `catalog.tres`，在 Quests 数组中增加一格，将新任务拖进去。所有前置任务也必须在此目录资源中登记。
6. 保存后重新运行。主线优先显示，Priority 越大越靠前；左侧最多显示两个进行中的任务，其余可在 J 日志查看。

复制任务资源时修改新任务 ID；如果多个任务有意共用子资源，修改会影响所有引用它的任务。需要独立修改时先 Make Unique。

## 目标类型与字段

| Kind | 配置字段 | 实际计数时机 |
| --- | --- | --- |
| ENTER_ROOM | Room Id 下拉选择区域 | 从其他区域进入所选区域，初次开始也检查所在区域 |
| MEOW | Target Count；Target Id 留空 | 角色实际发出喵叫事件；遵循原游戏冷却 |
| OPEN_DOOR | Target Id 留空表示任意门；也可填写门节点名 | 玩家按 E 操作的门完成开启动画，且没有被挡住 |
| CUSTOM | Target Id 填自定义事件 ID | 其他游戏系统调用 report_event 时 |

房间 ID 和小地图使用同一份区域定义，识别楼层时也沿用地图的脚下碰撞判定。

| Room Id | 区域 |
| --- | --- |
| floor_1/living、dining、kitchen | 一层客厅、餐厅、厨房（分别选择完整下拉项） |
| floor_1/guest、bathroom、laundry、hall | 一层客卧、卫生间、洗衣间、过厅 |
| floor_2/master、bedroom_a、bedroom_b | 二层主卧、次卧 A、次卧 B |
| floor_2/study、bathroom、dressing、reading、terrace、hall | 二层书房、卫生间、衣帽储物、阅读角、露台、过厅 |
| garden/any | 任意室外花园区域 |
| garden/north、south、west、east | 北侧花园、入户庭院、西侧、东侧 |
| stairs/any | 楼梯任一区域 |
| any | 任意区域 |

目标只统计接取后的事件。已完成过的动作不会追溯；同一个进入事件也不会同时推进由它刚刚解锁的下一个任务。站在同一房间不会每帧加一；接取后需要离开并重新进入，除新游戏/重置时主动检查一次当前区域。

所有目标满足才完成任务。接取之后，不因前置标记改变而退回未解锁。第一版任务不循环、不自动失败、不设限时；外部系统可显式调用 fail_quest 执行失败流程。

## 结果类型

| Kind | 如何填写 | 实际效果 |
| --- | --- | --- |
| SET_FLAG | Key 标记 ID；Flag Value | 写入任务状态中的布尔标记，可用于后续前置条件 |
| ADD_VALUE | Key 数值 ID；Amount | 给任务数值加上数量，例如 exploration_points |
| EMIT_EVENT | Key 自定义事件 ID | 发出 manager.custom_result 信号，供场景或剧情逻辑订阅 |

SET_FLAG 与 ADD_VALUE 会和任务完成状态一起存档，读档不重复发奖。EMIT_EVENT 用来调用另外编写的剧情/表现逻辑，不会自动找到或打开某扇门；持久性的开门、道具、剧情效果应以保存的标记为依据，在场景进入时恢复。当前示例只解锁后续任务，没有锁住原地图的任何房间或门。

需要接入新玩法时，在组件初始化后取得管理器：

```gdscript
var tasks = get_tree().current_scene.get_node("QuestSystem").manager

# 剧情系统通知接取条件变化。
tasks.set_flag(&"found_key", true)
tasks.set_value(&"friendship", 10)

# 喂食实际成功时，再投递自定义事件。
tasks.report_event(CalicoQuestObjective.Kind.CUSTOM, &"feed_cat", 1, "feeding:0001")

# 订阅任务结果中的 EMIT_EVENT。
tasks.custom_result.connect(func(event_id: StringName):
    if event_id == &"show_ending":
        print("在这里连接你的结尾剧情")
)

# 可选的失败流程。
tasks.fail_quest(&"q06")
```

请在初始化完成后调用：主场景中的其他脚本可用 `call_deferred()` 延后接线。每次真实行为应有新的 event_id；同一行为重试则复用 ID。最近 1024 个显式事件 ID 会保存并去重，适合事件重试，不是无限期的物品防重记录。拾取物品等永久性状态仍应由背包系统负责。

## 组件设置与存档

在主场景选中 QuestSystem 实例可修改：

- Catalog：任务目录资源。
- Tracker Width：任务栏宽度，默认 280 逻辑像素。
- Gap Below Map：与小地图底边的间距，默认 12。
- Player Path、Map Path：场景层级更改后重新指定对应节点。
- Save Enabled：是否自动保存。
- Save File：任务存档路径，默认 `user://calico_quests_v1.json`。

副本的主场景覆盖 Save File 为 `user://calico_quests_demo_v1.json`，避免副本试玩记录混入原项目正式任务记录。将默认组件拖进原项目会使用正式文件名。

存档位于 Godot 的 user:// 用户数据目录，不在提交的项目文件夹中。可以从 Godot 的“项目 → 打开用户数据文件夹”找到它。损坏或不支持的存档会被保留并停止自动覆盖，日志中显示原因；只有用户确认重置后才用新进度覆盖。

任务模块目前随主游戏场景存活。如果以后把游戏拆成多个根场景，应保证每个场景使用同一保存路径、正确设置节点路径，或将管理器移到常驻场景，并调整挂载方式。

## 导出与测试

默认 catalog 用显式资源引用，任务数据随场景依赖进入导出包。继续遵循原地图资源的导出要求，特别是 layout.json 和动态加载的地图贴图。

可运行以下测试；把 GODOT_EXE 换成本机 Godot 程序路径，并在项目根目录执行：

```text
GODOT_EXE --headless --path . --script res://quest_system/tests/test_quests.gd
GODOT_EXE --headless --path . --script res://quest_system/tests/test_game.gd --fixed-fps 60 -- --quest-test
GODOT_EXE --headless --path . --script res://quest_system/tests/test_persistence.gd --fixed-fps 60
GODOT_EXE --headless --path . --script res://quest_system/tests/test_tracker_layout.gd --fixed-fps 60 -- --quest-test --check-overflow
```

前两项分别验证逻辑和实际主场景接入；第三项只使用测试专用存档，检查跨场景重载、主动重置和坏文件保护。tests 文件夹不是运行游戏的必要依赖，可以不随最终项目提交；需要回归测试时保留。

第四项专门检查两行页脚、完成提示、长文字、窄面板和可用空间变化，逐条验证显示的目标没有被裁切。
