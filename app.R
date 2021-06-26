library(shiny)
library(DT)
library(shinyWidgets)

jscode <- "Shiny.addCustomMessageHandler('closeWindow', function(m) {window.close();});"

css <- "
.nowrap {
white-space: nowrap;
}"


ui <- fluidPage(
  setBackgroundColor(rgb(.1,.7,.8)),
  tags$head(
    tags$style(HTML(css)), tags$script(HTML(jscode))
  ),
  fluidRow(column(12, align = 'center',
  wellPanel(h1("Select data for geocoding"),
  fileInput(inputId = "file",label = NULL,accept = '\\.csv$'),
            htmlOutput("caption")),
  DT::dataTableOutput("view"),
  wellPanel(htmlOutput("selectCaption"),
  uiOutput('conditionalPanel')  )))
  
  )


server <- function(input, output, session) {
  
  datasetInput <- reactive({
    req(input$file$datapath)
    
    
    fname = input$file$name
    saveRDS(fname, 
            file = 'shiny-server/fname.RDS')
            #file = 'fname.RDS')
    
    read.csv(input$file$datapath, stringsAsFactors = F)
  })
  
  
  output$caption = renderUI({req(input$file$datapath)
                              HTML('Select column containing address data <br/>
                              <b/>(REMINDER: column should be formatted as "<i/>{street address} {city} {state} {5 digit zip}</i/>")</b/> <br/>
                              (e.g. <i/>"1234 Main st Fairfield MA 12345"</i/>)')})
  
  output$view <- DT::renderDataTable(datasetInput(),
                                     selection = list(target = "column",mode='single'),
                                     options = list(searching = FALSE, 
                                                    columnDefs = list(
                                                      list(className = "nowrap", targets = "_all")
                                                    )))
  
  output$selectCaption = renderText({
    req(input$view_columns_selected)
    paste0('Selected column <b/>"',colnames(datasetInput())[input$view_columns_selected], '"</b/>')
  })
  
  output$conditionalPanel = renderUI({
    req(input$view_columns_selected)
    actionButton("confirmSelection","Confirm selection and proceed")
  })
  
  observeEvent(input$confirmSelection,
               {
                 dat = datasetInput()
                 write.csv(data.frame(address = dat[,input$view_columns_selected],rowid = 1:nrow(dat)), 
                           file = 'shiny-server/temp.csv', row.names = F)
                           #file = 'temp.csv', row.names = F)
                 fname = input$file$name
                 write.csv(data.frame(dat), 
                           file = paste0('shiny-server/',fname), row.names = F)
                 #file = fname, row.names = F)
                 session$sendCustomMessage(type = 'closeWindow', message ='message')
                 stopApp()
               }
               )
  
}

shinyApp(ui, server)
