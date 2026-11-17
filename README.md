# FundR <a href="https://tony2015116.github.io/FundR/"><img src="docs/reference/figures/logo.svg" width="120" align="right" alt="FundR logo"></a>

[![GitHub R package version](https://img.shields.io/github/r-package/v/tony2015116/FundR)](DESCRIPTION)
[![GitHub last commit](https://img.shields.io/github/last-commit/tony2015116/FundR)](https://github.com/tony2015116/FundR/commits/master/)

FundR 是一个从东方财富天天基金获取基金目录和历史净值的 R 包。用基金名称查找六位代码，再按代码下载指定日期范围的历史净值。两个函数都返回 R 的 `data.frame`，可直接用于筛选、绘图和导出。

| 函数 | 用途 |
| --- | --- |
| `fund_list()` | 获取基金代码、名称和类型 |
| `fund_nav(fund_code, start_date = NULL, end_date = NULL)` | 获取一只基金的单位净值、累计净值和日增长率 |

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

## 六、许可证

[MIT](LICENSE.md)
