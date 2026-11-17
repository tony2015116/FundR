# FundR <a href="https://tony2015116.github.io/FundR/"><img src="docs/reference/figures/logo.svg" width="120" align="right" alt="FundR logo"></a>

[![GitHub R package version](https://img.shields.io/github/r-package/v/tony2015116/FundR)](https://github.com/tony2015116/FundR/blob/master/DESCRIPTION)
[![GitHub last commit](https://img.shields.io/github/last-commit/tony2015116/FundR)](https://github.com/tony2015116/FundR/commits/master/)

FundR 从东方财富天天基金网获取基金目录和历史净值，返回可直接在 R 中使用的数据框。

## 一、安装

```r
# install.packages("remotes")
remotes::install_github("tony2015116/FundR")
```

## 二、查询基金代码

```r
library(FundR)

funds <- fund_list()
head(funds)
subset(funds, grepl("华夏成长", fund_name))
```

目录包含 `fund_code`（基金代码）、`fund_name`（名称）和 `fund_type`（类型）。基金代码是字符型，保留前导零。

## 三、下载历史净值

```r
nav <- fund_nav("000001", start_date = "2024-01-02", end_date = "2024-01-31")
head(nav)
```

起止日期均包含当天，可传入 `Date` 或 `YYYY-MM-DD` 字符串。省略日期表示让数据源使用开放边界。结果按日期升序排列。

| 字段 | 含义 |
| --- | --- |
| `fund_code` | 基金代码 |
| `date` | 净值日期（`Date` 类型） |
| `unit_nav` | 单位净值 |
| `cumulative_nav` | 累计净值 |
| `daily_return_pct` | 日增长率，数值 `1.25` 表示 `1.25%` |

指定区间无记录或数据源未识别基金代码时，可能返回零行数据框。货币基金的每万份收益和年化收益率属于独立指标，超出 `fund_nav()` 的适用范围。实时请求需要联网，数据可用性取决于天天基金网。
