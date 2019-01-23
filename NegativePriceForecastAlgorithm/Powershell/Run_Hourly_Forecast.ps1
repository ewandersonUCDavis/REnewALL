& "C:\Program Files\R\R-3.4.0\bin\x64\Rscript.exe" find_threshold.R
sleep-start 1

& "C:\Program Files\R\R-3.4.0\bin\x64\Rscript.exe" generate_price_forecast.R
sleep-start 1

& "C:\Program Files\R\R-3.4.0\bin\x64\Rscript.exe" find_threshold_w_threshold.R
sleep-start 1

& "C:\Program Files\R\R-3.4.0\bin\x64\Rscript.exe" generate_price_forecast_w_threshold.R
sleep-start 1




