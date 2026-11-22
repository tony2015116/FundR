#' Download historical fund NAVs from Eastmoney
#'
#' @param fund_code One six-digit fund code as a character string.
#' @param start_date,end_date Optional inclusive date bounds, as `Date` values
#'   or strings in `YYYY-MM-DD` format. Use `NULL` for an open bound.
#' @return A data frame ordered by date with columns `fund_code` (character),
#'   `date` (Date), `unit_nav`, `cumulative_nav`, and `daily_return_pct`
#'   (numeric). A daily return of 1.25 represents 1.25%. Blank numeric
#'   fields become `NA`. A successful response with no records returns
#'   a zero-row data frame, which can also occur for an unknown code.
#' @details Money market yield series are outside the scope of this function.
#' @export
#' @examples
#' \dontrun{
#' fund_nav("000001", "2024-01-02", "2024-01-31")
#' }
fund_nav <- function(fund_code, start_date = NULL, end_date = NULL) {
  validate_fund_code(fund_code)

  start_date <- nav_date_arg(start_date, "start_date")
  end_date <- nav_date_arg(end_date, "end_date")
  if (nzchar(start_date) && nzchar(end_date) && start_date > end_date) {
    stop("start_date must be on or before end_date.", call. = FALSE)
  }

  request <- httr2::request("https://api.fund.eastmoney.com/f10/lsjz")
  request <- httr2::req_headers(
    request, Referer = paste0("https://fundf10.eastmoney.com/jjjz_", fund_code, ".html")
  )
  request <- httr2::req_url_query(
    request, fundCode = fund_code, startDate = start_date, endDate = end_date,
    pageSize = 20L
  )

  first <- fetch_nav_page(request, 1L)
  page_count <- max(1, ceiling(first$TotalCount / first$PageSize))
  pages <- vector("list", page_count)
  pages[[1L]] <- nav_page_data(first, fund_code, 1L)
  for (page in seq_len(page_count)[-1L]) {
    result <- fetch_nav_page(request, page)
    if (result$TotalCount != first$TotalCount || result$PageSize != first$PageSize) {
      stop("Eastmoney NAV pagination changed during the request. Try again.",
           call. = FALSE)
    }
    pages[[page]] <- nav_page_data(result, fund_code, page)
  }

  nav <- do.call(rbind, pages)
  if (anyDuplicated(nav$date)) {
    stop("Eastmoney returned duplicate NAV dates. Try again.", call. = FALSE)
  }
  if ((nzchar(start_date) && any(nav$date < as.Date(start_date))) ||
      (nzchar(end_date) && any(nav$date > as.Date(end_date)))) {
    stop("Eastmoney returned NAV dates outside the requested range.", call. = FALSE)
  }
  nav <- nav[order(nav$date), , drop = FALSE]
  rownames(nav) <- NULL
  nav
}

nav_date_arg <- function(value, argument) {
  if (is.null(value)) {
    return("")
  }
  if (inherits(value, "Date")) {
    value <- format(value)
  }
  if (!is.character(value) || length(value) != 1L || is.na(parse_nav_date(value))) {
    stop(argument, " must be a Date or a valid YYYY-MM-DD string.", call. = FALSE)
  }
  value
}

parse_nav_date <- function(value) {
  date <- as.Date(value, format = "%Y-%m-%d")
  valid <- !is.na(date) & !is.na(value) & format(date, "%Y-%m-%d") == value
  date[!valid] <- NA
  date
}

fetch_nav_page <- function(request, page) {
  request <- httr2::req_url_query(request, pageIndex = page)
  result <- eastmoney_json(eastmoney_get(request), "NAV history")

  if (!is.list(result) || is.null(result$ErrCode)) {
    stop("Unexpected Eastmoney NAV response.", call. = FALSE)
  }
  if (!isTRUE(result$ErrCode == 0)) {
    stop("Eastmoney reported a NAV service error (", result$ErrCode, ").",
         call. = FALSE)
  }
  is_count <- function(value) {
    is.numeric(value) && length(value) == 1L && is.finite(value) &&
      value == floor(value) && value <= .Machine$integer.max
  }
  if (!is_count(result$TotalCount) || result$TotalCount < 0 ||
      !is_count(result$PageSize) || result$PageSize < 1 ||
      !isTRUE(result$PageIndex == page) || !is.list(result$Data)) {
    stop("Unexpected Eastmoney pagination metadata on NAV page ", page, ".",
         call. = FALSE)
  }

  data <- result$Data
  if (identical(data$FundType, "005") || isTRUE(nzchar(data$SYType, keepNA = TRUE))) {
    stop("Money market yield series are not supported by fund_nav().", call. = FALSE)
  }
  result
}

nav_page_data <- function(result, fund_code, page) {
  rows <- result$Data$LSJZList
  page_start <- (page - 1) * result$PageSize
  expected <- min(result$PageSize, result$TotalCount - page_start)
  if (!is.list(rows) || !is.null(names(rows)) || length(rows) != expected) {
    stop("Eastmoney returned an incomplete or invalid NAV page ", page, ".",
         call. = FALSE)
  }

  read_field <- function(field) {
    vapply(rows, function(row) {
      if (!is.list(row) || !field %in% names(row)) {
        stop("Missing Eastmoney NAV field ", field, " on page ", page, ".",
             call. = FALSE)
      }
      value <- row[[field]]
      if (is.null(value)) {
        return(NA_character_)
      }
      if (length(value) != 1L || !(is.character(value) || is.numeric(value))) {
        stop("Invalid Eastmoney NAV field ", field, " on page ", page, ".",
             call. = FALSE)
      }
      as.character(value)
    }, character(1))
  }
  read_number <- function(field) {
    value <- trimws(read_field(field))
    value[value %in% c("", "-", "--")] <- NA_character_
    number <- suppressWarnings(as.numeric(value))
    if (any(!is.na(value) & !is.finite(number))) {
      stop("Invalid Eastmoney NAV field ", field, " on page ", page, ".",
           call. = FALSE)
    }
    number
  }

  date <- parse_nav_date(read_field("FSRQ"))
  if (anyNA(date)) {
    stop("Invalid Eastmoney NAV date on page ", page, ".", call. = FALSE)
  }
  data.frame(
    fund_code = rep(fund_code, length(rows)),
    date = date,
    unit_nav = read_number("DWJZ"),
    cumulative_nav = read_number("LJJZ"),
    daily_return_pct = read_number("JZZZL"),
    stringsAsFactors = FALSE
  )
}

validate_fund_code <- function(fund_code) {
  if (!is.character(fund_code) || length(fund_code) != 1L ||
      is.na(fund_code) || !grepl("^[0-9]{6}$", fund_code)) {
    stop("fund_code must be a six-digit character string.", call. = FALSE)
  }
}
