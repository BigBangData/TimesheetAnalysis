
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

hour_start <- sample(x = 6:21, size = nrow(dfm), replace = TRUE, prob = hour_start_probs)
mins_start <- sample(x = 0:59, size = nrow(dfm), replace = TRUE, prob = mins_start_probs)

dfm$start_time <- paste0(sprintf("%02d", hour_start), ":", sprintf("%02d", mins_start), ":00")

# add number of sessions that day
session_n_probs <- c(
    0.03448, 0.06465, 0.02586, 0.07327, 0.05172, 0.05172, 0.08189, 0.07758, 
    0.12068, 0.08620, 0.09913, 0.05172, 0.03879, 0.03879, 0.04741, 0.01293, 
    0.00862, 0.00862, 0.00862, 0.00008, 0.00862, 0.00862
)

dfm$num_sessions <- sample(x = 1:22, size = nrow(dfm), replace = TRUE, prob = session_n_probs)

# explore num sessions with late start times, reduce by half, 2x, fix any leftovers over 8
dfm$num_sessions[dfm$start_time > '12:00:00'] <- ceiling(dfm$num_sessions[dfm$start_time > '12:00:00']/2)
dfm$num_sessions[dfm$start_time > '17:00:00'] <- ceiling(dfm$num_sessions[dfm$start_time > '17:00:00']/2)
dfm$num_sessions[dfm$start_time > '12:00:00'][dfm$num_sessions[dfm$start_time > '12:00:00'] >= 8] <- 4


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
    0.005015674, 0.010658307, 0.034482759, 0.060188088, 0.075235110, 0.063636364, 0.056426332,
    0.040752351, 0.072100313, 0.096238245, 0.061128527, 0.020376176, 0.013479624, 0.034169279,
    0.075548589, 0.046708464, 0.020689655, 0.015047022, 0.009404389, 0.021316614, 0.007523511,
    0.014420063, 0.003761755, 0.006269592, 0.018808777, 0.013793103, 0.008777429, 0.003761755,
    0.006269592, 0.028213166, 0.020062696, 0.013793103, 0.001253918, 0.003134796, 0.001253918,
    0.000626959, 0.001253918, 0.000940439, 0.000313480, 0.000313480, 0.000626959, 0.000940439,
    0.000313480, 0.001253918, 0.002507837, 0.000626959, 0.000313480, 0.000313480, 0.000000000,
    0.000626959, 0.000313480, 0.000313480, 0.000000000, 0.000000000, 0.000626959, 0.000313480,
    0.000000000, 0.000000000, 0.000626959, 0.001253918, 0.000626959, 0.000313480, 0.000313480,
    0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000000000, 0.000626959
)


new_df$session_mins <- sample(x = seq(2, 140, by = 2)
    , size = nrow(new_df), replace = TRUE, prob = session_min_probs)

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

new_df$notes <- sample(x = notes, size = nrow(new_df), replace = TRUE, prob = notes_probs)

tags <- c(
    ""
    , "done"
    , "review"
    , "asap"
    , "yes"
)

tags_probs <- c(0.50, 0.18, 0.14, 0.10, 0.08)

new_df$tags <- sample(x = tags, size = nrow(new_df), replace = TRUE, prob = tags_probs)

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