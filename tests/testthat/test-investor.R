test_that("quarter changes distinguish new disclosures and changed share counts", {
  old <- data.frame(cusip = c("a","b"), issuer = c("A","B"), unit = "SH",
                    security_class = "COM", option = "", quantity = c(10,20),
                    cik = "1", report_date = as.Date("2026-06-30"), confidential_omissions = FALSE)
  new <- old
  new$report_date <- as.Date("2026-09-30")
  new$cusip[2] <- "c"
  new$quantity[1] <- 15
  diff <- investor_changes(old, new)
  expect_equal(diff$change, c(5,-20,20))
  expect_equal(diff$status, c("increased","no_longer_reported","newly_reported"))
  expect_error(investor_changes(new, old), "chronological")
})
