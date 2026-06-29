# fund-cockpit · 基金整合驾驶舱

这是一个最终版基金分析skill，数据接口都已经配置好，你可以通过examples先看看效果是否满意。
通过把三个既有基金分析 skill 串成一条流水线，输入一个或多个基金代码，输出**一份综合报告 + 一个 0–10 加权综合分**。
完全免费 只求一个star
```
基金代码 → Stage1 fund_analysis（联网抓天天基金净值数据）
        → Stage2 famas 单基金深度分析（5 维 + 1-5 星）
        → Stage3 zhengxi-views 郑希框架评分（六维 /100）
        → Stage4 三方各自归一到 0-10，按 4:4:2 加权 → 最终综合分
```

**最终权重**：`0.40 × famas适配 + 0.40 × zhengxi契合 + 0.20 × 量化信号`

## 仓库结构

```
fund-cockpit/
├── skills/fund-cockpit/SKILL.md   # 主 skill（编排三阶段）
├── install.sh                     # 软链安装到 ~/.claude/skills/
├── vendor/                        # 三个依赖 skill 的源码副本（自包含，clone 即可用）
│   ├── fund_analysis/             # 联网抓天天基金 pingzhongdata + 净值分析
│   ├── FAMAS-Skill/               # famas 单基金深度分析（prompt 编排）
│   └── zhengxi-views/             # 郑希框架评分（score_fund.py + scorecard.md）
├── README.md  LICENSE  .gitignore
```

`vendor/` 下是依赖项目的**精简副本**：zhengxi-views 只保留了 fund-cockpit 实际调用的部分（scripts + scorecard/method + 全市场基金列表 + 郑希基金快照），跳过了语料 corpus 与运行时缓存。

## 安装

依赖：`python3`、`curl`。zhengxi-views 的可选 Python 依赖见 `vendor/zhengxi-views/requirements.txt`。

```bash
git clone <本仓库地址> ~/codes/fund-cockpit
cd ~/codes/fund-cockpit
bash install.sh
```

`install.sh` 会把 4 个 skill 软链进 `~/.claude/skills/`：

| 软链 | 指向 |
|------|------|
| `~/.claude/skills/fund-cockpit` | `skills/fund-cockpit` |
| `~/.claude/skills/fund_analysis` | `vendor/fund_analysis` |
| `~/.claude/skills/famas-analyze-fund` | `vendor/FAMAS-Skill/.claude/skills/famas-analyze-fund` |
| `~/.claude/skills/zhengxi-views` | `vendor/zhengxi-views` |

重启 Claude Code 会话后即可使用。

## 用法

在 Claude Code 中：

```
fund-cockpit 026213
fund-cockpit 020602 090010
fund-cockpit 026213,110011,090010
```

多基金输入会逐只跑三阶段，再出横向对比表。

## 输出示例

每只基金输出：

- **综合分**（0–10）+ 一句话定性
- **Stage1 量化信号**：收益/最大回撤/年化波动/净值位置（历史分位、支撑压力位）/周期胜率/月度规律；附 HTML 报告路径
- **Stage2 综合适配（famas）**：5 维评分 + 星级 + 时机矩阵 + 风险画像 + 适配投资者 + 核心风险提示
- **Stage3 郑希框架契合（zhengxi-views）**：六维评分表（带季度证据）+ 总分 /100 + 与郑希风格差别
- **加权汇总表**：三因子分、权重、贡献、最终分

所有输出均带数据溯源（天天基金 pingzhongdata / 郑希精编快照 / 全市场缓存 + 日期）与免责声明。

## 数据来源

- 天天基金 `fund.eastmoney.com/pingzhongdata/{code}.js`（净值/收益/仓位）
- 天天基金公开持仓/业绩/规模（经 zhengxi-views 脚本抓取，季度快照）
- 郑希 8 只基金的精编快照（`vendor/zhengxi-views/references/fund_data/`）

持仓/净值/业绩为**季度快照**，引用时标注季度与日期，不杜撰；无数据项标注"需核实"。

## 设计取向说明

这套 4:4:2 加权里，famas 综合适配度与郑希框架契合度各占 40%，量化信号占 20%。因此**科技景气方向的基金**（如半导体/AI 算力）在郑希维度天然拿高分，最终分偏高；**红利/消费/纯债等防御型基金**在郑希维度拉胯，最终分偏低——这是设计取向，不是绝对优劣判断。郑希契合分衡量的是"像不像郑希会买的基金"，**非基金好坏**。改权重方案见 `skills/fund-cockpit/SKILL.md`。

## 合规与边界

- 不输出"买入/卖出/加仓/减仓/清仓"等明确交易信号
- 所有评级附带风险提示与免责声明
- 研究学习辅助，不构成投资建议；基金过往业绩不预示未来表现

## 致谢

本仓库 `vendor/` 下整合了三个独立项目的能力：
- **fund_analysis** —— 天天基金净值数据分析 + HTML 报告
- **FAMAS-Skill**（[xiangyupaiso/FAMAS-Skill](https://github.com/xiangyupaiso/FAMAS-Skill)）—— 基金智选多智能体分析系统
- **zhengxi-views**（[lyra81604/zhengxi-views](https://github.com/lyra81604/zhengxi-views)）—— 郑希观点库 + 框架评分

fund-cockpit 只做编排与加权汇总，三阶段的具体能力与合规约束继承自上述项目。
