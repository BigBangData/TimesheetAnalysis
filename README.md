# Timesheet Analysis

![License](https://img.shields.io/github/license/BigBangData/TimesheetAnalysis)
![File Count](https://img.shields.io/github/directory-file-count/BigBangData/TimesheetAnalysis)
![Last Commit](https://img.shields.io/github/last-commit/BigBangData/TimesheetAnalysis?color=blueviolet)
![Stars](https://img.shields.io/github/stars/BigBangData/TimesheetAnalysis?style=social)
![Forks](https://img.shields.io/github/forks/BigBangData/TimesheetAnalysis?style=social)
![Watchers](https://img.shields.io/github/watchers/BigBangData/TimesheetAnalysis?style=social)

## [Motivation](#motivation)

My wife owns a bookkeeping 📚 business and we found some ways for me to help her automate and analyze 📈 things.

I've been learning [shiny](https://shiny.rstudio.com/) with projects such as [this](https://bigbangdata.shinyapps.io/shinyapp/) and thought it'd be a good tool since downloading and running R is more user-friendly to non-programmers than the whole python 🐍🐍🐍 ecosystem and running a local app is better for security 🔐and privacy.

In `v1` of this project we used Excel as input-output. In `v2` we used Excel as input and a local shiny app as output. This project recreates `v2` with fake data...


<<p align="center"><img src="www/munchfakedata.jpg" width=150></p>


...in a reproducible and more realistic way than using a service like [mockaroo](https://www.mockaroo.com/) by using R and probabilities derived from actual data. This still has some imperfections (see [faking data](#faking-data)) but is good enough for the project.


In theory🎓this app can be adapted by anyone who keeps a timesheet of any sort (hobbies, projects, exercise...) and wants to see some reporting on it. In practice 👊a lot of reworking might be needed unless one's a bookkeeper with similar client breakdown and reporting needs.

See [using the app](#using-the-app) for how to use the app. [Try the app](#try-the-app) or see [reproduce the app](#reproduce-the-app) to reproduce it locally. 💻


---

## [Demo](#demo)





---

## [Try the app](#try-the-app)

Please give this free service a few seconds ⏳ to spin up the app. 🙏🏼

[<p align="center"><img src="www/monty.png" width=100></p>](https://bigbangdata.shinyapps.io/timesheetanalysis/)</center>


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



---

## [Reproduce the app](#reproduce-the-app)


---
## [Faking data](#faking-data)




---
