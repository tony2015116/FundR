eastmoney_get <- function(request) {
  request <- httr2::req_user_agent(request, "Mozilla/5.0 (compatible; FundR)")
  request <- httr2::req_timeout(request, seconds = 20)
  request <- httr2::req_retry(request, max_tries = 3, retry_on_failure = TRUE)

  tryCatch(
    httr2::resp_body_string(httr2::req_perform(request)),
    error = function(error) {
      stop("Eastmoney request failed: ", conditionMessage(error), call. = FALSE)
    }
  )
}

eastmoney_json <- function(body, resource) {
  tryCatch(
    jsonlite::fromJSON(body, simplifyVector = FALSE),
    error = function(error) {
      stop("Eastmoney returned invalid JSON for the ", resource, ".", call. = FALSE)
    }
  )
}
