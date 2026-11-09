# 数据库与工程约定

`data/cards.json` 是卡牌唯一编辑源，`data/enemies.json` 是敌人唯一编辑源。构建嵌入 HTML，不运行时 fetch，本地双击可用。CSV 和卡牌 Markdown 是只读导出；编辑它们不会改变游戏。

## 关键字段

| 字段 | 意义 |
|---|---|
| schema_version / content_version | 数据形状版本 / 内容版本；不能混为存档版本 |
| id | 稳定 ID，改名不改 ID；删除或改语义需写变更记录 |
| name / description | 中文名称及精确玩家可见卡文 |
| status | implemented 或 planned；后者不进入运行时牌池 |
| rarity / reward_weight / price | 显示稀有度、抽取权重、商店价格 |
| family / role | 流派及 enabler、converter、reward、safety 等设计定位 |
| slot / exclusive_group / stacking | 核心或被动位置、互斥组、唯一持有规则 |
| effect_key / phase / params | 注册效果名、主显示阶段、数值参数。复合卡可跨阶段，具体顺序由引擎契约定义 |
| synergies / tensions | 有用搭配与机会成本。仅核心互斥是硬限制，其他张力可以同时装备 |
| reference_ids | 机制启发来源，关联研究报告，非原作技能对照 ID |
| trigger_limit / balance_note | 触发约束与当前平衡状态 |

Schema 为编辑器提供基础类型提示，`scripts/validate.cjs` 额外检查跨牌引用、ID 唯一、效果注册、状态和数值。两者不等于所有文案语义都已自动证明；修改卡面仍要更新例子测试。

## 执行边界

`src/engine.js` 的 `evaluate(state, database)` 不修改输入、不读 DOM、不抽随机数、不发金币。返回比分、实际伤害、胜负、金币增量、结构化来源事件及文本轨迹。

界面执行结算时先保存输入快照，再调用引擎，播放效果，最后一次性应用结果。`busy` 阻止动画期间重复提交；已死亡目标不能再次发放击败奖励。预览使用同一函数而不应用结果。

对于单骰规则，计分卡的主效果停用，复合卡伤害副作用仍按文字约定执行。规则栏有停用标识；图鉴给出搭配取舍。

## 随机、存档、诊断

- 随机使用固定算法和 `state.rng`。每局保存初始 seed，地图完成点保存当前 RNG 状态。
- `walkoffpitch-v06` 存档 version 为 6；旧版 `dicebound-v05` 不读取、不删除。
- 保存的是地图节点完成后的状态，不承诺战斗中恢复。刷新回到最近完成节点，同一动作序列得到同一随机序列。
- 诊断导出包括版本、初始 seed、结算前输入、输出和最多 2,000 条已记录动作。它可以离线重算**该次结算**，不等于完整 UI 回放协议。
- 诊断保存在玩家本地；没有后台收集、上传或第三方分析脚本。提交 Issue 时由玩家自行附上。

## 改一张卡的流程

1. 修改 `cards.json` 的卡文、参数、关联与状态。
2. 新 effect_key 先在引擎注册，添加正例、未触发例和关键冲突例。
3. 完成集成前保持 planned；开放时同步测试中的卡数、图鉴计数与文档。
4. 运行 `node scripts/check.cjs`，确认生成文件可重建；平衡变化再运行 `node scripts/simulate.cjs`。
5. 若改变 UI，再做真实桌面及窄屏浏览器检查。DOM 替身测试不能当截图验收。
6. 更新版本和 CHANGELOG，提交 JSON、源代码、测试及生成文件。


## v0.8 字段追加

`pool_class` 按 U/S/B/K 互斥统计；`display_class` 按 economy/assistance/school/gameplay 互斥统计。`school` 只填写40张专属牌；`serves` 是可服务方向，不能据此重复计数。`bridge_pairs` 必须对应可执行联动；`effects` 保存声明式条件与操作。`compatible_cores` 是设计声明，实际可用证据见 compatibility80.json。计分与改面等特殊效果使用 effect_key 分派；所有80个 key 均有处理器与测试。LBL 参考为幸运房东官方商品说明，未声称其开发者采用本项目的封顶机制。
