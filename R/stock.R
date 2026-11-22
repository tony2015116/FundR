#' Download daily stock prices for mainland China, Hong Kong or the US
#'
#' @param stock_code Six-digit A-share code, four- or five-digit Hong Kong code (or 0700.HK),
#'   or US ticker such as AAPL or BRK.B.
#' @param start_date,end_date Inclusive dates or ISO date strings.
#' @param adjustment NULL selects Tencent hfq for A shares and Yahoo adjusted prices
#'   for HK/US. "none" uses the provider's standard OHLC (Yahoo prices can
#'   already reflect splits). HK/US adjusted OHLC uses adjusted close / close.
#' @return Daily stock_code, date, open, close, high, low and adjustment.
#'   Dates without quotes are omitted. Requests are split into calendar years.
#' @export
stock_history <- function(stock_code, start_date, end_date, adjustment = NULL) {
  if (!is.character(stock_code) || length(stock_code) != 1L || is.na(stock_code)) {
    stop("Supply one stock code as text.", call. = FALSE)
  }
  stock_code <- toupper(trimws(stock_code))
  mainland <- grepl("^(60[0-9]|688|000|001|002|003|300|301)[0-9]{3}$", stock_code)
  hk <- grepl("^[0-9]{4,5}([.]HK)?$", stock_code)
  us <- grepl("^[A-Z]{1,5}([.-][A-Z])?$", stock_code)
  if (!(mainland || hk || us)) stop("Unsupported stock code.", call. = FALSE)
  modes <- if (mainland) c("hfq", "none") else c("adjusted", "none")
  if (is.null(adjustment)) adjustment <- modes[1L]
  adjustment <- match.arg(adjustment, modes)
  start <- nav_date_arg(start_date, "start_date")
  end <- nav_date_arg(end_date, "end_date")
  if (!nzchar(start) || !nzchar(end) || start > end) stop("Invalid date range.", call. = FALSE)
  if (!mainland) {
    if (hk) {
      number <- as.integer(sub("[.]HK$", "", stock_code))
      symbol <- sprintf("%04d.HK", number)
      stock_code <- sprintf("%05d", number)
    } else {
      symbol <- chartr(".", "-", stock_code)
      stock_code <- symbol
    }
    return(global_stock_bars(symbol, stock_code, as.Date(start), as.Date(end), adjustment))
  }
  symbol <- paste0(if (startsWith(stock_code, "6")) "sh" else "sz", stock_code)
  years <- seq.int(as.integer(substr(start, 1, 4)), as.integer(substr(end, 1, 4)))
  fetch_year <- function(year) {
    first <- max(start, sprintf("%04d-01-01", year))
    last <- min(end, sprintf("%04d-12-31", year))
    mode <- if (adjustment == "hfq") "hfq" else ""
    req <- httr2::request("https://web.ifzq.gtimg.cn/appstock/app/fqkline/get")
    req <- httr2::req_url_query(req, param = paste(symbol, "day", first, last, 640, mode, sep = ","))
    req <- httr2::req_timeout(httr2::req_retry(req, max_tries = 3), seconds = 20)
    result <- jsonlite::fromJSON(httr2::resp_body_string(httr2::req_perform(req)), simplifyVector = FALSE)
    if (!isTRUE(result$code == 0)) stop("Tencent rejected the quote request.", call. = FALSE)
    rows <- result$data[[symbol]][[paste0(mode, "day")]]
    if (is.null(rows) || !is.list(rows)) {
      stop("Requested price series unavailable for ", stock_code, " in ", year, ".", call. = FALSE)
    }
    if (any(lengths(rows) < 5L)) stop("Incomplete Tencent price row.", call. = FALSE)
    field <- function(i) vapply(rows, function(row) as.character(row[[i]]), character(1))
    date <- parse_nav_date(field(1))
    if (anyNA(date) || anyDuplicated(date)) stop("Invalid Tencent price dates.", call. = FALSE)
    prices <- lapply(2:5, function(i) as.numeric(field(i)))
    names(prices) <- c("open", "close", "high", "low")
    if (any(!is.finite(unlist(prices))) || any(unlist(prices) <= 0)) {
      stop("Invalid Tencent prices.", call. = FALSE)
    }
    n <- length(date)
    data <- data.frame(stock_code = rep(stock_code, n), date, prices, adjustment = rep(adjustment, n))
    data[date >= as.Date(first) & date <= as.Date(last), , drop = FALSE]
  }
  out <- do.call(rbind, lapply(years, fetch_year))
  out[order(out$date), , drop = FALSE]
}

#' Compare historical stock returns and drawdowns
#'
#' @param prices Complete adjusted bars from stock_history(), optionally
#'   combined with rbind for multiple stocks. All stocks must share endpoints.
#' @return One row per stock with actual dates, observation count, close-to-close
#'   period return and peak-to-trough maximum drawdown (positive percentage).
#' @export
stock_review <- function(prices) {
  required <- c("stock_code", "date", "close", "adjustment")
  if (!is.data.frame(prices) || !all(required %in% names(prices)) ||
      !nrow(prices) || anyNA(prices[required]) || any(!prices$adjustment %in% c("hfq", "adjusted")) ||
      !inherits(prices$date, "Date") || !is.numeric(prices$close) ||
      any(!is.finite(prices$close)) || any(prices$close <= 0)) {
    stop("Supply complete adjusted stock_history() data.", call. = FALSE)
  }
  review <- function(x) {
    if (length(unique(x$adjustment)) != 1L) stop("Mixed price adjustments for a stock.", call. = FALSE)
    if (nrow(x) < 2L || anyDuplicated(x$date)) stop("Need at least two distinct dates per stock.", call. = FALSE)
    x <- x[order(x$date), ]
    close <- x$close
    data.frame(stock_code = x$stock_code[1], start_date = min(x$date), end_date = max(x$date),
               observations = length(close), return_pct = 100 * (close[length(close)] / close[1] - 1),
               max_drawdown_pct = 100 * max(1 - close / cummax(close)))
  }
  out <- do.call(rbind, lapply(split(prices, prices$stock_code, drop = TRUE), review))
  if (length(unique(out$start_date)) != 1L || length(unique(out$end_date)) != 1L) {
    stop("Stocks must cover the same start and end trading dates.", call. = FALSE)
  }
  rownames(out) <- NULL
  out
}

global_stock_bars <- function(symbol, stock_code, start, end, adjustment) {
  # Pad UTC boundaries, then select dates in the exchange time zone.
  req <- httr2::request(paste0("https://query2.finance.yahoo.com/v8/finance/chart/", symbol))
  req <- httr2::req_url_query(req, period1 = as.numeric(start - 1) * 86400,
                              period2 = as.numeric(end + 2) * 86400, interval = "1d")
  req <- httr2::req_user_agent(req, "Mozilla/5.0")
  req <- httr2::req_timeout(httr2::req_retry(req, max_tries = 3), seconds = 20)
  chart <- httr2::resp_body_json(httr2::req_perform(req), simplifyVector = FALSE)$chart
  if (!is.null(chart$error) || length(chart$result) != 1L) stop("Stock history unavailable.", call. = FALSE)
  x <- chart$result[[1]]
  if (!identical(x$meta$symbol, symbol) ||
      !isTRUE(x$meta$exchangeTimezoneName %in% OlsonNames())) stop("Invalid quote metadata.", call. = FALSE)
  timestamps <- vapply(x$timestamp, as.numeric, numeric(1))
  dates <- as.Date(as.POSIXct(timestamps, origin = "1970-01-01", tz = "UTC"),
                   tz = x$meta$exchangeTimezoneName)
  if (anyNA(dates) || anyDuplicated(dates)) stop("Invalid quote dates.", call. = FALSE)
  column <- function(values) {
    if (length(values) != length(dates)) stop("Misaligned quote series.", call. = FALSE)
    vapply(values, function(v) if (is.null(v)) NA_real_ else as.numeric(v), numeric(1))
  }
  quote <- x$indicators$quote[[1]]
  prices <- as.data.frame(lapply(quote[c("open", "close", "high", "low")], column))
  if (!identical(names(prices), c("open", "close", "high", "low"))) stop("Missing OHLC fields.", call. = FALSE)
  keep <- dates >= start & dates <= end & rowSums(!is.na(prices)) > 0
  if (adjustment == "adjusted") {
    adjusted <- column(x$indicators$adjclose[[1]]$adjclose)
    ratio <- adjusted / prices$close
    prices[] <- lapply(prices, function(v) v * ratio)
    prices$close <- adjusted
  }
  values <- as.matrix(prices[keep, , drop = FALSE])
  if (any(!is.finite(values)) || any(values <= 0)) stop("Incomplete or invalid daily bar.", call. = FALSE)
  result <- data.frame(stock_code = rep(stock_code, sum(keep)), date = dates[keep],
                       prices[keep, , drop = FALSE], adjustment = rep(adjustment, sum(keep)))
  result[order(result$date), , drop = FALSE]
}
