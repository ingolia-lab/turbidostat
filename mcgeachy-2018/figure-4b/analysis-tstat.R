filltime.s <- 850

foatime.s <- 95000
chxtime.s <- 231200
samples <- c(t15am.s = 62000,
                t15pm.s = 91500,
                t16pm.s = 169000,
                t17am.s = 230200,
                t17pm.s = 264500,
                t18am.s = 325500)

res <- system("grep ^T screenlog-tstat.txt > tstat.txt")
tlog <- read.delim("tstat.txt", header=TRUE)
tlog$neph <- tlog$neph / tlog$gain
tlog$pumptime.s <- tlog$pumptime.s - min(tlog$pumptime.s)

tlog$time.min <- round(tlog$time.s/60)

tmin <- aggregate(x=tlog[,c("neph", "pumptime.s")],
                  by=list(time.min = tlog$time.min), median, simplify=TRUE)

pdf("Fig4b-neph.pdf", width=6, height=2.5, useDingbats=FALSE)
plot(tmin$time.min/60, tmin$neph,  
     pch=20, cex=0.25,
     xlab="Time [hrs]", ylab="Density",
     xlim=c(0,93), xaxp=c(0,84,7),
     ylim=c(0,4), yaxp=c(0,4,2))
abline(v=foatime.s/3600, col="#d95f0280", lwd=2)
abline(v=chxtime.s/3600, col="#e7298a80", lwd=2)
dev.off()

# Fit pump rate to LOESS
range <- 120
pumpfit <- loess(pumptime.s ~ time.min, data=tmin,
                 span = range / nrow(tmin), degree=1)
tmin$pumpfit.s <- predict(pumpfit)
tmin[2:(nrow(tmin)-1), "pumpduty"] <- 
  diff(tmin$pumpfit.s,lag=2)/(diff(tmin$time.min,lag=2)*60)

lastmin <- max(tmin$time.min)

pdf("Fig4b-grow.pdf", width=6, height=3.5, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$pumpduty*3600/filltime.s,
     type="l", lwd=2,
     xlab="Time (hrs)", ylab="Dilution (1/hr)",
     xlim=c(0,93), xaxp=c(0,84,7),
     ylim=c(0,0.6), yaxp=c(0,0.6,2))
points(samples/3600, rep.int(0, length(samples)), pch=17)
#abline(v=samples/3600, col="#1b9e77c0", lwd=2)
abline(v=foatime.s/3600, col="#d95f0280", lwd=2)
abline(v=chxtime.s/3600, col="#e7298a80", lwd=2)
dev.off()
