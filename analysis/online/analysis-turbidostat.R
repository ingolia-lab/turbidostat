library("RColorBrewer")

tstatdir <- Sys.getenv("TSTATDIR")
wwwpath <- Sys.getenv("WWWPATH")

prefix <- "^T"
filltime <- 800 # seconds of pumping
voltime <- 0.252 * 60 * 60  # ml / hour of pumping

totalPumpTime <- 0

## Grep out one turbidostat header followed by all turbidostat data lines
## Direct into a temporary file and return the temporary filename
extractTlog <- function(tstat) {
    screenfile <- sprintf("%s/%s/screenlog.0", tstatdir, tstat)
    tlogfile <- tempfile(pattern="tlog", tmpdir=".", fileext=".txt")

    system(sprintf("grep \'%s\' \'%s\' | grep time.s | head -n1 > %s",
                   prefix, screenfile, tlogfile))
    system(sprintf("grep \'%s\' \'%s\' | grep -v time.s >> %s",
                   prefix, screenfile, tlogfile))

    tlogfile
}

readTlog <- function(tlogfile) {
    tlog <- read.delim(tlogfile)
    tlog$pumptime.s <- tlog$pumptime.s - min(tlog$pumptime.s)
    tlog
}    

## Extract and read turbidostat data
getTlog <- function(tstat) {
    tlogfile <- extractTlog(tstat)
    tlog <- readTlog(tlogfile)
    file.remove(tlogfile)
    tlog
}

plotNeph <- function(tlog) {
    highest <- max(tlog$neph/tlog$gain, tlog$target/tlog$gain)
    plot(tlog$time.s / 3600, tlog$neph / tlog$gain,
         pch=20, cex=0.25, col="#1b9e77",
         ylim=c(0,1.1*highest),
         xlab="Time [hrs]", ylab="Cell Dens [A.U.]")
    abline(h=tlog$target/tlog$gain, col=rgb(231,41,138,154,maxColorValue=255))
}    

plotGrowth <- function(tlog) {
    tlogRecent <- tlog[tlog$time.s > (max(tlog$time.s) - 60*60),]
    tlogFit <- lm(tlogRecent$pumptime.s ~ tlogRecent$time.s)
    kgrow <- tlogFit$coefficients[[2]] / filltime
    tdbl <- log(2) / (kgrow * 60*60)
    vtime <- voltime * tlogFit$coefficients[[2]]

    pumptime <- max(tlog$pumptime.s)

    totalPumpTime <<- totalPumpTime + pumptime + filltime
    
    print(sprintf("[[1]] = %0.3f, [[2]] = %0.3f\n", coef(tlogFit)[[1]], coef(tlogFit)[[2]]))
    
    plot(tlog$time.s / (60*60), tlog$pumptime.s / filltime,
         type="l", lwd=2, 
         xlab="Time [hrs]", ylab="Pump [vol]")
    lines(tlog$time.s / (60*60),
          (coef(tlogFit)[[1]] + tlog$time.s * coef(tlogFit)[[2]]) / filltime,
          col=rgb(231,41,138,154,maxColorValue=255))
    legend(x="topleft", bty="n",
           legend=sprintf("duty = %0.3f\nk = %0.2e s^-1\nTdbl = %0.2f hrs\n%0.0f ml/hr",
                          coef(tlogFit)[[2]], kgrow, tdbl, vtime),
           lwd=2, col=rgb(231,41,138,154,maxColorValue=255))
    axis(side=4, at=c(0, pumptime / filltime),
         labels=sprintf("%0.0f ml",
                        c(filltime * (voltime / 3600),
                          (filltime + pumptime) * (voltime / 3600))))
}

handleTstat <- function(tstat) {
    if (!file.exists(sprintf("%s/%s/screenlog.0", tstatdir, tstat))) {
        return("")
    }

    tlog <- getTlog(tstat)

    nephPng <- sprintf("%s/neph-%s.png", wwwpath, tstat)
    pumpPng <- sprintf("%s/pump-%s.png", wwwpath, tstat)

    latest = max(tlog$time.s)

    png(filename=nephPng, width=800, height=400, res=300, pointsize=3)
    plotNeph(tlog)
    title(main=sprintf("%s Turbidity", tstat),
          sub=sprintf("Time = %.0f seconds = %0.2f hours", latest, latest/3600.0))
    dev.off()

    png(filename=pumpPng, width=800, height=600, res=300, pointsize=3)
    plotGrowth(tlog)
    title(main=sprintf("%s Pumping", tstat),
          sub=sprintf("Time = %.0f seconds = %0.2f hours", latest, latest/3600.0))          
    dev.off()

    sprintf("<P> <IMG SRC=\"neph-%s.png\"> </P>\n<P> <IMG SRC=\"pump-%s.png\"> </P>",
            tstat, tstat)
}

tstats <- list.dirs(tstatdir, full.names=FALSE, recursive=FALSE)

htmlBody <- c()

for (tstat in tstats) {
    htmlFrag <- handleTstat(tstat)
    htmlBody <- c(htmlBody, htmlFrag)
}

htmlPrefix <-"<?xml version=\"1.0\"?>
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">
<HTML>
<HEAD><TITLE>Turbidostat</TITLE><meta http-equiv=\"refresh\" content=\"60\"></HEAD>
<BODY>"
htmlPumping <- sprintf("<P>Total pump time (including fill) %0.0f seconds, %0.0f ml</P>",
                       totalPumpTime, totalPumpTime * voltime / 3600)
htmlSuffix <- "</BODY></HTML>"

conn <- file(sprintf("%s/tstat.html", wwwpath))
writeLines(c(htmlPrefix, htmlPumping, htmlBody, htmlSuffix), conn)
close(conn)
