source("app_code.R")

# ui
tabPanelfooter <- fluidRow(
    column(width = 12,
        # signature, GitHub link
        p(style = "text-align:right;",
        tags$a(href="https://bigbangdata.github.io/", "Marcelo Sanches"),
        tags$a(href="https://github.com/BigBangData/TimesheetAnalysis",
        img(src="GitHub-Mark-32px.png", height = 20), " BigBangData"))
    )
)

ui <- navbarPage(
    title = div(
        style = "color:#430E8A; text-align: left; font-size: 22px; font-weight: 600",
        tags$a(href="https://www.time.gov/", img(src="monty.png", height = 50, width = 50)),
        "Timesheet Analysis"
    ),
    tabPanel(title = "Plots",
        sidebarLayout(position = "left",
            sidebarPanel(width = 2,
                # drop-down for report
                selectInput(
                    inputId = "report",
                    label = "Report",
                    choices = reports,
                    selected = reports[1]
                ),
                tags$style(HTML("hr {border-top: 1px solid #000000;}")),
                hr(),
                # slider for year
                sliderInput(
                    inputId = "year",
                    label = "Year",
                    min = as.integer(substr(min(mm$date), 1, 4)),
                    max = as.integer(substr(max(mm$date), 1, 4)),
                    value = "2022",
                    sep = "",
                    step = 1,
                    ticks = TRUE
                ),
                # select quarter
                radioButtons(
                    inputId = "quarter",
                    label = "Quarter",
                    choices = c("All", "1", "2", "3", "4"),
                    selected = "4",
                    inline = TRUE
                ),
                # select month
                selectInput(
                    inputId = "month",
                    label = "Month",
                    choices = c("All", month_list),
                    selected = "All"
                ),
                # start date
                dateInput(
                    inputId = "start_date", 
                    label = "Start Date", 
                    min = min(mm$date),
                    max = max(mm$date),
                    value = "2022-10-01"
                ),
                # end date
                dateInput(
                    inputId = "end_date", 
                    label = "End Date", 
                    min = min(mm$date),
                    max = max(mm$date),
                    value = "2022-10-31"
                ),
                hr(),
                # checkbox for term
                checkboxGroupInput(
                    inputId = "term",
                    label = "Term",
                    choices = c("month", "quarter", "biz"),
                    selected = c("month", "quarter", "biz"),
                    inline = TRUE
                ),
                # select client groups
                radioButtons(
                    inputId = "client_group",
                    label = "Client Group",
                    choices = client_groups,
                    selected = client_groups[1], # All
                    inline = TRUE
                ),
                # checkbox for client code
                checkboxGroupInput(
                    inputId = "client_code",
                    label = "Client Code",
                    choices = c("All", rts$code),
                    selected = "All" # rts$code[rts$term == "month"]
                )
            ),
            mainPanel(width = 10,
                plotOutput("viz", width="100%", height="800px"),
                br(),
                tabPanelfooter
            )
        )
    ),
    tabPanel(title = "Data & Downloads",
        sidebarLayout(position = "left",
            sidebarPanel(width = 2,
                downloadButton("download_csv", label = "Download Data"),
                hr(),
                downloadButton("download_plot", label = "Download Plot"),
                br(), br(),
                # select height
                selectInput(
                    inputId = "height",
                    label = "Height (in)",
                    choices = c(6:16),
                    selected = 10
                ),
                # select width
                selectInput(
                    inputId = "width",
                    label = "Width (in)",
                    choices = c(10:20),
                    selected = 16
                ),
                # select dpi
                radioButtons(
                    inputId = "dpi",
                    label = "DPI (dots per inch)",
                    choices = c(400, 500, 600, 700, 800),
                    selected = 600
                )
            ),
            mainPanel(width = 10,
                DTOutput("tab", width="100%", height="auto"),
                br(),
                tabPanelfooter
            )
        )
    )
)

# server
server <- function(input, output, session) {
    # year slider udpates available dates
    observe({
        beg_selected <- min(mm$date[year(mm$date) == input$year])
        end_selected <- max(mm$date[year(mm$date) == input$year])
        updateDateInput(
            session
            , "start_date"
            , label = paste("Start Date")
            , value = beg_selected
            , min = beg_selected
            , max = end_selected
        )
        updateDateInput(
            session
            , "end_date"
            , label = paste("End Date")
            , value = end_selected
            , min = beg_selected
            , max = end_selected
        )
    })
    # quarter filter updates availble dates
    observe({
        year <- input$year
        beg_selected <- min(mm$date[year(mm$date) == year])
        end_selected <- max(mm$date[year(mm$date) == year])
        # needs to be radio buttons
        if ("1" == input$quarter) {
            beg_selected <- c(paste0(year, '-01-01'))
            end_selected <- c(paste0(year, '-03-31'))
        }
        if ("2" == input$quarter) {
            beg_selected <- c(paste0(year, '-04-01'))
            end_selected <- c(paste0(year, '-06-30'))
        }
        if ("3" == input$quarter) {
            beg_selected <- c(paste0(year, '-07-01'))
            end_selected <- c(paste0(year, '-09-30'))
        }
        if ("4" == input$quarter) {
            beg_selected <- c(paste0(year, '-10-01'))
            end_selected <- c(paste0(year, '-12-31'))
        }
        if ("All" == input$quarter) {
            beg_selected <- beg_selected
            end_selected <- end_selected
        }
        updateDateInput(
            session
            , "start_date"
            , label = paste("Start Date")
            , value = beg_selected
            , min = beg_selected
            , max = end_selected
        )
        updateDateInput(
            session
            , "end_date"
            , label = paste("End Date")
            , value = end_selected
            , min = beg_selected
            , max = end_selected
        )
    })
    # month filter updates available dates independently
    observe({
        year <- input$year
        beg_selected <- min(mm$date[year(mm$date) == year])
        end_selected <- max(mm$date[year(mm$date) == year])
        if (input$month %in% c("04", "06", "09", "11")) {
            beg_selected <- c(paste0(year, '-', input$month, '-01'))
            end_selected <- c(paste0(year, '-', input$month, '-30'))
        } else if (input$month == "02") {
            beg_selected <- c(paste0(year, '-', input$month, '-01'))
            # account for leap years
            if (as.numeric(year) %% 4 != 0) {
                end_selected <- c(paste0(year, '-', input$month, '-28'))
            } else {
                end_selected <- c(paste0(year, '-', input$month, '-29'))
            }
        } else if (input$month == "All") {
            beg_selected <- beg_selected
            end_selected <- end_selected
        } else {
            beg_selected <- c(paste0(year, '-', input$month, '-01'))
            end_selected <- c(paste0(year, '-', input$month, '-31'))
        }
        updateDateInput(
            session
            , "start_date"
            , label = paste("Start Date")
            , value = beg_selected
            , min = beg_selected
            , max = end_selected
        )
        updateDateInput(
            session
            , "end_date"
            , label = paste("End Date")
            , value = end_selected
            , min = beg_selected
            , max = end_selected
        )
    })
    # client group filter to select client codes
    observe({
        choices <- c(rts$code)
        selected <- c()
        # cannot use 'else' since it skips eval; still evals in order
        # works for radio buttons AND checkboxes with %in%
        if (client_groups[1] %in% input$client_group) {
            selected <- c(rts$code)
        }
        if (client_groups[2] %in% input$client_group) {
            selected <- c()
        }
        if (client_groups[3] %in% input$client_group) {
            selected <- c(rts$code[rts$term == "month"])
        }
        if (client_groups[4] %in% input$client_group) {
            selected <- c(rts$code[rts$term == "quarter"])
        }
        if (client_groups[5] %in% input$client_group) {
            selected <- c(rts$code[rts$type == "flat rate"])
        }
        if (client_groups[6] %in% input$client_group) {
            selected <- c(rts$code[rts$type == "hourly"])
        }
        updateCheckboxGroupInput(
            session
            , "client_code"
            , label = paste("Client Code")
            , choices = choices
            , selected = selected
        )
    })
    # data table
    output$tab <- renderDT({
        dfm <- return_dfm(input, reports)
        # config table object
        table_obj <- DT::datatable(
            dfm
            , options = list(
                searchHighlight = TRUE
                , lengthMenu = list(c(50, 100, -1), c('50', '100', 'All'))
                , pageLength = -1
            )
        )
        # Format table
        # proxy condition for: Sessions
        if ('session_hs' %in% colnames(dfm)) {
            out <- format_weekday(table_obj)
        # proxy condition for: Daily Hours, Daily by Client
        } else if ('day' %in% colnames(dfm) & !'rate' %in% colnames(dfm)) {
            table_obj <- format_weekday(table_obj)
            out <- make_totals_bold(table_obj, dfm)
        # proxy condition for: Monthly, Quarterly Clients
        } else if (('rate' %in% colnames(dfm)) & ('avg_hourly_rate' %in% colnames(dfm))) {
            table_obj <- table_obj %>% formatCurrency(c('rate', 'avg_hourly_rate'))
            out <- make_totals_bold(table_obj, dfm)
        # proxy condition for: Monthly, Quarterly, Annual Reports
        } else if ('revenue' %in% colnames(dfm)) {
            table_obj <- table_obj %>% formatCurrency(c('revenue', 'avg_hourly_rate'))
            out <- make_totals_bold(table_obj, dfm)
        # proxy condition for: Monthly, Quarterly Hours
        } else if ('pct_days_work' %in% colnames(dfm)) {
            table_obj <- table_obj %>% formatPercentage('pct_days_work', 2)
            out <- make_totals_bold(table_obj, dfm)
        } else {
            out <- data.frame(data='Report unavailable.')
        }
        return(out)
    })
    # data viz
    output$viz <- renderPlot({
        dfm_with_totals <- return_dfm(input, reports)
        return_plot(dfm_with_totals, input, reports)
    })
    # download csv
    output$download_csv <- downloadHandler(
        filename = function() {
            paste0(input$report, " ", Sys.Date(), ".csv", sep="")
        }
        , content = function(file) {
            write.csv(return_dfm(input, reports), file, row.names=FALSE)
        }
    )
    # download viz
    output$download_plot <- downloadHandler(
        filename = function() { 
            paste(input$report, " ", Sys.Date(), ".png", sep="")
        }
        , content = function(file) {
            dfm_with_totals <- return_dfm(input, reports)
            ggsave(file
                , plot = return_plot(dfm_with_totals, input, reports)
                , device = "png"
                , units = "in"
                , height = as.numeric(input$height)
                , width = as.numeric(input$width)
                , dpi = as.numeric(input$dpi)
            )
        }
    )
}

# run app
shinyApp(ui = ui, server = server)