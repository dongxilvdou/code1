# 开发与目录说明

## 当前入口

- `project.godot`：Godot 4.7.1，Forward+；主场景是 `scenes/main.tscn`。
- `scripts/game.gd` 管理菜单、开始/继续、音量和视角；`scripts/villa_game.gd` 接入房间、门及可选彩蛋。
- `scenes/player.tscn` 的 `Miso` 是现有 CharacterBody3D。当前猫包装为 `scenes/calico.tscn`，实际使用 `assets/models/pets/house_cat.glb` 与 `scripts/imported_cat.gd`。文件入口名保留 Calico，不代表仍使用早期程序猫。
- `scenes/cat_studio.tscn`、根目录「查看猫模型.cmd」查看当前猫模型；较早的程序化建模源文件保留供对照，不作为当前玩家的默认替代品。

## 地图与家具

当前地图在 `scenes/villa.tscn`；一层、二层、楼梯、屋顶、花园、地下室按节点分组。家具实例位于各楼层的 `Furnishings`，复用 `furniture_pack/scenes/` 中的场景。

- `scripts/villa_builder.gd`：建筑主体和场地。
- `scripts/villa_furnishings.gd`：家具位置与稳定编号；已删除的编号会保留空位，以免改变主场景中的家具引用。
- `furniture_pack/villa_layout.json`：当前布局清单，坐标以建筑西北角为原点，单位米。
- `scripts/villa_basement.gd`、`scenes/basement/medical_laboratory.tscn`：地下楼梯与医学实验室。
- `furniture_pack/authoring/`、`furniture_pack/models/`：可编辑 Blender 源文件与导出的 GLB。

修改已有地图时直接编辑场景，并同步维护相应的生成配置。`tools/build_villa.gd` 会重新生成场景，不能用它替代保留手工修改的普通保存操作。实际显示和任务交互还可能由 `day*/world.gd` 或 `act*/world.gd` 调整，因此不能只同步 `scenes/`。

角色和家具均以米为单位，Y 向上。通过玩家的 `cat_scale` 调整体型；保持碰撞体直立，不通过倾斜碰撞节点模拟缩小。GLB 提取出的同目录贴图属于正式依赖，需要和模型一起提交。

## 剧情与任务

`day1/daily_notes.gd` 保存每日任务清单与确认规则。`DayOne` 同时承载共享状态及 HUD，其他章节复用它；目录名不表示其内容只在第一天使用。

| 内容 | 主要入口 |
| --- | --- |
| 第 1、2 天 | `day1/day_one.gd`、`day2/day_two.gd` |
| 第 3–5 天 | `act2/chapter.gd`、`act2/puzzles.gd` |
| 第 6、7 天 | `act3/chapter.gd`、电脑和电路组件 |
| 第 8–11 天 | `act4/chapter.gd`、`act4/world.gd` |
| 地下室结局 | `ending/chapter.gd`、`ending/world.gd`、`ending/film.gd` |
| 通用任务目录、状态与保存 | `act2/quests/catalog.tres`、`quest_system/` |

修改任务时保留既有 ID、存档字段及跨天状态。一次性道具的显示与碰撞由任务日期和完成标记恢复；不能仅删除画面上的模型。读完当日清单才解锁任务，开始新游戏与继续已有存档分别走原入口。

## 开场、彩蛋与音频

- 漫画：`assets/cinematics/comic/README.md`、`opening_book.json`、`scripts/cinematics/opening_cutscene.gd`。当前为四页九格、约 55 秒，不再使用旧版 28 秒 3D 运镜。
- 大狗：`scripts/cinematics/dog_secret.gd`。
- 次卧按钮：`scripts/cinematics/bedroom_secret.gd`。
- 电视和香蕉：`scripts/cinematics/house_memes.gd`。
- 环境声：`scripts/environment_ambience.gd`，维护说明在 `assets/audio/summer_afternoon.md`。
- 药瓶音效：`tools/build_medicine_audio.py`，说明在 `act3/audio/medicine_sound_notes.md`。

正常运行使用工程内转换后的音视频，不要求原始 MP4/AAC 路径存在。重新制作资源时才需要相应的 Python、Blender 或 FFmpeg 环境。

透明的视频解码 Control 必须保留 `MOUSE_FILTER_IGNORE` 和 `FOCUS_NONE`，否则会遮住鼠标视角。过场独立处理进入、结束、取消和状态恢复；游戏主音量设置始终有效。

## 运行和截图

以 Windows 本机 Godot 路径举例：

```powershell
& 'C:\zGoDot\Godot_v4.7.1-stable_win64_console.exe' --headless --editor --path . --import --quit
& 'C:\zGoDot\Godot_v4.7.1-stable_win64_console.exe' --path . --script res://tools/capture_showcase.gd
```

第二条命令从当前真实场景生成 `previews/showcase/`，禁用正常存档；不会替换游戏场景。`previews/.gdignore` 使文档截图无需进入 Godot 的资源导入过程。旧的家具与地图截图工具仍可保留供开发使用，生成目录有需要时才重新创建。

## 验证与边界

| 工具 | 检查内容 |
| --- | --- |
| `tools/playtest_opening.gd` | 漫画推进、跳过、进入游戏、继续存档 |
| `tools/playtest_mouse_look.gd` | 实机鼠标、暂停、已有彩蛋结束/取消后的恢复；需要窗口 |
| `tools/playtest_imported_pets.gd` | 猫狗绑定、动作、跳跃、前爪及上下楼 |
| `tools/playtest_act4_polish.gd` | 第 8–10 天任务与相关道具 |
| `tools/playtest_environment_ambience.gd` | 室内外音量、循环和过场音量接管 |
| `tools/playtest_house_memes.gd` | 电视/香蕉交互、短片结束及复原 |
| `quest_system/tests/` | 通用任务管理和持久化 |

测试必须在加入场景树之前设置 `QuestSystem.save_enabled = false`，或使用隔离的测试存档路径，避免改动正常进度。仅用 `--autoplay` 并不能替代禁用存档。

部分历史测试包含旧版任务总数和固定摆放假设，不能把过去的通过记录当作当前全流程保证。此前 `playtest_five_day_props.gd` 在“固定 20 条任务”的断言及第三天浇水准备环节有失败；本次文件整理没有改动这些玩法，也没有将该脚本宣称为全绿。游戏退出仍可能打印原有 ObjectDB、resource 或 Texture RID 释放警告。

## 协作与保留规则

- 运行资源、建模源文件、生成工具、验证工具、`.uid` 和正式资源旁的 `.import` 都有用途，保留在仓库中。
- `.godot/`、旧日志和临时截图属于本机产物。文档图片统一保存在 `previews/showcase/`，不要再把旧批量预览作为当前截图。
- 通过 `git status --short` 检查本次改动，再按实际文件暂存；功能修改走分支和 Pull Request，审核后合并主线。
- 仓库包含自制内容和用户提供的模型、音视频素材；资源来源与制作方式保留在相应目录说明中，仓库目前未设置统一的 LICENSE 文件。
