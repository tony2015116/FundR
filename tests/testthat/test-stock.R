test_that("adjusted stock prices give close-to-close returns and historical drawdown", {
  x <- data.frame(stock_code = "300308", date = as.Date("2025-01-01") + 0:3,
                  close = c(100, 120, 90, 110), adjustment = "hfq")
  result <- stock_review(x[4:1, ])
  expect_equal(result$return_pct, 10)
  expect_equal(result$max_drawdown_pct, 25)
  y <- x[-1, ]
  y$stock_code <- "688361"
  expect_error(stock_review(rbind(x, y)), "same start")
  x$adjustment <- "none"
  expect_error(stock_review(x), "adjusted")
  expect_error(stock_history("bad!", "2025-01-01", "2025-01-31"), "Unsupported")
})

test_that("Hong Kong aliases and US share classes use consistent symbols", {
  local_mocked_bindings(global_stock_bars = function(symbol, stock_code, start, end, adjustment)
    c(symbol, stock_code, adjustment))
  for (ticker in c("0700", "00700", "0700.HK")) {
    expect_identical(stock_history(ticker, "2025-01-01", "2025-01-31"),
                     c("0700.HK", "00700", "adjusted"))
  }
  expect_identical(stock_history("brk.b", "2025-01-01", "2025-01-31", "none"),
                   c("BRK-B", "BRK-B", "none"))
})
