#' Retrieve product details needed to interpret fund performance
#'
#' @param fund_code A six-digit fund code as a string.
#' @return One row with company ID and name, fund type, managers, fees,
#'   benchmark and fund assets. Disclosure text retains units and dates.
#' @export
fund_profile <- function(fund_code) {
  doc <- fund_archive(fund_code, "jbgk")
  table <- xml2::xml_find_first(doc, "//table[.//th='基金全称']")
  cell <- function(label) {
    xml2::xml_find_first(table, sprintf(".//th[normalize-space()='%s']/following-sibling::*[1][self::td]", label))
  }
  manager <- cell("基金管理人")
  href <- xml2::xml_attr(xml2::xml_find_first(manager, ".//a"), "href")
  if (is.na(href) || !grepl("/company/[0-9]+\\.html$", href)) {
    stop("Missing fund management company identifier.", call. = FALSE)
  }
  labels <- c(fund_name = "基金简称", fund_type = "基金类型", managers = "基金经理人",
              fund_assets = "净资产规模", management_fee = "管理费率",
              custody_fee = "托管费率", sales_service_fee = "销售服务费率",
              benchmark = "业绩比较基准")
  values <- lapply(labels, function(label) xml2::xml_text(cell(label), trim = TRUE))
  data.frame(fund_code = fund_code, company = xml2::xml_text(manager, trim = TRUE),
             company_id = sub(".*company/([0-9]+)\\.html$", "\\1", href), values)
}

fund_archive <- function(fund_code, page) {
  validate_fund_code(fund_code)
  url <- sprintf("https://fundf10.eastmoney.com/%s_%s.html", page, fund_code)
  doc <- xml2::read_html(eastmoney_get(httr2::request(url)), encoding = "UTF-8")
  title <- xml2::xml_text(xml2::xml_find_first(doc, "//title"))
  if (is.na(title) || !grepl(paste0("(", fund_code, ")"), title, fixed = TRUE)) {
    stop("Unrecognized fund archive or mismatched code.", call. = FALSE)
  }
  doc
}

#' Retrieve the management company's published operating figures
#'
#' @param company_id A character identifier from fund_profile().
#' @return One row with company_id, assets, fund_count, manager_count,
#'   founded, ownership and retrieved_at. Values retain the provider's units.
#'   Retrieval time is not the financial reporting date.
#' @export
fund_company <- function(company_id) {
  if (!is.character(company_id) || length(company_id) != 1L || is.na(company_id) ||
      !grepl("^[0-9]+$", company_id)) {
    stop("Expected a numeric company identifier as text.", call. = FALSE)
  }
  url <- sprintf("https://fund.eastmoney.com/company/%s.html", company_id)
  doc <- xml2::read_html(eastmoney_get(httr2::request(url)), encoding = "UTF-8")
  path <- sprintf("//a[contains(@href,'/gmbd_%s.html') and normalize-space()='管理规模']/ancestor::ul[1]", company_id)
  box <- xml2::xml_find_first(doc, path)
  if (inherits(box, "xml_missing")) stop("Unrecognized company profile.", call. = FALSE)
  labels <- c(assets = "管理规模", fund_count = "基金数量", manager_count = "经理人数",
              founded = "成立日期", ownership = "公司性质")
  values <- lapply(labels, function(label) {
    path <- sprintf("./li[starts-with(normalize-space(.),'%s')]/label", label)
    xml2::xml_text(xml2::xml_find_first(box, path), trim = TRUE)
  })
  data.frame(company_id = company_id, values, retrieved_at = Sys.time())
}

#' Retrieve management team history for a fund
#'
#' @param fund_code A six-digit fund code as a string.
#' @return One row per reported team interval, with dates, manager names,
#'   team size, current status and cumulative team return in percentage points.
#'   Ongoing intervals have an NA end date. Unreported returns are NA.
#' @export
fund_manager_history <- function(fund_code) {
  doc <- fund_archive(fund_code, "jjjl")
  rows <- xml2::xml_find_all(doc, "//table[thead/tr/th[1]='起始期' and thead/tr/th[2]='截止期' and thead/tr/th[3]='基金经理' and thead/tr/th[5]='任职回报']/tbody/tr")
  if (!length(rows)) stop("Management history unavailable.", call. = FALSE)
  parse_row <- function(row) {
    cells <- xml2::xml_find_all(row, "./td")
    if (length(cells) != 5L) stop("Invalid management history row.", call. = FALSE)
    fields <- xml2::xml_text(cells, trim = TRUE)
    managers <- xml2::xml_text(xml2::xml_find_all(cells[[3]], ".//a"), trim = TRUE)
    current <- fields[2] == "至今"
    start <- parse_nav_date(fields[1])
    end <- if (current) as.Date(NA_character_) else parse_nav_date(fields[2])
    if (!length(managers) || any(!nzchar(managers)) || is.na(start) ||
        (!current && (is.na(end) || end < start))) {
      stop("Invalid manager names or tenure dates.", call. = FALSE)
    }
    pct <- fields[5]
    missing <- pct %in% c("", "-", "--", "---")
    if (!missing && !grepl("^[+-]?[0-9]+([.][0-9]+)?%$", pct)) {
      stop("Invalid management interval return.", call. = FALSE)
    }
    data.frame(fund_code = fund_code, start_date = start, end_date = end,
               managers = paste(managers, collapse = "、"), team_size = length(managers),
               is_current = current, team_return_pct = if (missing) NA_real_ else as.numeric(sub("%$", "", pct)))
  }
  do.call(rbind, lapply(rows, parse_row))
}
