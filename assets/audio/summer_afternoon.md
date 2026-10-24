# 夏日午后环境声

来源：用户提供的 `C:\zGoDot\3D\音频\【午安】农村夏日午后白噪音.aac`。
完整约 17 分钟的录音转换为 `summer_afternoon.ogg`，44.1 kHz 立体声 Vorbis，
保留原内容；原文件不修改。为降低花园里的沙沙底噪，使用轻度固定底噪抑制，
并将此前 16 dB 的增益降到 10 dB，避免把录音噪声过度放大。
实机核对确认正常花园只有这一条环境音在循环，旧雨声没有叠加播放。

`scripts/environment_ambience.gd` 负责循环和房屋内外音量：

- 室内与地下室 -28 dB，室外与二楼露台 -8 dB，约 1.5 秒平滑过渡。
- 根据现有房屋尺寸、露台分区以及猫的位置判断，8 厘米门槛缓冲避免反复切换。
- 连续播放，进出房屋不会从头开始；主音量设置仍有效。
- 漫画开场及彩蛋进行时让原有过场系统管理音量，结束后恢复房间混音。
- 原有 `rain_audio` 引用保留供过场使用，但播放内容已替换为夏日环境声。

转码参数：`-map 0:a:0 -vn -c:a libvorbis -q:a 3 -ar 44100 -ac 2 -af highpass=f=60,afftdn=nr=9:nf=-55:gs=6,volume=10dB -map_metadata -1`。
可调整控制器的 `indoor_volume_db`、`outdoor_volume_db` 和 `transition_seconds`。
