PRO GRAB_SP15_ACTUALS

  ;; ACTUALS SP15 ;;

  CD,'Data\SP15_Actuals\temp'

  today=SYSTIME(/JULIAN)-(2./24)
  yesterday=today-1
  CALDAT,yesterday,M_yes,D_yes,Y_yes,H_yes
  CALDAT,today,M_tod,D_tod,Y_tod,H_tod
  cmd = 'wget -O test.zip "http://oasis.caiso.com/oasisapi/SingleZip?queryname=SLD_REN_FCST&startdatetime='+STRING(Y_yes,FORMAT='(i4.4)')+STRING(M_yes,FORMAT='(i2.2)')+STRING(D_yes,FORMAT='(i2.2)')+'T07:00-0000&enddatetime='+STRING(Y_tod,FORMAT='(i4.4)')+STRING(M_tod,FORMAT='(i2.2)')+STRING(D_tod,FORMAT='(i2.2)')+'T07:00-0000&market_run_id=ACTUAL&&TRADING_HUB=SP15&RENEWABLE_TYPE=Wind&resultformat=6&version=1" '

  SPAWN,cmd

  path_7z = 'C:\Program Files\7-Zip\7z.exe'

  cmd = STRING(34B)+path_7z+STRING(34B)+' x test.zip
  spawn,cmd

  file=FILE_SEARCH('201*SLD_REN_FCST*.csv')
  ;stop
  FILE_COPY,'..\SP15_WIND_ACTUALS.csv','2016_SP15_WIND_ACTUALS.csv'
  cmd='gawk "FNR==1 && NR!=1{next;}{print}" *.csv > ..\SP15_WIND_ACTUALS.csv'
  SPAWN,cmd

  cmd='rm *.csv'
  SPAWN,cmd
  
  cmd = 'wget -O test.zip "http://oasis.caiso.com/oasisapi/SingleZip?queryname=SLD_REN_FCST&startdatetime='+STRING(Y_yes,FORMAT='(i4.4)')+STRING(M_yes,FORMAT='(i2.2)')+STRING(D_yes,FORMAT='(i2.2)')+'T07:00-0000&enddatetime='+STRING(Y_tod,FORMAT='(i4.4)')+STRING(M_tod,FORMAT='(i2.2)')+STRING(D_tod,FORMAT='(i2.2)')+'T07:00-0000&market_run_id=ACTUAL&&TRADING_HUB=SP15&RENEWABLE_TYPE=Solar&resultformat=6&version=1" '

  SPAWN,cmd

  path_7z = 'C:\Program Files\7-Zip\7z.exe'

  cmd = STRING(34B)+path_7z+STRING(34B)+' x test.zip
  spawn,cmd

  file=FILE_SEARCH('201*SLD_REN_FCST*.csv')
  ;stop
  FILE_COPY,'..\SP15_SOLAR_ACTUALS.csv','2016_SP15_SOLAR_ACTUALS.csv'
  cmd='gawk "FNR==1 && NR!=1{next;}{print}" *.csv > ..\SP15_SOLAR_ACTUALS.csv'
  SPAWN,cmd

  cmd='rm *.csv'
  SPAWN,cmd


END