# 2017 12 29
filltime <- 900

res <- system("grep ^GTD screenlog-gtd.txt > gtd.txt")
tlog <- read.delim("gtd.txt", header=TRUE)
tlog <- tlog[tlog$time.s <= 50 * 3600,]

tlog$neph <- tlog$neph / tlog$gain
tlog$pump1.s <- tlog$pump1.s - min(tlog$pump1.s)
tlog$pump2.s <- tlog$pump2.s - min(tlog$pump2.s)
tlog$pumptime.s <- tlog$pump1.s + tlog$pump2.s

tlog$time.min <- round(tlog$time.s/60)

tmin <- aggregate(x=tlog[,c("neph", "pumptime.s", "target")],
                  by=list(time.min = tlog$time.min), median, simplify=TRUE)
rm(tlog)

# Fit pump rate to LOESS
# Lower bandwidth because of "drop-out" at density changes
range <- 120
pumpfit <- loess(pumptime.s ~ time.min, data=tmin,
                 span = range / nrow(tmin), degree=1)
tmin$pumpfit.s <- predict(pumpfit)
tmin[2:(nrow(tmin)-1), "pumpduty"] <- 
  diff(tmin$pumpfit.s,lag=2)/(diff(tmin$time.min,lag=2)*60)

write.csv(tmin, "Fig2d.csv", row.names=FALSE)

pdf("Fig2d-density.pdf", width=6, height=3, useDingbats = FALSE)
plot(tmin$time.min / 60, tmin$neph,
    pch=20, cex=0.25,
    xlab="Time (hrs)", ylab="Neph",
    ylim=c(0,2.5), yaxp=c(0,2,2))
abline(v=seq(10,40,10), col="#7570b380")
dev.off()

pdf("Fig2d-diln.pdf", width=6, height=3.5, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$pumpduty * 3600 / filltime,
     type="l", lwd=2, col="#1b9e77",
     xlab="Time (hrs)", ylab="Growth (1/hr)", ylim=c(0,0.35), yaxp=c(0,0.3,3))
abline(v=seq(10,40,10), col="#7570b380")
dev.off()

targs <- data.frame(target = sort(unique(tmin$target)))
targs$last <- sapply(targs$target, 
                     function(targ) { max(tmin[tmin$target == targ,"time.min"])})
fitDiln <- function(endtime, starttime = endtime - 2*60) {
  tminFit <- tmin[tmin$time.min >= starttime & tmin$time.min <= endtime,]
  fit <- lm(pumptime.s ~ time.min, data=tminFit)
  fit$coefficients[[2]]
}
targs$diln <- sapply(targs$last, fitDiln)
targs$growHr <- targs$diln * 60 / filltime
targs$targNeph <- targs$target / 5

write.csv(targs, "Fig2e.csv", row.names=FALSE)

pdf("Fig2e-response.pdf", width=3.5, height=3.5, useDingbats=FALSE)
plot(targs$targNeph * 2.5, targs$growHr, 
     pch=20, cex=1.5, col="#7570b3",
     xlab="Density (M cells / ml)", ylab="Growth (1/hr)", 
     xaxp=c(0,5,2), xlim=c(0,6.5),
     yaxp=c(0,0.3,3), ylim=c(0,0.35))
dev.off()

fit <- lm(growHr ~ targNeph, data=targs[2:5,])
# growHr = 0.3166 hr-1 - 0.1034 hr-1 neph-1 * targNeph
# AND
# growHr = -0.1089 hr-1 + 0.9066 hr-1 [NH4]-1 * targNH4
# => 0.3166 - 0.1034 * targNeph = -0.1089 + 0.9066 * targNH4
# => 0.4255 - 0.1034 * targNeph = 0.9066 * targNH4
# => 0.4693 - 0.1141 * targNeph = targNH4
# => 0.1141 [NH4] / neph / (2.5 Mcells / neph)
#    = 0.04564 [NH4] / Mcells i.e. 46 µM / Mcells
