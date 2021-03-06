library(shiny)
library(shinyjs)
library(ShinyPsych)
library(htmltools)
library(plotly)
library(dplyr)
library(fullPage)
library(RColorBrewer)
library(tidyquant)
library(rdrop2)

# setwd("C:/Users/mwandingik/Box/Ergo Analytics/Projects/Rydefine")
# s <- "C:/Users/mwandingik/Box/Ergo Analytics/Projects/Rydefine/PompianSurvey.txt"
# i <- "C:/Users/mwandingik/Box/Ergo Analytics/Projects/Rydefine/instructions.txt"

drop_auth(rdstoken = "dbtoken.rds")  
drop_acc()
# Dropbox directory to save data
outputDir <- "rydefineShiny/responses"

saveData <- function(data) {
  data <- t(data)
  # Create a unique file name
  fileName <- sprintf("%s_%s.csv", as.integer(Sys.time()), digest::digest(data))
  # Write the data to a temporary file locally
  filePath <- file.path(tempdir(), fileName)
  write.csv(data, filePath, row.names = FALSE, quote = TRUE)
  # Upload the file to Dropbox
  drop_upload(filePath, path = outputDir)
}

loadData <- function() {
  # Read all the files into a list
  filesInfo <- drop_dir(outputDir)
  filePaths <- filesInfo$path
  data <- lapply(filePaths, drop_read_csv, stringsAsFactors = FALSE)
  # Concatenate all data together into one data.frame
  data <- do.call(rbind, data)
  data
}

# Vector with page ids used to later access objects
# idsVec <- c("Instructions", "Survey", "Demographics", "Goodbye")

#investor Scores
#data.list <- read.csv("C:/Users/mwandingik/Box/Ergo Analytics/Projects/Rydefine/www/2345tzv15705479335741f67b3884afcec45d31a06966234c_g.csv")
inv.m <- read.csv("invest_matrix.csv")

myPalette <- brewer.pal(5, "Set2")

#create page lists for the instructions and the last page
#There are some default files, such as the four loaded in here. If you do not use a default list, make sure to set the defaulttxt argument of createPageList() to FALSE.
# instructions.list <- createPageList(defaulttxt  = FALSE, fileName = i,location = "local",
#                                     globId = "Instructions")#to move from survey to next section
# 
# survey.list <- createPageList(defaulttxt  = FALSE, fileName = s,location = "local",
#                               globId = "Survey")
# 
# # survey.list <- createPageList(fileName = "Survey_Example",
# #                               globId = "Survey")
# 
# 
# demographics.list <- createPageList(fileName = "Demographics")
# 
# goodbye.list <- createPageList(fileName = "Goodbye")
# 
# # CurrentValues controls page setting such as which page to display
# CurrentValues <- createCtrlList(firstPage = "instructions", # id of the first page
#                                 globIds = idsVec,           # ids of pages for createPage
#                                 complCode = TRUE,           # create a completion code
#                                 complName = "EP-Survey")    # first element of completion code

pool <- data.frame(
  id = "Pool Level",
  target = 1,
  current = 0.6,
  pool = "A pool is where respondents with similar profiles can pool their money and we will invest in funds suitable to them. 
          You are finally able to participate in finance no matter your income level."
  )

#Paypal------

ppsrc <- tags$script(src = "https://www.paypalobjects.com/api/checkout.js")
ppcode <- tags$script("paypal.Button.render({
                            // Configure environment
                            env: 'sandbox',
                            client: {
                            sandbox: 'demo_sandbox_client_id',
                            production: 'demo_production_client_id'
                            },
                            // Customize button (optional)
                            locale: 'en_US',
                            style: {
                            size: 'small',
                            color: 'white',
                            shape: 'pill',
                            },
                            // Set up a payment
                            payment: function (data, actions) {
                            return actions.payment.create({
                            transactions: [{
                            amount: {
                            total: '0.01',
                            currency: 'USD'
                            }
                            }]
                            });
                            },
                            // Execute the payment
                            onAuthorize: function (data, actions) {
                            return actions.payment.execute()
                            .then(function () {
                            // Show a confirmation message to the buyer
                            window.alert('Thank you for your purchase!');
                            });
                            }
                            }, '#paypal-button');")
ppid <- tags$div(id = "paypal-button")

# ppsrc
# ppcode
# ppid

##Rydefine----
cn <- c("date","adjClose")
ABSBINA_price <- read.csv("ABSA_ABSBINA SJ EQUITY_price.csv")
SYGALBB_price <- read.csv("SYGALBB_SJ_EQUITY_price.csv")
ASHR40_price <- read.csv("ASHR40_SJ_EQUITY_price.csv")

colnames(ASHR40_price) <- cn
colnames(SYGALBB_price) <- cn


ASHR40_price$date <- strptime(as.character(ASHR40_price$date), "%m/%d/%Y")
SYGALBB_price$date <- strptime(as.character(SYGALBB_price$date), "%m/%d/%Y")

ASHR40_price$date <- as.Date(ASHR40_price$date)
SYGALBB_price$date <- as.Date(SYGALBB_price$date)

#convert data to monthly
ASHR40_price <- ASHR40_price %>% tq_transmute(select = adjClose, mutate_fun = to.monthly, indexAt = "lastof")
SYGALBB_price <- SYGALBB_price %>% tq_transmute(select = adjClose, mutate_fun = to.monthly, indexAt = "lastof")

#Calculate returns
n_lag <- 12

ASHR40_returns <- 
  ASHR40_price %>% 
  mutate(ASHR40_return =  ((adjClose / lag(adjClose)) - 1),
         ASHR40_twelve_mon_ret = ((adjClose / lag(adjClose, n_lag)) -1)) %>%
  dplyr::select(-adjClose) %>% 
  na.omit()

SYGALBB_returns <- 
  SYGALBB_price %>% 
  mutate(SYGALBB_return =  ((adjClose / lag(adjClose)) - 1),
         SYGALBB_twelve_mon_ret = ((adjClose / lag(adjClose, n_lag)) -1)) %>%
  dplyr::select(-adjClose) %>% 
  na.omit()

ASHR40_returns <- ASHR40_returns[112:121,]

#forecast


inv.m$Momentum[3] <- mean(ASHR40_returns$ASHR40_twelve_mon_ret)
inv.m$Momentum[2] <- mean(SYGALBB_returns$SYGALBB_twelve_mon_ret)



ASH40gs <- readRDS(file = "ASH40gs.rds")
SYGT40gs <- readRDS(file = "SYGT40gs.rds")


inv.m$Sentiment[3] <- mean(ASH40gs$score_pct)
inv.m$Sentiment[2] <- mean(SYGT40gs$score_pct)

sa <- gdata::combine(ASH40gs, SYGT40gs)