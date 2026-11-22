#' Discover institutional filers to follow
#' @return A directory of investor labels, filing institutions and SEC CIKs.
#' @export
investor_list <- function() {
  data.frame(investor = c("Buffett", "Li Lu"),
             institution = c("Berkshire Hathaway Inc", "Himalaya Capital Management LLC"),
             cik = c("0001067983", "0001709323"))
}

sec_read <- function(url) {
  contact <- getOption("FundR.sec_user_agent", "")
  if (!is.character(contact) || length(contact) != 1L || is.na(contact) ||
      !grepl("@", contact, fixed = TRUE)) {
    stop("Set options(FundR.sec_user_agent = 'Your name your@email.com') with your contact details.")
  }
  req <- httr2::req_user_agent(httr2::request(url), contact)
  req <- httr2::req_timeout(httr2::req_retry(req, max_tries = 3), seconds = 30)
  httr2::resp_body_string(httr2::req_perform(req))
}

#' Read a recent quarterly SEC 13F holdings table
#' @param investor Directory label (Buffett or Li Lu), or a filer CIK as text.
#' @param quarter Optional quarter-end ISO date. Defaults to the latest reported quarter.
#' @details Uses recent EDGAR submissions for quarters from 2023 onward.
#'   Set option FundR.sec_user_agent to your name and contact email.
#'   Notice-only and amended quarters require manual review.
#' @return Security-level quantities (shares or principal as indicated), USD
#'   quarter-end values, percentage of reported value, dates and SEC source.
#' @export
investor_holdings <- function(investor = "Buffett", quarter = NULL) {
  directory <- investor_list()
  if (!is.character(investor) || length(investor) != 1L || is.na(investor)) stop("Supply one investor label or CIK.")
  cik <- directory$cik[match(tolower(investor), tolower(directory$investor))]
  if (is.na(cik)) {
    if (!grepl("^[0-9]{1,10}$", investor)) stop("Unknown investor. See investor_list().")
    cik <- sprintf("%010.0f", as.numeric(investor))
  }
  meta <- jsonlite::fromJSON(sec_read(sprintf("https://data.sec.gov/submissions/CIK%s.json", cik)))
  filings <- as.data.frame(meta$filings$recent, stringsAsFactors = FALSE)
  filings <- filings[filings$form %in% c("13F-HR", "13F-HR/A", "13F-NT", "13F-NT/A") &
                       filings$reportDate >= "2023-03-31", , drop = FALSE]
  if (!nrow(filings)) stop("No supported recent 13F reports.")
  period <- if (is.null(quarter)) max(filings$reportDate) else nav_date_arg(quarter, "quarter")
  filing <- filings[filings$reportDate == period, , drop = FALSE]
  if (!nrow(filing)) stop("Quarter not found in recent submissions.")
  if (nrow(filing) != 1L || filing$form != "13F-HR") {
    stop("Amended or notice-only quarter: review the filings in EDGAR.")
  }
  id <- filing$accessionNumber
  url <- sprintf("https://www.sec.gov/Archives/edgar/data/%s/%s/%s.txt",
                 sub("^0+", "", cik), gsub("-", "", id), id)
  out <- parse_13f(sec_read(url))
  out$cik <- cik
  out$institution <- meta$name
  out$report_date <- as.Date(period)
  out$filed_date <- as.Date(filing$filingDate)
  out$source <- url
  out
}

parse_13f <- function(body) {
  blocks <- regmatches(body, gregexpr("(?s)<XML>.*?</XML>", body, perl = TRUE))[[1]]
  docs <- lapply(blocks, function(block) {
    xml2::xml_ns_strip(xml2::read_xml(trimws(sub("</XML>$", "", sub("^<XML>", "", block)))))
  })
  roots <- vapply(docs, function(doc) xml2::xml_name(xml2::xml_root(doc)), character(1))
  if (sum(roots == "informationTable") != 1L || sum(roots == "edgarSubmission") != 1L) stop("Unexpected 13F XML documents.")
  cover <- docs[[which(roots == "edgarSubmission")]]
  nodes <- xml2::xml_find_all(docs[[which(roots == "informationTable")]], ".//*[local-name()='infoTable']")
  field <- function(path) {
    parts <- strsplit(path, "/", fixed = TRUE)[[1]]
    xpath <- paste(sprintf("*[local-name()='%s']", parts), collapse = "/")
    xml2::xml_text(xml2::xml_find_first(nodes, xpath), trim = TRUE)
  }
  cover_field <- function(name) xml2::xml_text(xml2::xml_find_first(cover, paste0(".//", name)))
  rows <- data.frame(issuer = field("nameOfIssuer"), cusip = field("cusip"),
                     security_class = field("titleOfClass"), option = field("putCall"),
                     unit = field("shrsOrPrnAmt/sshPrnamtType"),
                     quantity = as.numeric(field("shrsOrPrnAmt/sshPrnamt")),
                     value_usd = as.numeric(field("value")))
  rows$option[is.na(rows$option)] <- ""
  if (!nrow(rows) || anyNA(rows) || any(!is.finite(rows$quantity)) ||
      any(!is.finite(rows$value_usd)) || any(rows$quantity < 0 | rows$value_usd < 0) ||
      !isTRUE(as.numeric(cover_field("tableEntryTotal")) == nrow(rows)) ||
      !isTRUE(as.numeric(cover_field("tableValueTotal")) == sum(rows$value_usd))) stop("13F totals or fields failed validation.")
  keys <- c("cusip", "security_class", "option", "unit")
  out <- stats::aggregate(rows[c("quantity", "value_usd")], rows[keys], sum)
  out$issuer <- rows$issuer[match(out$cusip, rows$cusip)]
  out$weight_pct <- 100 * out$value_usd / sum(out$value_usd)
  out$confidential_omissions <- tolower(cover_field("isConfidentialOmitted")) %in% c("true", "1")
  out[order(-out$value_usd), , drop = FALSE]
}

#' Compare two consecutive institutional disclosures
#' @param previous,current Tables from investor_holdings() for the same filer.
#' @return Reported quantities, changes and status for each security.
#'   Corporate actions or confidential omissions may explain differences.
#' @export
investor_changes <- function(previous, current) {
  cols <- c("cusip", "security_class", "option", "unit")
  check <- function(x) {
    needed <- c(cols, "issuer", "quantity", "cik", "report_date", "confidential_omissions")
    is.data.frame(x) && nrow(x) > 0 && all(needed %in% names(x)) &&
      !anyNA(x[needed]) && length(unique(x$cik)) == 1L &&
      length(unique(x$report_date)) == 1L && !anyDuplicated(x[cols])
  }
  if (!check(previous) || !check(current) || previous$cik[1] != current$cik[1]) stop("Supply two reports from the same filer.")
  dates <- c(previous$report_date[1], current$report_date[1])
  if (!(as.numeric(diff(dates)) %in% 90:92)) stop("Supply consecutive quarters in chronological order.")
  x <- merge(previous[c(cols, "issuer", "quantity")], current[c(cols, "issuer", "quantity")],
             by = cols, all = TRUE, suffixes = c("_prev", "_now"))
  absent_prev <- is.na(x$quantity_prev)
  absent_now <- is.na(x$quantity_now)
  x$issuer <- ifelse(absent_now, x$issuer_prev, x$issuer_now)
  x$quantity_prev[absent_prev] <- 0
  x$quantity_now[absent_now] <- 0
  x$change <- x$quantity_now - x$quantity_prev
  x$status <- ifelse(absent_prev, "newly_reported", ifelse(absent_now, "no_longer_reported",
                     ifelse(x$change > 0, "increased", ifelse(x$change < 0, "decreased", "unchanged"))))
  x$previous_date <- dates[1]
  x$current_date <- dates[2]
  x$confidential_omissions <- any(previous$confidential_omissions, current$confidential_omissions)
  x[c("issuer", cols, "quantity_prev", "quantity_now", "change", "status", "previous_date", "current_date", "confidential_omissions")]
}
