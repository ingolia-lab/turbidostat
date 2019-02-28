# 2017 12 29
filltime <- 900

res <- system("grep ^GTC screenlog-gtc.txt > gtc.txt")
tlog <- read.delim("gtc.txt", header=TRUE)
tlog$neph <- tlog$neph / tlog$gain
tlog$pump1.s <- tlog$pump1.s - min(tlog$pump1.s)
tlog$pump2.s <- tlog$pump2.s - min(tlog$pump2.s)
tlog$pumptime.s <- tlog$pump1.s + tlog$pump2.s

last <- max(tlog$time.s)

tlog$time.min <- round(tlog$time.s/60)

tmin <- aggregate(x=tlog[,c("neph", "pumptime.s", "targPpm", "currPpm")],
                  by=list(time.min = tlog$time.min), median, simplify=TRUE)

# Fit pump rate to LOESS -- slow & memory-intensive
range <- 120
pumpfit <- loess(pumptime.s ~ time.min, data=tmin,
                 span = range / nrow(tmin), degree=1)
tmin$pumpfit.s <- predict(pumpfit)
tmin[2:(nrow(tmin)-1), "pumpduty"] <- 
  diff(tmin$pumpfit.s,lag=2)/(diff(tmin$time.min,lag=2)*60)

write.csv(tmin, "Fig2a.csv", row.names=FALSE)

pdf("Fig2a-media.pdf", width=6, height=3, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$targPpm * 4 / 1e6,
    type="l", lwd=2, col="#1b9e77",
    xlab="Time (hr)", ylab="[NH4] (mM)")
lines(tmin$time.min / 60, tmin$currPpm * 4 / 1e6,
      lwd=2, col="#d95f02")
abline(v=seq(8*2,last/3600,8), col="#7570b380")
rect(xleft=82, xright=94, ybottom=0.4, ytop=0.6, 
     col="#00000030", border="#000000b0", lwd=0.5)
legend(x="topright", bg="white",
       col=c("#1b9e77","#d95f02"),
       lwd=2,
       legend=c("Target", "Actual"),
       text.col=c("#1b9e77","#d95f02"))
dev.off()

pdf("Fig2a-diln.pdf", width=6, height=3.5, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$pumpduty * 3600 / filltime,
     type="l", lwd=2, col="#1b9e77",
     xlab="Time (hr)", ylab="Growth (1/hr)",
     ylim=c(0,0.35), yaxp=c(0,0.3,3))
abline(v=seq(8*2,last/3600,8), col="#7570b380")
rect(xleft=82, xright=94, ybottom=0.1, ytop=0.3, 
     col="#00000030", border="#000000b0", lwd=0.5)
axis(side=4, at=log(2)/seq(2,8), labels=seq(2,8))
axis(side=4, at=log(2)/seq(2.5,7.5), labels=NA, tcl=-0.25)
dev.off()

zoom <- tmin[tmin$time.min >= 82*60 & tmin$time.min <= 94*60,]
write.csv(zoom, "Fig2b.csv", row.names=FALSE)

pdf("Fig2b-media.pdf", width=6, height=3, useDingbats=FALSE)
plot(zoom$time.min / 60, zoom$targPpm * 4 / 1e6,
     type="l", lwd=2, col="#1b9e77",
     xlab="Time (hr)", ylab="[NH4] (mM)", ylim=c(0.4,0.6), yaxp=c(0.4,0.6,2))
lines(zoom$time.min / 60, zoom$currPpm * 4 / 1e6,
      lwd=2, col="#d95f02")
abline(v=88, col="#7570b380")
dev.off()

pdf("Fig2b-diln.pdf", width=6, height=3.5, useDingbats=FALSE)
plot(zoom$time.min / 60, zoom$pumpduty * 3600 / filltime,
     type="l", lwd=2, col="#1b9e77",
     xlab="Time (hr)", ylab="Growth (1/hr)", 
     ylim=c(0.,0.35),yaxp=c(0,0.3,3))
abline(v=88, col="#7570b380")
axis(side=4, at=log(2)/seq(2,8), labels=seq(2,8))
axis(side=4, at=log(2)/seq(2.5,7.5), labels=NA, tcl=-0.25)
dev.off()

targs <- data.frame(targPpm = sort(unique(tlog$targPpm)))
targs$last <- sapply(targs$targPpm, 
                     function(targ) { max(tlog[tlog$targPpm == targ,"time.s"])})
fitDiln <- function(endtime, starttime = endtime - 2*3600) {
  tlogFit <- tlog[tlog$time.s >= starttime & tlog$time.s <= endtime,]
  fit <- lm(pumptime.s ~ time.s, data=tlogFit)
  fit$coefficients[[2]]
}
targs$diln <- sapply(targs$last, fitDiln)
targs$growHr <- targs$diln * 3600 / filltime
targs$targNH4 <- targs$targPpm * 4 / 1e6

# 15 pg dry weight / cell * 2.5e6 cells / ml = 0.0375 g / l dry weight
# Elemental composition 6.5% - 8% N => ≥2.44 mg / l elemental N
# 2.44 mg / l elemental N = 135 µM NH4

write.csv(targs, "Fig2c.csv", row.names=FALSE)

chemofit <- lm(growHr ~ targNH4, data=targs[1:4,])

pdf("Fig2c-response.pdf", width=4, height=4, useDingbats=FALSE)
plot(targs$targNH4, targs$growHr, 
     pch=20, cex=1.5, col="#7570b3",
     xlab="[NH4] (mM)", ylab="Growth (1/hr)", yaxp=c(0,0.3,3), ylim=c(0,0.35))
#lines(targs$targNH4, targs$monodFit,
#      lwd=2, col="#d95f0280")
axis(side=4, at=log(2)/seq(2,8), labels=seq(2,8))
axis(side=4, at=log(2)/seq(2.5,7.5), labels=NA, tcl=-0.25)
dev.off()

pdf("Fig2c-response-inset.pdf", width=3, height=3, useDingbats=FALSE)
plot(targs$targNH4, targs$growHr, 
     pch=20, cex=1.5, col="#7570b3",
     xlab="[NH4] (mM)", ylab="Growth (1/hr)", 
     xlim=c(0,0.9), yaxp=c(0,0.3,1), ylim=c(0,0.35))
#abline(v=0.135, lwd=2, col="#1b9e7780")
abline(a=coef(chemofit)[[1]], b=coef(chemofit)[[2]], lwd=2, col="#1b9e7780")
axis(side=4, at=log(2)/seq(2,8), labels=seq(2,8))
axis(side=4, at=log(2)/seq(2.5,7.5), labels=NA, tcl=-0.25)
dev.off()

