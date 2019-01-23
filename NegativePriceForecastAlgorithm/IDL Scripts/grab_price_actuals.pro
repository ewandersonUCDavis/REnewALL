PRO GRAB_PRICE_ACTUALS

  node_name='NORTHWND_6_N002'

  CD,'Data\Nodal_Price_Actuals\temp'

  today=SYSTIME(/JULIAN)-(2./24)
  yesterday=today-1
  CALDAT,yesterday,M_yes,D_yes,Y_yes,H_yes
  CALDAT,today,M_tod,D_tod,Y_tod,H_tod
  cmd = 'wget -O test.zip "http://oasis.caiso.com/oasisapi/SingleZip?queryname=PRC_CURR_LMP&node=ALL&startdatetime='+STRING(Y_tod,FORMAT='(i4.4)')+STRING(M_tod,FORMAT='(i2.2)')+STRING(D_tod,FORMAT='(i2.2)')+'T'+STRING(H_tod,FORMAT='(i2.2)')+':00-0000&enddatetime='+STRING(Y_tod,FORMAT='(i4.4)')+STRING(M_tod,FORMAT='(i2.2)')+STRING(D_tod,FORMAT='(i2.2)')+'T'+STRING(H_tod,FORMAT='(i2.2)')+':00-0000&NODE='+STRING(node_name)+'&LMP_TYPE=LMP&resultformat=6&version=1'
  SPAWN,cmd

  path_7z = 'C:\Program Files\7-Zip\7z.exe'

  cmd = STRING(34B)+path_7z+STRING(34B)+' x test.zip
  spawn,cmd

  file=FILE_SEARCH('201*PRC*.csv')
  
  FILE_COPY,'..\NODAL_PRICE_ACTUALS.csv','2016_NODAL_PRICE_ACTUALS.csv'
  cmd='gawk "FNR==1 && NR!=1{next;}{print}" *.csv > ..\NODAL_PRICE_ACTUALS.csv'
  SPAWN,cmd

  cmd='rm *.csv'
  SPAWN,cmd



END