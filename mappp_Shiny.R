mappp_Shiny <- function(.x, .f,
                  parallel = FALSE,
                  cache = FALSE, cache.name = 'cache',
                  error.value = NA,
                  quiet = TRUE,
                  num.cores = NULL,
                  file = NULL) {
  
  .f <- purrr::as_mapper(.f)
  
  if (cache) {
    fc <- memoise::cache_filesystem(cache.name)
    .f <- memoise::memoise(.f, cache = fc)
  }
  
  if (!is.null(error.value)) {
    .f <- purrr::possibly(.f,
                          otherwise = error.value,
                          quiet = quiet)
  }
  
  if (!is.vector(.x) || is.object(.x)) .x <- as.list(.x)
  
  # set number of cores
  if (parallel) {
    if (is.null(num.cores)) num.cores <- parallelly::availableCores()
    if (is.na(num.cores)) num.cores <- 1
    if (identical(.Platform$OS.type, "windows")) {
      message("detected a windows platform; disabling parallel processing")
      num.cores <- 1
    }
  } else {
    num.cores <- 1
  }
  
  if (num.cores == 1) out <- lapply_pb_Shiny(.x, .f, file)
  
  if (num.cores > 1 && !identical(.Platform$GUI, "RStudio")) {
    out <- mclapply_pb_Shiny(.x, .f, num.cores, file)
  }
  
  return(out)
}

lapply_pb_Shiny <- function(X, FUN, file = NULL) {
  n <- length(X)
  tmp <- vector('list', n)
  
  
  if(!is.null(file)){
    pb.params = readLines(file)
    pb.params[2] = n
  } 
  
  .time0 <- proc.time()['elapsed']
  
  for (i in seq_len(n)) {
    tmp[[i]] <- FUN(X[[i]])
    
    .timenow <- proc.time()['elapsed']
    .span <- .timenow - .time0
    .perIter <- .span/i
    .ETA <- (n - i) * .perIter
    
    if(!is.null(file)){
      pb.params[3]  = formatTime(.ETA)
      pb.params[1]  = i
      pb.params[4]  = formatTime(.span)
      writeLines(pb.params, file)
    } 
  }
  return(tmp)
}

parallel.mcexit <-
  utils::getFromNamespace("mcexit", "parallel")

parallel.mcfork <-
  utils::getFromNamespace("mcfork", "parallel")

mclapply_pb_Shiny <- function(X, FUN, mc.cores, file = NULL){
  n <- length(X)
  f <- fifo(tempfile(), open = "w+b", blocking = T)
  #on.exit(close(f))
  p <- parallel.mcfork()
  
  if(!is.null(file)){
    pb.params = readLines(file)
    pb.params[2] = n
  }
  
  .time0 <- proc.time()['elapsed']
  
  progress <- 0
  if (inherits(p, "masterProcess")) {
    while (progress < n) {
      readBin(f, "double")
      progress <- progress + 1
      
      .timenow <- proc.time()['elapsed']
      .span <- .timenow - .time0
      .perIter <- .span/progress
      .ETA <- (n - progress) * .perIter
      
      if(!is.null(file)){
        pb.params[3]  = formatTime(.ETA)
        pb.params[1]  = progress
        pb.params[4]  = formatTime(.span)
        writeLines(pb.params, file)
      } 
    }
    parallel.mcexit()
  }
  wrapFUN <- function(i) {
    out <- FUN(i)
    writeBin(1, f)
    return(out)
  }
  res = parallel::mclapply(X, wrapFUN, mc.cores = mc.cores)
  close(f)
  res
}

formatTime <- function(seconds) {
  if (seconds == Inf || is.nan(seconds) || is.na(seconds))
    return("NA")
  
  seconds <- round(seconds)
  
  sXmin <- 60
  sXhr <- sXmin * 60
  sXday <- sXhr * 24
  sXweek <- sXday * 7
  sXmonth <- sXweek * 4.22
  sXyear <- sXmonth * 12
  
  years <- floor(seconds / sXyear)
  seconds <- seconds - years * sXyear
  
  months <- floor(seconds / sXmonth)
  seconds <- seconds - months * sXmonth
  
  weeks <- floor(seconds / sXweek)
  seconds <- seconds - weeks * sXweek
  
  days <- floor(seconds / sXday)
  seconds <- seconds - days * sXday
  
  hours <- floor(seconds / sXhr)
  seconds <- seconds - hours * sXhr
  
  minutes <- floor(seconds / sXmin)
  seconds <- seconds - minutes * sXmin
  
  ETA <- c(years, months, days, hours, minutes, seconds)
  
  # Add labels for years, months, days
  labels <- c("year", "years", "month", "months", "day", "days")
  
  # Kevin - Always show minutes
  startst <- which(ETA > 0)[1]
  if (is.na(startst) | startst == 6)
    startst <- 5
  
  # Kevin - Split year;month;day and HH:MM:SS
  if (startst <= 3) {
    # Kevin - Handle plurals
    ymt <- labels[startst:3 * 2 - as.integer(ETA[startst:3] == 1)]
    fmtstr <- paste(paste("%01d", ymt, collapse = " "),
                    paste(rep("%02d", length(ETA) - 3), collapse = ":"))
  } else {
    fmtstr <- rep("%02d", length(ETA))[startst:length(ETA)]
    fmtstr <- paste(fmtstr, collapse = ":")
  }
  
  return(do.call(sprintf, as.list(c(
    as.list(fmtstr), ETA[startst:length(ETA)]
  ))))
}
