#' List funds in the Eastmoney directory
#'
#' @return A data frame with character columns `fund_code`, `fund_name`, and
#'   `fund_type`. Fund codes retain leading zeros. The directory may include
#'   products that do not publish historical NAVs.
#' @export
#' @examples
#' \dontrun{
#' head(fund_list())
#' }
fund_list <- function() {
  request <- httr2::request("https://fund.eastmoney.com/js/fundcode_search.js")
  parse_fund_list(eastmoney_get(request))
}

parse_fund_list <- function(body) {
  body <- trimws(sub("^\ufeff", "", body))
  prefix <- "^var[[:space:]]+r[[:space:]]*=[[:space:]]*"
  if (!grepl(prefix, body)) {
    stop("Unexpected Eastmoney fund directory response.", call. = FALSE)
  }

  payload <- sub(";[[:space:]]*$", "", sub(prefix, "", body))
  rows <- eastmoney_json(payload, "fund directory")
  if (!is.list(rows) || !is.null(names(rows))) {
    stop("Unexpected Eastmoney fund directory format.", call. = FALSE)
  }

  valid_row <- function(row) {
    is.list(row) && length(row) == 5L &&
      all(vapply(row, function(value) is.character(value) && length(value) == 1L,
                 logical(1))) &&
      grepl("^[0-9]{6}$", row[[1L]])
  }
  if (!all(vapply(rows, valid_row, logical(1)))) {
    stop("Unexpected row in the Eastmoney fund directory.", call. = FALSE)
  }

  data.frame(
    fund_code = vapply(rows, `[[`, character(1), 1L),
    fund_name = vapply(rows, `[[`, character(1), 3L),
    fund_type = vapply(rows, `[[`, character(1), 4L),
    stringsAsFactors = FALSE
  )
}
