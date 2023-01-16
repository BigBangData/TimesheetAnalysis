########################################################################################
## SETUP

setwd("faking_data")

# cleanup env
rm(list=ls())

install_packages <- function(pkg){
    new_pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new_pkg)) suppressMessages(
        install.packages(new_pkg, dependencies=TRUE)
    )
    sapply(pkg, require, character.only=TRUE)
}

pkgs <- c("dplyr", "lubridate")
suppressPackageStartupMessages(install_packages(pkgs))

########################################################################################
## WORK DAYS

# creata a data frame at the day level (dfd) of dates worked
set.seed(123)
year_start <- 2020
year_end <- 2023

if (year_start != year_end) {
    tot_num_days <- 0
    for (year in year_start:year_end) {
        num_days <- ifelse(year %% 4 != 0, 365, 366)
        tot_num_days <- tot_num_days +num_days
    }
} else {
    tot_num_days <- ifelse(year_start %% 4 != 0, 365, 366)
}

binomial_mask <- rbinom(tot_num_days, 1, 0.3) # a bit more than weekends off
date_spine <- seq(
    from=as.Date(paste0(year_start, '-01-01'), "%Y-%m-%d")
    , to=as.Date(paste0(year_end, '-12-31'), "%Y-%m-%d")
    , by=1
)

dfd <- data.frame(
    date=as.Date(date_spine)
    , day_out=binomial_mask
)

dfd <- dfd[dfd$day_out == 0, ]
dfd$day_out <- NULL

# add start times for the day
# hours
start_h_prob <- c(
    0.215, 0.370, 0.237, 0.052, 0.013, 0.012, 0.017, # 6 AM through noon
    0.013, 0.010, 0.009, 0.009, 0.004, # 1 through 5 PM
    0.004, 0.021, 0.008, 0.006 # evening
)
# mins
start_m_prob <- c(
    0.091, 0.004, 0.009, 0.017, 0.017, 0.022, 0.013, 0.013, 0.013, 0.009,
    0.026, 0.013, 0.017, 0.009, 0.009, 0.069, 0.009, 0.004, 0.000, 0.022,
    0.000, 0.017, 0.026, 0.004, 0.013, 0.039, 0.013, 0.017, 0.013, 0.009,
    0.056, 0.009, 0.004, 0.000, 0.009, 0.022, 0.013, 0.017, 0.013, 0.004,
    0.026, 0.000, 0.004, 0.013, 0.017, 0.034, 0.004, 0.013, 0.009, 0.009,
    0.039, 0.004, 0.004, 0.026, 0.004, 0.034, 0.013, 0.017, 0.043, 0.004
)

set.seed(234)
Ndays <- nrow(dfd)
start_h <- sample(x=6:21, size=Ndays, replace=TRUE, prob=start_h_prob)
start_m <- sample(x=0:59, size=Ndays, replace=TRUE, prob=start_m_prob)

dfd$start_time <- paste0(
    sprintf("%02d", start_h), ":", sprintf("%02d", start_m), ":00"
)

# add a day-period dimension since the distributions of num_sessions and 
# prob of minutes worked in those sesssions are conditional on which 
# period of the day work started
dfd$day_period <- ifelse(dfd$start_time <= '12:00:00', "morning"
    , ifelse(dfd$start_time > '12:00:00' & dfd$start_time <= '17:00:00'
    , "afternoon", "eve"))

# add number of sessions that day, conditional on day period
morn_p <- c(
    0.03448, 0.06465, 0.02586, 0.07327, 0.05172, 0.05172, 0.08189, 0.07758, 
    0.12068, 0.08620, 0.09913, 0.05172, 0.03879, 0.03879, 0.04741, 0.01293, 
    0.00862, 0.00862, 0.00862, 0.00008, 0.00862, 0.00862
)

aftn_p <- c(
    0.0928, 0.1501, 0.2210, 0.2044, 0.1401, 0.0766, 0.0513, 0.0319, 0.0191, 
    0.0127
)

even_p <- c(0.554, 0.296, 0.122, 0.028)

n_morn <- nrow(dfd[dfd$day_period == "morning", ])
n_aftn <- nrow(dfd[dfd$day_period == "afternoon", ])
n_even <- nrow(dfd[dfd$day_period == "eve", ])

set.seed(25)
dfd$num_sessions <- ifelse(
    dfd$day_period == "morning"
    , sample(x=1:length(morn_p), size=n_morn, replace=TRUE, prob=morn_p)
    , ifelse(
        dfd$day_period == "afternoon"
        , sample(x=1:length(aftn_p), size=n_aftn, replace=TRUE, prob=aftn_p)
        # evening
        , sample(x=1:length(even_p), size=n_even, replace=TRUE, prob=even_p)
    )
)

########################################################################################
## SESSIONS

# explode to session-level data
Nsess <- sum(dfd$num_sessions)

# add a session number to identify session along with date
dfs <- data.frame(
    date=as.Date(rep(NA, Nsess)),
    start_time=as.character(rep("", Nsess)),
    day_period=as.character(rep("", Nsess)),
    num_sessions=as.integer(rep(0, Nsess)),
    session_num=as.integer(rep(0, Nsess))
)

# populate dfs
ct <- 1
for (i in 1:nrow(dfd)) {
    for (j in 1:dfd$num_sessions[i]) {
        dfs$date[ct] <- dfd$date[i]
        dfs$start_time[ct] <- dfd$start_time[i]
        dfs$day_period[ct] <- dfd$day_period[i]
        dfs$num_sessions[ct] <- dfd$num_sessions[i]
        dfs$session_num[ct] <- j
        ct <- ct + 1
    }
}

# add session duration in minutes, depending on period of day
# load probs
sess <- read.csv("session_min_prob.csv")

n_morn <- nrow(dfs[dfs$day_period == "morning", ])
n_aftn <- nrow(dfs[dfs$day_period == "afternoon", ])
n_even <- nrow(dfs[dfs$day_period == "eve", ])

set.seed(25)
dfs$session_mins <- ifelse(
    dfs$day_period == "morning"
    , sample(x=1:nrow(sess), size=n_morn, replace=TRUE, prob=sess$morn_p)
    , ifelse(
        dfs$day_period == "afternoon"
        , sample(x=1:nrow(sess), size=n_aftn, replace=TRUE, prob=sess$aftn_p)
        # evening
        , sample(x=1:nrow(sess), size=n_even, replace=TRUE, prob=sess$even_p)
    )
)

# when over 15 sessions, reduce long sessions
cond <- (dfs$num_sessions >= 15 & dfs$session_mins >= 40)
dfs$session_mins[cond] <- floor(dfs$session_mins[cond]/4)

# do it again if necessary
cond <- (dfs$num_sessions >= 15 & dfs$session_mins >= 40)
if (length(dfs$session_mins[cond]) > 0) {
    cond <- (dfs$num_sessions >= 15 & dfs$session_mins >= 40)
    dfs$session_mins[cond] <- floor(dfs$session_mins[cond]/4)
}

# calculate cumulative sum of minutes through the day
dfs$cumsum_mins <- ave(dfs$session_mins, dfs$date, FUN=cumsum)

# start_time: at the day level
# start_datetime: at the session level
dfs$start_datetime <- strptime(
    paste0(dfs$date, ' ', dfs$start_time), "%Y-%m-%d %H:%M:%S"
)

for (i in 2:nrow(dfs)) {
    # skips first session of each day (which has a different date)
    if (dfs$date[i] == dfs$date[i-1]) {
        # change start datetime by adding previous session minutes
        # (times 60 since datetime is in seconds)
        dfs$start_datetime[i] <- dfs$start_datetime[i] + dfs$cumsum_mins[i-1] * 60
    }
}

# create end datetimes based on session start times and session durations
dfs$end_datetime <- dfs$start_datetime + dfs$session_mins * 60

# examine data for issues such as working through midnight
# dd <- data.frame(
#     dfs %>%
#     select(date, day_period, end_datetime) %>%
#     # filter(day_period == "eve") 
#     group_by(date) %>%
#     summarise(
#         first_end = dplyr::first(end_datetime),
#         last_end = dplyr::last(end_datetime)
#     ) %>%
#     arrange(desc(hour(last_end)))
# )

# # days when worked through midnight
# dfs[hour(dfs$end_datetime) < 6, ]
# dfs[dfs$date != substr(dfs$start_datetime, 1, 10), ]


########################################################################################
# CLIENT CODES

code <- c(
    "AAPL"
    , "AMZN"
    , "BIZ"
    , "BRK/A"
    , "BRK/B"
    , "CVX"
    , "GOOG"
    , "HD"
    , "JNJ"
    , "JPM"
    , "MA"
    , "META"
    , "MSFT"
    , "NVDA"
    , "NVO"
    , "PFE"
    , "PG"
    , "TSLA"
    , "TSM"
    , "UNH"
    , "WMT"
    , "XOM"
)

code_p <- c(
    0.05
    , 0.05
    , 0.15
    , 0.01
    , 0.02
    , 0.04
    , 0.05
    , 0.03
    , 0.02
    , 0.01
    , 0.01
    , 0.04
    , 0.06
    , 0.05
    , 0.05
    , 0.04
    , 0.06
    , 0.08
    , 0.04
    , 0.03
    , 0.07
    , 0.04
)

set.seed(23487)
dfs$code <- sample(x=code, size=nrow(dfs), replace=TRUE, prob=code_p)

notes <- c(
    ""
    , "emails"
    , "setup books"
    , "prep for mtg"
    , "phone call"
    , "balance sheets"
    , "check last month's payments"
    , "price quotes"
    , "crosscheck w bank statements"
    , "planning session"
    , "discuss issues"
)

notes_p <- c(
    0.23513
    , 0.26279
    , 0.15214
    , 0.13278
    , 0.07746
    , 0.03181
    , 0.03457
    , 0.02074
    , 0.02351
    , 0.01798
    , 0.01109
)

set.seed(25)
dfs$notes <- sample(x=notes, size=nrow(dfs), replace=TRUE, prob=notes_p)

tags <- c(
    ""
    , "done"
    , "redo"
    , "asap"
    , "fixed"
)

tags_p <- c(0.50, 0.18, 0.14, 0.10, 0.08)

set.seed(234595)
dfs$tags <- ifelse(dfs$notes != ""
    , sample(x=tags, size=nrow(dfs), replace=TRUE, prob=tags_p)
    , ""
)

dfs$clock_in <- substr(dfs$start_datetime, 12, 19)
dfs$clock_out <- substr(dfs$end_datetime, 12, 19)

tms <- dfs[, c("date", "clock_in", "clock_out", "code", "notes", "tags")]

# SAVE
write.csv(tms, "../data/timesheet.csv", row.names=FALSE)

########################################################################################
# CLIENT DATA

term <- c(
    "month"
    ,"quarter"
    ,"biz"
    ,"month"
    ,"month"
    ,"quarter"
    ,"quarter"
    ,"month"
    ,"month"
    ,"month"
    ,"quarter"
    ,"quarter"
    ,"quarter"
    ,"month"
    ,"month"
    ,"month"
    ,"month"
    ,"quarter"
    ,"quarter"
    ,"quarter"
    ,"month"
    ,"month"
)

type <- c(
    "flat rate"
    , "flat rate"
    , "biz"
    , "hourly"
    , "flat rate"
    , "flat rate"
    , "hourly"
    , "hourly"
    , "flat rate"
    , "flat rate"
    , "flat rate"
    , "flat rate"
    , "flat rate"
    , "hourly"
    , "flat rate"
    , "flat rate"
    , "hourly"
    , "hourly"
    , "flat rate"
    , "flat rate"
    , "hourly"
    , "flat rate"
)

rate <- c(
    420.00
    , 800.00
    , 0.01
    , 100.00
    , 330.00
    , 850.00
    , 120.00
    , 90.00
    , 380.00
    , 350.00
    , 700.00
    , 780.00
    , 820.00
    , 120.00
    , 350.00
    , 400.00
    , 100.00
    , 90.00
    , 680.00
    , 750.00
    , 90.00
    , 420.00
)

clients <- data.frame(
    code=code
    , term=term
    , type=type
    , rate=rate
)

# SAVE
write.csv(clients, "../data/clients.csv", row.names=FALSE)
setwd("..")