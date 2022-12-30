
source("app_code.R")

## UI
# ----

tabPanelfooter <- fluidRow(
    column(width = 12,
        # signature, GitHub link
        p(style = "text-align:right;",
        "App by: ", tags$a(href="https://bigbangdata.github.io/", "Marcelo Sanches"),
        tags$a(href="https://bigbangdata.github.io/",
        img(src="GitHub-Mark-32px.png", height = 20)), " BigBangData")
    )
)


ui <- navbarPage(
    title = div(
        style = "color:#430E8A; text-align: left; font-size: 22px; font-weight: 600",
        tags$a(href="https://www.jennifersbookkeeping.com/", img(src="JB_logo_500width.png", height = 35, width = 48)),
        "Timesheet Analysis"
    ),
    tabPanel(title = "Data Table",
        sidebarLayout(position = "left",
            sidebarPanel(width = 2,
                # drop-down for report
                selectInput(
                    inputId = "report",
                    label = "Report",
                    choices = reports,
                    selected = reports[1]
                ),
                downloadButton("download_csv", label = "Download Data"),
                tags$style(HTML("hr {border-top: 1px solid #000000;}")),
                hr(),
                # checkbox for term
                checkboxGroupInput(
                    inputId = "term",
                    label = "Term",
                    choices = c("month", "quarter", "biz"),
                    selected = c("month", "quarter", "biz"),
                    inline = TRUE
                ),
                # start date
                dateInput(
                    inputId = "start_date", 
                    label = "Start Date", 
                    value = min(mm$date),
                    min = min(mm$date),
                    max = max(mm$date)
                ),
                # end date
                dateInput(
                    inputId = "end_date", 
                    label = "End Date", 
                    value = max(mm$date),
                    min = min(mm$date),
                    max = max(mm$date)
                ),
                # select quarter
                radioButtons(
                    inputId = "quarter",
                    label = "Quarter",
                    choices = c("All", "1", "2", "3", "4"),
                    selected = "All",
                    inline = TRUE
                ),
                # select month
                selectInput(
                    inputId = "month",
                    label = "Month",
                    choices = c("All", month_list),
                    selected = "All"
                ),
                # select client groups
                radioButtons(
                    inputId = "client_group",
                    label = "Client Group",
                    choices = client_groups,
                    selected = client_groups[1],
                    inline = TRUE
                ),
                # checkbox for client code
                checkboxGroupInput(
                    inputId = "client_code",
                    label = "Client Code",
                    choices = c("All", rts$code),
                    selected = "All"
                )
            ),
            mainPanel(width = 10,
                DTOutput("tbl", width="100%", height="auto"),
                br(),
                tabPanelfooter
            )
        )
    ),

    tabPanel(title = "Plots",
        sidebarLayout(position = "left",
            sidebarPanel(width = 2,
                downloadButton("download_plot", label = "Download Plot"),
                hr(),
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
                plotOutput("plot", width="100%", height="800px"),
                br(),
                tabPanelfooter
            )
        )
    )
)

## Server
# -------

server <- function(input, output, session) {

    # separate observations else selecting a client group affects quarter picker
    observe({

        # client group filter to select client codes
        # must initialize at session in case all are unchecked (app fails)
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

        # updates client code filter
        updateCheckboxGroupInput(
            session
            , "client_code"
            , label = paste("Client Code")
            , choices = choices
            , selected = selected
        )
    })

    observe({

        # quarter filter selects dates
        beg_selected <- min(mm$date)
        end_selected <- max(mm$date)
        # solution for latest year only
        max_year <- max(as.character(mm$year))

        # needs to be radio buttons
        if ("1" == input$quarter) {
            beg_selected <- c(paste0(max_year, '-01-01'))
            end_selected <- c(paste0(max_year, '-03-31'))
        }
        if ("2" == input$quarter) {
            beg_selected <- c(paste0(max_year, '-04-01'))
            end_selected <- c(paste0(max_year, '-06-30'))
        }
        if ("3" == input$quarter) {
            beg_selected <- c(paste0(max_year, '-07-01'))
            end_selected <- c(paste0(max_year, '-09-30'))
        }
        if ("4" == input$quarter) {
            beg_selected <- c(paste0(max_year, '-10-01'))
            end_selected <- c(paste0(max_year, '-12-31'))
        }
        if ("All" == input$quarter) {
            beg_selected <- beg_selected
            end_selected <- end_selected
        }

        # updates dates filters
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

    observe({

        # month filter selects dates
        beg_selected <- min(mm$date)
        end_selected <- max(mm$date)

        # solution for latest year only
        max_year <- max(as.character(mm$year))
        if (input$month %in% c("04", "06", "09", "11")) {
            beg_selected <- c(paste0(max_year, '-', input$month, '-01'))
            end_selected <- c(paste0(max_year, '-', input$month, '-30'))
        } else if (input$month == "02") {
            beg_selected <- c(paste0(max_year, '-', input$month, '-01'))
            end_selected <- c(paste0(max_year, '-', input$month, '-28')) # needs leap year solution
        } else if (input$month == "All") {
            beg_selected <- beg_selected
            end_selected <- end_selected
        } else {
            beg_selected <- c(paste0(max_year, '-', input$month, '-01'))
            end_selected <- c(paste0(max_year, '-', input$month, '-31'))
        }

        # updates dates filters
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


    output$tbl <- renderDT({

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


    output$plot <- renderPlot({

        dfm_with_totals <- return_dfm(input, reports)
        return_plot(dfm_with_totals, input, reports)

    })

    output$download_csv <- downloadHandler(
        filename = function() {
            paste0(input$report, " ", Sys.Date(), ".csv", sep="")
        }
        , content = function(file) {
            write.csv(return_dfm(input, reports), file, row.names=FALSE)
        }
    )

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
