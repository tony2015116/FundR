#' Retrieve trailing returns published by Eastmoney
#'
#' @param fund_code A six-digit fund code as a character string.
#' @return Four rows with fund_code, months (1, 3, 6, 12), return_pct
#'   (percentage points), and retrieved_at (retrieval time, not NAV date).
#'   Blank or placeholder returns are NA. Money market funds are unsupported.
#' @export
fund_period_returns <- function(fund_code) {
  validate_fund_code(fund_code)
  read_period_returns(fund_snapshot(fund_code), fund_code)
}

fund_snapshot <- function(fund_code) {
  url <- sprintf("https://fund.eastmoney.com/pingzhongdata/%s.js", fund_code)
  eastmoney_get(httr2::request(url))
}

snapshot_field <- function(body, name, pattern) {
  assignment <- paste0("\\bvar\\s+", name, "\\s*=\\s*(", pattern, ")\\s*;")
  match <- regmatches(body, regexec(assignment, body, perl = TRUE))[[1L]]
  if (!length(match)) {
    stop("Missing or invalid Eastmoney field: ", name, call. = FALSE)
  }
  match[[2L]]
}

check_snapshot_code <- function(body, fund_code) {
  if (snapshot_field(body, "fS_code", '"[0-9]{6}"') != paste0('"', fund_code, '"')) {
    stop("Eastmoney returned a different fund code.", call. = FALSE)
  }
}

read_period_returns <- function(body, fund_code) {
  check_snapshot_code(body, fund_code)
  if (snapshot_field(body, "ishb", "true|false") == "true") {
    stop("Money market yields are not supported.", call. = FALSE)
  }
  value <- vapply(c("syl_1y", "syl_3y", "syl_6y", "syl_1n"), snapshot_field, body = body,
                  character(1), pattern = '"[^"]*"', USE.NAMES = FALSE)
  value <- trimws(substring(value, 2L, nchar(value) - 1L))
  value[value %in% c("", "-", "--")] <- NA_character_
  number <- suppressWarnings(as.numeric(value))
  if (any(!is.na(value) & !is.finite(number))) {
    stop("Invalid Eastmoney period return.", call. = FALSE)
  }
  data.frame(fund_code = fund_code, months = c(1L, 3L, 6L, 12L),
             return_pct = number, retrieved_at = Sys.time())
}
