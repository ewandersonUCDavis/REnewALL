CreateANNInputData_NhrsWindow <- function(input,hrsback,hrsforward,option,single)
{
  ##CreateANNInputData_NhrsWindow(input,2,1,1)
  #------------------------------------------------------------------------------------------------------------------#
  ##THIS ROUTINE CREATES AN ARRAY OF DATA THAT CONTAINS ALL DATA FROM N ROWS BEFORE (hrsback) FORECAST EVAL TIME 
  ##TO N HOURS AFTER (hrsforward) FORECAST EVAL TIME. 

  ## hrsback = number of  hours back from the current evaluation time. 
  ## hrsforward is the number of hours in the future you want to include in the input data. Defaults to 1 hour ahead
  
  ##If Option = 0 then use method that uses actuals from N records back up until last record before current time.
  ##If Option = 1 then use method that only uses actual values at N hours back and uses only met data between then and current time.
  ##If Option = 2 then use method that only uses past actuals but only  up until the previous record. The previous record is only met data.
  ##If Option = 3 then use method that only uses past actuals but only  up until the previous record. The previous record is only met data. Hrsforward is value you are predicting.
  ##If Option = 4 then use method that uses actuals from N records back up until last record before current time.Hrsforward is value you are predicting.
  
  #Option = 2 can be useful for SOM's or ANEN which want to identify regime over next N hours
  #Option = 3,4 can be useful for creating data for neural networks trained for each forecast horizon.
  
  ##Note: The order of the data created by this routine is different than the regular Murray ANN data
  ##      in that each row here starts with data N records back and moves forward instead of data at 
  ##      1 hour ahead and moving backward.
  #-----------------------------------------------------------------------------------------------------------------  
  
  
  
  
  if(option != 0 & option != 1 & option != 2 & option !=3 & option !=4)
  {
    option <- 1
  }
  
  #if hrsforward = 0 then set it 1 because 1 is for the next record you are trying to predict
  if(hrsforward == 0)
  {
    hrsforward <- 1
  }
  
  nrows <- dim(input)[1]
  ncols <- dim(input)[2]
  
  

  #Define training array. Assign it 10000 columns at first and then you will cut it down at the end.
  trainingarray <- data.frame()
  trainingarray <- mat.or.vec(nrows-hrsback,1000)
  if(single == 1)
  {
    trainingarray <- mat.or.vec((hrsback+1),1000)
  }
  nrowst <- dim(trainingarray)[1]
    
  if(option == 0)  #Option = 0 Use actuals from N records back up until last record before current time. 
  {
    
    start1 <- hrsback+1
    end1 <- nrows-hrsforward-hrsback

    for (i in start1:end1)
    {
      ctr <- 2  #Starts at 2 because that is the column for actuals
      idx <- i-hrsback
      end2 <- hrsback+hrsforward
      for (j in 1:end2)
      {
        
        if(j <= hrsback)
        {
          trainingarray[i, ctr:(ctr+ncols-2)] <- round(as.numeric(input[idx+j-1,2:ncols]),3) #Add previous hour's value
          ctr = ctr+ncols-1 #ncols+1
        }
        else
        {
          trainingarray[i, ctr:(ctr+ncols-3)] <- round(as.numeric(input[(idx+j-1),3:ncols]),3)
          ctr = ctr+ncols-2
          
        }
      }
      
    }  
    
    ##RESIZE TRAINING ARRAY
    ctr=ctr-1
    trainingarray2 <- trainingarray[(hrsback+1):(nrowst-hrsforward),1:ctr] #remove first N blank rows
    end <- nrowst-hrsforward
    trainingarray2[,1] <- as.numeric((input[(hrsback+1):end,2]))
    rm(trainingarray)
    rm()
    gc()

  }
  
  if(option == 1) #Option = 1 so use actuals from n hrs back up until previous record to current time.
    {
    
    start1 <- hrsback+1
    end1 <- nrows-hrsforward-hrsback
    for (i in start1:end1)
    {
      ctr <- 2  #Starts at 2 because that is the column for actuals
      idx <- i-hrsback
      end2 <- hrsback+hrsforward
      for (j in 1:end2)
      {
        
        if(j == 1)
        {
          trainingarray[i, ctr:ncols] <- round(as.numeric(input[idx,2:ncols]),3) #Add previous hour's value
          ctr = ncols+1
        }
        else
        {
          trainingarray[i, ctr:(ctr+ncols-3)] <- round(as.numeric(input[(idx+j-1),3:ncols]),3)
          ctr = ctr+ncols-2
          
        }
      }
      
    }  
    
    ##RESIZE TRAINING ARRAY
    ctr=ctr-1
    trainingarray2 <- trainingarray[(hrsback+1):(nrowst-hrsforward),1:ctr] #remove first N blank rows
    end <- nrowst-hrsforward
    trainingarray2[,1] <- as.numeric(input[(hrsback+1):end,2])
    rm(trainingarray)
    rm()
    gc()
    
    
  }

  if(option == 2) #Option = 2 so only use actual value from N records (hrsback) in the past. Only met data are used from all other times.
  {
    start1 <- hrsback+1
    end1 <- nrows-hrsforward-hrsback
    for (i in start1:end1)
    {
      ctr <- 2  #Starts at 2 because that is the column for actuals
      idx <- i-hrsback
      end2 <- hrsback+hrsforward
      for (j in 1:end2)
      {
        
        if(j < hrsback)
        {
          trainingarray[i, ctr:(ctr+ncols-2)] <- round(as.numeric(input[idx+j-1,2:ncols]),3) #Add previous hour's value
          ctr = ctr+ncols-1 #ncols+1
        }
        else
        {
          trainingarray[i, ctr:(ctr+ncols-3)] <- round(as.numeric(input[(idx+j-1),3:ncols]),3)
          ctr = ctr+ncols-2
          
        }
      }
      
    }  
    
    ##RESIZE TRAINING ARRAY
    ctr=ctr-1
    trainingarray2 <- trainingarray[(hrsback+1):(nrowst-hrsforward),1:ctr] #remove first N blank rows
    end <- nrowst-hrsforward
    trainingarray2[,1] <- as.numeric(input[(hrsback+1):end,2])
    rm(trainingarray)
    rm()
    gc()
  }

  if(option == 3) #Option = 3 so only use actual value from N records (hrsback) in the past. Only met data are used from all other times.
  {
    start1 <- hrsback+1
    end1 <- nrows-hrsforward-hrsback
    if (single == 1) {
      end1 <- hrsback+1
    }
    for (i in start1:end1)
    {
      ctr <- 2  #Starts at 2 because that is the column for actuals
      idx <- i-hrsback
      end2 <- hrsback+hrsforward
      for (j in 1:end2)
      {
        
        if(j < hrsback)
        {
          trainingarray[i, ctr:(ctr+ncols-2)] <- round(as.numeric(input[idx+j-1,2:ncols]),3) #Add previous hour's value
          ctr = ctr+ncols-1 #ncols+1
        }
        else
        {
          trainingarray[i, ctr:(ctr+ncols-3)] <- round(as.numeric(input[(idx+j-1),3:ncols]),3)
          ctr = ctr+ncols-2
          
        }
      }
      
    }  
    
    ##RESIZE TRAINING ARRAY
    ctr=ctr-1
    if(single ==0)
    {
      trainingarray2 <- trainingarray[(hrsback+1):(nrowst-hrsforward),1:ctr] #remove first N blank rows
      end <- nrowst-hrsforward
      trainingarray2[,1] <- as.numeric(input[(hrsback+hrsforward):(end+hrsforward-1),2])
    }
    
    
    if(single == 1)
    {
      trainingarray2 <- mat.or.vec(1,ctr)
      trainingarray2[,1:ctr] <- trainingarray[(hrsback+1),1:ctr]
      trainingarray2[1,1] <- -999
      trainingarray2 <- as.data.frame(trainingarray2)
    }
    
    
    rm(trainingarray)
    rm()
    gc()
  }

  if(option == 4)  #Option = 4 Use actuals from N records back up until last record before current time. 
  {
    
    start1 <- hrsback+1
    end1 <- nrows-hrsforward-hrsback
    if (single == 1) {
      end1 <- hrsback+1
    }

    for (i in start1:end1)
    {
      ctr <- 2  #Starts at 2 because that is the column for actuals
      idx <- i-hrsback
      end2 <- hrsback+hrsforward
      for (j in 1:end2)
      {
        
        if(j <= hrsback)
        {
          trainingarray[i, ctr:(ctr+ncols-2)] <- round(as.numeric(input[idx+j-1,2:ncols]),3) #Add previous hour's value
          ctr = ctr+ncols-1 #ncols+1
        }
        else
        {
          trainingarray[i, ctr:(ctr+ncols-3)] <- round(as.numeric(input[(idx+j-1),3:ncols]),3)
          ctr = ctr+ncols-2
          
        }
      }
      
    }  
    
    ##RESIZE TRAINING ARRAY
    ctr=ctr-1
    
    
    if(single ==0)
    {
      trainingarray2 <- trainingarray[(hrsback+1):(nrowst-hrsforward),1:ctr] #remove first N blank rows
      end <- nrowst-hrsforward
      trainingarray2[,1] <- as.numeric(input[(hrsback+hrsforward):(end+hrsforward-1),2])
    }

    
    if(single == 1)
    {
      trainingarray2 <- mat.or.vec(1,ctr)
      trainingarray2[,1:ctr] <- trainingarray[(hrsback+1),1:ctr]
      trainingarray2[1,1] <- -999
      trainingarray2 <- as.data.frame(trainingarray2)
    }


    rm(trainingarray)
    rm()
    gc()
    
  }
  

return(trainingarray2)
  
}

