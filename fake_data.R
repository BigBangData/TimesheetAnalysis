
# Faking data:
# ------------

# setwd("../GitHub/TimesheetAnalysis")

# creata a dfm of dates worked
rm(list=ls())

install_packages <- function(pkg){
    new_pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new_pkg)) suppressMessages(install.packages(new_pkg, dependencies = TRUE))
    sapply(pkg, require, character.only = TRUE)
}

pkgs <- c("dplyr", "lubridate")
suppressPackageStartupMessages(install_packages(pkgs))


set.seed(25)
binomial_mask <- rbinom(365, 1, 2/7)
date_spine <- seq(from=as.Date('2022-01-01'), to=as.Date('2022-12-31'), by=1)
dfm <- data.frame(
    date = as.Date(date_spine)
    , day_out = binomial_mask
)

dfm <- dfm[dfm$day_out == 0, ]
dfm$day_out <- NULL

# add start times for day
hour_start_probs <- c(
    0.215, 0.379, 0.237, 0.052, 0.013, 0.017, 0.017, 0.013, 0.010, 0.009, 
    0.009, 0.004, 0.004, 0.013, 0.004, 0.004
)

mins_start_probs <- c(
    0.091, 0.004, 0.009, 0.017, 0.017, 0.022, 0.013, 0.013, 0.013, 0.009,
    0.026, 0.013, 0.017, 0.009, 0.009, 0.069, 0.009, 0.004, 0.000, 0.022,
    0.000, 0.017, 0.026, 0.004, 0.013, 0.039, 0.013, 0.017, 0.013, 0.009,
    0.056, 0.009, 0.004, 0.000, 0.009, 0.022, 0.013, 0.017, 0.013, 0.004,
    0.026, 0.000, 0.004, 0.013, 0.017, 0.034, 0.004, 0.013, 0.009, 0.009,
    0.039, 0.004, 0.004, 0.026, 0.004, 0.034, 0.013, 0.017, 0.043, 0.004
)

set.seed(25)
hour_start <- sample(x = 6:21, size = nrow(dfm), replace = TRUE, prob = hour_start_probs)
mins_start <- sample(x = 0:59, size = nrow(dfm), replace = TRUE, prob = mins_start_probs)

dfm$start_time <- paste0(sprintf("%02d", hour_start), ":", sprintf("%02d", mins_start), ":00")

# add number of sessions that day, yet highly dependent on hour start
# for morning-start sessions, use 1:22 probs
mrn_probs <- c(
    0.03448, 0.06465, 0.02586, 0.07327, 0.05172, 0.05172, 0.08189, 0.07758, 
    0.12068, 0.08620, 0.09913, 0.05172, 0.03879, 0.03879, 0.04741, 0.01293, 
    0.00862, 0.00862, 0.00862, 0.00008, 0.00862, 0.00862
)
# for afternoon-start sessions, use 1:10 probs
aft_probs <- c(
    0.0928, 0.1501, 0.2210, 0.2044, 0.1401, 0.0766, 0.0513, 0.0319, 0.0191, 0.0127
)

# for evening-start sessions, use 1:4 probs
eve_probs <- c(0.554, 0.266, 0.102, 0.078)

# conditions
mrn_cond <- (dfm$start_time <= '12:00:00')
aft_cond <- (dfm$start_time > '12:00:00' & dfm$start_time <= '17:00:00')
eve_cond <- (dfm$start_time > '17:00:00')

mrn_nrow <- nrow(dfm[mrn_cond,])
aft_nrow <- nrow(dfm[aft_cond,])
eve_nrow <- nrow(dfm[eve_cond,])

set.seed(25)
dfm$num_sessions <- ifelse(mrn_cond
    , sample(x = 1:22, size = mrn_nrow, replace = TRUE, prob = mrn_probs),
    ifelse(aft_cond
        , sample(x = 1:10, size = aft_nrow, replace = TRUE, prob = aft_probs)
        , sample(x = 1:4, size = eve_nrow, replace = TRUE, prob = eve_probs)))


# explode to session-level data
N <- sum(dfm$num_sessions)

# add session numbers
new_df <- data.frame(
    date = as.Date(rep(NA, N)),
    start_time = as.character(rep("", N)),
    num_sessions = as.integer(rep(0, N)),
    session_num = as.integer(rep(0, N))
)

ct <- 1
for (i in 1:nrow(dfm)) {
    for (j in 1:dfm$num_sessions[i]) {
        new_df$date[ct] <- dfm$date[i]
        new_df$start_time[ct] <- dfm$start_time[i]
        new_df$num_sessions[ct] <- dfm$num_sessions[i]
        new_df$session_num[ct] <- j
        ct <- ct + 1
    }
}

# add session duration in minutes
session_min_probs <- c(
  0.001955990, 0.003911980, 0.018581907, 0.022493888, 0.032273839, 0.028361858, 0.025427873, 0.031295844, 0.018581907, 0.028361858
, 0.023471883, 0.027872861, 0.025427873, 0.019559902, 0.036674817, 0.016625917, 0.018581907, 0.021026895, 0.017603912, 0.019070905
, 0.015647922, 0.020048900, 0.008312958, 0.013691932, 0.014669927, 0.014180929, 0.018092910, 0.013202934, 0.013202934, 0.017114914
, 0.012224939, 0.007823961, 0.005867971, 0.007823961, 0.007334963, 0.008312958, 0.008801956, 0.007823961, 0.005867971, 0.012713936
, 0.010268949, 0.007823961, 0.008801956, 0.005867971, 0.009779951, 0.005867971, 0.004889976, 0.005378973, 0.006356968, 0.007823961
, 0.004400978, 0.003422983, 0.004400978, 0.005378973, 0.005867971, 0.008312958, 0.004400978, 0.004889976, 0.004400978, 0.008312958
, 0.007823961, 0.004400978, 0.006845966, 0.006845966, 0.005378973, 0.002933985, 0.002933985, 0.003911980, 0.006356968, 0.003911980
, 0.003422983, 0.003422983, 0.005378973, 0.002444988, 0.005867971, 0.002444988, 0.001955990, 0.002933985, 0.002444988, 0.002444988
, 0.003422983, 0.003911980, 0.003422983, 0.001466993, 0.000977995, 0.002444988, 0.001466993, 0.002933985, 0.003422983, 0.002933985
, 0.001955990, 0.000977995, 0.002933985, 0.003422983, 0.004889976, 0.003422983, 0.000488998, 0.000977995, 0.001955990, 0.004400978
, 0.002933985, 0.001466993, 0.002444988, 0.003422983, 0.001955990, 0.000488998, 0.001955990, 0.001466993, 0.000488998, 0.002933985
, 0.000488998, 0.001466993, 0.000488998, 0.001466993, 0.001466993, 0.001466993, 0.000977995, 0.000488998, 0.000488998, 0.000977995
, 0.000977995, 0.000000000, 0.000977995, 0.000000000, 0.000488998, 0.003422983, 0.000488998, 0.001466993, 0.000977995, 0.000000000
, 0.000977995, 0.000977995, 0.000488998, 0.000488998, 0.000000000, 0.001466993, 0.000488998, 0.000000000, 0.000977995, 0.000000000
, 0.000488998, 0.000000000, 0.000977995, 0.000488998, 0.000000000, 0.000488998, 0.000977995, 0.000000000, 0.000488998, 0.000977995
, 0.000000000, 0.000488998, 0.002444988, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000977995, 0.000000000, 0.000488998
, 0.000000000, 0.000000000, 0.000488998, 0.000488998, 0.000488998, 0.000488998, 0.000977995, 0.000000000, 0.000977995, 0.000000000
, 0.000488998, 0.000488998, 0.000000000, 0.000000000, 0.000000000, 0.000488998, 0.000977995, 0.000000000, 0.000488998, 0.000000000
, 0.000000000, 0.000977995, 0.000000000, 0.000000000, 0.000000000, 0.000488998, 0.000000000, 0.000000000, 0.000000000, 0.000488998
, 0.000977995, 0.000000000, 0.000488998, 0.000000000, 0.000488998, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000000000
, 0.000000000, 0.000000000, 0.000000000, 0.000422983, 0.000000000, 0.000500000, 0.000000000, 0.000000000, 0.000000000, 0.000000000
, 0.000500000, 0.000000000, 0.000000000, 0.000500000, 0.000500000, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000000000
, 0.000000000, 0.000500000, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000500000
)

set.seed(25)
new_df$session_mins <- sample(x = 1:length(session_min_probs), size = nrow(new_df), replace = TRUE, prob = session_min_probs)

new_df$cumsum_mins <- ave(new_df$session_mins, new_df$date, FUN = cumsum)

# calculate end times for sessions and note any oddities (too long days that go past midnight?)
new_df$start_datetime <- strptime(paste0(new_df$date, ' ', new_df$start_time), "%Y-%m-%d %H:%M:%S")

for (i in 2:nrow(new_df)) {
    if (new_df$date[i] == new_df$date[i-1]) {
        new_df$start_datetime[i] <- new_df$start_datetime[i] + new_df$cumsum_mins[i-1]*60
    }
}

new_df$end_datetime <- new_df$start_datetime + new_df$session_mins*60

client_codes <- c(
    "MM", "NAT-C", "NAT-A", "NAT-B", "TR-La", "TR-Ma", "ACT"
    , "BAR", "ZR", "X5", "CT-Y1", "CT-Y2", "G-TM", "G-AR", "BIZ"
)

client_codes_probs <- c(
    0.0339, 0.0392, 0.2533, 0.0836, 0.0914, 0.0627, 0.0653, 0.0131, 
    0.0261, 0.0261, 0.0183, 0.0731, 0.0888, 0.0151, 0.1100
)

set.seed(25)
new_df$client_code <- sample(x = client_codes,
    size = nrow(new_df), replace = TRUE, prob = client_codes_probs)

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
new_df$notes <- sample(x = notes, size = nrow(new_df), replace = TRUE, prob = notes_probs)

tags <- c(
    ""
    , "done"
    , "redo"
    , "asap"
    , "fixed"
)

tags_probs <- c(0.50, 0.18, 0.14, 0.10, 0.08)

set.seed(25)
new_df$tags <- ifelse(new_df$notes != ""
    , sample(x = tags, size = nrow(new_df), replace = TRUE, prob = tags_probs)
    , "")

new_df$clock_in <- substr(new_df$start_datetime, 12, 19)
new_df$clock_out <- substr(new_df$end_datetime, 12, 19)

new_df <- new_df[, c("date", "clock_in", "clock_out", "client_code", "notes", "tags")]

write.csv(new_df, "data/timesheet.csv", row.names=FALSE)

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
    code = sort(client_codes)
    , term = terms
    , type = types
    , rate = rates
)

write.csv(codes_rates, "data/clients.csv", row.names=FALSE)