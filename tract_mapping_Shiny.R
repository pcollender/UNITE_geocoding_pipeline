library(rgdal)
library(rgeos) #used for matching coordinates to shapefile
library(sp)

sink('tstream2')

dat = read.csv('temp_geocoded_v3.0.csv', stringsAsFactors = F)

#dat$rowid = 1:nrow(dat)
#cat(nrow(dat))
#neighborhoods = readOGR('../Shapefiles/Neighborhoods/ZillowNeighborhoods-CA.shp',
#                        stringsAsFactors = F)

cat('\n <h1/> Mapping to census tracts </h1> \n')

cat('<i/> Loading census maps </i> \n')

tracts_00 = readOGR('Shapefiles/Census_tracts/tl_2010_06_tract00.shp', stringsAsFactors = F, verbose = F)
tracts_10 = readOGR('Shapefiles/Census_tracts/tl_2010_06_tract10.shp', stringsAsFactors = F, verbose = F)
tracts_20 = readOGR('Shapefiles/Census_tracts/tl_2020_06_tract.shp', stringsAsFactors = F, verbose = F)

latlong = na.omit(dat[,c('rowid','lat','lon')])

coordinates(latlong) = ~lon+lat
latlong@proj4string <- tracts_20@proj4string #assign same coordinate reference system

#plot(neighborhoods,border = 'black')
#points(latlong, col = 'red', pch = 16,cex = 0.2)
#axis(1)
#axis(2)

#points_in_neighborhood = over(latlong, neighborhoods)

#latlong$neighborhood = points_in_neighborhood$NAME

cat('<i/> Mapping geocodes to year 2000 CA census tracts </i> \n')
points_in_tract00 = over(latlong, tracts_00)

cat('<i/> Mapping geocodes to year 2010 CA census tracts </i> \n')
points_in_tract10 = over(latlong, tracts_10)

cat('<i/> Mapping geocodes to year 2020 CA census tracts </i> \n')
points_in_tract20 = over(latlong, tracts_20)

latlong$tract00 = points_in_tract00$NAME00
latlong$tract10 = points_in_tract10$NAME10
latlong$tract20 = points_in_tract20$NAME

dat = merge(dat,latlong@data,by = 'rowid',all = T)
#cat(nrow(dat))
dat = dat[order(dat$rowid),]

write.csv(dat, file = 'temp_geocoded_v3.0_mapped.csv',row.names = F)

sink()

file.create('process_done')