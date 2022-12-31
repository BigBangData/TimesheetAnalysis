# TO DO:
# fake data needs limit on work hours before midnight
# separate faking the data from the actual data, both code and csv

# fix for new year and leap year
# do client code data validation

# limitations:
# no variable rates per client

# current:
# recreate and add to github and portfolio
# fake data, different logo -> take pic of monty python clock!

# Setup
# -------

# cleanup env
rm(list=ls())
# disable scientific notation
options(scipen=999)
# suppress group by warnings
options(dplyr.summarise.inform = FALSE)


# Install and/or load packages
# ---------------------------

install_packages <- function(pkg){
    new_pkg <- pkg[!(pkg %in% installed.packages()[, "Package"])]
    if (length(new_pkg)) suppressMessages(install.packages(new_pkg, dependencies = TRUE))
    sapply(pkg, require, character.only = TRUE)
}

pkgs <- c("dplyr", "DT", "ggplot2", "ggrepel", "lubridate", "shiny")
suppressPackageStartupMessages(install_packages(pkgs))

# To test in R:
setwd("../GitHub/TimesheetAnalysis")

# input <- data.frame(
#     "report"="Monthly Hours"
#     , "term"=c("month")
#     , "quarter"=c("All")
#     , "start_date"=as.Date('2022-02-01')
#     , "end_date"=as.Date('2022-12-31')
#     , "client_group"="All"
# )

# Load data
# ---------

na_strings <- c("", "-", "NA", "N/A", "#N/A", "na", "n/a", "#n/a", "NULL", "Null", "null")
tms <- read.csv("data/timesheet.csv", na.strings = na_strings)
rts <- read.csv("data/clients.csv", na.strings = na_strings)

# fix data types
tms$date <- as.Date(tms$date, format="%Y-%m-%d")

tms$start_time <- strptime(paste0(tms$date, ' ', tms$clock_in), "%Y-%m-%d %H:%M:%S")
tms$end_time <- strptime(paste0(tms$date, ' ', tms$clock_out), "%Y-%m-%d %H:%M:%S")

tms$session_hs <- round(as.numeric(sub("secs", "", tms$end_time - tms$start_time))/60, 2)


# examine data to make sure ends of sessions are indeed before midnight
# but also not before 6 AM
t <- tms 
d <- t %>%
    select(date, end_time) %>%
    group_by(date) %>%
    summarise(
        first_end = dplyr::first(end_time),
        last_end = dplyr::last(end_time)
    )

d[hour(d$last_end) == max(hour(d$last_end)), ]
d[hour(d$first_end) == min(hour(d$first_end)), ]



# tms <- tms[which(!is.na(tms$date)),]
tms <- apply(tms, 2, function(x) trimws(x))
tms <- data.frame(tms, stringsAsFactors = FALSE)
tms$session_hs <- as.numeric(tms$session_hs)
tms$code <- toupper(tms$client_code)
exclude_cols <- c('clock_in', 'clock_out', 'end_time', 'client_code')
tms <- tms[ ,!colnames(tms) %in% exclude_cols]

# rates
rts <- apply(rts, 2, function(x) trimws(x))
rts <- data.frame(rts, stringsAsFactors = FALSE)
rts$rate <- as.numeric(rts$rate)
rts$code <- toupper(rts$code)
rts <- na.omit(rts)

# merge
# TO DO: more checking of client codes
mm <- merge(tms, rts, by.x="code", by.y="code")
mm$rate <- as.numeric(mm$rate)
mm <- mm[order(mm$start_time), ]
#mm <- mm[order(mm$date, mm$day_cumsum_hs), ]
row.names(mm) <- 1:nrow(mm)
#mm <- mm[, colnames(mm) != 'start_time']
mm <- mm[, c('code', 'date', 'session_hs', 'notes', 'tags', 'type', 'term', 'rate')]

# add missing dates
#mm <- mm[as.character(mm$date) %in% c('2022-10-01', '2022-10-03', '2022-10-05'), ]
date_spine <- seq(from=as.Date(min(mm$date)), to=as.Date(max(mm$date)), by=1)

# figure out which are missing
mm_dates <- as.character(unique(mm$date))
missing_dates <- date_spine[which(!as.character(date_spine) %in% mm_dates)]
N <- length(missing_dates)

# create a temp df with missing dates & append to bottom
temp <- data.frame(
    "code" = rep("", N)
    , "date" = as.character(missing_dates)
    , "session_hs" = rep(0.0, N)
    , "notes" = rep("", N)
    , "tags" = rep("", N)
    , "type" = rep("", N)
    , "term" = rep("", N)
    , "rate" = rep(0.0, N)
)
mm <- rbind(mm, temp)

# create date partitions
mm$year <- as.factor(substr(mm$date, 1, 4))
mm$month <- as.factor(substr(mm$date, 6, 7))
month_list <- c("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12")
mm$quarter <- ifelse(mm$month %in% month_list[1:3], "Q1",
    ifelse(mm$month %in% month_list[4:6], "Q2",
    ifelse(mm$month %in% month_list[7:9], "Q3","Q4")))
mm$day <-weekdays(as.Date(mm$date), abbreviate=TRUE)

# reorder
mm <- mm[ , c("year", "quarter", "month", "date", "day", "code"
    , "session_hs", "rate", "type", "term", "notes", "tags")]

# use blank instead of NA
mm$notes[is.na(mm$notes)] <- mm$tags[is.na(mm$tags)] <- ""

reports <- c(
    "Sessions" # 1
    , "Daily Hours" # 2
    , "Daily Hours by Client" # 3
    , "Monthly Hours" # 4
    , "Quarterly Hours" # 5
    , "Monthly Clients" # 6
    , "Quarterly Clients" # 7
    , "Month Report" # 8
    , "Quarter Report" # 9
    , "Annual Report" # 10
)

client_groups <- c("All", "none", "month", "quarter", "flat rate", "hourly")

# Server functions
# ----------------

daily_agg <- function(mm, input, firstCol, secondCol) {
    mm[(mm$date >= input$start_date & mm$date <= input$end_date), ] %>%
        select({{firstCol}}, {{secondCol}}, date, session_hs) %>%
        group_by({{firstCol}}, {{secondCol}}, date) %>%
        summarise('tot_hs'=sum(session_hs)
            , 'day_available'=1
            , 'day_worked'=ifelse(sum(session_hs) > 0, 1, 0))
}

daily_totals <- function(agg_df) {
    totals <- data.frame(firstCol = "Total"
        , secondCol = ""
        , tot_hs = sum(agg_df$tot_hs)
        , day_available = sum(agg_df$day_available)
        , day_worked = sum(agg_df$day_worked)) %>%
    rename_at(
        vars(c('firstCol', 'secondCol'))
        , ~ c(colnames(agg_df)[1:2]))
    dfm <- rbind(agg_df, totals) %>%
        select(month, date, day, tot_hs) %>%
        arrange(date)
    return(dfm)
}

daily_by_client_agg <- function(mm, input) {
        # includes client cols in agg: code, term, type
        mm[mm$term %in% input$term
            & mm$code %in% input$client_code
            & mm$date >= input$start_date
            & mm$date <= input$end_date, ] %>%
        select(month, date, day, code, term, type, session_hs) %>%
        group_by(month, date, day, code, term, type) %>%
        summarise('tot_hs'=sum(session_hs))
}

daily_by_client_totals <- function(agg_df) {
        totals <- data.frame(month = "Total"
            , date = ""
            , day = ""
            , code = ""
            , term = ""
            , type = ""
            , tot_hs = sum(agg_df$tot_hs))
        dfm <- rbind(agg_df, totals)
        return(dfm)
}

second_agg <- function(mm, input, firstCol, secondCol) {
    daily_agg(mm, input, {{firstCol}}, {{secondCol}}) %>%
        group_by({{firstCol}}, {{secondCol}}) %>%
        summarise('sum_hs'=sum(tot_hs)
            , 'avg_workday_hs'=round(mean(tot_hs[tot_hs > 0]), 2)
            , 'tot_days_avail'=sum(day_available)
            , 'tot_days_work'=sum(day_worked)
            , 'pct_days_work'=round(sum(day_worked) / sum(day_available), 4)) %>%
    rename_at(vars('sum_hs'), ~ 'tot_hs')
}

second_totals <- function(agg_df) {
    totals <- data.frame(firstCol = "Total"
        , secondCol = ""
        , tot_hs = sum(agg_df$tot_hs)
        , avg_workday_hs = round(mean(agg_df$avg_workday_hs), 2)
        , tot_days_avail = sum(agg_df$tot_days_avail)
        , tot_days_work = sum(agg_df$tot_days_work)
        , pct_days_work = round(
            sum(agg_df$tot_days_work) / sum(agg_df$tot_days_avail), 4)
        ) %>%
    rename_at(
        vars(c('firstCol', 'secondCol'))
        , ~ c(colnames(agg_df)[1:2]))
    dfm <- rbind(agg_df, totals)
    return(dfm)
}

# comment out client_code to run in R
third_agg <- function(mm, input, firstCol, secondCol) {
    # Notes:
    #    - 'code' and 'rate' must be 1:1 (no multiple rates over time for same client)
    #    - assumes users select term-appropriate client codes and also won't:
    #           + select a period shorter than a quarter for quarterly clients
    #           + select a period shorter than a month for monthly clients
    # flat rate
    flat_agg <- mm[mm$type == "flat rate"
            & mm$code %in% input$client_code
            & mm$term == deparse(substitute(secondCol))
            & mm$date >= input$start_date
            & mm$date <= input$end_date, ] %>%
        select({{firstCol}}, {{secondCol}}
            , code, term, type, rate, session_hs) %>%
        group_by({{firstCol}}, {{secondCol}}
            , code, term, type, rate) %>%
        summarise('tot_hs'=sum(session_hs)
            , 'avg_hourly_rate'=round(max(rate)/sum(session_hs), 2))
    # hourly
    hour_agg <- mm[mm$type == "hourly"
            & mm$code %in% input$client_code
            & mm$term == deparse(substitute(secondCol))
            & mm$date >= input$start_date
            & mm$date <= input$end_date, ] %>%
        select({{firstCol}}, {{secondCol}}
            , code, term, type, rate, session_hs) %>%
        group_by({{firstCol}}, {{secondCol}}
            , code, term, type, rate) %>%
        summarise('tot_hs'=sum(session_hs)
            , 'avg_hourly_rate'=round(max(rate)*sum(session_hs), 2)) %>%
        rename_at(vars(c('rate', 'avg_hourly_rate'))
            , ~ c('avg_hourly_rate', 'rate')) %>%
        relocate({{firstCol}}, {{secondCol}}
            , code, term, type, rate, tot_hs, avg_hourly_rate)
    agg_df <- rbind(flat_agg, hour_agg)
    return(agg_df)
}

third_totals <- function(agg_df, tot_only=FALSE) {
    totals <- data.frame(firstCol = "Total"
        , secondCol = ""
        , code = ""
        , term = ""
        , type = ""
        , rate = sum(agg_df$rate)
        , tot_hs = sum(agg_df$tot_hs)
        , avg_hourly_rate = round(sum(agg_df$rate)/sum(agg_df$tot_hs), 2)) %>%
    rename_at(
        vars(c('firstCol', 'secondCol'))
        , ~ c(colnames(agg_df)[1:2]))
    if (tot_only==TRUE) {
        return(totals)
    } else {
        dfm <- rbind(agg_df, totals)
        return(dfm)
    }
}

period_rates <- function(agg_df, firstCol, secondCol) {
    dfm <- agg_df %>%
        group_by({{firstCol}}, {{secondCol}}, term) %>%
        summarise(
            revenue = sum(rate)
            , hours = sum(tot_hs)
            , avg_hourly_rate = round(sum(rate)/sum(tot_hs), 2)
        )
    return(dfm)
}

period_totals <- function(dfm) {
    totals <- data.frame(firstCol = "Total"
        , secondCol = ""
        , term = ""
        , revenue = sum(dfm$revenue)
        , hours = sum(dfm$hours)
        , avg_hourly_rate = round(sum(dfm$revenue)/sum(dfm$hours), 2)) %>%
    rename_at(
        vars(c('firstCol', 'secondCol'))
        , ~ c(colnames(dfm)[1:2]))
    return(rbind(dfm, totals))
}

annual_report <- function(mm, input) {
    # quarter totals for quarterly clients
    quarter_agg <- third_agg(mm, input, year, quarter)
    year_quarter_agg <- period_rates(quarter_agg, year, quarter)
    # quarter totals for monthly clients
    month_agg <- third_agg(mm, input, quarter, month)
    year_month_agg <- period_rates(month_agg, quarter, month)
    # reformat and fix rates
    year_month_agg$year <- factor(max(as.numeric(as.character(mm$year))))
    year_month_agg$term <- 'month'
    year_month_agg <- year_month_agg %>% group_by(year, quarter, term) %>%
        summarise(revenue = sum(revenue)
            , hours = sum(hours)
            , avg_hourly_rate = round(revenue / hours, 2))
    quarter_totals <- period_totals(year_quarter_agg)
    month_totals <- period_totals(year_month_agg)
    # combine and add totals
    dfa <- rbind(quarter_totals, month_totals) %>%
        mutate(year = ifelse(year == "Total", "Quarter Total", year))
    dfa_totals <- rbind(dfa,
        period_totals(rbind(year_quarter_agg, year_month_agg)) %>%
            filter(year == "Total")) %>%
            mutate(year = ifelse(year == "Total", "Annual Total", year))
    return(dfa_totals)
}

# returns a dataframe per report
return_dfm <- function(input, reports) {
    # Raw
    # Sessions
    if (input$report == reports[1]) {
        dfm <- mm[mm$term %in% input$term
                & mm$code %in% input$client_code
                & mm$date >= input$start_date
                & mm$date <= input$end_date, ] %>%
            mutate(term_type = paste0(term, ' - ', type)) %>%
            select(date, day, code, term_type, session_hs, notes, tags)
        return(dfm)
    }
    # First agg type
    # Daily Hours (includes non-work days)
    if (input$report == reports[2]) {
        agg_df <- daily_agg(mm, input, month, day)
        dfm <- daily_totals(agg_df)
        return(dfm)
    }
    # Daily Hours by Client
    if (input$report == reports[3]) {
        agg_df <- daily_by_client_agg(mm, input)
        dfm <- daily_by_client_totals(agg_df)
        return(dfm)
    }
    # Secod agg type
    # Monthly Hours
    if (input$report == reports[4]) {
        agg_df <- second_agg(mm, input, quarter, month)
        dfm <- second_totals(agg_df)
        return(dfm)
    }
    # Quarterly Hours
    if (input$report == reports[5]) {
        agg_df <- second_agg(mm, input, year, quarter)
        dfm <- second_totals(agg_df)
        return(dfm)
    }
    # Third agg type
    # Monthly Clients
    if (input$report == reports[6]) {
        agg_df <- third_agg(mm, input, quarter, month)
        dfm <- third_totals(agg_df)
        return(dfm)
    }
    # Quarterly Clients
    if (input$report == reports[7]) {
        agg_df <- third_agg(mm, input, year, quarter)
        dfm <- third_totals(agg_df)
        return(dfm)
    }
    # Super agg types
    # Monthly Report
    if (input$report == reports[8]) {
        agg_df <- third_agg(mm, input, quarter, month)
        dfm <- period_rates(agg_df, quarter, month)
        dfm_tot <- period_totals(dfm)
        return(dfm_tot)
    }
    # Quarterly Report
    if (input$report == reports[9]) {
        agg_df <- third_agg(mm, input, year, quarter)
        dfm <- period_rates(agg_df, year, quarter)
        dfm_tot <- period_totals(dfm)
        return(dfm_tot)
    }
    # Annual Report
    if (input$report == reports[10]) {
        dfa <- annual_report(mm, input)
        return(dfa)
    }

}

# Formatting help funcs
format_weekday <- function(table_obj) {
    weekday_names <- weekdays(ISOdate(1, 1, 1:7), abbrev=TRUE)
    weekday_cols <- c(rep("steelblue", 5), rep("darkred", 2))
    table_obj %>%
        formatStyle('day'
            , color = styleEqual(weekday_names, weekday_cols))
}

make_totals_bold <- function(table_obj, dfm) {
    table_obj %>%
    formatStyle(0, target = "row"
        , fontWeight = styleEqual(dim(dfm)[1], "bold"))
}

# Plotting functions
# ------------------

# # Choose color palette:
# library(RColorBrewer)
# par(mar=c(3,4,2,2))
# display.brewer.all()

# # Use hex values directly:
# color_palette <- brewer.pal(n = 8, name = "Set3")
# test_colors <- rep(10, length(color_palette))
# barplot(test_colors, col=color_palette, names.arg=color_palette)

# # test in R, need to remove the checks in third_agg and daily_by_client_agg
# # for both client_code AND term
# input <- data.frame(
#     "report"="Daily Hours by Client"
#     , "term"=c("all")
#     , "quarter"=c("all")
#     , "start_date"=as.Date('2022-10-01')
#     , "end_date"=as.Date('2022-10-07')
#     , "client_group"="all"
# )

# # dev plot
# dfm <- return_dfm(input, reports)
# total_row <- dfm[nrow(dfm), ]
# dfm <- dfm[-nrow(dfm), ]

# dfm <- read.csv("test.csv")
# dfm <- dfm[-nrow(dfm), ]
# dfm <- dfm[dfm$date >= "2022-12-20",]

# # best one
#     num_dates <- length(unique(dfm$date))
#     num_cols <- ifelse(num_dates > 8, 2, 1)
#     # prep base
#     ggplot(dfm, aes(x = code, y = tot_hs, fill = term)) +
#         geom_bar(stat = 'identity') +
#         facet_wrap(~ date, ncol = num_cols) +
#         scale_fill_manual(values = c("#FB8072", "#80B1D3", "#8DD367")) +
#         ggtitle("title"
#             , subtitle = paste0("Subtitle")) +
#         labs(x = "", y = "Total Hours") +
#         theme_bw() +
#         theme(plot.title = element_text(size = 22)
#             , plot.subtitle = element_text(size = 18)
#             , axis.text.x = element_text(size = 14, angle = 90, vjust = 0.5, hjust=1)
#             , text = element_text(size = 16)
#             , legend.position = "right")

# ggplot(dfm, aes(x = code, y = tot_hs, fill = term)) +
#     geom_bar(stat = 'identity') +
#     facet_wrap(~ date, ncol = 1) +
#     labs(x = "", y = "Total Hours") +
#     theme_bw()

# ggplot(dfm, aes(x = code, y = tot_hs, fill = code)) +
#     geom_bar(stat = 'identity') +
#     facet_wrap(~ date, ncol = 1) +
#     labs(x = "", y = "Total Hours") +
#     theme_bw()

# ggplot(dfm, aes(x = date, y = tot_hs, fill = code)) +
#     geom_bar(stat = 'identity') +
#     facet_wrap(~ term, ncol = 1) +
#     labs(x = "", y = "Total Hours") +
#     theme_bw()

# ggplot(dfm[dfm$term %in% c("month", "biz"), ], aes(x = date, y = tot_hs, fill = code)) +
#     geom_bar(stat = 'identity') +
#     facet_wrap(~ code, ncol = 2) +
#     labs(x = "", y = "Total Hours") +
#     theme_bw()

plot_faceted_barplots <- function(dfm, total_row, xaxis, title) {
    num_dates <- length(unique(dfm$date))
    num_cols <- ifelse(num_dates > 8, 2, 1)
    total_hs <- round(total_row$tot_hs, 1)
    biz_hs <- round(sum(dfm$tot_hs[dfm$term == "biz"]), 1)
    month_hs <- round(sum(dfm$tot_hs[dfm$term == "month"]), 1)
    quarter_hs <- round(sum(dfm$tot_hs[dfm$term == "quarter"]), 1)
    # prep base
    g <- ggplot(dfm, aes(x = {{xaxis}}, y = tot_hs, fill = term)) +
        geom_bar(stat = 'identity') +
        facet_wrap(~ date, ncol = num_cols) +
        scale_fill_manual(values = c("#FB8072", "#80B1D3", "#8DD367"))
    # style plot
    g <- g +
        ggtitle(title
            , subtitle = paste0("Total: ", total_hs
                , " hs | Biz: ", biz_hs
                , " hs | Month: ", month_hs
                , " hs | Quarter: ", quarter_hs, " hs")) +
        labs(x = "", y = "Total Hours") +
        theme_bw() +
        theme(plot.title = element_text(size = 22)
            , plot.subtitle = element_text(size = 18)
            , axis.text.x = element_text(size = 14, angle = 90, vjust = 0.5, hjust=1)
            , text = element_text(size = 16)
            , legend.position = "right")
    return(g)
}

plot_barline <- function(dfm, total_row, xaxis, title) {
    # set max for the avg_hourly_rate (sec y axis scale)
    max_rate <- 125 # manual
    max_revenue <- max(dfm$revenue)
    mean_revenue <- round(mean(dfm$revenue), 2)
    scale_y_axis <- function(X) {
        return((max_revenue * X) / max_rate)
    }
    # dotted line with avg for entire period chosen
    avg_rate_period <- total_row$avg_hourly_rate
    # prep base
    g <- ggplot(dfm, aes(group = 1)) + 
        geom_bar(aes(x = {{xaxis}}, y = revenue), stat = "identity", fill = "#C6CED6") +
        geom_line(aes(x = {{xaxis}}, y = scale_y_axis(avg_hourly_rate))
            , stat = "identity"
            , color = "#BB0828"
            , size = 1) +
        scale_y_continuous("Revenue"
                , sec.axis = sec_axis(~ . * max_rate / max_revenue
                    , name = "Avg. Hourly Rate"
                    , labels=scales::dollar_format())
                , labels=scales::dollar_format()) +
        geom_hline(yintercept = scale_y_axis(avg_rate_period)
            , col = "#BB0828", linetype = "dotted", size = 1.2) +
        geom_hline(yintercept = mean_revenue
            , col = "#7D848A", linetype = "dashed", size = 1)
    # style plot
    g <- g +
        theme_classic(base_size = 16) +
        ggtitle(title
            , subtitle = paste0("For ", deparse(substitute(xaxis)), "ly clients only"
            , " | Total Revenue: $", format(round(total_row$revenue, 2), big.mark = ",")
            , " | Mean Revenue: $", format(mean_revenue, big.mark = ",")
            , " | Avg Hourly Rate: $", avg_rate_period)) +
        xlab("") +
        theme(plot.title = element_text(size = 22)
            , plot.subtitle = element_text(size = 18)
            , axis.text.x = element_text(size = 16)
            , text = element_text(size = 16)
            , legend.position = "right"
            , axis.line.y.right = element_line(color = "#BB0828") 
            , axis.ticks.y.right = element_line(color = "#BB0828")
            , axis.text.y.right = element_text(color = "#BB0828")
            , axis.title.y.right = element_text(color = "#BB0828")
            )
    return(g)
}

plot_hours_barplot <- function(dfm, total_row, xaxis, title) {
    # only common var
    tot_hs <- round(total_row$tot_hs, 1)
    # prep daily
    if (title == "Daily Hours") {
        # subset to days worked
        dfw <- dfm[dfm$tot_hs > 0, ]
        mean_hs <- round(mean(dfw$tot_hs), 2)
        avg_workday_hs <- mean_hs
        # add a weekend var for color
        dfm$weekday <- as.factor(ifelse(grepl("S(at|un)", dfm$day), "weekend", "weekday"))
        days_work <- length(unique(dfw$date))
        days_avail <- length(unique(dfm$date))
        pct_days_work <- round(100 * days_work / days_avail, 2)
        subtitle_head <- ""
        # prep base barplot
        g <- ggplot(dfm, aes(x=as.Date(date), y=tot_hs, fill=weekday)) + 
            geom_bar(stat="identity") +
            scale_fill_manual(values = c("#80B1D3", "#FB8072"))
    # prep monthly/quarterly
    } else {
        mean_hs <- round(mean(dfm$tot_hs), 1)
        avg_workday_hs <-  round(total_row$avg_workday_hs, 2)
        days_work <- total_row$tot_days_work
        days_avail <- total_row$tot_days_avail
        pct_days_work <- 100 * total_row$pct_days_work
        subtitle_head <- paste0("Avg ", deparse(substitute(xaxis))
            , "ly hs: ", mean_hs, " hs | ")
        # prep base barplot
        g <- ggplot(dfm, aes(x={{xaxis}}, y=tot_hs, fill=quarter)) + 
            geom_bar(stat="identity")
    }
    # add avg line, title, labs, theme
    g <- g +
        theme_classic(base_size = 16) +
        geom_hline(yintercept = mean_hs
            , col = "black", linetype = "dotted", size = 1.2) +
        ggtitle(title
            , subtitle = paste0(subtitle_head
                , "Avg daily hs: ", avg_workday_hs, " hs"
                , " | Tot hs: ", tot_hs, " hs"
                , " | Num days (worked / available): ", days_work, " / ", days_avail
                , " | Pct days worked: ", pct_days_work, "%")) +
        labs(x = "", y = "Total Hours") +
        theme(plot.title = element_text(size = 22)
            , plot.subtitle = element_text(size = 18)
            , axis.text.x = element_text(size = 16)
            , text = element_text(size = 16)
            , legend.position = "right")
    return(g)
}

plot_client_scatter <- function(dfm, title) {
    # create color
    qt25 <- round(quantile(dfm$tot_hs)[[2]], 2)
    qt75 <- round(quantile(dfm$tot_hs)[[4]], 2)
    dfm$qt_color <- ifelse(dfm$tot_hs <= qt25, '#269808' # green
                    , ifelse(dfm$tot_hs <= qt75, '#063970' # blue
                    , '#C02403')) # red
    mean_hs <- round(mean(dfm$tot_hs), 1)
    # prep base scatterplot + avg line for desired hourly rate
    g <- ggplot(dfm, aes(x=avg_hourly_rate, y=rate)) +
            geom_point(color = 'red') +
            theme_classic(base_size = 16) +
            geom_vline(xintercept = 65
                , col = "black", linetype = "dotted", size = 1.2)
    # plot out with labels that repel
    g <- g +
        geom_label_repel(aes(label = code)
            , fill = factor(dfm$qt_color)
            , color = 'white'
            , size = 6) +
        ggtitle(title,
            subtitle = paste0(
                "Avg. Hours Worked: ", mean_hs, " hs"
                , " | Red = above 75% quantile: ", qt75, " hs"
                , " | Green = below 25% quantile: ", qt25, " hs")) +
        labs(x = "Avg. Hourly Rate ($)", y = "Revenue ($)") +
        theme(plot.title = element_text(size = 22)
            , plot.subtitle = element_text(size = 18)
            , axis.text.x = element_text(size = 16)
            , text = element_text(size = 16))
    return(g)
}

return_plot <- function(dfm_with_totals, input, reports) {
    # separate out total row (for all reports)
    total_row <- dfm_with_totals[nrow(dfm_with_totals), ]
    dfm <- dfm_with_totals[-nrow(dfm_with_totals), ]
    # Daily Hours
    if (input$report == reports[2]) {
        p <- plot_hours_barplot(dfm, total_row, xaxis="", title=reports[2])
    # Daily Hours by Client
    } else if (input$report == reports[3]) {
        p <- plot_faceted_barplots(dfm, total_row, xaxis=code, title=reports[3])
    # Monthly Hours
    } else if (input$report == reports[4]) {
        p <- plot_hours_barplot(dfm, total_row, xaxis=month, title=reports[4])
    # Quarterly Hours
    } else if (input$report == reports[5]) {
        p <- plot_hours_barplot(dfm, total_row, xaxis=quarter, title=reports[5])
    # Monthly Clients
    } else if (input$report == reports[6]) {
        p <- plot_client_scatter(dfm, title=reports[6])
    # Quarterly Clients
    } else if (input$report == reports[7]) {
        p <- plot_client_scatter(dfm, title=reports[7])
    # Month Report
    } else if (input$report == reports[8]) {
        p <- plot_barline(dfm, total_row, xaxis=month, title=reports[8])
    # Quarter Report
    } else if (input$report ==  reports[9]) {
        p <- plot_barline(dfm, total_row, xaxis=quarter, title=reports[9])
    # Sessions, etc.
    } else {
        p <- ggplot(data.frame(data=c(""))) +
            ggtitle("No Plots Available for Session Data and the Annual Report") +
            theme_classic() +
            theme(plot.title = element_text(size = 22))
    }
    return(p)
}
