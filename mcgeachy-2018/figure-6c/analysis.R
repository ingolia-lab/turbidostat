options(stringsAsFactors=FALSE)
library("RColorBrewer")
library("grofit")
x <- read.csv("growth 2018-03-16.csv")
while(length(grep("Time..ms..", colnames(x))) > 0) {
  x[,grep("Time..ms..", colnames(x))[[1]]] <- NULL
}

x$time.hr <- x$Time..ms. / 3600000

wells <- grep("^[A-H][1-9]", colnames(x), value=TRUE)

gcraw <- t(x[,wells])

gcdata <- cbind.data.frame(strain=c(rep.int("Q38P", 12),
                                    rep.int("K55M", 12),
                                    rep.int("H39L", 12),
                                    rep.int("wt", 12)),
                           well=wells,
                           chx=rep.int(c(0,0,20,20,40,40,80,80,160,160,320,320),4),
                           gcraw)

gctime <- do.call("rbind", replicate(length(wells), x$time.hr, simplify=FALSE))

gc <- gcFit(gctime, gcdata, control=grofit.control(interactive=FALSE, suppress.messages=TRUE))

genocolor <- data.frame(geno=c("Q38P", "K55M", "H39L", "wt"),
                        color=c("#66a61e", "#e6ab02", "#a6761d", "black"))

drdata <- summary(gc)
dravg <- aggregate(drdata[,c("mu.model","mu.spline")], 
                   by=list(TestId=drdata$TestId, concentration=drdata$concentration), 
                   FUN=mean)
drzero <- dravg[dravg$concentration == 0,]
dravg$mu.spline.zero <- drzero[match(dravg$TestId, drzero$TestId),"mu.spline"]
drdata$mu.spline.zero <- drzero[match(drdata$TestId, drzero$TestId),"mu.spline"]

pdf("Fig6c-chx-growth.pdf", width=4, height=4, useDingbats=FALSE)
plot(drdata$concentration, drdata$mu.spline / drdata$mu.spline.zero, 
     pch=20, col=genocolor[match(drdata$TestId,genocolor$geno),"color"],
     xlim=c(0,350), xaxp=c(0,300,3), xlab="CHX (nM)",
     ylim=c(0,1.2), yaxp=c(0,1,2), ylab="Rel. Growth" )

lines(x=dravg[dravg$TestId == "wt","concentration"],
      y=dravg[dravg$TestId == "wt", "mu.spline"] / 
        drzero[drzero$TestId == "wt", "mu.spline"],
      col="black", lwd=2)

lines(x=dravg[dravg$TestId == "Q38P","concentration"],
      y=dravg[dravg$TestId == "Q38P", "mu.spline"] / 
        drzero[drzero$TestId == "Q38P", "mu.spline"],
      col="#66a61e", lwd=2)

lines(x=dravg[dravg$TestId == "K55M","concentration"],
      y=dravg[dravg$TestId == "K55M", "mu.spline"] / 
        drzero[drzero$TestId == "K55M", "mu.spline"],
      col="#e6ab02", lwd=2)

lines(x=dravg[dravg$TestId == "H39L","concentration"],
      y=dravg[dravg$TestId == "H39L", "mu.spline"] / 
        drzero[drzero$TestId == "H39L", "mu.spline"],
      col="#a6761d", lwd=2)

legend(x="topright", bty="n",
       pch=20,
       legend=genocolor$geno,
       col=genocolor$color)
dev.off()

pdf("Fig6-chx-growth-curves.pdf", width=4, height=4, useDingbats=FALSE)
for (geno in genocolor$geno) {
  genorows <- grep(geno, drdata$TestId)
  conccolors <- data.frame(conc=c(-3,-2,-1,320,160,80,40,20,0),
                           color=brewer.pal(9, "YlGnBu"))
  conccolors <- conccolors[conccolors$conc >= 0,]
  row1 <- genorows[[1]]
  gc1 <- gc$gcFittedSplines[[row1]]
  col1 <- conccolors[match(drdata[row1,"concentration"], conccolors$conc),"color"]
  plot(gc1$raw.time, gc1$raw.data, 
       type="l", col=col1,
       xlim=c(0,16.5), xaxp=c(0,16,4), xlab="Time (hr)",
       ylim=c(0,1.5), yaxp=c(0,1.0,2), ylab="OD600")
  title(main=geno)
  for (rowr in genorows) {
    gcr <- gc$gcFittedSplines[[rowr]]
    colr <- conccolors[match(drdata[rowr,"concentration"], conccolors$conc),"color"]
    lines(gcr$raw.time, gcr$raw.data, 
          type="l", col=colr,
          xlim=c(0,16.5), xaxp=c(0,16,4), xlab="Time (hr)",
          ylim=c(0,1.5), yaxp=c(0,1.0,2), ylab="OD600")
  }
  legend(x="topleft", bty="n", 
         lwd=2,
         legend=conccolors$conc,
         col=conccolors$color)
}
dev.off()
