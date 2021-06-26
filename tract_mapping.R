library(rgdal)
library(rgeos) #used for matching coordinates to shapefile
library(sp)

#args = commandArgs(trailingOnly = T)

dat = read.csv('data/temp_geocoded_v3.0.csv', stringsAsFactors = F)

#dat$rowid = 1:nrow(dat)
#cat(nrow(dat))
#neighborhoods = readOGR('../Shapefiles/Neighborhoods/ZillowNeighborhoods-CA.shp',
#                        stringsAsFactors = F)

tracts_00 = readOGR('../Shapefiles/Census_tracts/tl_2010_06_tract00.shp', stringsAsFactors = F)
tracts_10 = readOGR('../Shapefiles/Census_tracts/tl_2010_06_tract10.shp', stringsAsFactors = F)
tracts_20 = readOGR('../Shapefiles/Census_tracts/tl_2020_06_tract.shp', stringsAsFactors = F)

latlong = na.omit(dat[,c('rowid','lat','lon')])

coordinates(latlong) = ~lon+lat
latlong@proj4string <- tracts_20@proj4string #assign same coordinate reference system

#plot(neighborhoods,border = 'black')
#points(latlong, col = 'red', pch = 16,cex = 0.2)
#axis(1)
#axis(2)

#points_in_neighborhood = over(latlong, neighborhoods)

#latlong$neighborhood = points_in_neighborhood$NAME

points_in_tract00 = over(latlong, tracts_00)
points_in_tract10 = over(latlong, tracts_10)
points_in_tract20 = over(latlong, tracts_20)

latlong$tract00 = points_in_tract00$NAME00
latlong$tract10 = points_in_tract10$NAME10
latlong$tract20 = points_in_tract20$NAME

dat = merge(dat,latlong@data,by = 'rowid',all = T)
#cat(nrow(dat))
dat = dat[order(dat$rowid),]
dat$rowid = NULL

fname = readRDS('data/fname.RDS')

og_dat = read.csv(paste0('data/',fname), stringsAsFactors = F)

dat$address = NULL

dat = cbind(og_dat,dat)
fname = gsub('.csv','',fname)
write.csv(dat, file = paste0(fname,'_geocoded.csv'),row.names = F)

#cleanup
unlink('data',recursive = T)
unlink('geocoding_cache', recursive = T)