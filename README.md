# VHF Triangulation Shiny App

A Shiny application for visualising VHF telemetry observations and estimating an animal's location using triangulation.

The application reads field observations from Google Sheets, displays observation locations and bearing lines on a map, and estimates the triangulated location from the intersections of three bearings.

## Requirements

You will need:

-   R
-   RStudio (recommended)
-   A Google account
-   Access to Google Sheets
-   The R packages used by the application

Install the required packages with:

``` r
install.packages(c(
  "shiny",
  "leaflet",
  "googlesheets4",
  "dplyr",
  "geosphere",
  "DT",
  "shinyjs",
  "shinymanager"
))
```

## 1. Download the application

Download or clone this repository to your computer.

The main application file is:

``` text
app.R
```

## 2. Set up the Google Sheets

The application uses two Google Sheets:

1.  **Login Sheet** — stores user accounts and controls access.
2.  **Data Sheet** — stores VHF telemetry observations.

Template sheets are provided here:

-   **Login Sheet template:** <https://docs.google.com/spreadsheets/d/1ugTV2I2-Hq3XCyC9SQs4kfkLAk2nzTRyBM6oTlCz7_0/edit?usp=sharing>

-   **Data Sheet template:** <https://docs.google.com/spreadsheets/d/1VmV8_1vd5FiIf_zX6SYXDEym3Q1Hh_SPiD_Cryw0-7E/edit?usp=sharing>

## 3. Configure `app.R`

Open `app.R` and complete the sections marked **USER CONFIGURATION**, **LOGIN SHEET CONFIGURATION**, and **DATA SHEET CONFIGURATION**.

### Google account and Sheet URLs

Replace:

``` r
gs4_auth("YOUR_GOOGLE_ACCOUNT_EMAIL")

login_gsheet <- "PASTE_YOUR_LOGIN_GOOGLE_SHEET_URL_HERE"
data_gsheet  <- "PASTE_YOUR_DATA_GOOGLE_SHEET_URL_HERE"
```

with the Google account you will use to access the Sheets and the URLs of your own copies of the Login and Data Sheets.

The Google account must have the required access to both Sheets.

### Login Sheet configuration

The Login Sheet must contain columns for:

-   Username
-   Password
-   Name
-   Designation
-   Referrer
-   Access status

The names of these columns do not have to be the same as those in the template. Enter the actual column names from your Login Sheet in the corresponding `LOGIN_*` settings in `app.R`.

The Login Sheet must use:

``` text
1 = access granted
0 = access pending/restricted
```

in the access column.

Newly registered users are assigned `0` and will remain unable to log in until their access is changed to `1`.

### Data Sheet configuration

Enter the names of the corresponding columns from your Data Sheet in the `DATA SHEET CONFIGURATION` section.

The application requires fields for:

-   Longitude: degrees, minutes and seconds
-   Latitude: degrees, minutes and seconds
-   Left bearing
-   Right bearing
-   Middle bearing
-   Date
-   Time group
-   Pulse
-   Gain
-   Remarks
-   Observer name

The column names can be different from those in the template, provided the corresponding settings in `app.R` are updated.

### Date format

Set `date_format` to match the format used in your Data Sheet.

Examples:

``` r
date_format <- "%d/%m/%Y"   # 31/12/2026
date_format <- "%m/%d/%Y"   # 12/31/2026
date_format <- "%Y-%m-%d"   # 2026-12-31
```

The application automatically uses this setting for the date picker as well.

### Time groups

The time groups are defined in `timegroup`.

You can use any time-group structure appropriate for your study. For example:

``` r
timegroup <- c(
  "Morning" = "morning",
  "Noon" = "noon",
  "Evening" = "evening",
  "Night" = "night"
)
```

Or you can use shorter sampling intervals, for example:

``` r
timegroup <- c(
  "00:00–02:00" = "00:00–02:00",
  "02:00–04:00" = "02:00–04:00",
  "04:00–06:00" = "04:00–06:00"
)
```

The values must correspond to the entries used in the time-group column of your Data Sheet. Add or remove groups as required.

## 4. User registration and access

The application includes a **Register user** tab.

A new user provides:

-   Name
-   Designation
-   Username
-   Password

The registration is added to the Login Sheet with access set to `0`.

An administrator can then review the registration and change the user's access value to `1`.

Once access is granted, the user can log in to the application.

The application periodically checks whether the user's access is still granted.

The default check interval is:

``` r
ACCESS_CHECK_INTERVAL <- 120
```

This represents **120 seconds (2 minutes)**. Change this value if you require a different interval.

## 5. Running the application

Open `app.R` in RStudio and run:

``` r
shiny::runApp()
```

The application will open in your browser.

## 6. Using the triangulation interface

After logging in:

1.  Select a date.
2.  Select a time group.
3.  The observations for that date and time group will appear in the table.
4.  Select three observations from the table.
5.  The application calculates the intersections between the three bearings.
6.  The estimated triangulated location is displayed on the map and in the output.

The map displays:

-   Observation locations
-   Bearing lines
-   Estimated triangulated location

### Bearing line distance

The application currently projects each bearing line to a fixed distance of **5 km (5000 m)**.

This value is set in the application code and can be changed if required.

## 7. Google authentication

The application currently uses `googlesheets4` for Google Sheets authentication.

The simplest approach is to authenticate using a Google account that has access to the required Sheets.

For a more controlled deployment, particularly when the application is deployed for multiple users or on a server, a **Google service account** can be considered instead. Users choosing this approach should configure Google Cloud authentication and grant the service account access to the required Sheets.

## 8. Data requirements

For triangulation, select three observations corresponding to three bearing locations.

The accuracy of the resulting location depends on the quality of the field observations, GPS coordinates, bearing measurements, and the geometry of the observation points.

This application performs the geometric triangulation; it does not assess the field accuracy or reliability of the individual bearings.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
