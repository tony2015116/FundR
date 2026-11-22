#' Retrieve reported asset weights by reporting date
#'
#' @param fund_code A six-digit fund code as text.
#' @return One row per report_date, with stock_pct, bond_pct, and cash_pct
#'   expressed as percentages of net assets. Missing categories are NA.
#'   Dates cover the history exposed in the current snapshot. The function
#'   reports an error for products without an allocation series.
#' @export
fund_allocation <- function(fund_code) {
  validate_fund_code(fund_code)
  body <- fund_snapshot(fund_code)
  check_snapshot_code(body, fund_code)
  payload <- snapshot_field(body, "Data_assetAllocation", "[^;]+")
  chart <- eastmoney_json(payload, "asset allocation")
  dates <- parse_nav_date(vapply(chart$categories, identity, character(1)))
  labels <- c(stock_pct = "股票占净比", bond_pct = "债券占净比", cash_pct = "现金占净比")
  series_names <- vapply(chart$series, "[[", character(1), "name")
  if (!length(dates) || anyNA(dates) || anyDuplicated(dates) ||
      anyDuplicated(series_names) || !any(labels %in% series_names)) {
    stop("No usable asset allocation series for this fund.", call. = FALSE)
  }
  weights <- lapply(labels, function(label) {
    pos <- match(label, series_names)
    if (is.na(pos)) return(rep(NA_real_, length(dates)))
    values <- chart$series[[pos]]$data
    if (length(values) != length(dates)) stop("Misaligned allocation dates.", call. = FALSE)
    vapply(values, function(x) {
      if (is.null(x)) return(NA_real_)
      if (!is.numeric(x) || length(x) != 1L || !is.finite(x)) {
        stop("Invalid allocation percentage.", call. = FALSE)
      }
      x
    }, numeric(1))
  })
  out <- data.frame(fund_code, report_date = dates, weights, row.names = NULL)
  out[order(out$report_date), , drop = FALSE]
}

#' Retrieve the latest disclosed stock or bond positions
#'
#' @param fund_code A six-digit fund code as text.
#' @param asset_type Either "stock" (default) or "bond".
#' @return A data frame ordered by decreasing weight_pct (percentage of net
#'   assets), with fund_code, report_date, asset_type, security_code and
#'   security_name. Only provider-disclosed rows are returned. A valid dated
#'   snapshot with an empty list returns zero rows. Its reporting date is
#'   also available as attr(result, "report_date").
#' @export
fund_holdings <- function(fund_code, asset_type = c("stock", "bond")) {
  validate_fund_code(fund_code)
  asset_type <- match.arg(asset_type)
  req <- httr2::request("https://fundmobapi.eastmoney.com/FundMNewApi/FundMNInverstPosition")
  req <- httr2::req_url_query(req, FCODE = fund_code, deviceid = "Wap", plat = "Wap",
                              product = "EFund", version = "6.3.8")
  result <- eastmoney_json(eastmoney_get(req), "holdings")
  if (!isTRUE(result$Success) || !isTRUE(result$ErrCode == 0) ||
      !is.character(result$Expansion) || length(result$Expansion) != 1L) {
    stop("No valid dated holdings response.", call. = FALSE)
  }
  date <- parse_nav_date(result$Expansion)
  if (is.na(date)) stop("Invalid holdings report date.", call. = FALSE)
  fields <- switch(asset_type, stock = c("fundStocks", "GPDM", "GPJC", "JZBL"),
                   bond = c("fundboods", "ZQDM", "ZQMC", "ZJZBL"))
  rows <- result$Datas[[fields[1]]]
  if (is.null(rows) || !is.list(rows) || !is.null(names(rows))) {
    stop("Missing or invalid holdings list.", call. = FALSE)
  }
  column <- function(field) vapply(rows, function(row) {
    x <- row[[field]]
    if (field == fields[4] && field %in% names(row) && is.null(x)) return(NA_character_)
    if (length(x) != 1L || !(is.character(x) || is.numeric(x))) {
      stop("Invalid holdings field: ", field, call. = FALSE)
    }
    as.character(x)
  }, character(1))
  raw <- column(fields[4])
  raw[raw %in% c("", "-", "--", "---")] <- NA_character_
  weight <- suppressWarnings(as.numeric(raw))
  if (any(!is.na(raw) & !is.finite(weight))) stop("Invalid holdings weight.", call. = FALSE)
  n <- length(rows)
  out <- data.frame(fund_code = rep(fund_code, n), report_date = rep(date, n),
                    asset_type = rep(asset_type, n), security_code = column(fields[2]),
                    security_name = column(fields[3]), weight_pct = weight)
  out <- out[order(-weight), , drop = FALSE]
  attr(out, "report_date") <- date
  out
}
