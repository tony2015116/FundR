test_that("published periods are mapped and missing values stay missing", {
  body <- paste('var ishb=false; var fS_code="000001";',
                'var syl_1y="-3"; var syl_3y=""; var syl_6y="2"; var syl_1n="10";')
  local_mocked_bindings(eastmoney_get = function(request) body)
  result <- fund_period_returns("000001")
  expect_identical(result$months, c(1L, 3L, 6L, 12L))
  expect_equal(result$return_pct, c(-3, NA, 2, 10))
  expect_error(read_period_returns(body, "000002"), "different fund")
  expect_error(read_period_returns(sub("false", "true", body), "000001"), "Money market")
  expect_error(read_period_returns(sub("syl_1n", "bad", body), "000001"), "field")
})

test_that("review measures the peak loss even after full recovery", {
  nav <- data.frame(fund_code = "000001", date = as.Date("2024-01-01") + 0:3,
                    daily_return_pct = c(NA, 10, -20, 25))
  out <- fund_risk_review(nav[4:1, ], 20)
  expect_equal(out$observed_drawdown_pct, 20)
  expect_equal(out$period_return_pct, 10)
  expect_true(out$limit_reached)
  expect_false(fund_risk_review(nav, 21)$limit_reached)
  expect_error(fund_risk_review(nav, 0), "limit|number")
  expect_error(fund_risk_review(rbind(nav, nav[1, ]), 10), "distinct")
  nav$daily_return_pct[2] <- NA
  expect_error(fund_risk_review(nav, 10), "Incomplete")
})

test_that("a co-management interval remains one team observation", {
  body <- paste0("<title>Test(000001)</title><table><thead><tr>",
                 "<th>起始期</th><th>截止期</th><th>基金经理</th><th>任职期间</th><th>任职回报</th>",
                 "</tr></thead><tbody><tr><td>2024-01-01</td><td>至今</td>",
                 "<td><a>A</a> <a>B</a></td><td>1年</td><td>--</td></tr></tbody></table>")
  local_mocked_bindings(eastmoney_get = function(request) body)
  team <- fund_manager_history("000001")
  expect_equal(nrow(team), 1)
  expect_equal(team$team_size, 2)
  expect_true(team$is_current)
  expect_true(is.na(team$end_date))
  expect_true(is.na(team$team_return_pct))
  expect_error(fund_manager_history("999999"), "mismatched")
})
