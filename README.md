<img style="float: left;" src="www/monty.png" width=80/><h1 style="color:#B265EE;">&nbsp;Timesheet Analysis</h1>


---

## [Motivation](#motivation)

My wife owns a bookkeeping business ⚖️ 📚 and we found some ways for me to help her automate and analyze things. 🤖 📈

I've been learning [shiny](https://shiny.rstudio.com/) with projects such as [Coronavirus: Latest Country Statistics](https://bigbangdata.shinyapps.io/shinyapp/) and thought it'd be a good tool since downloading and running R is more user-friendly to non-programmers than the whole python ecosystem 🐍🐍🐍, and running a local app is better for security and privacy. 🔐

In `v1` of this project we used Excel🐱‍👤 as input-output. In `v2` we used Excel as input and a local shiny app ✨as output. This project recreates `v2` with fake data 🙃 using R and probabilities derived from actual data for a more realistic input. Still has some imperfections (see [Faking data](#faking-data)) but is good enough for the project.


In theory, 👼this app can be adapted by anyone who keeps a timesheet of any sort (hobbies, projects, exercise...) and wants to see some reporting on it. In practice, 👊👊👊a lot of reworking might be needed unless one's a bookkeeper with similar client breakdown and reporting needs.

See [using the app](#using-the-app) for how to use the app. [Try the app](#try-the-app) or see [reproduce the app](#reproduce-the-app) to reproduce it locally. 💻


---

## [Demo](#demo)





---

## [Try the app](#try-the-app)

Try the app [here](https://bigbangdata.shinyapps.io/timesheetanalysis/). Please give this free service a few seconds ⏳ to spin up the app. 🙏🏼

The app isn't 100% intuitive for the uninitiated. 🛐 

Select an appropriate time period 📅 before selecting a report:

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
