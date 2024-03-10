library(fusen)
# Create a new project
FundR <- "C:/Users/Dell/Documents/projects/FundR" #(tempfile(pattern = "pptsdd")

# {fusen} steps
dev_file <- create_fusen(FundR, template = "teaching", open = FALSE)


# Explore directory of the package
browseURL(fundR)


devtools::build(path = "./", binary = T)
remotes::install_local(force = F)

#set package icon
library(hexSticker)
library(showtext)
imgurl <- "C:/Users/Dell/Downloads/piggy-bank.png"
## Loading Google fonts (http://www.google.com/fonts)
font_add_google("Orbitron")
## Automatically use showtext to render text for future devices
showtext_auto()
s <- sticker(imgurl, package="FundR", p_size=8.8, s_x=1, s_y=0.78, s_width=.39,p_y = 1.39,p_color = "#1e2732", p_fontface = "bold",p_family = "Orbitron",
             h_fill="#ffffff", h_color="#1e2732", url = "https://tony2015116.github.io/FundR/",u_size = 1.3,filename="C:/Users/Dell/Downloads/logo.svg")
plot(s) #导出logo.svg后移动到package包主目录下即可运行下面的命令
pkgdown::build_favicons(pkg = ".", overwrite = TRUE)
#将logo.svg转移到docs/reference/figures/中

#Try pkgdown build
#step1
usethis::use_pkgdown()#如果使用prefarly包，这个命令只需要使用一次
#step2
#usethis::use_pkgdown_github_pages()#对于需要如下载等特殊环境的不适用，该命令只需执行一次。在代码做出变动时，只需commit,push即可，build_site()/run example有github action执行。
#step2
pkgdown::build_site(example = T)




usethis::use_article(name = "tut", title = "test")
usethis::use_vignette(name = "tut", title = "test")
pkgdown::build_article("tut")
pkgdown::build_article("tut")

usethis::use_news_md()
pkgdown::build_news()

usethis::use_readme_md()

pkgdown::build_reference()
pkgdown::build_reference_index()
#usethis::use_pkgdown_github_pages()
#1.3.5
usethis::use_git(message = ":art: improve structures")#每次修改完代码，都需使用该命令（新建立R包时也要使用该命令）
#4. #commit 后，可使用Rstudio push 或者 Tools shell -> git push
#2.
usethis::use_github()#包的名字由description文件控制
#usethis::use_git_remote("origin", url = "https://github.com/tony2015116/pptos.git", overwrite = TRUE)
#usethis::use_git_remote("origin", url = NULL, overwrite = TRUE)
usethis::use_github_release()#发布R包

#安装R包
devtools::install_github("tony2015116/pptsdd")


install.packages("preferably")
