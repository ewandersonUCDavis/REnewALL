PRO GRAB_DA_FCAST_LOAD


  
  
CD,'Data\CAISO_Load_Forecast_GOOD\temp'
  today=SYSTIME(/JULIAN)-(2./24)
  tomorrow=today+3
  CALDAT,tomorrow,M_tom,D_tom,Y_tom,H_tom
  CALDAT,today,M_tod,D_tod,Y_tod,H_tod
  cmd = 'wget -O test.zip "http://oasis.caiso.com/oasisapi/SingleZip?queryname=SLD_FCST&startdatetime='+STRING(Y_tod,FORMAT='(i4.4)')+STRING(M_tod,FORMAT='(i2.2)')+STRING(D_tod,FORMAT='(i2.2)')+'T'+STRING(H_tod,FORMAT='(i2.2)')+':00-0000&enddatetime='+STRING(Y_tom,FORMAT='(i4.4)')+STRING(M_tom,FORMAT='(i2.2)')+STRING(D_tom,FORMAT='(i2.2)')+'T'+STRING(H_tom,FORMAT='(i2.2)')+':00-0000&market_run_id=DAM&TAC_AREA_NAME=CA ISO-TAC&resultformat=6&version=1" '

  SPAWN,cmd

  path_7z = 'C:\Program Files\7-Zip\7z.exe'

  cmd = STRING(34B)+path_7z+STRING(34B)+' x test.zip
  spawn,cmd
 
  file_temp=FILE_SEARCH('201*SLD_FCST*.csv')
  file=FILE_BASENAME(file_temp)
  cmd='cp '+STRING(file)+' ..'
  spawn,cmd
  CD,'..\archive'
  cmd='rm DA_CAISO_LOAD_PREV.csv'
  spawn,cmd
  CD,'..'
  cmd='cp DA_CAISO_LOAD_CURR.csv archive\'
  spawn,cmd
  cmd='mv '+string(file)+' DA_CAISO_LOAD_CURR.csv'
  spawn,cmd
  
  CD,'Data\CAISO_Load_Forecast_GOOD\'
  cmd='rm 201*SLD_FCST*.csv'
  spawn,cmd
  CD,'Data\CAISO_Load_Forecast_GOOD\temp'
  cmd='rm *.csv'
  spawn, cmd

 
  END
  