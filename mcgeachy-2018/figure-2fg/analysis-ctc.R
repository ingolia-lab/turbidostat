library("RColorBrewer")
filltime <- 900

res <- system("grep ^CTC screenlog-ctc.txt > ctc.txt")
tlog <- read.delim("ctc.txt", header=TRUE)
tlog$neph <- tlog$neph / tlog$gain
tlog$pump1.s <- tlog$pump1.s - min(tlog$pump1.s)
tlog$pump2.s <- tlog$pump2.s - min(tlog$pump2.s)
tlog$pumptime.s <- tlog$pump1.s + tlog$pump2.s

tlog$time.min <- round(tlog$time.s/60)

tmin <- aggregate(x=tlog[,c("neph", "pumptime.s", "targPpm", "currPpm")],
                  by=list(time.min = tlog$time.min), median, simplify=TRUE)
rm(tlog)

# Fit pump rate to LOESS
range <- 120
pumpfit <- loess(pumptime.s ~ time.min, data=tmin,
                 span = range / nrow(tmin), degree=1)
tmin$pumpfit.s <- predict(pumpfit)
tmin[2:(nrow(tmin)-1), "pumpduty"] <- 
  diff(tmin$pumpfit.s,lag=2)/(diff(tmin$time.min,lag=2)*60)

last <- max(tmin$time.min)

write.csv(tmin, "Fig2f.csv", row.names=FALSE)

pointmins <- seq(48*60, 63*60, 60)
tminpoint <- tmin[tmin$time.min %in% pointmins,]
tminpoint$color <- rainbow(n=nrow(tminpoint), end=0.75)

pdf("Fig2f-media.pdf", width=6, height=3, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$targPpm * 4 / 1e6,
    type="l", lwd=2, col="#1b9e77",
    ylim=c(0,2.5), yaxp=c(0,2,2),
    xlab="Time (hrs)", ylab="[NH4] (mM)")
lines(tmin$time.min / 60, tmin$currPpm * 4 / 1e6,
      lwd=2, col="#d95f02")
abline(v=seq(4,last/60,16), col="#7570b380")
abline(v=seq(16,last/60,16), col="#7570b380")
#rect(xleft=82, xright=94, ybottom=0.4, ytop=0.6, 
#     col="#00000030", border="#000000b0", lwd=0.5)
dev.off()

pdf("Fig2f-diln.pdf", width=6, height=3.5, useDingbats=FALSE)
plot(tmin$time.min / 60, tmin$pumpduty * 3600 / filltime,
     type="l", lwd=2, col="#1b9e77",
     ylim=c(0,0.35), yaxp=c(0,0.3,3),
     xlab="Time (hrs)", ylab="Growth (1/hr)")
abline(v=seq(4,last/60,16), col="#7570b380")
abline(v=seq(16,last/60,16), col="#7570b380")
points(tminpoint$time.min / 60, rep.int(0.33, times=nrow(tminpoint)),
       type="p", pch=21, cex=0.67, col="black", bg=tminpoint$color)
dev.off()

pdf("Fig2g-phase.pdf", width=3.5, height=3.5, useDingbats=FALSE)
plot(tmin[tmin$time.min>16*60,]$currPpm * 4 / 1e6, 
     tmin[tmin$time.min>16*60,]$pumpduty * 3600 / filltime,
     type="l", lwd=2,
     xlab="[NH4] (mM)", ylab="Growth (1/hr)", 
     xlim=c(0,2.5), xaxp=c(0,2,2),
     ylim=c(0,0.35), yaxp=c(0,0.3,3))
points(tminpoint$currPpm * 4 / 1e6, tminpoint$pumpduty * 3600 / filltime,
       type="p", pch=21, cex=1, col="black", bg=tminpoint$color)
dev.off()

