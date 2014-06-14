### Creat a zoo object with all the predictions for each day.

getPointRuns <- function(point, vars = 'swflx',
                         start = Sys.Date() - 1,
                         end = Sys.Date(),
                         service = 'meteogalicia'){

    start <- as.Date(start)
    end <- as.Date(end)
    stopifnot(end > start)
    stopifnot(end <= Sys.Date())
    seqDays <- seq(start, end, by='day')
        
    ## Number of days comprised in the forecast
    ## Adjusted for Meteogalicia
    da <- 4

    rng <- range(seqDays)
    fd <- rng[1]
    ld <- rng[2]

    seqInit <- seq(fd - (da - 1), fd - 1, by='day')
    seqDaysExt <- c(seqInit, seqDays)
  
    ## The possibilities for service can be expanded in the future
    runs <- switch(service, meteogalicia = '00')
  
    rd <- expand.grid(Run=runs, Day=seqDaysExt)
    N <- nrow(rd)
    
    zl <- lapply(seq_len(N), FUN=function(i){
        run <- as.character(rd[i, 'Run'])
        day <- as.Date(rd[i, 'Day'])

        vals <- try(getPoint(point, vars = vars, day = day,
                             run = run, service = service),
                    silent = FALSE)
    })
    
    isOK <- sapply(zl, function(z) class(z) != 'try-error')
    
    zl <- zl[isOK]
  
    ## Remove bad run/day from rd
    rdFiltered <- rd[isOK,]
  
    ## Joining elements of zl into a zoo object limited by fd and ld
    z <- do.call(cbind, zl)
    names(z) <- paste(rdFiltered$Day, rdFiltered$Run, sep='_')
    z <- window(z, start=as.POSIXct(fd)+3600, end=as.POSIXct(ld+1))
  
    ## Day index of time series
    dayIndex <- as.Date(as.POSIXct(index(z))-3600)
    ## Forecast run day
    dayForecast <- as.Date(format(names(z)))
    ## Matrix of time differences (in days) between dayIndex and dayForecast
    dayDif <- outer(dayIndex, dayForecast, '-')
    ## Combinations of day differences and runs (0='00', 1='12')
    dayDifRun <- expand.grid(run=runs, dif=(da-1):0)
    ## Matrix with run indication for each cell
    tagRun <- do.call(rbind, rep(list(as.character(rdFiltered[,1])), nrow(z)))
    ## Extract cells corresponding to each time distance and run
    zzl <- lapply(seq_len(nrow(dayDifRun)), FUN=function(i){
        day <- dayDifRun[i, 'dif']
        run <- dayDifRun[i, 'run']
        idx <- (dayDif == day) & (tagRun == run)
        tt <- index(z)[apply(idx, 1, any)]
        zoo(coredata(z)[idx], tt)
    })
    zz <- do.call(cbind, zzl)
    names(zz) <- with(dayDifRun, paste0('D', -dif, '_', run))
    attr(index(zz), 'tzone') <- 'UTC'
    return(zz)
}