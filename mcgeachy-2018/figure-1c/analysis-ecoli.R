# 2017 07 09
# Growth chamber is filled with LB, aeration and stirring
# E coli added from saturated ~36 hour culture of DH5α in LB from 37 ºC shaker 
library("RColorBrewer")

system("grep ^M screenlog-ecoli.txt | head -n1 > measure.txt")
system("grep ^M screenlog-ecoli.txt | grep -v neph >> measure.txt")
x <- read.delim("measure.txt", header=TRUE)
x$neph <- x$neph / x$gain
summary(x)

histbreaks=seq(0,4,0.025)

x0 <- x[x$time.s > 300 & x$time.s < 400,]
h0 <- hist(x0$neph,breaks=histbreaks, plot=FALSE)

x2 <- x[x$time.s > 700 & x$time.s < 800,]
h2 <- hist(x2$neph,breaks=histbreaks, plot=FALSE)

x4 <- x[x$time.s > 1000 & x$time.s < 1100,]
h4 <- hist(x4$neph,breaks=histbreaks, plot=FALSE)
# OD after mixing 0.065

x8 <- x[x$time.s > 1250 & x$time.s < 1350,]
h8 <- hist(x8$neph,breaks=histbreaks, plot=FALSE)

x12 <- x[x$time.s > 1650 & x$time.s < 1750,]
h12 <- hist(x12$neph,breaks=histbreaks, plot=FALSE)
# After adding and mixing, OD600 = 0.210

x16 <- x[x$time.s > 1950 & x$time.s < 2050,]
h16 <- hist(x16$neph,breaks=histbreaks, plot=FALSE)

x20 <- x[x$time.s > 2200 & x$time.s < 2300,]
h20 <- hist(x20$neph,breaks=histbreaks, plot=FALSE)
# After adding and mixing, OD600 of 1:2 is 0.180

x23 <- x[x$time.s > 2500 & x$time.s < 2600,]
h23 <- hist(x23$neph,breaks=histbreaks, plot=FALSE)

nephEcoli <- data.frame(ecoliml=c(0, 2, 4, 8, 12, 16, 20, 23),
                        neph=c(median(x0$neph),
                               median(x2$neph),
                               median(x4$neph),
                               median(x8$neph),
                               median(x12$neph),
                               median(x16$neph),
                               median(x20$neph),
                               median(x23$neph)),
                        l05=c(quantile(x0$neph, 0.05),
                              quantile(x2$neph, 0.05),
                              quantile(x4$neph, 0.05),
                              quantile(x8$neph, 0.05),
                              quantile(x12$neph, 0.05),
                              quantile(x16$neph, 0.05),
                              quantile(x20$neph, 0.05),
                              quantile(x23$neph, 0.05)),
                        u95=c(quantile(x0$neph, 0.95),
                              quantile(x2$neph, 0.95),
                              quantile(x4$neph, 0.95),
                              quantile(x8$neph, 0.95),
                              quantile(x12$neph, 0.95),
                              quantile(x16$neph, 0.95),
                              quantile(x20$neph, 0.95),
                              quantile(x23$neph, 0.95)))

# OD measurements from growth chamber
odecoli <- data.frame(ecoliml=c(0,4,12,20), ods=c(0, 0.065, 0.210, 0.180*2))
odfit <- lm(odecoli$ods ~ odecoli$ecoliml)

pdf("SFig2c-ecoli-OD-calibration.pdf", height=4, width=4, useDingbats=FALSE)
plot(odecoli$ecoliml, odecoli$ods, pch=20, cex=2, 
     xlim=c(0,25), ylim=c(0,0.5), yaxp=c(0,0.5,2),
     xlab="E. coli added [ml]", ylab="OD600")
xs <- seq(0,23,0.1)
lines(x=xs, y=odfit$coefficients[[1]] + xs * odfit$coefficients[[2]], 
      lwd=2, col="#9ebcda")
legend(x="topleft", bty="n",
       legend=sprintf("%0.3f + %0.3f x", 
                      odfit$coefficients[[1]], odfit$coefficients[[2]]), 
       lwd=2, col="#9ebcda")
dev.off()


nephEcoli$odest <- odfit$coefficients[[1]] + nephEcoli$ecoliml * odfit$coefficients[[2]]
nephfit <- lm(nephEcoli$neph ~ nephEcoli$odest)

pdf("Fig1c-ecoli-neph.pdf", height=4, width=4, useDingbats=FALSE)
xs <- seq(0,0.45,0.05)
plot(nephEcoli$odest, nephEcoli$neph, pch=20,
     xlim=c(0,0.5), ylim=c(0,4),
     xlab="E. coli density (A600)", ylab="Nephelometer")
arrows(nephEcoli$odest, nephEcoli$l05,
       nephEcoli$odest, nephEcoli$u95,
       length=0.05, angle=90, code=3)
lines(x=xs, y=nephfit$coefficients[[1]] + xs * nephfit$coefficients[[2]], 
      lwd=3, col="#99d8c9")
legend(x="topleft", 
       legend=sprintf("%0.2f + %0.2f x\nR2 = %0.2f", 
                      nephfit$coefficients[[1]], nephfit$coefficients[[2]],
                      cor(nephEcoli$neph, nephEcoli$odest)**2), 
       lwd=4, col="#99d8c9")
dev.off()

write.csv(nephEcoli, "Fig1c-ecoli-neph.csv")

pdf("SFig2d-ecoli-neph-hist.pdf", height=6, width=6, useDingbats=FALSE)
cols <- brewer.pal(n=9, name="Paired")

plot(h0$mids, h0$density, type="l", col="black", ylim=c(0,17),
     xlab="Nephelometer", ylab="Frequency", yaxt='n')
lines(h2$mids, h2$density, col=cols[[1]])
lines(h4$mids, h4$density, col=cols[[2]])
lines(h8$mids, h8$density, col=cols[[3]])
lines(h12$mids, h12$density, col=cols[[4]])
lines(h16$mids, h16$density, col=cols[[5]])
lines(h20$mids, h20$density, col=cols[[6]])
lines(h23$mids, h23$density, col=cols[[7]])

text(x=nephEcoli$neph, y=14, 
     labels=sprintf("%0.2f", nephEcoli$odest), 
     col=c("black", cols), srt=90)
text(x=0, y=14, labels=c("OD600"))
dev.off()
