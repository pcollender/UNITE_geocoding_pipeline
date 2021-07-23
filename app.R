library(shiny)
library(DT)
library(shinyWidgets)

#make sure progress markers start fresh
invisible(file.remove('pb1_active'))
invisible(file.remove('active2'))
invisible(file.remove('active3'))
invisible(file.remove('summarytable'))
invisible(file.remove('temp.csv'))
invisible(file.remove('temp_geocoded_v3.0.csv'))
invisible(file.remove('process_done'))

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
                  DT::dataTableOutput("Tableview"),
                  uiOutput('conditionalPanel'))),
  fluidRow(column(12, align = 'left',
                  uiOutput("downstream_output1"),
                  htmlOutput("bar1"),
                  uiOutput('summtable'),
                  htmlOutput("downstream_output2"))))


server <- function(input, output, session) {
  
   rvs <- reactiveValues(textstream1 = c(""),
                         tabletext = c(""),
                         textstream2 = c(""),
                         activate1 = F,
                         activate2 = F,
                         activate3 = F,
                         activateFinal = F,
                         activate.pb1 = F,
                         activate.summarytable = F,
                         pb1.params = as.character(c(0,100,NA,0)),
                         timer = reactiveTimer(500)
                         )
  
  datasetInput <- reactive({
    req(input$file$datapath)
    
    read.csv(input$file$datapath, stringsAsFactors = F)
  })
  
  
  output$caption = renderUI({req(input$file$datapath)
                              HTML('Click on column containing address data <br/>
                              <b/>(REMINDER: column should be formatted as "<i/>{street address} {city} {state} {5 digit zip}</i/>")</b/> <br/>
                              (e.g. <i/>"1234 Main st Fairfield MA 12345"</i/>)')})
  
  output$Tableview <- DT::renderDataTable(datasetInput(),
                                     selection = list(target = "column",mode='single'),
                                     options = list(searching = FALSE, 
                                                    columnDefs = list(
                                                      list(className = "nowrap", targets = "_all")
                                                    )))
  
  output$selectCaption = renderText({
    req(input$Tableview_columns_selected)
    paste0('Selected column <b/>"',colnames(datasetInput())[input$Tableview_columns_selected], '"</b/>')
  })
  
  output$conditionalPanel = renderUI({
    req(input$Tableview_columns_selected)
    wellPanel(
      HTML(paste0('Selected column <b/>"',colnames(datasetInput())[input$Tableview_columns_selected], '"</b/> <br/>')),
      actionButton("confirmSelection","Confirm selection and proceed")
      )
    })
  
  output$downstream_output1 = renderUI({
    req(rvs$activate1)
    wellPanel(HTML(rvs$textstream1))
  })
  
  output$bar1 = renderUI({
    req(rvs$activate.pb1)
    nrow_ = nrow(datasetInput())
    wellPanel(progressBar('pb1',0,nrow_,title = 'Geocoding will start shortly...'))
  })
 
  output$downstream_output2 = renderUI({
    req(rvs$activate2)
    wellPanel(HTML('<i/> Now cleaning and summarizing geocoding Results... </i>'),
              HTML(rvs$tabletext),
              HTML(rvs$textstream2))
  })
  
  observeEvent(input$confirmSelection,
               {
                 dat = datasetInput()
                 write.csv(data.frame(address = dat[,input$Tableview_columns_selected],rowid = 1:nrow(dat)), 
                           file = 'temp.csv', row.names = F)
                 
                 removeUI(
                   selector = "div#selectCaption"
                 )
                 removeUI(
                   selector = "div#conditionalPanel"
                 )
                 removeUI(
                   selector = "div#Tableview"
                 )
                 
                 file.create('tstream1')
                 file.create('tstream2')
                 
                 file.create('pb1_stats')
                 
                 rvs$pb1.params[2] = nrow(dat)
                 
                 writeLines(rvs$pb1.params, 'pb1_stats')
                 
                 system2('Rscript', c('geocode_Shiny.R','temp.csv'),wait = F)
                 
                 rvs$activate1 = T
                 })
  
  observeEvent(rvs$activate3,
               {
                 system2('Rscript', c('tract_mapping_Shiny.R','temp.csv'),wait = F)
               })
  
  observeEvent(rvs$activateFinal,
               {
                 fname = gsub('.csv','',input$file$name)

                 res_dat = read.csv('temp_geocoded_v3.0_mapped.csv')
                 rownames(res_dat) = res_dat$rowid
                 res_dat$address = NULL; res_dat$rowid = NULL

                 og_dat = datasetInput()

                 dat = cbind(og_dat, res_dat[order(as.numeric(rownames(res_dat))),])

                 write.csv(dat, file = paste0('tmp/',fname,'_geocoded_mapped.csv'), row.names = F)

                 sink('tstream2')

                 cat('\n <h1/> Done! File written as ', fname,'_geocoded_mapped.csv </h1> \n', sep = '')

                 sink()

                 insertUI(selector = '#downstream_output2',
                          where = 'afterEnd',
                          ui = actionButton('close',label = HTML("<span style='font-size:5.75em;'>Exit</span>"),
                                            class = 'btn-warning btn-block'))
               },ignoreInit = T)
  
  observeEvent(input$close,
               {
                 #file.remove('pb1_active')
                 file.remove('pb1_stats')
                 file.remove('active2')
                 file.remove('active3')
                 file.remove('temp.csv')
                 file.remove('process_done')
                 file.remove('temp_geocoded_v3.0.csv')
                 file.remove('tstream1')
                 file.remove('tstream2')
                 file.remove('summarytable')
                 
                 #unlink('geocoding_cache', recursive = T)       
                 
                 session$sendCustomMessage(type = 'closeWindow', message ='message')
                 stopApp()
               },ignoreInit = T)
  
  observe({
    rvs$timer()
    
    if(isolate(rvs$activate1)){
      
      rvs$textstream1 = paste(suppressWarnings(readLines('tstream1')), collapse = '<br/>')
      
      if(!(rvs$activate.pb1)) rvs$activate.pb1 = file.exists('pb1_active')
      
      if(file.exists('pb1_active')){
        update.params = try(readLines('pb1_stats'))
        
        if(length(update.params) == length(rvs$pb1.params))  rvs$pb1.params = update.params
        
        if(rvs$pb1.params[1] =='0'){
          updateProgressBar(session = session, id = 'pb1', value = 0,
                            total = as.integer(rvs$pb1.params[2]), title = 'Setting up cache...')
        }else{
          updateProgressBar(session = session, id = 'pb1', value = as.integer(rvs$pb1.params[1]),
                          total = as.integer(rvs$pb1.params[2]), title = paste0('Now geocoding... ETA ', rvs$pb1.params[3]))
        }
        
        if((rvs$pb1.params[1] == rvs$pb1.params[2]) | rvs$activate2){ #second condition added to deal with bug when cache is present... not sure of actual cause
          
          ttl = paste0('Finished geocoding ',rvs$pb1.params[2],
                       ' addresses in ', rvs$pb1.params[4])
          
          updateProgressBar(session = session, id = 'pb1', value = as.integer(rvs$pb1.params[2]),
                            total = as.integer(rvs$pb1.params[2]), title = ttl)
          file.remove('pb1_active')
        }
      }
      
      if(!(rvs$activate2)){
        rvs$activate2 = file.exists('active2')
      } 
      
      if(file.exists('summarytable')) rvs$tabletext = readLines('summarytable')
      
      if(!(rvs$activate3)) rvs$activate3 = file.exists('active3')
      
      
      if(file.exists('tstream2'))  
        rvs$textstream2 = paste(suppressWarnings(readLines('tstream2')), collapse = '<br/>')
      
      if(!(rvs$activateFinal)) rvs$activateFinal = file.exists('process_done')
    }
  }) 
  session$onSessionEnded(function() {
    file.remove('pb1_stats')
    file.remove('active2')
    file.remove('active3')
    file.remove('temp.csv')
    file.remove('process_done')
    file.remove('temp_geocoded_v3.0.csv')
    file.remove('tstream1')
    file.remove('tstream2')
    file.remove('summarytable')
    q()}) #stop app on browser window close
}

shinyApp(ui, server)
