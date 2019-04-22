runbase <- "TestRuns"
wwwpath <- "TestWWW"

library("RColorBrewer")

prefix <- "^T"
filltime <- 800 # seconds of pumping
voltime <- 0.252 * 60 * 60  # ml / hour of pumping

totalPumpTime <- 0

## Grep out one turbidostat header followed by all turbidostat data lines
## Direct into a temporary file and return the temporary filename
extractTlog <- function(screenfile) {
  print(screenfile)
  tlogfile <- tempfile(pattern="tlog", tmpdir=dirname(screenfile), fileext=".txt")
  
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
getTlog <- function(screenfile) {
    tlogfile <- extractTlog(screenfile)
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

plotTstat <- function(names) {
    tlog <- getTlog(names$screenlog)

    latest = max(tlog$time.s)

    pngtmp <- tempfile(pattern="temp-plot", tmpdir=dirname(names$nephPng), fileext="png")
    png(filename=pngtmp, width=800, height=400, res=300, pointsize=3)
    plotNeph(tlog)
    title(main=sprintf("%s Turbidity", names$display),
          sub=sprintf("Time = %.0f seconds = %0.2f hours", latest, latest/3600.0))
    dev.off()
    file.rename(from=pngtmp, to=names$nephPng)

    pngtmp <- tempfile(pattern="temp-plot", tmpdir=dirname(names$nephPng), fileext="png")
    png(filename=pngtmp, width=800, height=600, res=300, pointsize=3)
    plotGrowth(tlog)
    title(main=sprintf("%s Pumping", names$display),
          sub=sprintf("Time = %.0f seconds = %0.2f hours", latest, latest/3600.0))          
    dev.off()
    file.rename(from=pngtmp, to=names$pumpPng)
    
    pngtmp <- tempfile(pattern="temp-plot", tmpdir=dirname(names$nephPng), fileext="png")
    png(filename=pngtmp, width=800, height=600, res=300, pointsize=3)
    plotGrowth(tlog[tlog$time.s > (max(tlog$time.s) - 60*60*4),])
    title(main=sprintf("%s Pumping Recent", names$display),
          sub=sprintf("Time = %.0f seconds = %0.2f hours", latest, latest/3600.0))          
    dev.off()
    file.rename(from=pngtmp, to=names$pumpRecentPng)
}

tstatNames <- function(screenlog) {
  tstatbase <- gsub("/", "_", sub(sprintf("^%s/", runbase), "", dirname(screenlog))) 
  list(screenlog = screenlog,
       analyzed = sub("screenlog.0$", "analyzed.txt", screenlog),
       updateTime = file.mtime(screenlog),
       base = tstatbase,
       display = gsub("/", " ", sub(sprintf("^%s/", runbase), "", dirname(screenlog))),
       html = sprintf("%s/%s_index.html", wwwpath, tstatbase),
       nephPng = sprintf("%s/%s_neph.png", wwwpath, tstatbase),
       pumpPng = sprintf("%s/%s_pump.png", wwwpath, tstatbase),
       pumpRecentPng = sprintf("%s/%s_pump-recent.png", wwwpath, tstatbase))
}

htmlPrefix <- function(title) {
  sprintf("<?xml version=\"1.0\"?>
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">
<html xmlns=\"http://www.w3.org/1999/xhtml\">
<HTML>
<HEAD><TITLE>%s</TITLE><meta http-equiv=\"refresh\" content=\"60\"></HEAD>
<BODY>", title)
}

htmlSuffix <- function() { "</BODY></HTML>" }

writeTstatPage <- function(names) {
  plots <-  sprintf("<P> <IMG SRC=\"%s\"> </P>\n<P> <IMG SRC=\"%s\"> </P>\n<P> <IMG SRC=\"%s\"> </P>",
                    basename(names$nephPng),
                    basename(names$pumpPng),
                    basename(names$pumpRecentPng))
  page <- sprintf("%s\n%s\n%s\n",
                  htmlPrefix(sprintf("Turbidostat %s", names$display)), plots, htmlSuffix())

  conn <- file(names$html)
  writeLines(c(htmlPrefix(names$display), plots, htmlSuffix()), conn)
  close(conn)
}

analyzeTstat <- function(names) {
  write.table(x=data.frame(), file=names$analyzed, col.names=FALSE)
  plotTstat(names)
  writeTstatPage(names)
}
  
screenlogAnalysis <- function(screenlog) {
  names <- tstatNames(screenlog)
  if (!file_test("-nt", names$analyzed, names$screenlog)) {
    try(analyzeTstat(names))
  }
  names
}

while (TRUE) {
  screenlogs <- list.files(runbase, pattern="screenlog.0", full.names=TRUE, recursive=TRUE)
  
  runs <- lapply(screenlogs, screenlogAnalysis)
  
  runOrder <- order(sapply(runs, function(r) { r$updateTime }), decreasing=TRUE)
  runs <- runs[runOrder]
  
  conn <- file(sprintf("%s/index.html", wwwpath))
  writeLines(c(htmlPrefix("Turbidostat Runs"),
               "<UL>",
               sapply(runs, function(r) { sprintf("<LI><A href=\"%s\">%s</A>", basename(r$html), r$display) }),
               "</UL>",
               htmlSuffix()),
             conn)
  close(conn)

  Sys.sleep(1)
}

## ZZZ
## Collect all "recent" plots" on one page
