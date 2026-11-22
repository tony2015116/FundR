# FundR <a href="https://tony2015116.github.io/FundR/"><img src="docs/reference/figures/logo.svg" width="120" align="right" alt="FundR logo"></a>

[![GitHub R package version](https://img.shields.io/github/r-package/v/tony2015116/FundR)](DESCRIPTION)
[![GitHub last commit](https://img.shields.io/github/last-commit/tony2015116/FundR)](https://github.com/tony2015116/FundR/commits/master/)

FundR 用于研究中国公募基金、沪深 A 股、港股、美股和机构公开持仓。你可以从基金名称找到重仓证券，再查看个股行情；也可以直接从投资人名字出发，查看其机构最近披露的持仓和季度数量变化。以下 14 个函数均返回 R 数据框。

## 函数速查

| 想了解什么 | 函数 | 主要结果 |
| --- | --- | --- |
| 基金代码是什么 | `fund_list()` | 基金代码、名称、类型 |
| 基金在指定日期的表现 | `fund_nav()` | 单位净值、累计净值、日增长率 |
| 最近几个阶段涨跌多少 | `fund_period_returns()` | 近 1、3、6、12 个月收益率 |
| 历史跌幅是否触及我的上限 | `fund_risk_review()` | 区间收益、最大回撤、阈值是否触发 |
| 基金的规模、费用和比较基准 | `fund_profile()` | 产品资料及管理公司编号 |
| 基金公司管理多少资产和产品 | `fund_company()` | 公司规模、产品数、经理数 |
| 哪一届团队取得了这段业绩 | `fund_manager_history()` | 经理、独管或共管区间、任职回报 |
| 股票、债券和现金各占多少 | `fund_allocation()` | 各报告期的净资产配置比例 |
| 最近披露了哪些重仓证券 | `fund_holdings()` | 股票或债券代码、名称、占净值比例 |
| 个股每日价格是多少 | `stock_history()` | 沪深 A 股、港股、美股的日线 OHLC |
| 哪只股票的区间回撤较大 | `stock_review()` | 同期收益、最大回撤、实际交易日数 |
| 可以按哪些投资人查询 | `investor_list()` | 内置名称、申报机构和 SEC 编号（CIK） |
| 某机构季末持有什么 | `investor_holdings()` | 证券、持有数量、美元市值、披露日期 |
| 与上季相比有哪些变化 | `investor_changes()` | 两期数量、差额、变化类型 |

## 一、安装

在 R 或 RStudio 中运行以下命令。

```r
# 首次使用时运行 install.packages("remotes")
# 安装包含本 README 全部功能的开发版本
remotes::install_github("tony2015116/FundR", ref = "feature/stock-analysis")
```

安装默认分支可省略 `ref`。运行 `packageVersion("FundR")` 核对版本，本页示例对应 `0.0.1.9005`。查询远端数据需要联网。已下载的数据可以离线交给 `fund_risk_review()`、`stock_review()` 和 `investor_changes()` 分析。

| 数据 | 来源 | 查询口径 |
| --- | --- | --- |
| 中国公募基金 | 天天基金 | 净值按净值日，持仓按报告期 |
| 沪深 A 股 | 腾讯行情 | 默认后复权日线 |
| 港股、美股 | Yahoo Finance | 默认使用调整收盘价 |
| 机构持仓 | 美国 SEC EDGAR | 近期普通 13F-HR 季报，需配置随请求发送的联系信息 |

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

## 九、从基金持仓到个股比较

```r
codes <- c("300308", "688361")  # 也可以从 fund_holdings() 的 security_code 列选择沪深 A 股
bars <- lapply(codes, stock_history, start_date = "2025-01-01", end_date = "2025-01-31")
stock_review(do.call(rbind, bars))
```

`stock_history()` 从腾讯获取沪深 A 股日线，默认使用后复权价格；查看历史成交价格可指定 `adjustment = "none"`。区间收益按首末交易日收盘价计算，最大回撤按日收盘价计算，均以百分比表示。比较多只股票时要求实际首末交易日一致。费用和个人现金流未纳入计算。用最新披露的重仓股回看过去的行情仅用于了解这些股票，不能据此还原基金过去的持仓或收益。

### 港股和美股

```r
hk <- stock_history("00700", "2025-01-02", "2025-01-24") # 腾讯控股，也可写 0700.HK
us <- stock_history("AAPL",  "2025-01-02", "2025-01-24") # 苹果，类别股可写 BRK.B
stock_review(rbind(hk, us))
```

港美股使用 Yahoo Finance 日线，默认按调整收盘价计算收益，其他价格按同日调整收盘价与收盘价之比折算。指定 `adjustment = "none"` 可查看供应商的标准行情，其中历史价格可能已调整拆股。收益按各自报价币种计算，未计汇率变动、税费。两地休市日不同，跨市场比较需使用共同的首末交易日，中间保留各自的交易日。

## 十、从投资人查机构持仓

```r
# 将示例替换为你愿意随请求发给 SEC 的姓名及联系邮箱
options(FundR.sec_user_agent = "Your Name you@example.com")
investor_list()
now <- investor_holdings("Buffett")       # 自动选最新报告期
head(now[c("issuer", "quantity", "unit", "value_usd", "weight_pct", "report_date", "filed_date")], 10)
q2 <- investor_holdings("Buffett", "2026-06-30")
q3 <- investor_holdings("Buffett", "2026-09-30")
subset(investor_changes(q2, q3), status != "unchanged")
investor_holdings("Li Lu")                # 也支持直接传入机构 CIK
```

13F 披露机构季末证券头寸。SH 为股数，PRN 为本金；期权另列。市值是期末估值，权重以该机构本表披露市值为分母。新出现或消失指公开表格的变化；保密处理、公司行动和证券类别变化均可能影响比较。研究跟随策略应从披露日之后观察。当前支持 2023 年起的近期普通 13F-HR，遇修订或通知型申报提示人工核对。

| `status` | 两份公开申报之间的变化 |
| --- | --- |
| `newly_reported` | 本季首次出现在这两期对照中 |
| `increased` / `decreased` | 同一证券头寸的披露数量增加 / 减少 |
| `unchanged` | 披露数量相同，市值仍可能变化 |
| `no_longer_reported` | 本季表中已找不到上季的头寸 |

如需从申报表继续查行情，请先核对证券类别及其交易代码。`cusip` 是申报表中的证券标识；`stock_history()` 接受的是交易代码，例如苹果的 `"AAPL"`。伯克希尔的 `weight_pct` 以其 13F 表内市值为分母，基金持仓的同名列则以基金净资产为分母。

## 十一、许可证

[MIT](LICENSE.md)
