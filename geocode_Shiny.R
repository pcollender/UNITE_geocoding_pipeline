#!/usr/bin/Rscript

source('mappp_Shiny.R')

sink(file = 'tstream1', type = 'output')

cat('<h1/> Welcome to DeGAUSS </h1/> 
You are using the geocoding container, version 3.0. 
This container returns geocoded coordinates based on input address strings. 
For more information about the geocoder container, visit <a href="https://degauss.org/geocoder/"/>https://degauss.org/geocoder/</a/>
For DeGAUSS troubleshooting, visit <a href="https://degauss.org/"/>https://degauss.org/</a/>
To help us improve DeGAUSS, please take our user survey at <a href="https://redcap.link/jf4lil0n"/>https://redcap.link/jf4lil0n</a/> \n\n')

dht::qlibrary(argparser)
dht::qlibrary(dplyr)
dht::qlibrary(digest)
dht::qlibrary(knitr)

# library(digest)
p <- argparser::arg_parser('offline geocoding, returns the input file with geocodes appended')
p <- argparser::add_argument(p,'file_name',help='name of input csv file')
p <- argparser::add_argument(p, '--score_threshold', default = 0.5, help = 'optional; defaults to 0.5')

args <- argparser::parse_args(p)

d <- readr::read_csv(args$file_name)

## must contain character column called address
if (! 'address' %in% names(d)) stop('no column called address found in the input file', call. = FALSE)

## clean up addresses / classify 'bad' addresses

cat('<i/>removing non-alphanumeric characters...
    removing excess whitespace...</i> \n')

d$address <- dht::clean_address(d$address)

cat('<i/>flagging PO boxes...</i> \n')

d$po_box <- dht::address_is_po_box(d$address)

cat('<i/>flagging known Cincinnati foster & institutional addresses...</i> \n')

d$cincy_inst_foster_addr <- dht::address_is_institutional(d$address)

cat('<i/>flagging non-address text and missing addresses...</i> \n')

d$non_address_text <- dht::address_is_nonaddress(d$address)

## exclude 'bad' addresses from geocoding
d_excluded_for_address <- dplyr::filter(d, cincy_inst_foster_addr | po_box | non_address_text)
d_for_geocoding <- dplyr::filter(d, !cincy_inst_foster_addr & !po_box & !non_address_text)

## geocode
sink()

file.create('pb1_active')

geocode <- function(addr_string) {
  stopifnot(class(addr_string)=='character')
  out <- system2('ruby',
                 args = c('/root/geocoder/geocode.rb', shQuote(addr_string)),
                 stderr=FALSE,stdout=TRUE) %>%
    jsonlite::fromJSON()
  # if geocoder returns nothing then system will return empty list
  if (length(out) == 0) out <- tibble(street = NA, zip = NA, city = NA, state = NA,
                                      lat = NA, lon = NA, score = NA, precision = NA)
  out
}

#dealing with weird bug where pb1_stats gets erased when cache is present
pb1.params = as.character(c(0,100,Inf,0))
t0_ = proc.time()['elapsed']
N_ = length(d_for_geocoding$address)

d_for_geocoding$geocodes <- mappp_Shiny(d_for_geocoding$address,
                                        geocode,
                                        parallel = TRUE,
                                        cache = TRUE,
                                        #cache.name = 'geocoding_cache',
                                        cache.name = 'tmp/geocoding_cache',
                                        file = 'pb1_stats')

#file.remove('pb1_active')



lengths = sapply(d_for_geocoding$geocodes, length)

if(any(lengths < 8 )){
  
  while(any(lengths < 8 )){
    #file.create('pb2_active')  
    d_for_geocoding$geocodes[lengths<8] <- mappp_Shiny(d_for_geocoding$address[lengths < 8],
                                                       geocode,
                                                       parallel = TRUE,
                                                       cache = TRUE,
                                                       #cache.name = 'geocoding_cache')#,
                                                       cache.name = 'tmp/geocoding_cache')
    
    lengths = sapply(d_for_geocoding$geocodes, length)
  }
  #file.remove('pb2_active')
}

file.create('active2')

## extract results, if a tie then take first returned result
d_for_geocoding <- d_for_geocoding %>%
  dplyr::mutate(row_index = 1:nrow(d_for_geocoding),
                geocodes = purrr::map(geocodes, ~ .x %>% purrr::map(unlist) %>% as_tibble())) %>%
  tidyr::unnest(cols = c(geocodes)) %>%
  dplyr::group_by(row_index) %>%
  dplyr::slice(1) %>%
  dplyr::ungroup() %>%
  dplyr::rename(matched_street = street,
                matched_city = city,
                matched_state = state,
                matched_zip = zip) %>%
  dplyr::select(-fips_county, -prenum, -number, -row_index) %>%
  dplyr::mutate(precision = factor(precision,
                                   levels = c('range', 'street', 'intersection', 'zip', 'city'),
                                   ordered = TRUE)) %>%
  dplyr::arrange(desc(precision), score)

## clean up 'bad' address columns / filter to precise geocodes
#cat('<b/>geocoding complete; now filtering to precise geocodes...</b>\n')
out_file <- dplyr::bind_rows(d_excluded_for_address, d_for_geocoding) %>%
  dplyr::mutate(geocode_result = dplyr::case_when(
    po_box ~ "po_box",
    cincy_inst_foster_addr ~ "cincy_inst_foster_addr",
    non_address_text ~ "non_address_text",
    !precision %in% c('street', 'range') | score < args$score_threshold ~ "imprecise_geocode",
    TRUE ~ "geocoded"),
    lat = ifelse(geocode_result == 'imprecise_geocode', NA, lat),
    lon = ifelse(geocode_result == 'imprecise_geocode', NA, lon)
  ) %>%
  select(-po_box, -cincy_inst_foster_addr, -non_address_text) # note, just "PO" not "PO BOX" is not flagged as "po_box"

## summarize geocoding results
geocode_summary <- out_file %>%
  mutate(geocode_result = factor(geocode_result,
                                 levels = c('po_box', 'cincy_inst_foster_addr', 'non_address_text',
                                            'imprecise_geocode', 'geocoded'),
                                 ordered = TRUE)) %>%
  group_by(geocode_result) %>%
  tally() %>%
  mutate(`%` = round(n/sum(n)*100,1),
         `n (%)` = glue::glue('{n} ({`%`})'))

## print geocoding results summary to console
n_geocoded <- geocode_summary$n[geocode_summary$geocode_result == 'geocoded']
n_total <- sum(geocode_summary$n)
pct_geocoded <- geocode_summary$`%`[geocode_summary$geocode_result == 'geocoded']

file.create('summarytable')
sink('summarytable')

knitr::kable(geocode_summary %>% dplyr::select(geocode_result, `n (%)`),
             format = 'html')

out.file.name <- paste0(gsub('.csv', '', args$file_name, fixed=TRUE),'_geocoded_v3.0.csv')
readr::write_csv(out_file, out.file.name)

sink()

file.create('active3')
