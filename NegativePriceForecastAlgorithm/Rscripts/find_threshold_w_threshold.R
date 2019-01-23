rm(list=ls())
library(zoo)
library(anytime)
library(schoolmath)
require(data.table)
require(dplyr)
library(lubridate)



current_time <- format(Sys.time(), "%Y-%m-%d %H:%00")
start_date <- ymd_hm(current_time) - lubridate::hours(3)
end_date <- ymd_hm(current_time) - lubridate::days(7) - lubridate::hours(2)

dts <- seq(end_date,start_date,by ='60 mins')

price_path <- "NODAL_PRICE_ACTUALS.csv"
price <- read.csv(price_path,as.is = TRUE, header=TRUE, stringsAsFactors=FALSE)
price <- data.frame("Date" = price[,5],"Actuals" = price[,10])
price[,1] <- as.POSIXct(price[,1], format ="%Y-%m-%dT%H", tz ="GMT" )

count_pos <- 0
count_neg <- 0
total_pos <- 0
total_neg <- 0
min_pos <- 1
final_list_pos <- data.frame()
for (n in c(1:length(dts))) {
  
  forc_path <- paste("Price_Forecast_w_threshold_",format(dts[n],format="%Y%m%d_%H00"),".csv",sep="")
  if (file_test("-f",forc_path)){
  forecast <- read.csv(forc_path, as.is=TRUE, header = TRUE,stringsAsFactors=FALSE)
  forecast <- data.frame("Date" = forecast[,2],"Pred" = forecast[,4])
  forecast[,1] <- as.POSIXct(forecast[,1], format ="%Y-%m-%d %H:%M", tz ="America/Los_Angeles" )
  
  g1<-inner_join(forecast,price,by='Date')
  
  input_threshold <- -14
  for (m in c(1:length(g1[,1]))) {
  if (g1$Actuals[m] > input_threshold){
    total_pos <- total_pos + g1$Pred[m]
    count_pos <- count_pos + 1
    final_list_pos<-rbind(final_list_pos,g1$Pred[m]) 
    
    if (g1$Pred[m] < min_pos){
      min_pos <-g1$Pred[m]
    }
  }
  
  if (g1$Actuals[m] < input_threshold){
    total_neg <- total_neg + g1$Pred[m]
    count_neg <- count_neg + 1
  }
  }
  }
}
sd_pos<-sd(final_list_pos[,1])
new_threshold <- (total_pos/count_pos)-sd_pos

threshold_file <- "curr_threshold_w_threshold.txt"

old_threshold_file <- paste("threshold_w_threshold_",format(start_date,format="%Y%m%d_%H00"),".txt",sep="")
file.copy(threshold_file,old_threshold_file,overwrite=TRUE)
write(new_threshold,threshold_file)

