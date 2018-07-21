# 2017 07 09
filltime <- 750

res <- system("grep ^T screenlog-tstat.txt > tstat.txt")
tlog <- read.delim("tstat.txt", header=TRUE)
tlog$neph <- tlog$neph / tlog$gain
tlog$pumptime.s <- tlog$pumptime.s - min(tlog$pumptime.s)

tlog$time.min <- round(tlog$time.s/60)

tmin <- aggregate(x=tlog[,c("neph", "pumptime.s")],
                  by=list(time.min = tlog$time.min), median, simplify=TRUE)

expoStart <- min(tmin[tmin$neph > 0.5, "time.min"])
expoEnd <- min(tmin[tmin$neph > 2.0, "time.min"])
expo <- tmin[tmin$time.min >= expoStart & tmin$time.min <= expoEnd,]
expofit <- nls(neph ~ yb + y0*exp((time.min - expoStart) * k),
               data=expo,
               start=c(yb=0.2, y0=0.5, k=1/120))

pdf("Fig1e-neph.pdf", width=6, height=3, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$neph, 
     pch=20, cex=0.25,
     xlab="Time [hrs]", ylab="Neph.", 
     ylim=c(0,3), yaxp=c(0,2,1))
xs <- seq(expoStart, expoEnd)
lines(xs / 60, predict(expofit, xs - expoStart), lwd=5, col="#de2d2680")
dev.off()

# Extract the last 2 hours 
final <- tmin[tmin$time.min >= (max(tmin$time.min) - 120),]
dilufit <- lm(pumptime.s ~ time.min, data=final)

pdf("Fig1e-pump.pdf", width=6, height=3, useDingbats = FALSE)
plot(tmin$time.min / 60, tmin$pumptime.s / filltime, 
     type="s", lwd=2,
     xlab="Time [hrs]", ylab="Media [vols]", ylim=c(0,4), yaxp=c(0,4,2))
## fit starts where (dilufit_1 + time.min * dilufit_2) / filltime = 0
##   => - dilufit_1 = time.min * dilufit_2
##   => - dilufit_1 / dilufit_2 = time.min
fitstart <- - coef(dilufit)[[1]] / coef(dilufit)[[2]]
fitxs <- seq(fitstart, max(tmin$time.min))
lines(fitxs / 60,
      (coef(dilufit)[[1]] + fitxs * coef(dilufit)[[2]]) / filltime,
      lwd=5, col="#de2d2680")
rect(xleft=23.5, xright=24, ybottom=2.2, ytop=2.5, 
     col="#00000030", border="#000000b0", lwd=0.5)
legend(x="topleft", lwd=2, col="#de2d26", bty="n",
       legend=sprintf("%0.2f vols / hr", 60 * coef(dilufit)[[2]] / filltime))
dev.off()

inset <- tlog[tlog$time.s >= 23.45*3600 & tlog$time.s < 24.05*3600,]
pdf("Fig1e-pump-inset.pdf", width=3, height=3, useDingbats=FALSE)
plot(inset$time.s / 3600, inset$pumptime.s / filltime, 
     type="s", lwd=2,
     xlab=NA, ylab=NA, ylim=c(2.2,2.5), xaxp=c(23.5,24,1), yaxp=c(2.4,2.4,1))
lines(inset$time.s / 3600,
      (dilufit$coefficients[[1]] + (0.5 + inset$time.s / 60) * dilufit$coefficients[[2]]) / filltime,
      lwd=3, col="#de2d2680")
dev.off()





