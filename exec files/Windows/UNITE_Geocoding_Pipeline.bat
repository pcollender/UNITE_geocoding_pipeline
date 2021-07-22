::Probably done during install: Set up and set target folder
set GEOCODE_PIPELINE_DIR "%USERPROFILE%\Documents\UNITE_geocoding_pipeline"

if not exist "%GEOCODE_PIPELINE_DIR%" mkdir "%GEOCODE_PIPELINE_DIR%"

:: Run container

docker run --rm -p 3838:3838  -dv "%GEOCODE_PIPELINE_DIR%:/root/geocoder/tmp" --name=geocode_pipeline pcollender/unite_geocoding_pipeline 

explorer "http:\\localhost:3838"

docker wait geocode_pipeline

explorer "%GEOCODE_PIPELINE_DIR%"

::drop cached memory
::wsl echo 1 > sudo tee /proc/sys/vm/drop_caches