# FundR <a href='https://tony2015116.github.io/FundR/'><img src='man/figures/logo.svg'  width="120" align="right" />
<!--apple-touch-icon-120x120.png-->
<!-- <picture><source srcset="reference/figures/apple-touch-icon-120x120.png" media="(prefers-color-scheme: dark)"></picture> -->
<!-- badges: start -->
[![GitHub R package version](https://img.shields.io/github/r-package/v/tony2015116/FundR)](#)
[![GitHub last commit](https://img.shields.io/github/last-commit/tony2015116/FundR)](#)
<!-- badges: end -->

`FundR` is an R package that allows windows users to manage the *downloading* and *running* of third party binaries relating to the webdriver/selenium projects using Google browser. The package was inspired by [wdman](https://docs.ropensci.org/wdman/) and my work [pptsdd](https://tony2015116.github.io/pptsdd/).`get_cd()` and `get_ss()` are used to download chromedriver and selenium server respectively. `auto_cs()` is used to start the selenium webdriver service. `reset_cs()` is used to reset the selenium webdriver service.

The downloading of binaries is handled by the [`httr2`](https://httr2.r-lib.org/) package and [`rvest`](https://rvest.tidyverse.org/) package, and the running of the binaries as processes is handled by generating a .bat file, which is placed in the Windows startup folder.

The `wdauto` package currently manages the following binaries:

* [chromedriver](https://chromedriver.chromium.org/)
* [Selenium standalone binary](http://selenium-release.storage.googleapis.com/index.html)

## Installation

You can install the development version of FundR from [GitHub](https://tony2015116.github.io/FundR/) with:

``` r
# install.packages("devtools")
devtools::install_github("tony2015116/FundR")
# install.packages("pak")
pak::pak("tony2015116/FundR")
```

## Example

This is a basic example which shows you how to start a selenium webdriver server:

``` r
library(FundR)

## download chromedriver
get_cd(dest_dir = "path/to/destination/directory")
## download selenium server
get_ss(dest_dir = "path/to/destination/directory")
## start selenium webdriver service
auto_cs(dest_dir = "path/to/destination/directory")
## reset selenium webdriver
reset_cs()
```



