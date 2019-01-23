rm(list=ls())
library(zoo)
library(anytime)
library(schoolmath)
require(data.table)
require(dplyr)
library(lubridate)

## Generate a start and end date for the training dataset ##
start_date <- Sys.time()
start_date <- as.POSIXct(start_date,format = "%Y%m%d %H:%M",tz = "GMT")
end_date <- paste(as.Date(start_date) %m-% months(12),"0:00")


#-----------------------------------
#CAISO Generation Actuals 
#-----------------------------------


## Grab SP15 Actual Data ##

## These files come from CAISO's OASIS system.  See Daily OASIS Grabber Script ##

genpath <- "SP15_SOLAR_ACTUALS.csv"

gen <- read.csv(genpath, as.is=TRUE, header = TRUE, stringsAsFactors=FALSE)
gen <- data.frame("Date" = gen[,5],"zone" = gen[,6],"type" = gen[,7],"actual" = gen[,12])
gen[,1] <- as.POSIXct(gen[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )


gen_sp_solar <- gen[which(gen[,2] == "SP15" & gen[,3] == "Solar"),]
gen_sp_solar <- gen_sp_solar[!duplicated(gen_sp_solar),]

#####DUMMY VARIABLE
gen_np_solar <- gen_sp_solar
######
genpath <- "SP15_WIND_ACTUALS.csv"

gen <- read.csv(genpath, as.is=TRUE, header = TRUE, stringsAsFactors=FALSE)
gen <- data.frame("Date" = gen[,5],"zone" = gen[,6],"type" = gen[,7],"actual" = gen[,12])
gen[,1] <- as.POSIXct(gen[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )

gen_sp_wind <- gen[which(gen[,2] == "SP15" & gen[,3] == "Wind"),]
gen_sp_wind <- gen_sp_wind[!duplicated(gen_sp_wind),]

#####DUMMY VARIABLE
gen_np_wind <- gen_sp_wind
#####
g1 <- inner_join(gen_sp_solar[,c(1,4)],gen_sp_wind[,c(1,4)], by='Date')
g2 <- inner_join(g1,gen_np_wind[,c(1,4)], by='Date')
g3 <- inner_join(g2,gen_sp_wind[,c(1,4)], by='Date')
g4 <- rbind(g4,g3)


gen_actuals <- data.frame("Date" = g4[,1],"sp15_solar"=g4[,2],"np15_solar"=g4[,3],"np15_wind"=g4[,4],"sp15_wind"=g4[,5])
gen_actuals[,1] <- as.POSIXct(gen_actuals[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )




#-----------------------------------
#Node Level Actuals 
#-----------------------------------



## Grab historical LMP price data ##

## These files come from CAISO's OASIS system.  See Price Grabber Script. ##


pricepath <- "NODAL_PRICE_ACTUALS.csv"

price <- read.csv(pricepath, as.is=TRUE, header = TRUE,stringsAsFactors=FALSE)
price <- data.frame("Date" = price[,5],"price_type" = price[,9],"price" = price[,10])
price[,1] <- as.POSIXct(price[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )
gdate <- which(!is.na(price$Date))
price <- price[gdate,]
temp <- which(grepl(":00:00",price$Date) == TRUE)
price <- price[temp,]

new<-price 
price_out <- rbind(price_out,new)

old_price <- price_out
price_out$sign <- replace(price_out[,3],which(price_out[,3] > 0),1)
price_out$sign <- replace(price_out[,4],which(price_out[,4] < 0),-1)


## FOR THRESHOLD OF 0$/MWH
for (n in c(1:length(price_out[,1]))) {
  if (price_out$price[n] > 0) {
    avg <- mean(price_out[which(price_out[,3] > 0),3])
    stdev <- sd(price_out[which(price_out[,3] > 0),3])
    high <- avg+stdev
    low <- 0
    price_out$sign[n] <- (price_out$price[n]/high)
  } else {
    avg <- mean(price_out[which(price_out[,3] < 0),3])
    stdev <- sd(price_out[which(price_out[,3] < 0),3])
    low <- avg-stdev
    high <- 0
    price_out$sign[n] <- ((price_out$price[n]-low))/(0-low)-1
  }
}
price_out$sign <- replace(price_out[,4],which(price_out[,4] > 1),1)
price_out$sign <- replace(price_out[,4],which(price_out[,4] < -1),-1)



#-----------------------------------
#CAISO Load Data 
#-----------------------------------

## Grab historical CAISO Load data ##
## These files come from CAISO's OASIS system.  See Daily OASIS Grabber Script. ##


loadpath <- "ACT_CAISO_LOAD.csv"
load <- read.csv(loadpath, as.is=TRUE, header = TRUE,stringsAsFactors=TRUE)
load <- data.frame("Date" = load[,2],"CAISO" = load[,12])
load[,1] <-as.POSIXct(load[,1], format ="%Y-%m-%dT%H:%M", tz ="GMT" )
gdate <- which(!is.na(load$Date))
load <- load[gdate,]
g4 <- na.exclude(load)
load_out <-rbind(load_out,g4)

load<-load_out



#-----------------------------------
# Match the data
#-----------------------------------

library(dplyr)

m0_train <- inner_join(price_out[c(1,3,4)],gen_actuals[c(1,2,5)], by='Date')
m1_train <- inner_join(m0_train,load_out, by='Date')
m1_train$sp15_solar <- replace(m1_train[,4],which(m1_train[,4] < 0),0)
m1_train$sp15_wind <- replace(m1_train[,5],which(m1_train[,5] < 0),0)
m1_train$diff <- m1_train[,6]-m1_train[,5]-m1_train[,4]
m1_train$Hour <- as.numeric(format(m1_train$Date,"%H"))
m1_train$DOW <- as.numeric(format(m1_train$Date,"%w"))

date_range <- which( (m1_train$Date <= start_date) & (m1_train$Date > end_date) )

m1_verification<-m1_train[date_range[1:2000],]
m1_train<-m1_train[date_range,]




#-------------------------------------------
#Load neural net data creation function
#-------------------------------------------

load(file = 'CreateANNInputData_NhrsWindow.rda')
hrsback <- 0  #Number of records you wish to look back at and include in training data.
hrsforward <- 0  #Number of records forward you want to predict. 
option <- 0      #assumes data for current hour will be available.
single <- 0      #Use 0 when creating training data. Use 1 when running operational forecast.

train <- CreateANNInputData_NhrsWindow((m1_train[,c(1,3,6,7,8)]),hrsback,hrsforward,option, single)
verif <- CreateANNInputData_NhrsWindow((m1_verification[,c(1,3,6,7,8)]),hrsback,hrsforward,option, single)

#INITIALIZE H2O
library(h2o)
localH2O <- h2o.init(max_mem_size = '4g', nthreads = 2) ## using a max 2GB of RAM

##CONVERT TO DATA FRAME SO DATA CAN BE CONVERTED TO H2O OBJECT AND THEN CONVERT TO H2O OBJECT
train_hex.f <- as.data.frame(train)
train_hexfinal <- as.h2o(train_hex.f,destination_frame="train_hexfinal")

verif_hex.f <- as.data.frame(verif)
verif_hexfinal <- as.h2o(verif_hex.f,destination_frame="verif_hexfinal")

nrowshex <- dim(train_hexfinal)[1]
ncolshex <- dim(train_hexfinal)[2]

## Run 5 Training Models ##

model <- h2o.deeplearning(x = 2:ncolshex,    
                          y = 1,
                          training_frame=train_hexfinal,
                          validation_frame=verif_hexfinal,
                          activation = "Rectifier",
                          hidden = c(50,100,50),
                          epochs = 100000,
                          variable_importances=T,
                          stopping_rounds=5,
                          stopping_tolerance=0.001,
                          stopping_metric="MSE",
                          model_id="DeepLearning_model_R_1")
h2o.saveModel(object = model, path = paste("SavedANN\\",sep=""), force = TRUE)
model <- h2o.deeplearning(x = 2:ncolshex,    
                          y = 1,
                          training_frame=train_hexfinal,
                          validation_frame=verif_hexfinal,
                          activation = "Rectifier",
                          hidden = c(50,100,50),
                          epochs = 100000,
                          variable_importances=T,
                          stopping_rounds=5,
                          stopping_tolerance=0.001,
                          stopping_metric="MSE",
                          model_id="DeepLearning_model_R_2")
h2o.saveModel(object = model, path = paste("SavedANN\\",sep=""), force = TRUE)
model <- h2o.deeplearning(x = 2:ncolshex,    
                          y = 1,
                          training_frame=train_hexfinal,
                          validation_frame=verif_hexfinal,
                          activation = "Rectifier",
                          hidden = c(50,100,50),
                          epochs = 100000,
                          variable_importances=T,
                          stopping_rounds=5,
                          stopping_tolerance=0.001,
                          stopping_metric="MSE",
                          model_id="DeepLearning_model_R_3")
h2o.saveModel(object = model, path = paste("SavedANN\\",sep=""), force = TRUE)
model <- h2o.deeplearning(x = 2:ncolshex,    
                          y = 1,
                          training_frame=train_hexfinal,
                          validation_frame=verif_hexfinal,
                          activation = "Rectifier",
                          hidden = c(50,100,50),
                          epochs = 100000,
                          variable_importances=T,
                          stopping_rounds=5,
                          stopping_tolerance=0.001,
                          stopping_metric="MSE",
                          model_id="DeepLearning_model_R_4")
h2o.saveModel(object = model, path = paste("SavedANN\\",sep=""), force = TRUE)
model <- h2o.deeplearning(x = 2:ncolshex,    
                          y = 1,
                          training_frame=train_hexfinal,
                          validation_frame=verif_hexfinal,
                          activation = "Rectifier",
                          hidden = c(50,100,50),
                          epochs = 100000,
                          variable_importances=T,
                          stopping_rounds=5,
                          stopping_tolerance=0.001,
                          stopping_metric="MSE",
                          model_id="DeepLearning_model_R_5")
h2o.saveModel(object = model, path = paste("SavedANN\\",sep=""), force = TRUE)

