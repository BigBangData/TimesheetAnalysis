########################################################################################
## SETUP

 # uncomment to dev, comment to source
# setwd("../GitHub/TimesheetAnalysis")

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

# creata a dfd (data frame at the day level) of dates worked
set.seed(123)
binomial_mask <- rbinom(365, 1, 2/7)
date_spine <- seq(from=as.Date('2022-01-01'), to=as.Date('2022-12-31'), by=1)
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

even_p <- c(0.554, 0.266, 0.102, 0.078)

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
sess <- read.csv("data/session_min_prob.csv")

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
dd <- data.frame(
    dfs %>%
    select(date, day_period, end_datetime) %>%
    # filter(day_period == "eve") 
    group_by(date) %>%
    summarise(
        first_end = dplyr::first(end_datetime),
        last_end = dplyr::last(end_datetime)
    ) %>%
    arrange(desc(hour(last_end)))
)

# problematic days
dfs[hour(dfs$end_datetime) < 6, ]

## HERE HERE HERE

########################################################################################
# CLIENT CODES


client_codes <- c(
    "MM", "NAT-C", "NAT-A", "NAT-B", "TR-La", "TR-Ma", "ACT"
    , "BAR", "ZR", "X5", "CT-Y1", "CT-Y2", "G-TM", "G-AR", "BIZ"
)

client_codes_probs <- c(
    0.0339, 0.0392, 0.2533, 0.0836, 0.0914, 0.0627, 0.0653, 0.0131, 
    0.0261, 0.0261, 0.0183, 0.0731, 0.0888, 0.0151, 0.1100
)

set.seed(25)
dfs$client_code <- sample(x=client_codes,
    size=nrow(dfs), replace=TRUE, prob=client_codes_probs)

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

notes_probs <- c(
    0.23513, 0.26279, 0.15214, 0.13278, 0.07746, 
    0.03181, 0.03457, 0.02074, 0.02351, 0.01798, 0.01109
)

set.seed(25)
dfs$notes <- sample(x=notes, size=nrow(dfs)
    , replace=TRUE, prob=notes_probs)

tags <- c(
    ""
    , "done"
    , "redo"
    , "asap"
    , "fixed"
)

tags_probs <- c(0.50, 0.18, 0.14, 0.10, 0.08)

set.seed(25)
dfs$tags <- ifelse(
    dfs$notes != ""
    , sample(x=tags, size=nrow(dfs), replace=TRUE, prob=tags_probs)
    , ""
)

dfs$clock_in <- substr(dfs$start_datetime, 12, 19)
dfs$clock_out <- substr(dfs$end_datetime, 12, 19)

dfs <- dfs[, c("date", "clock_in", "clock_out", "client_code", "notes", "tags")]

write.csv(dfs, "data/timesheet.csv", row.names=FALSE)

# fake code clients
terms <- c(
    "month", "quarter", "biz", rep("quarter", 2), rep("month" , 2),
    "quarter", rep("month", 3), rep("quarter", 2), rep("month" , 2)
)

types <- c(
    rep("flat rate", 2), "biz", "hourly", "flat rate", "hourly",
    rep("flat rate", 5), "hourly", "flat_rate", rep("hourly", 2)
)

rates <- c(
    400, 700, 0.01, 90, 750, 90, 320, 750, 380, 420, 350, 90, 660, 90, 420
)

codes_rates <- data.frame(
    code=sort(client_codes)
    , term=terms
    , type=types
    , rate=rates
)

write.csv(codes_rates, "data/clients.csv", row.names=FALSE)
