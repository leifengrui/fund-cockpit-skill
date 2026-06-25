---
name: fund-cockpit
description: 基金整合驾驶舱——输入一个或多个基金代码，依次跑 fund_analysis（联网抓天天基金净值数据）→ famas 单基金深度分析（复用前一步数据；famas 无联网脚本，若模型联网不可用则退化用已抓数据）→ zhengxi-views 郑希框架评分，最后把三方各自归一到 0-10 按 4:4:2 加权，给出最终 0-10 综合分。当用户要"整合分析基金/给基金打个综合分/三合一分析基金代码"时使用。
argument-hint: "[基金代码，多个用空格或逗号]"
arguments:
  - fund_codes
---

# 基金整合驾驶舱 (Fund Cockpit)

把三个既有 skill 串成一条流水线，对给定基金代码输出**一份综合报告 + 一个 0–10 加权综合分**。

## 流水线

```
基金代码(1个或多个)
   │
   ├─ Stage 1  fund_analysis   联网抓天天基金 pingzhongdata/{code}.js → fund_analyzer.py → HTML+JSON
   │                              （净值统计/压力位/周期涨跌/反转/月度，量化信号来源）
   │
   ├─ Stage 2  famas-analyze-fund  单基金深度分析：5 维(业绩/成本/经理/宏观/风控) + 1-5 星
   │                              输入 = Stage1 的 JSON + 模型可联网补充；联网不可用就只用 Stage1 数据
   │
   ├─ Stage 3  zhengxi-views       score_fund.py 自动抓持仓/业绩/规模 → scorecard.md 六维(满分100)
   │
   └─ Stage 4  汇总加权           三方各自归一到 0-10，按 4:4:2 加权 → 最终综合分
```

## 权重方案（均衡三因子）

最终分 = `0.40 × famas适配 + 0.40 × zhengxi契合 + 0.20 × 量化信号`

| 分项 | 来源 | 归一方法 |
|------|------|----------|
| famas适配 | famas 综合星级 + 5 维 | 星级 `★→2×(星数)`，再以 5 维微调 ±，落在 0–10 |
| zhengxi契合 | zhengxi 六维 /100 | `/100 × 10` |
| 量化信号 | fund_analysis JSON | 收益/回撤/波动/净值位置/支撑压力 综合给 0–10 |

分项均须给到小数点后 1 位，并附一句理由。最终分同精度。

## 执行细则（按此顺序，逐个基金）

### Stage 1 — fund_analysis（联网，必跑）

对每个 code：

1. `mkdir -p ./output_fund/{code}/{raw,analysis,report}`
2. 抓数据：`curl -s "https://fund.eastmoney.com/pingzhongdata/{code}.js?v=$(date +%Y%m%d%H%M%S)" -o ./output_fund/{code}/raw/{code}_raw.js`
   - 校验：`grep -o 'fS_name="[^"]*"'` 能取到基金名；取不到说明抓取失败或代码错，停止并报告。
3. 跑分析：`python3 ~/.claude/skills/fund_analysis/scripts/fund_analyzer.py --code {code} --input ./output_fund/{code}/raw/{code}_raw.js --output ./output_fund/{code}/report/report_{code}.html --json-output ./output_fund/{code}/analysis/analysis_{code}.json`
   - 注意用 `python3`（本机 `python` 不存在）。
4. 读 JSON `analysis` 节取量化信号：`max_drawdown`、`volatility.annualized`、`multi_period_returns`、`return_periods`、`pressure_zones.current_price/current_zone_index/support_zones/resistance_zones/analysis_summary`、`net_worth_stats.成立以来`、`monthly_returns`。

### Stage 2 — famas 单基金深度分析

按 `famas-analyze-fund` 的 SKILL.md 流程跑（prospectus→performance/cost/manager 并行→macro→wealth_advisor）。
- **数据来源优先级**：① Stage1 的 JSON（净值/回撤/波动/收益真实值）→ ② 模型联网补充（招募书/季报/经理档案，能 fetch 就用）→ ③ 都没有就标"需核实"，不编。
- famas 自身**没有联网脚本**，联网靠模型 WebFetch；若联网不可用，仅凭 Stage1 数据完成可算维度，缺项标"需核实"。
- 产出：5 维评分(每维0-5) + 综合 1-5 星 + 时机矩阵 + 风险画像 + 核心风险提示（遵守 famas 合规：不出买卖信号、带免责声明）。
- 归一到 0-10：`famas适配 = 2 × 星级 + 五维均值(0-5)归一后的微调`，控制在 0–10。

### Stage 3 — zhengxi 郑希框架评分

1. `python3 ~/.claude/skills/zhengxi-views/scripts/score_fund.py {code}` —— 一条命令出证据档案（自动解析代码、抓持仓/业绩/规模、算集中度/换手代理）。
   - 脚本已自带输出上限，**不要加 `| head`/`2>/dev/null`/`cd`**，否则触发额外确认。
2. 读 `references/scorecard.md`，按六维逐项给分（每维：给分 + 证据带季度 + method 依据 + 拿不准标"需核实"），总分 /100。
3. 归一：`zhengxi契合 = 总分 / 100 × 10`。
4. 守住定位：这是"像不像郑希会买的"，不是基金好坏；防御/红利/纯债天然低分要讲清。

### Stage 4 — 汇总加权

`最终分 = 0.40×famas适配 + 0.40×zhengxi契合 + 0.20×量化信号`（四舍五入到 0.1）。

## 输出格式

对每个基金输出：

```markdown
# 基金整合驾驶舱报告 · {基金名}（{code}）

## 0. 综合分：{最终分}/10
> 一句话定性。

## 1. Stage1 量化信号（fund_analysis）
- 今年以来/近1年/近3月/近1月收益、最大回撤、年化波动率
- 当前净值位置（历史分位、所在区间、最近支撑/压力位）
- 周期胜率/正收益持续期/月度规律要点
- 量化信号分：{x}/10 —— {理由}
- HTML 报告：`./output_fund/{code}/report/report_{code}.html`

## 2. Stage2 综合适配（famas）
- 5 维评分表 + 综合星级
- 时机矩阵 / 风险画像 / 适配投资者 / 核心风险提示
- famas 适配分：{x}/10 —— {理由}

## 3. Stage3 郑希框架契合（zhengxi-views）
- 六维评分表（带季度证据）
- 总分 {x}/100 → {x}/10
- 与郑希风格的差别

## 4. 加权汇总
| 分项 | 得分(0-10) | 权重 | 贡献 |
|------|-----------|------|------|
| famas适配 | {x} | 40% | {x×0.4} |
| zhengxi契合 | {x} | 40% | {x×0.4} |
| 量化信号 | {x} | 20% | {x×0.2} |
| **最终** |  |  | **{最终分}/10** |

---
*免责声明：本报告整合三方 skill 的信息整理与适配度/风格契合度分析，不构成投资建议。基金过往业绩不预示未来表现。郑希框架分衡量风格契合度，非基金优劣判断。*
```

## 多基金输入

- 代码以空格或逗号分隔时，对每只分别跑 Stage1-3，再在 Stage4 并列汇总表（每行一只基金，含三因子分与最终分），便于横向对比。
- 组合级（持仓比例）诊断不在本 skill 范围，交给 `famas-diagnose-portfolio`。

## 边界与合规

- 继承三方合规：不出"买入/卖出/加仓/减仓/清仓"明确信号；所有评级带风险提示；带免责声明。
- 数据溯源：每条关键数字标注来源（天天基金 pingzhongdata / 郑希精编快照 / 全市场缓存）与日期；季度快照标季度。
- 不杜撰：持仓/净值/业绩只能来自脚本输出，无数据标"需核实"。
- 研究学习辅助，非投资建议。
