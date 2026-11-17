# 资产与呈现说明

当前酒馆来自用户提供的 TapNow 哥特歌舞厅 GLB，主音乐来自用户的“main 背景.mp3”。原文件内容保留，本项目不另行声明这些素材的许可。可编辑场景中调整了灯光、镜头和骰子位置。

骰体采用 [Modanung 的 Low poly dice](https://opengameart.org/content/low-poly-dice-with-lods)，CC0。保留模型外轮廓，移除固定点数，六面由 Godot 控制。

旧场景资产作为备份保留，目前入口不使用：

- [AnyRPG — Medieval Tavern Interior](https://opengameart.org/content/medieval-tavern-interior)，CC0。
- [Ulan Cabanilla / Poly Haven — Round Wooden Table 01](https://polyhaven.com/a/round_wooden_table_01)，CC0。

遗物与敌人图集沿用用户此前提供的素材。用户和第三方素材不因代码仓库许可而自动重新授权。

四种短音效为本项目原创合成，未使用第三方采样。生成器为 `scripts/cabaret-sounds.cjs`，可直接替换四个 WAV。悬停使用失谐高音，点击与掷骰结合木质敲击，揭晓使用不协和分解和弦。

主音乐约 153.17 秒，淡入并循环，切换页面不重启。按文件首尾接续，不保证原曲本身为无缝循环。音乐和音效开关分别保存至 `user://presentation.cfg`，检查器中可以调整各自音量。

默认滤镜为 12 级黑白灰阶、2.5 像素采样、有序抖动、轮廓压暗与暗角。滤镜在 UI 下方，文字保持清晰。设置中可以关闭滤镜查看琥珀烛光、灰绿环境光和暗红边光。烛火只作小幅连续波动，不使用突发闪屏。

滤镜实现遵循 [Godot 屏幕采样说明](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)，音乐循环使用 [AudioStreamMP3.loop](https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html)。
