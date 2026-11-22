# FundR <a href="https://tony2015116.github.io/FundR/"><img src="docs/reference/figures/logo.svg" width="120" align="right" alt="FundR logo"></a>

[![GitHub R package version](https://img.shields.io/github/r-package/v/tony2015116/FundR)](DESCRIPTION)
[![GitHub last commit](https://img.shields.io/github/last-commit/tony2015116/FundR)](https://github.com/tony2015116/FundR/commits/master/)

FundR 是一个从东方财富天天基金获取基金目录和历史净值的 R 包。用基金名称查找六位代码，再按代码下载指定日期范围的历史净值。各函数均返回 R 的 `data.frame`，可直接用于筛选、绘图和导出。

| 函数 | 用途 |
| --- | --- |
| `fund_list()` | 获取基金代码、名称和类型 |
| `fund_nav(fund_code, start_date = NULL, end_date = NULL)` | 获取一只基金的单位净值、累计净值和日增长率 |
| `fund_period_returns(fund_code)` | 查询近 1、3、6、12 个月的已公布收益率 |
| `fund_risk_review(nav, max_drawdown_pct)` | 复核历史区间收益和最大回撤是否达到个人设定的上限 |
| `fund_profile(fund_code)` | 查询管理人、产品规模、费用和业绩比较基准 |
| `fund_company(company_id)` | 查询公司规模、产品数量、经理人数与成立日期 |
| `fund_manager_history(fund_code)` | 查询独管和共管区间、起止日期及团队任职回报 |
| `fund_allocation(fund_code)` | 按报告期查看股票、债券和现金占基金净资产的比例 |
| `fund_holdings(fund_code, asset_type)` | 查询最近一期已披露股票或债券的代码、名称、净值占比 |

## 一、安装

在 R 或 RStudio 中运行以下命令。

```r
# 首次使用时运行 install.packages("remotes")
remotes::install_github("tony2015116/FundR")
```

安装时会处理 `httr2` 和 `jsonlite` 等依赖。查询数据需要联网。

## 二、按名称查找基金

```r
library(FundR)

funds <- fund_list()
matches <- subset(funds, grepl("华夏成长", fund_name, fixed = TRUE))
matches
```

| 列名 | 类型 | 含义 |
| --- | --- | --- |
| `fund_code` | 字符 | 六位基金代码，保留前导零 |
| `fund_name` | 字符 | 天天基金返回的基金名称 |
| `fund_type` | 字符 | 天天基金返回的基金类型 |

同一个关键词可能匹配多个产品或份额。先核对名称和代码，再将所需代码传给 `fund_nav()`。

## 三、下载历史净值

以下示例查询基金 `000001` 在 2024 年 1 月 2 日至 1 月 31 日公布的净值。

```r
nav <- fund_nav(
  fund_code = "000001",
  start_date = "2024-01-02",
  end_date = "2024-01-31"
)
head(nav)
```

每次查询传入一个六位字符代码，例如 `"000001"`。起止日期可用 `Date` 对象或 `YYYY-MM-DD` 字符串，两端都包含当天。省略某个日期时，该边界由数据源决定。函数自动请求后续页面，按净值日期升序返回结果。

| 列名 | 类型 | 含义 |
| --- | --- | --- |
| `fund_code` | 字符 | 基金代码 |
| `date` | `Date` | 净值日期 |
| `unit_nav` | 数值 | 单位净值 |
| `cumulative_nav` | 数值 | 累计净值 |
| `daily_return_pct` | 数值 | 天天基金返回的日增长率，`1.25` 表示 `1.25%` |

数据源的空数值字段返回 `NA`。结果只包含数据源提供的净值日期。

## 四、绘图与导出

```r
if (any(is.finite(nav$unit_nav))) {
  plot(nav$date, nav$unit_nav, type = "l", xlab = "Date", ylab = "Unit NAV")
}

write.csv(nav, "fund_000001_nav.csv", row.names = FALSE)
```

用 R 重新读入 CSV 时，可通过 `colClasses = c(fund_code = "character")` 保留基金代码的前导零。用 Excel 导入时，将基金代码列设为文本。

## 五、常见问题

| 情况 | 处理方式 |
| --- | --- |
| 查询结果有 0 行 | 核对基金代码和日期区间。数据源没有该区间的净值或未识别该代码时，都可能返回空数据框。 |
| 货币基金查询报错 | `fund_nav()` 适用于发布历史净值的基金。每万份收益和年化收益率属于货币基金收益指标，当前版本暂未提供查询。 |
| 网络或分页报错 | 检查网络后重试。查询较长历史时，可先指定较短的日期范围。分页不完整或响应格式异常时，函数会报错。 |

数据来源为东方财富天天基金，覆盖范围和更新时间由数据源决定。遇到问题可在 [GitHub Issues](https://github.com/tony2015116/FundR/issues) 提交基金代码、日期区间和错误信息。

## 六、用回撤上限复核候选基金

```r
# 查询最新可得的阶段收益。retrieved_at 是抓取时间。
fund_period_returns("000001")

# 用实际公布的净值记录，检查完整的历史区间
nav <- fund_nav("000001", "2023-01-01", "2025-12-31")
review <- fund_risk_review(nav, max_drawdown_pct = 15)
review
```

`15` 表示你为本次筛选设定的 15% 回撤上限。假设某基金区间收益为正，最大回撤为 20%，它仍会触发 15% 的上限。若资金用途难以承受这一级别的账面损失，可以先复核仓位，或比较同类型、同区间内回撤更小的候选基金。未触发仅说明该段历史没有达到上限，未来仍可能超过。

区间以实际返回的首末净值日为准。函数从首日收盘开始，复合计算后续公布的日增长率，并从每个历史高点计算跌幅。请传入完整日期序列；抽样、删除交易日或使用周频数据都会改变结果。结果受日增长率公布精度影响，未计个人申赎费。阶段收益来自另一条快照接口，窗口可能与自选区间不同。

## 七、结合管理公司和经理任期评估基金

```r
profile <- fund_profile("000001")
company <- fund_company(profile$company_id)
teams <- fund_manager_history("000001")
current <- subset(teams, is_current)
profile
company
current
# 仅评价现任团队共同管理期间，并要求至少两条净值记录
if (nrow(current) == 1L) {
  nav <- fund_nav("000001", start_date = current$start_date)
  if (nrow(nav) >= 2L) fund_risk_review(nav, max_drawdown_pct = 15)
}
```

公司管理规模、产品数量和经理人数描述的是机构整体；单只产品的规模及披露日在 `profile$fund_assets`。评估主动基金时，按团队任期截取净值，并使用同一时期、同一产品基准比较。团队成员变化会产生新的区间，共管期的回报属于整个团队。指数基金可优先核对跟踪标的、基准、费用及长期跟踪偏离。公司页面取数时间与规模统计日可能不同。费率保留披露原文，缺失或占位符不应按零计算。

## 八、查看仓位和重仓证券

```r
fund_allocation("000001")                  # 各报告期股票、债券、现金的净值占比
stocks <- fund_holdings("000001")          # 最近一期已披露股票，按净值占比降序
head(stocks, 10)
head(fund_holdings("000001", "bond"), 5)   # 最近一期已披露债券
```

`report_date` 是持仓截止日。`weight_pct = 5.26` 表示该证券占基金净资产的 5.26%。前十大股票的合计占比反映重仓集中度，总股票仓位请看 `fund_allocation()` 的 `stock_pct`。各类资产以净资产为分母，占比合计可能超过 100%。比较两期股票仓位可以观察敞口变化，交易、价格和申赎都可能影响权重。

持仓明细仅包含来源披露的证券。若股票列表为空，可用 `attr(stocks, "report_date")` 核对报告期。配置表中未披露的类别为 `NA`，没有配置序列时函数会提示不可用。

## 九、许可证

[MIT](LICENSE.md)
