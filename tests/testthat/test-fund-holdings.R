test_that("allocation keeps unreported values separate from zero exposure", {
  body <- paste0('var fS_code="000001";var Data_assetAllocation=',
    '{"series":[{"name":"股票占净比","data":[0,null]}],',
    '"categories":["2025-03-31","2025-06-30"]};')
  local_mocked_bindings(eastmoney_get = function(request) body)
  result <- fund_allocation("000001")
  expect_equal(result$stock_pct, c(0, NA))
  expect_true(all(is.na(result$bond_pct)))
  body <- sub("股票占净比", "总份额", body)
  expect_error(fund_allocation("000001"), "No usable")
})

test_that("holdings preserve codes and dates, including on empty stock lists", {
  body <- '{"Success":true,"ErrCode":0,"Expansion":"2025-09-30","Datas":{"fundStocks":[],"fundboods":[{"ZQDM":"00123","ZQMC":"Bond","ZJZBL":"2.5"}]}}'
  local_mocked_bindings(eastmoney_get = function(request) body)
  stocks <- fund_holdings("000198")
  expect_equal(nrow(stocks), 0)
  expect_equal(attr(stocks, "report_date"), as.Date("2025-09-30"))
  bonds <- fund_holdings("000198", "bond")
  expect_identical(bonds$security_code, "00123")
  expect_equal(bonds$weight_pct, 2.5)
  body <- sub("fundStocks", "unknown", body)
  expect_error(fund_holdings("000198"), "list")
})
