# Timesheet Analysis

![License](https://img.shields.io/github/license/BigBangData/TimesheetAnalysis)
![File Count](https://img.shields.io/github/directory-file-count/BigBangData/TimesheetAnalysis)
![Last Commit](https://img.shields.io/github/last-commit/BigBangData/TimesheetAnalysis?color=blueviolet)
![Stars](https://img.shields.io/github/stars/BigBangData/TimesheetAnalysis?style=social)
![Forks](https://img.shields.io/github/forks/BigBangData/TimesheetAnalysis?style=social)
![Watchers](https://img.shields.io/github/watchers/BigBangData/TimesheetAnalysis?style=social)

## [Motivation](#motivation)

My wife owns a bookkeeping 📚 business and we found some ways for me to help her automate and analyze 📈 things.

I've been learning [shiny](https://shiny.rstudio.com/) with projects such as [this](https://bigbangdata.shinyapps.io/shinyapp/) and thought it'd be a good tool for her since downloading and running R is more user-friendly to non-programmers than the whole Python 🐍🐍🐍 ecosystem and running a local app is better for security 🔐and privacy.

In `v1` of this project we used Excel as input-output to an R script. In `v2` we used Excel as input and a local shiny app as output. This public-facing `v3` of the project recreates the shiny app with fake data...

<p align="center"><img src="www/munchfakedata.jpg" width=180></p>


...in a reproducible and more realistic way than using a service like [mockaroo](https://www.mockaroo.com/), using R and probabilities derived from actual data. This method still has some imperfections: see [faking data](#faking-data) for limitations.


In theory🎓this app can be adapted by anyone who keeps a timesheet of any sort (hobbies, projects, exercise) and wants to see some reporting on it. In practice 👊a lot of reworking might be needed unless one's a bookkeeper with similar client breakdown and reporting needs.

See [using the app](#using-the-app) for how to use the app. [Try the app](#try-the-app) or see [reproduce the app](#reproduce-the-app) to run a local version. 💻

---

## [Demo](#demo)

<img src="www/demo.gif">

---

## [Try the app](#try-the-app)

Please give [this free service](https://bigbangdata.shinyapps.io/timesheetanalysis/) a few seconds ⏳ to get up and... walking <img src="www/ministry-of-silly-walks.gif" width=40>

The app isn't super intuitive for the uninitiated... 🛐

"Initiate" by selecting an appropriate time period 📅 before selecting a report:

- `Sessions:` shorter periods for data; longer ones for plots
- `Daily Hours:` from a week to a quarter
- `Daily Hours by Client:` from a week to a month
- `Monthly Hours`: a quarter or full year
- `Quarterly Hours`: full year
- `Monthly Clients`: must select a specific month
- `Quarterly Clients`: must select a specific quarter
- `Month Report`: a quarter or full year
- `Quarter Report`: full year
- `Annual Report:` full year

---

## [Using the app](#using-the-app)

### [Overview](#overview)

The app has two main tabs:
1. __Plots__ visualizes the data selected through various menu options
2. __Data & Downloads__ shows the data and a menu of download options


__Plots__

There are 10 reports, see [details](#details) below for specific usage.


<img src="www/ex2.jpg" width=180>

The `Year`, `Quarter`, and `Month` menus affect the `Start Date` and `End Date` date pickers and interact independently of each other. One must trigger an event by selecting a *different* value in one of these menus (re-selecting the same value won't affect the date pickers).

<img src="www/ex3.png" width=550>

`Term` is the billing cycle: clients pay once a month or once a quarter. The "biz" option is to log unpaid activities related to the bookkeeper's business, such as learning a new niche or tool.

<img src="www/ex4.jpg" width=180>

`Client Group` affects the `Client Code` and helps pick specific groups such as deselecting all to pick a particular client, or picking those with a billing `Type`.

There are two types:
- __flat rate__ -fixed rate paid at the start of a term
- __hourly__ - variable rate paid at the end of a term, based on hours worked


Again, "biz" is treated as a "client" of sorts. All other codes identify actual paying clients. In this project I faked the codes with some Nasdaq symbols of a few companies you might have heard about in the (fake?) news.

<img src="www/ex5.jpg" width=180>

```
```

__Data & Downloads tab__

In this tab one can view and download the data and plot selected in the `Plots` tab.

<img src="www/ex6.jpg" width=180>


The data is downloaded as CSV and the plots as PNG with a few customizations possible, which might come in handy depending on the plot. In particular, the "Daily Hours by Client" report will only work well on-screen for a period of about two weeks, but if a month is desired one can download a long PNG using 16" height by 10" width (see [demo](#demo)).

```
```
### [Details](#details)

__1. Sessions__


Session data is unaggregated data at the level of a work session. It combines two Excel tabs (in our fake data case, two CSV files): __Clients__ and __Timesheet__.

__Clients__ is a more static, small table at the client-level, where `code` ("client code") is the primary key:

<img src="www/ex8.jpg" width=200>

__Timesheeet___ is a more dymanic, long dataset which is the bookeeper's daily manual timesheet entries:

<img src="www/ex7.jpg" width=400>

There is a variety of plots that could be made with data at this level, but the most useful was the boxplot comparison with a `geom_jitter` layer of dots to show not just the distribution of hours worked but also the volume of sessions for each client, given a period.



__2. Daily Hours__

__3. Daily Hours by Client__

__4. Monthly Hours__

__5. Quarterly Hours__

__6. Monthly Clients__

__7. Quarterly Clients__

__8. Month Report__

__9. Quarter Report__

__10. Annual Report__


---

## [Reproduce the app](#reproduce-the-app)


---
## [Faking data](#faking-data)




---
