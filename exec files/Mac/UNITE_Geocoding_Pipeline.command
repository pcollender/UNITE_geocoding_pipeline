#!/bin/bash

#Create and store address of directory for output
export GEOCODE_PIPELINE_DIR="/Users/$USER/Documents/UNITE_geocoding_pipeline"

mkdir -p "$GEOCODE_PIPELINE_DIR"

docker run --rm -p 3838:3838  -dv "$GEOCODE_PIPELINE_DIR:/root/geocoder/tmp" --name=geocode_pipeline pcollender/unite_geocoding_pipeline 

open "http://localhost:3838"

docker wait geocode_pipeline

open "$GEOCODE_PIPELINE_DIR"

