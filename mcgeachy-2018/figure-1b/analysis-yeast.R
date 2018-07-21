# 2017 07 09
# Growth chamber is filled with YEP (no dextrose), aeration and stirring
# Yeast added from saturated ~36 hour culture of BY4741 in YEPD from 30 ºC shaker
# 
library("RColorBrewer")

system("grep ^M screenlog-yeast.txt | head -n1 > measure.txt")
system("grep ^M screenlog-yeast.txt | grep -v neph >> measure.txt")
x <- read.delim("measure.txt", header=TRUE)
x$neph <- x$neph / x$gain
summary(x)

histbreaks=seq(0,4,0.02)

x0 <- x[x$time.s > 300 & x$time.s < 400,]
h0 <- hist(x0$neph,breaks=histbreaks, plot=FALSE)

x1 <- x[x$time.s > 700 & x$time.s < 800,]
h1 <- hist(x1$neph,breaks=histbreaks, plot=FALSE)

x2 <- x[x$time.s > 1100 & x$time.s < 1200,]
h2 <- hist(x2$neph,breaks=histbreaks, plot=FALSE)
# After addition and mixing, OD 0.124 after 2.0 ml

x3 <- x[x$time.s > 1500 & x$time.s < 1600,]
h3 <- hist(x3$neph,breaks=histbreaks, plot=FALSE)

x4 <- x[x$time.s > 1850 & x$time.s < 1950,]
h4 <- hist(x4$neph,breaks=histbreaks, plot=FALSE)
# After addition and mixing, OD 0.255 after 4.0 ml

x6 <- x[x$time.s > 2250 & x$time.s < 2350,]
h6 <- hist(x6$neph,breaks=histbreaks, plot=FALSE)

x8 <- x[x$time.s > 2650 & x$time.s < 2750,]
h8 <- hist(x8$neph,breaks=histbreaks, plot=FALSE)
# After addition and mixing, OD 0.412 (1:2 = 0.226) after 8.0 ml

x10 <- x[x$time.s > 3050 & x$time.s < 3150,]
h10 <- hist(x10$neph,breaks=histbreaks, plot=FALSE)

x12 <- x[x$time.s > 3450 & x$time.s < 3550,]
h12 <- hist(x12$neph,breaks=histbreaks, plot=FALSE)
# After adding and mixing, OD 103 (1:2 = 0.324, 1:4 = 35) ???

x14 <- x[x$time.s > 3850 & x$time.s < 3950,]
h14 <- hist(x14$neph,breaks=histbreaks, plot=FALSE)

nephYeast <- data.frame(yeastml=c(0, 1, 2, 3, 4, 6, 8, 10, 12, 14),
                        neph=c(median(x0$neph),
                               median(x1$neph),
                               median(x2$neph),
                               median(x3$neph),
                               median(x4$neph),
                               median(x6$neph),
                               median(x8$neph),
                               median(x10$neph),
                               median(x12$neph),
                               median(x14$neph)),
                        l05=c(quantile(x0$neph, 0.05),
                             quantile(x1$neph, 0.05),
                             quantile(x2$neph, 0.05),
                             quantile(x3$neph, 0.05),
                             quantile(x4$neph, 0.05),
                             quantile(x6$neph, 0.05),
                             quantile(x8$neph, 0.05),
                             quantile(x10$neph, 0.05),
                             quantile(x12$neph, 0.05),
                             quantile(x14$neph, 0.05)),
                        u95=c(quantile(x0$neph, 0.95),
                             quantile(x1$neph, 0.95),
                             quantile(x2$neph, 0.95),
                             quantile(x3$neph, 0.95),
                             quantile(x4$neph, 0.95),
                             quantile(x6$neph, 0.95),
                             quantile(x8$neph, 0.95),
                             quantile(x10$neph, 0.95),
                             quantile(x12$neph, 0.95),
                             quantile(x14$neph, 0.95)))
                        
# OD measurements from growth chamber
odyeast <- data.frame(yeastml=c(0,2,4,8), ods=c(0, 0.124, 0.255, 0.226*2))
odfit <- lm(odyeast$ods ~ odyeast$yeastml)

pdf("SFig2a-yeast-OD-calibration.pdf", height=4, width=4, useDingbats=FALSE)
plot(odyeast$yeastml, odyeast$ods, pch=20, cex=2, xlim=c(0,10), ylim=c(0,0.6), 
     xlab="Yeast added [ml]", ylab="OD600")
xs <- seq(0,10,0.1)
lines(x=xs, y=odfit$coefficients[[1]] + xs * odfit$coefficients[[2]], 
      lwd=2, col="#9ebcda")
legend(x="topleft", bty="n",
       legend=sprintf("%0.3f + %0.3f x", 
                      odfit$coefficients[[1]], odfit$coefficients[[2]]), 
       lwd=2, col="#9ebcda")
dev.off()

nephYeast$odest <- odfit$coefficients[[1]] + nephYeast$yeastml * odfit$coefficients[[2]]
nephfit <- lm(nephYeast$neph ~ nephYeast$odest)

pdf("Fig1b-yeast-neph.pdf", height=4, width=4, useDingbats=FALSE)
xs <- seq(0,0.8,0.1)
plot(nephYeast$odest, nephYeast$neph, pch=20,
     xlim=c(0,1), ylim=c(0,4),
     xlab="Yeast density (A600)", ylab="Nephelometer")
arrows(nephYeast$odest, nephYeast$l05,
       nephYeast$odest, nephYeast$u95,
       length=0.05, angle=90, code=3)
lines(x=xs, y=nephfit$coefficients[[1]] + xs * nephfit$coefficients[[2]], 
      lwd=3, col="#99d8c9")
legend(x="topleft", bty="n",
       legend=sprintf("%0.2f + %0.2f x\nR2 = %0.2f", 
                      nephfit$coefficients[[1]], nephfit$coefficients[[2]],
                      cor(nephYeast$neph, nephYeast$odest)**2), 
       lwd=4, col="#99d8c9")
dev.off()

write.csv(nephYeast, "Fig1b-yeast-neph.csv")

pdf("SFig2b-yeast-neph-hist.pdf", height=6, width=6, useDingbats=FALSE)
cols <- brewer.pal(n=9, name="Paired")

plot(h0$mids, h0$density, type="l", col="black", ylim=c(0,18),
     xlab="Nephelometer", ylab="Frequency", yaxt='n')
lines(h1$mids, h1$density, col=cols[[1]])
lines(h2$mids, h2$density, col=cols[[2]])
lines(h3$mids, h3$density, col=cols[[3]])
lines(h4$mids, h4$density, col=cols[[4]])
lines(h6$mids, h6$density, col=cols[[5]])
lines(h8$mids, h8$density, col=cols[[6]])
lines(h10$mids, h10$density, col=cols[[7]])
lines(h12$mids, h12$density, col=cols[[8]])
lines(h14$mids, h14$density, col=cols[[9]])
text(x=nephYeast$neph, y=16, 
     labels=sprintf("%0.2f", nephYeast$odest), 
     col=c("black", cols), srt=90)
text(x=0, y=16, labels=c("OD600"))
dev.off()
