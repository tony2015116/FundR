#' Review a fund against a historical drawdown limit
#'
#' @param nav A single fund's complete, unfiltered fund_nav() result for the
#'   period. Requires unique dates and finite reported returns after day one.
#' @param max_drawdown_pct Positive loss limit in percentage points, up to 100.
#' @return One row with fund_code, start_date, end_date, n_returns,
#'   period_return_pct, observed_drawdown_pct (positive loss magnitude),
#'   limit_pct and limit_reached. Equality counts as reaching the limit.
#' @details Compounds the provider's reported daily percentage changes from
#'   the first observation as baseline. Results reflect published precision
#'   and omit investor-specific fees. Missing calendar rows cannot be inferred.
#' @export
fund_risk_review <- function(nav, max_drawdown_pct) {
  if (!is.numeric(max_drawdown_pct) || length(max_drawdown_pct) != 1L ||
      !is.finite(max_drawdown_pct) || max_drawdown_pct <= 0 || max_drawdown_pct > 100) {
    stop("max_drawdown_pct must be a number in (0, 100].", call. = FALSE)
  }
  required <- c("fund_code", "date", "daily_return_pct")
  if (!is.data.frame(nav) || !all(required %in% names(nav)) || nrow(nav) < 2L) {
    stop("Supply at least two fund_nav() observations.", call. = FALSE)
  }
  code <- unique(nav$fund_code)
  validate_fund_code(code)
  if (!inherits(nav$date, "Date") || any(!is.finite(nav$date)) || anyDuplicated(nav$date)) {
    stop("Supply distinct, valid NAV dates.", call. = FALSE)
  }
  nav <- nav[order(nav$date), , drop = FALSE]
  returns <- nav$daily_return_pct[-1L]
  if (!is.numeric(returns) || any(!is.finite(returns)) || any(returns < -100)) {
    stop("Incomplete or invalid daily returns after the first observation.", call. = FALSE)
  }
  wealth <- cumprod(c(1, 1 + returns / 100))
  drawdown <- 100 * max(1 - wealth / cummax(wealth))
  data.frame(fund_code = code, start_date = nav$date[1L], end_date = max(nav$date),
             n_returns = length(returns), period_return_pct = 100 * (wealth[length(wealth)] - 1),
             observed_drawdown_pct = drawdown, limit_pct = max_drawdown_pct,
             limit_reached = drawdown >= max_drawdown_pct ||
               isTRUE(all.equal(drawdown, max_drawdown_pct, tolerance = 1e-12)))
}
