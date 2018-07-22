options(stringsAsFactors=FALSE)
library("RColorBrewer")
library("corrplot")

minor_decade <- function(d) { seq(2*d, 9*d, d) }

datadir <- Sys.getenv("DATADIR")
countdir <- Sys.getenv("COUNTDIR")

cts <- read.csv(sprintf("%s/real-counts.txt", countdir), row.names=1)

rename <- data.frame(sample=c("CYH2_input_S20",
                              "CYH2_15_AM_S21",
                              "CYH2_15_PM_S22",
                              "CYH2_16_PM_S23",
                              "CYH2_17_AM_S24",
                              "CYH2_17_PM_S25",
                              "CYH2_18_final_S26"),
                     name=c("Input", "Transform1", "Transform2",
                            "Countersel1", "Countersel2",
                            "Chx1", "Chx2"),
                     name2=c("Input", "His #1 (A)", "His #2 (B)",
                             "5FOA #1 (C)", "5FOA #2 (D)",
                             "Chx #1 (E)", "Chx #2 (F)"))
colnames(cts) <- rename[match(colnames(cts), rename$sample), "name"]

cts2 <- cts
colnames(cts2) <- rename[match(colnames(cts2), rename$name), "name2"]
cts2 <- cts2[,rename$name2]
m <- cor(cts2, method="spearman")

clust <- hclust(dist(m))

pdf(sprintf("%s/Fig4-corr.pdf", datadir), useDingbats=FALSE)
pal <- colorRampPalette(c(rep.int("#FFFFFF", 9), brewer.pal(9, "GnBu")))
corrplot(m, method="circle",
         tl.cex=2, tl.col="black",
         cl.lim=c(0,1), cl.length=6, col=pal(100))
plot(clust, axes=FALSE)
## ROTATE RIGHT BRANCH
## CHECK THAT THIS IS SAFE!
## COMPARE WITH "RAW" RESULTS
clust$order <- clust$order[c(1,2,3,5,6,7,4)]
plot(clust, axes=FALSE)
dev.off()

cfplot <- function(xs, ys) {
    plot(log10(pmax(xs, 0.5)), log10(pmax(ys, 0.5)),
         pch=20, cex=0.33, xlim=c(-0.3,4.5), ylim=c(-0.3,4.5),
         xlab=NA, ylab=NA, axes=FALSE)
    axis(1, seq(0,4), labels=c("1", "10", "100", "1k", "10k"), cex.axis=0.67)
    axis(1, log10(c(sapply(10**seq(0,3), minor_decade))), labels=F, tcl=-0.5)
    axis(2, seq(0,4), labels=c("1", "10", "100", "1k", "10k"), cex.axis=0.67)
    axis(2, log10(c(sapply(10**seq(0,3), minor_decade))), labels=F, tcl=-0.5)
    legend(x="topleft", bty="n",
           legend=substitute(paste(rho, " = ", r),
                             list(r = sprintf("%0.2f", cor(xs, ys, method="spearman")))))
}
    
png(sprintf("%s/Fig4-xfm1-vs-input.png", datadir), width=480, height=480, pointsize=24)
cfplot(cts$Input, cts$Transform1)
title(xlab="Input DNA", font.lab=2)
title(ylab="Transformed (His #1, A)", font.lab=2)
dev.off()

png(sprintf("%s/Fig4-xfm2-vs-xfm1.png", datadir), width=480, height=480, pointsize=24)
cfplot(cts$Transform1, cts$Transform2)
title(xlab="His #1 (A)", font.lab=2)
title(ylab="His #2 (B)", font.lab=2)
dev.off()

png(sprintf("%s/Fig4-foa1-vs-xfm2.png", datadir), width=480, height=480, pointsize=24)
cfplot(cts$Transform2, cts$Countersel2)
title(xlab="His #2 (B)", font.lab=2)
title(ylab="5-FOA #2 (D)", font.lab=2)
dev.off()

png(sprintf("%s/Fig4-chx2-vs-foa2.png", datadir), width=480, height=480, pointsize=24)
cfplot(cts$Countersel2, cts$Chx2)
title(xlab="5-FOA #2 (D)", font.lab=2)
title(ylab="Cycloheximide #2 (F)", font.lab=2)
dev.off()

