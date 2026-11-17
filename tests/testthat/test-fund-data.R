test_that("fund_list preserves codes and names without executing JavaScript", {
  body <- paste0(
    "\ufeffvar r = [[\"000001\",\"ABC\",\"\u534e\u590f\",\"mixed\",\"ABC\"]];\n"
  )
  local_mocked_bindings(eastmoney_get = function(request) body)

  expect_identical(
    fund_list(),
    data.frame(fund_code = "000001", fund_name = "\u534e\u590f", fund_type = "mixed")
  )
  expect_error(parse_fund_list("<html>denied</html>"), "directory response")
  expect_error(parse_fund_list("var r = [broken];"), "invalid JSON")
  expect_error(parse_fund_list('var r = [["1","ABC","Name","mixed","ABC"]];'),
               "Unexpected row")
})

nav_response <- function(rows = list(), page = 1, total = length(rows),
                         size = 20, type = "002", yield_type = NULL) {
  jsonlite::toJSON(list(
    ErrCode = 0, TotalCount = total, PageSize = size, PageIndex = page,
    Data = list(LSJZList = unname(rows), FundType = type, SYType = yield_type)
  ), auto_unbox = TRUE, null = "null")
}

nav_row <- function(date, unit = "1.23", cumulative = "2.34", change = "1.25") {
  list(FSRQ = date, DWJZ = unit, LJJZ = cumulative, JZZZL = change)
}

test_that("fund_nav follows server pagination and returns sorted typed columns", {
  responses <- c(
    nav_response(
      list(nav_row("2024-01-04"), nav_row("2024-01-03", "", NULL, "--")),
      total = 3, size = 2
    ),
    nav_response(list(nav_row("2024-01-02")), page = 2, total = 3, size = 2)
  )
  seen_urls <- character()
  local_mocked_bindings(eastmoney_get = function(request) {
    seen_urls <<- c(seen_urls, request$url)
    responses[[length(seen_urls)]]
  })

  result <- fund_nav("000001", as.Date("2024-01-02"), "2024-01-04")

  expect_length(seen_urls, 2)
  expect_match(seen_urls[1], "fundCode=000001")
  expect_match(seen_urls[1], "startDate=2024-01-02")
  expect_match(seen_urls[1], "endDate=2024-01-04")
  expect_match(seen_urls[2], "pageIndex=2")
  expect_identical(result, data.frame(
    fund_code = rep("000001", 3),
    date = as.Date(c("2024-01-02", "2024-01-03", "2024-01-04")),
    unit_nav = c(1.23, NA, 1.23),
    cumulative_nav = c(2.34, NA, 2.34),
    daily_return_pct = c(1.25, NA, 1.25)
  ))
})

test_that("fund_nav validates its inputs before contacting Eastmoney", {
  local_mocked_bindings(eastmoney_get = function(request) stop("network called"))

  expect_error(fund_nav(1), "six-digit character")
  expect_error(fund_nav("0000001"), "six-digit character")
  expect_error(fund_nav(c("000001", "000002")), "six-digit character")
  expect_error(fund_nav("000001", "2024-02-30"), "valid YYYY-MM-DD")
  expect_error(fund_nav("000001", "2024-2-01"), "valid YYYY-MM-DD")
  expect_error(fund_nav("000001", "2024-02-02", "2024-02-01"), "on or before")
})

test_that("fund_nav handles empty responses and rejects unsupported yield data", {
  response <- nav_response()
  local_mocked_bindings(eastmoney_get = function(request) response)

  expect_identical(fund_nav("000001"), data.frame(
    fund_code = character(), date = as.Date(character()),
    unit_nav = numeric(), cumulative_nav = numeric(),
    daily_return_pct = numeric()
  ))
  response <- nav_response(list(nav_row("2024-01-01")), type = "005")
  expect_error(fund_nav("004186"), "Money market yield")
  response <- nav_response(list(nav_row("2024-01-01")), yield_type = "yield")
  expect_error(fund_nav("004186"), "Money market yield")
  response <- '{"ErrCode":1,"TotalCount":0}'
  expect_error(fund_nav("000001"), "NAV service error")
})

test_that("fund_nav rejects broken pages instead of returning partial history", {
  response <- nav_response(list(nav_row("2024-01-01")), total = 2)
  local_mocked_bindings(eastmoney_get = function(request) response)

  expect_error(fund_nav("000001"), "incomplete or invalid NAV page 1")
  response <- nav_response(list(nav_row("2024-01-01")), page = 2)
  expect_error(fund_nav("000001"), "pagination metadata")
  response <- nav_response(list(nav_row("2024-01-01", unit = "unexpected")))
  expect_error(fund_nav("000001"), "Invalid Eastmoney NAV field DWJZ")
  response <- nav_response(list(nav_row("2024-01-01"), nav_row("2024-01-01")))
  expect_error(fund_nav("000001"), "duplicate NAV dates")
  response <- nav_response(list(nav_row("2024-01-01")))
  expect_error(fund_nav("000001", "2024-02-01"), "outside the requested range")
})
