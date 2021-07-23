# UNITE geocoding pipeline 

> A user-friendly pipeline developed for offline geocoding and mapping California addresses to census tracts, built using the DeGAUSS geocoder v 3.0, R Shiny, and geospatial packages.

[![Docker Build Status](https://img.shields.io/docker/automated/pcollender/unite_geocoding_pipeline)](https://hub.docker.com/repository/docker/pcollender/unite_geocoding_pipeline/tags)

## Requirements

- Docker desktop (must be running in background before calling the pipeline! Install instructions for [Windows](https://docs.docker.com/docker-for-windows/install/) & [Mac](https://docs.docker.com/docker-for-mac/install/))
- Web browser (used to navigate to port on local machine, internet connection is not required)
- Input files should contain an address column with full addresses present in the format described in the [DeGAUSS documentation](https://degauss.org/geocoder/)
	- **\<Street Address\> \<City\> \<Zip Code\> \<State\>** 
		- Separated by single spaces
	- Do not include apartment numbers or second address lines
	- Zip codes should be 5 digits, without "plus four" digits
	- Use Arabic numerals instead of written numbers
	
### Description

- Developed as a GUI to use the [DeGAUSS v 3.0](https://github.com/degauss-org/geocoder) offline geocoder to map California addresses to Census Tracts
- Operates using an R Shiny backend to render GUI, call geocoding scripts, and map addresses to 2000, 2010, and 2020 census tracts
- Clickable scripts to run the pipeline on Windows or Mac are available in the directory [exec files/](https://github.com/pcollender/UNITE_geocoding_pipeline/tree/main/exec%20files
- While the app is designed to be fairly intuitive to use, a detailed walkthrough of the pipeline is present in [ReadMe.pdf](https://github.com/pcollender/UNITE_geocoding_pipeline/blob/main/ReadMe.pdf)
- All executable files, the detailed ReadMe.pdf, and an example dataset are packaged in [UNITE_Geocoding_Pipeline.zip](https://github.com/pcollender/UNITE_geocoding_pipeline/blob/main/UNITE_Geocoding_Pipeline.zip)
