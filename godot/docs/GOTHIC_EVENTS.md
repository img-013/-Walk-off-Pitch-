# 哥特事件原型 1.0

## 使用
打开 scenes/main.tscn 运行。首页「事件调试」或 Esc →「开发调试 · 事件画廊」可直接查看十个事件。
调试使用独立 RunState（100 金币、20 生命、示例辅助规则、协议开启），不保存、不覆盖真实远征；完成事件或返回主页恢复原对象。
正常远征事件节点仅从十个独立 gothic_* ID 中等概率抽取（各10%），不再包含旧许愿井，不限制章节。

## 编辑入口
- scenes/ui/EventScreen.tscn：单一可编辑的 Control 场景，左侧约55%插画、右侧40%文字，滚动容器容纳长选项。
- data/events.json：十个事件的标题、故事、选项、成本、待执行效果、结局、插画和章节条件。
- scripts/event_director.gd：纯数据事务、统一 RNG、候选列表和替换校验；界面不抽随机数。
- scripts/main.gd：场景展示、原事件保留、地图进入/退出和调试入口。
- scripts/run_state.gd：战斗开始消费一次性事件效果；免费改骰复用 use_tactical。
- scenes/ui/MainMenu.tscn：独立主菜单布局，第11张插画；开始、继续、设置、退出。
- resources/event_theme.tres / event_title_font.tres：复用现有按钮资源，暗金悬停、思源宋体标题、清晰正文。字体及 OFL 许可证在 art/fonts/gothic。
- art/events：11张原始插画及静态边缘渐隐 shader；没有动画、粒子或镜头运动。
- scripts/cabaret_audio.gd：第二、三章地图播放对应 MP3，其余场景使用原主题，沿用音乐总线和音量设置。

## 数据与边界
沿用 s.hp/maxHp/gold/rules、spend()、capacity()、card.exclusive_group；不修改现有卡牌或战斗公式。
activeEvent 保存 id、stage、骰点、候选、替换目标和结果。choice 只能提交一次；result 只能离开一次。重铸在最终选卡前保留原规则，读取存档继续同一事务。
pendingEventEffects 写入原远征存档：hp_loss、shield、tokens、pot、free_increment。在 start_battle 初始化后读取并立即清除。
初始护盾使用原 carryShield，只作用首回合；免费改骰只限下一场战斗，先于战术筹码消耗，不会触发第三掷或卡牌专属改骰效果。
鱼市筹码以 eventCarriedTokens 暂存已有筹码资源的入场转移量，地图可见，进入下一场转到 tacticalTokens 并清除；不是另一种货币。
公共赌注上限、战术筹码上限读取 BattleProtocol.config（当前6和2）。协议关闭时依赖选项禁用；若领取后主动关闭协议，对应待执行效果在下次入场过期，不修改原版战斗规则。
主动支付生命沿用原事件的生存约束，须剩至少1生命；随机审判与契约入场代价可致命，界面明示。治疗不超上限，结局显示实际回复量。
镜中定向寻牌依据现有 school 和双向 synergies ID；候选不足3张时显示实际数量，不凭空生成规则。
新事件完成直接 finish_node，保留原地图进度及 node_gold 效果；不叠加旧脚本的额外里程碑随机奖励。旧许愿井代码保留，但不再进入事件池。

## 验证
- tests/event_faceless_check.gd：首先验证通用界面与无面庄家完整流程。
- tests/events_check.gd：6635项断言，覆盖10事件全部选项、多种随机种子、重复领取、资源下限、满槽、互斥、重铸事务、协同候选、下一场效果、赌注/筹码上限和免费改骰。
- tests/events_ui_check.gd：实际加载全部场景，逐一点击10事件离开及结果按钮、恢复原状态、音乐切换、截图。
- tests/battle_protocol_check.gd：32项协议检查，1072个旧战斗用例保持无差异。
运行例：Godot --headless --path <项目目录> --script res://tests/events_check.gd

本次未发布网页或推送 GitHub。
