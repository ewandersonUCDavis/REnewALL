rm(list=ls())
library(zoo)
library(anytime)
library(schoolmath)
require(data.table)
require(dplyr)
library(lubridate)
library(jsonlite)
library(RCurl)
library(httr)

#-----------------------------------
#SP15 Forecast 
#-----------------------------------

current<-Sys.time()
current<-as.POSIXct(current,format = "%Y-%m-%d %H:%M",tz = "America/Los_Angeles")

genpath <- paste("ISO_DB_CAISO_",format(Sys.time()-hours(2),"%Y"),format(Sys.time()-hours(2),"%m"),format(Sys.time()-hours(2),"%d"),"_",format(ymd_hms(current)-hours(2),"%H"),"00.csv",sep="")

all <- readLines(genpath)
skip <- all[-1:-2]
gen <- read.csv(textConnection(skip), as.is=TRUE, header = TRUE, stringsAsFactors=FALSE)
gen <- data.frame("Date" = gen[,1],"sp15_wind" = gen[,2],"sp15_solar" = gen[,3])
gen[,1] <- as.POSIXct(gen[,1], format ="%Y-%m-%d %H:%M", tz ="America/Los_Angeles")

gen_sp_solar <- gen[,c(1,3)]
gen_np_solar <- gen[,c(1,3)]
gen_sp_wind <- gen[,c(1,2)]
gen_np_wind <- gen[,c(1,2)]

g1 <- inner_join(gen_sp_solar[,c(1,2)],gen_np_solar[,c(1,2)], by='Date')
g2 <- inner_join(g1,gen_np_wind[,c(1,2)], by='Date')
g3 <- inner_join(g2,gen_sp_wind[,c(1,2)], by='Date')

g4 <- g3
gen_fcast<-g4



#-----------------------------------
#CAISO Forecast LoadData 
#-----------------------------------
loadpath <- "DA_CAISO_LOAD_CURR.csv"
load <- read.csv(loadpath, as.is=TRUE, header = TRUE,stringsAsFactors=FALSE)
load <- data.frame("Date" = load[,2],"CAISO" = load[,12])
load[,1] <-as.POSIXct(load[,1], format ="%Y-%m-%dT%H:%M", tz ="UTC" )
attr(load[,1], "tzone") <- "UTC"
gdate <- which(!is.na(load$Date))
load <- load[gdate,]
load <- na.exclude(load)
load_fcast <-load

#-----------------------------------
#GRAB MOST RECENT PRICE
#-----------------------------------

pricepath <- "NODAL_PRICE_ACTUALS.csv"

price <- read.csv(pricepath, as.is=TRUE, header = TRUE,stringsAsFactors=FALSE)
price <- data.frame("Date" = price[,5],"price" = price[,10])
price[,1] <- as.POSIXct(price[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )
#attr(price[,1], "tzone") <- "PPT"
gdate <- which(!is.na(price$Date))
price <- price[gdate,]
temp <- which(grepl(":00:00",price$Date) == TRUE)
price <- price[temp,]

curr_price<-price[length(price$price),2]


#-----------------------------------
# Match the data
#-----------------------------------
library(dplyr)
m0_test <- (gen_fcast[c(1,2,5)])
m1_test <- inner_join(m0_test,load_fcast, by='Date')
m1_test$sp15_solar.x <- replace(m1_test[,2],which(m1_test[,2] < 0),0)
m1_test$sp15_wind.y <- replace(m1_test[,3],which(m1_test[,3] < 0),0)
m1_test$diff <- m1_test[,4]-m1_test[,3]-m1_test[,2]
m1_test$Hour <- as.numeric(format(m1_test$Date,"%H"))
m1_test$DOW <- as.numeric(format(m1_test$Date,"%w"))
m1_test <- m1_test[,c(1,1,4,5,6)]
m1_test[,2] <- NA

library(h2o)

localH2O <- h2o.init(max_mem_size = '4g', nthreads = 2) ## using a max 2GB of RAM
load(file = 'Functions\\CreateANNInputData_NhrsWindow.rda')
hrsback <- 0  #Number of records you wish to look back at and include in training data.
hrsforward <- 0  #Number of records forward you want to predict. 
option <- 0      #assumes data for current hour will be available.
single <- 0   
test <-  CreateANNInputData_NhrsWindow(m1_test,hrsback,hrsforward,option, single)
#localH2O <- h2o.init(max_mem_size = '4g', nthreads = 2) ## using a max 2GB of RAM

##CONVERT TO DATA FRAME SO DATA CAN BE CONVERTED TO H2O OBJECT AND THEN CONVERT TO H2O OBJECT
test_hex.f <- as.data.frame(test)
test_hexfinal <- as.h2o(test_hex.f,destination_frame="test_hexfinal")

model_1 <- h2o.loadModel(path = "SavedANN\\DeepLearning_model_R_1")
model_2 <- h2o.loadModel(path = "SavedANN\\DeepLearning_model_R_2")
model_3 <- h2o.loadModel(path = "SavedANN\\DeepLearning_model_R_3")
model_4 <- h2o.loadModel(path = "SavedANN\\DeepLearning_model_R_4")
model_5 <- h2o.loadModel(path = "SavedANN\\DeepLearning_model_R_5")

yhat_1 <- h2o.predict(model_1, test_hexfinal)
yhat_2 <- h2o.predict(model_2, test_hexfinal)
yhat_3 <- h2o.predict(model_3, test_hexfinal)
yhat_4 <- h2o.predict(model_4, test_hexfinal)
yhat_5 <- h2o.predict(model_5, test_hexfinal)
len <- length(as.matrix(yhat_1$predict))
forc_write <- as.matrix( (yhat_1$predict+yhat_2$predict+yhat_3$predict+yhat_4$predict+yhat_5$predict)/5 )

neg_price_flag <- forc_write

new_threshold<-read.table("thresholds\\curr_threshold_w_threshold.txt")

neg_price_flag <- replace(neg_price_flag,which(forc_write <= new_threshold[1,1]),-1)
neg_price_flag <- replace(neg_price_flag,which(forc_write > new_threshold[1,1]),0)

output <- data.frame("Forecast Data" = m1_test[1:length(m1_test[,1])-1,1],"Negative Pricing Flag" = neg_price_flag,"Pred.Output" = forc_write)
attr(output$Forecast.Data,"tzone") <- "America/Los_Angeles"

out_file <- paste("Price_Forecast_w_threshold_no_mod_",format(Sys.time()-hours(2),"%Y"),format(Sys.time()-hours(2),"%m"),format(Sys.time()-hours(2),"%d"),"_",format(ymd_hms(current)-hours(2),"%H"),"00.csv",sep="")





write.csv(output, file=out_file)

## IF CURRENT PRICE IS ABOVE 0, THEN SET FLAG TO 0 ##
if (curr_price > -14){
  
  neg_price_flag[1] <- 0
}

output <- data.frame("Forecast Data" = m1_test[1:length(m1_test[,1])-1,1],"Negative Pricing Flag" = neg_price_flag,"Pred.Output" = forc_write)
attr(output$Forecast.Data,"tzone") <- "America/Los_Angeles"

out_file <- paste("Price_Forecast_w_threshold_",format(Sys.time()-hours(2),"%Y"),format(Sys.time()-hours(2),"%m"),format(Sys.time()-hours(2),"%d"),"_",format(ymd_hms(current)-hours(2),"%H"),"00.csv",sep="")





write.csv(output, file=out_file)

#ftpUpload(out_file,paste("ftp://mpiuser:mPr0c3ss@ftp.ghforecaster.com/ANALYSTS/Daniel/ReNewAll/Forecasts/","Price_Forecast_",format(Sys.time()-hours(2),"%Y"),format(Sys.time()-hours(2),"%m"),format(Sys.time()-hours(2),"%d"),"_",format(ymd_hms(current)-hours(2),"%H"),"00.csv",sep=""))

#out_json<-jsonlite::toJSON(output,pretty = TRUE)
#json_file_out<-paste("D:\\Projects\\ReNewALL\\Data\\Forecasts\\","Price_Forecast_",format(Sys.time()-hours(2),"%Y"),format(Sys.time()-hours(2),"%m"),format(Sys.time()-hours(2),"%d"),"_",format(ymd_hms(current)-hours(2),"%H"),"00.JSON",sep="")
#write_json(out_json,json_file_out)

for (a in c(1:length(output[,1]))){
POST(url = "http://12.145.46.162:8081/api/v1/2xljkOaEv3HAcIwnLMnc/telemetry",
         add_headers("Content-Type:application/json"),
         body = paste("{\"ts\":",print(as.numeric(output[a,1])*1000,digits=13),",\"values\": {\"flag_PTC\":","\"",output[a,2],"\"}}"),verbose()) -> res
}
# 
# 
#   POST(url = "http://99.105.39.251:8080/api/v1/FtV7CewA5LnKzo3WUTns/telemetry",
#        add_headers("Content-Type:application/json"),
#        body = paste("{\"ts\":",print(as.numeric(price[length(price$price),1])*1000,digits=13),",\"values\": {\"Nodal Price\":","\"",curr_price,"\"}}"),verbose()) -> res
# 
