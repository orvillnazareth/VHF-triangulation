library(shiny)
library(leaflet)
library(googlesheets4)
library(dplyr)
library(geosphere)
library(DT)
library(shinyjs)
library(shinymanager)

# ------------------------------------------------------------
# USER CONFIGURATION
# Replace the values below with your own Google account
# and Google Sheet URLs.
# See README.md for setup instructions.
# ------------------------------------------------------------

gs4_auth("YOUR_GOOGLE_ACCOUNT_EMAIL") # Google account used to access the Sheets

login_gsheet <- "PASTE_YOUR_LOGIN_SHEET_URL_HERE"
data_gsheet  <- "PASTE_YOUR_DATA_SHEET_URL_HERE"

# Template Google Sheets are provided in the README.
# Make your own copies of the templates and use the URLs
# of your copies above.

# ------------------------------------------------------------
# LOGIN SHEET CONFIGURATION
# Edit the values below to match your Login Sheet.
# See README.md for detailed instructions and examples.
# ------------------------------------------------------------

LOGIN_USER_COL        <- "YOUR_USERNAME_COLUMN_NAME"
LOGIN_PASSWORD_COL    <- "YOUR_PASSWORD_COLUMN_NAME"
LOGIN_NAME_COL        <- "YOUR_NAME_COLUMN_NAME"
LOGIN_DESIGNATION_COL <- "YOUR_DESIGNATION_COLUMN_NAME"
LOGIN_REFERRED_COL    <- "YOUR_REFERRED_BY_COLUMN_NAME"
LOGIN_ACCESS_COL      <- "YOUR_ACCESS_COLUMN_NAME"


# Access values used in the Login Sheet:
# 1 = access granted
# 0 = access pending/restricted
#
# Use these values in the access column of your Login Sheet.
ACCESS_GRANTED <- 1
ACCESS_PENDING <- 0

# How often the app checks whether a logged-in user's access
# is still granted, in seconds.
# Change this value if a different interval is required.
ACCESS_CHECK_INTERVAL <- 120   # seconds


# ------------------------------------------------------------
# DATA SHEET CONFIGURATION
# Edit the values below to match your Data Sheet.
# See README.md for detailed instructions and examples.
# ------------------------------------------------------------

lon_deg <- "YOUR_LONGITUDE_DEGREES_COLUMN_NAME"
lon_min <- "YOUR_LONGITUDE_MINUTES_COLUMN_NAME"
lon_sec <- "YOUR_LONGITUDE_SECONDS_COLUMN_NAME"

lat_deg <- "YOUR_LATITUDE_DEGREES_COLUMN_NAME"
lat_min <- "YOUR_LATITUDE_MINUTES_COLUMN_NAME"
lat_sec <- "YOUR_LATITUDE_SECONDS_COLUMN_NAME"

bearing_left <- "YOUR_BEARING_LEFT_COLUMN_NAME"
bearing_rigt <- "YOUR_BEARING_RIGHT_COLUMN_NAME"
bearing_midl <- "YOUR_BEARING_MIDDLE_COLUMN_NAME"

date <- "YOUR_DATE_COLUMN_NAME"
time <- "YOUR_TIME_GROUP_COLUMN_NAME"

# Enter the date format used in your Data Sheet.
# Examples:
# "%d/%m/%Y" = 31/12/2026
# "%m/%d/%Y" = 12/31/2026
# "%Y-%m-%d" = 2026-12-31
date_format <- "YOUR_DATE_FORMAT"

# Date format displayed in the Shiny app.
# Examples:
# "dd/mm/yyyy" = 31/12/2026
# "mm/dd/yyyy" = 12/31/2026
# "yyyy-mm-dd" = 2026-12-31
date_input_format <- "YOUR_DATE_INPUT_FORMAT"

pulse <- "YOUR_PULSE_COLUMN_NAME"
gain <- "YOUR_GAIN_COLUMN_NAME"
remarks <- "YOUR_REMARKS_COLUMN_NAME"
name <- "YOUR_OBSERVER_NAME_COLUMN_NAME"

# Enter the time groups used in your Data Sheet.
# Add or remove time groups as required.
# Each value must match the corresponding entry in the Data Sheet.
timegroup <- c(
  "YOUR_TIME_GROUP_1" = "your_time_group_1",
  "YOUR_TIME_GROUP_2" = "your_time_group_2",
  "YOUR_TIME_GROUP_3" = "your_time_group_3",
  "YOUR_TIME_GROUP_4" = "your_time_group_4"
)

credentials <- read_sheet(login_gsheet) %>%
  dplyr::filter(.data[[LOGIN_ACCESS_COL]] == ACCESS_GRANTED) %>%
  dplyr::rename(
    user = all_of(LOGIN_USER_COL),
    password = all_of(LOGIN_PASSWORD_COL)
  )

date_input_format <- date_format %>% 
  gsub("%d", "dd", x = _) %>% 
  gsub("%m", "mm", x = _) %>% 
  gsub("%Y", "yyyy", x = _)

ui <- secure_app(fluidPage(
  
  tabsetPanel(
    
    tabPanel("Triangulation",
             dateInput("replicate.date", "Date:", value = Sys.Date(), format = date_input_format),
             selectInput("replicate.time", "Time group:", timegroup),
             DT::dataTableOutput("details"),
             leafletOutput(outputId = "map", height = 600),
             h4("Leopard location from triangulation:"),
             verbatimTextOutput("output")
    ),
    
    tabPanel("Register user",
             sidebarLayout(
               sidebarPanel(
                 textInput("register_name", "Name"),
                 textInput("register_designation", "Designation"),
                 textInput("register_username", "Username"),
                 passwordInput("register_password", "Password"),
                 actionButton("submit_register", "Register")
               ),
               mainPanel()
             )
    )
    
  )
))

server <- function(input,output,session) {
  
  result_auth <- secure_server(
    check_credentials = check_credentials(credentials)
  )
  
  observe({
    
    invalidateLater(ACCESS_CHECK_INTERVAL * 1000, session)
    
    current_user <- reactiveValuesToList(result_auth)[["user"]]
    
    req(current_user)
    
    login_status <- read_sheet(login_gsheet) %>%
      dplyr::filter(.data[[LOGIN_USER_COL]] == current_user)
    
    if (nrow(login_status) == 0 ||
        login_status[[LOGIN_ACCESS_COL]][1] != ACCESS_GRANTED) {
      
      session$close()
    }
  })
  
  raw <- read_sheet(data_gsheet) %>% 
  cbind(longitude = .[[lon_deg]] + .[[lon_min]]/60 + .[[lon_sec]]/3600,
        latitude = .[[lat_deg]] + .[[lat_min]]/60 + .[[lat_sec]]/3600,
        bearing = ifelse(is.na(.[[bearing_midl]]),
                         ifelse(.[[bearing_rigt]] < .[[bearing_left]],
                                ifelse((360 - .[[bearing_left]] + .[[bearing_rigt]])/2 + .[[bearing_left]] > 360,
                                       ((360 - .[[bearing_left]] + .[[bearing_rigt]])/2 + .[[bearing_left]]) - 360,
                                       (360 - .[[bearing_left]] + .[[bearing_rigt]])/2 + .[[bearing_left]]),
                                (.[[bearing_left]] + .[[bearing_rigt]])/2),
                         .[[bearing_midl]]))

raw[[date]] <- as.Date(raw[[date]],date_format)

df.triangulation.visualizer <- reactive({
  raw %>%
    dplyr::filter(.data[[date]] == input$replicate.date & .data[[time]] == input$replicate.time) %>% 
    cbind(destPoint(.[,c("longitude","latitude")],.$bearing,5000)) %>% 
    .[!is.na(.$bearing),]
})

output$details <- DT::renderDataTable({
  df.triangulation.visualizer()[,c(date,
                                 time,
                                 bearing_left,
                                 bearing_midl,
                                 bearing_rigt,
                                 pulse,
                                 gain,
                                 remarks,
                                 name),drop = F]
  })

df.select <- reactive({
  df.triangulation.visualizer()[input$details_rows_selected,, drop = F] %>% 
    {
          rbind.data.frame(
            geosphere::gcIntersectBearing(.[1,c("longitude","latitude")],
                                          .[1,"bearing"],
                                          .[2,c("longitude","latitude")],
                                          .[2,"bearing"]),
            geosphere::gcIntersectBearing(.[1,c("longitude","latitude")],
                                          .[1,"bearing"],
                                          .[3,c("longitude","latitude")],
                                          .[3,"bearing"]),
            geosphere::gcIntersectBearing(.[2,c("longitude","latitude")],
                                          .[2,"bearing"],
                                          .[3,c("longitude","latitude")],
                                          .[3,"bearing"])
          )
        } %>% 
        .[,1:2] %>% 
        summarise(lon = mean(lon), lat = mean(lat))
})

output$output <- renderPrint({df.select()})

output$map <- renderLeaflet({
df.triangulation.vis_lines <- gcIntermediate(
  df.triangulation.visualizer()[,c("longitude","latitude")],
  df.triangulation.visualizer()[,c("lon","lat")],
  n = 0,
  addStartEnd = TRUE,
  output = "sf") #get lines between points
  
leaflet() %>%#start to map
  addProviderTiles(providers$Esri.WorldImagery) %>%#esri satellite basemap
  addScaleBar() %>%#check with scalebar
  
  addCircleMarkers(data = df.triangulation.visualizer(),
                   lat = ~latitude,
                   lng = ~longitude,
                   radius = 1,
                   color = ~"pink",
                   opacity = 1,
                   popup = ~paste(row.names(df.triangulation.visualizer()))
                   ) %>%
  addCircleMarkers(data = df.select(),
                   lat = ~lat,
                   lng = ~lon,
                   radius = ~1.5,
                   color = ~"red",
                   opacity = 1,
                   popup = ~paste0("lat:",`lat`,", lon:",`lon`)
                   ) %>% 
  addPolylines(data = df.triangulation.vis_lines,
               color = ~"yellow",
               weight = 1)
})

observeEvent(input$submit_register, {
  
  req(input$register_name,
      input$register_designation,
      input$register_username,
      input$register_password)
  
  loginsheet <- read_sheet(login_gsheet)
  
  if (any(loginsheet[[LOGIN_USER_COL]] == input$register_username)) {
    
    showModal(modalDialog(
      "Username already exists. Kindly choose another username."
    ))
    
  } else {
    
    new_register_row <- data.frame(
      setNames(list(input$register_username), LOGIN_USER_COL),
      setNames(list(input$register_password), LOGIN_PASSWORD_COL),
      setNames(list(input$register_name), LOGIN_NAME_COL),
      setNames(list(input$register_designation), LOGIN_DESIGNATION_COL),
      setNames(list(reactiveValuesToList(result_auth)[[1]]), LOGIN_REFERRED_COL),
      setNames(list(ACCESS_PENDING), LOGIN_ACCESS_COL)
    )
    
    new_register_row %>%
      sheet_append(login_gsheet, .)
    
    showModal(modalDialog(
      "Registration submitted successfully.",
      "Your account is pending approval. You will be able to log in once access has been granted."
    ))
    
  }
})
}

shinyApp(ui = ui, server = server)