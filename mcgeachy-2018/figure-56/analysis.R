options(stringsAsFactors=FALSE)
library("Biostrings")
library("DESeq2")
library("beeswarm")
library("RColorBrewer")

minor_decade <- function(d) { seq(2*d, 9*d, d) }

datadir <- Sys.getenv("DATADIR")
bcdir <- Sys.getenv("BCDIR")
countdir <- Sys.getenv("COUNTDIR")

## Read in barcode counts data frame
cts <- read.csv(sprintf("%s/good-counts.txt", countdir), row.names=1)

rename <- data.frame(sample=c("CYH2_input_S20",
                              "CYH2_15_AM_S21",
                              "CYH2_15_PM_S22",
                              "CYH2_16_PM_S23",
                              "CYH2_17_AM_S24",
                              "CYH2_17_PM_S25",
                              "CYH2_18_final_S26"),
                     name=c("Input", "Transform1", "Transform2",
                            "Countersel1", "Countersel2",
                            "Chx1", "Chx2"))
colnames(cts) <- rename[match(colnames(cts), rename$sample), "name"]

## Construct substScore, a table of PAM30 scores for substitutions
data(PAM30)

substScore <- data.frame()
for (aawt in row.names(PAM30)) {
    for (aamut in colnames(PAM30)) {
        score <- PAM30[aawt, aamut]
        substScore <- rbind.data.frame( substScore,
                                       data.frame( wt = aawt, mut = aamut, score = score) )
    }
}
substScore$subst <- paste(substScore$wt, substScore$mut, sep='')

## Position-Specific Scoring Matrix for the RPL27A/RPL28 CDD
## Note 1-based query positions
pssm <- read.delim("PTZ00160_matrix.txt", header=TRUE)
pssm$QueryPos <- as.integer(sub("-.*$", "", pssm$Query))
pssm$QueryAa <- sub("^.*-", "", pssm$Query)
pssm$QueryScore <- sapply(seq(1,nrow(pssm)),
                          function(i) { aa = pssm[i,"QueryAa"]; pssm[i,aa] })

## Read barcode/variant assignments
classify <- read.delim(sprintf("%s/barcode-classify.txt", bcdir),
                       header=FALSE,
                       col.names=c("bc", "ngood", "nmut", "heterog", "none", "class"))
classify <- classify[match(row.names(cts), classify$bc),]

## Barcodes with perfectly clean sequence
perfectBC <- classify[classify$ngood == 449 & classify$nmut == 0 & classify$heterog == 0, "bc"]

## Table of nucleotide mutations
nucmut <- read.delim(sprintf("%s/barcode-mutations.txt", bcdir),
                       header=FALSE,
                       col.names=c("bc", "pos", "wt", "mut"))
nucmut$change <- paste(nucmut$wt, nucmut$pos, nucmut$mut, sep="")
nucmutSplice <- nucmut[(nucmut$pos == 1143 | nucmut$pos == 1144) & nucmut$mut != '_',]

## Construct a data frame for barcodes having a single nuc change
nucmutMultiBC <- unique(nucmut[duplicated(nucmut$bc),"bc"])
nucmutSingle <- nucmut[!(nucmut$bc %in% nucmutMultiBC),]

## Table of amino acid mutations
## Incorporate PAM30 and PSSM scores
pepmut <- read.delim(sprintf("%s/barcode-peptide-mutations.txt", bcdir),
                     header=FALSE,
                     col.names=c("bc", "aapos", "aawt", "aamut"))
pepmut$change <- paste(pepmut$aawt, pepmut$aapos, pepmut$aamut, sep="")
pepmut$subst <- paste(pepmut$aawt, pepmut$aamut, sep="")
pepmut$score <- substScore[match(pepmut$subst, substScore$subst), "score"]

pepmutPssm <- pssm[match(pepmut$aapos + 1, pssm$QueryPos),]

pepmut$pssmWt <- pepmutPssm$QueryScore
pepmut$pssmMut <- unlist(sapply(seq(1,nrow(pepmut)),
                                function(i) { aa = pepmut[i,"aamut"];
                                    ifelse(aa == "?", 0, pepmutPssm[i,aa])
                                }))

## Construct a data frame for barcodes having a single pep change
pepmutMultiBC <- unique(pepmut[duplicated(pepmut$bc),"bc"])
pepmutSingle <- pepmut[!(pepmut$bc %in% pepmutMultiBC),]

## Barcode to peptide change(s) table
barcodeChanges <- function(bc) {
    changes <- pepmut[pepmut$bc == bc,"change"]
    changes <- changes[order(changes)]
    paste(changes, collapse=' ')
}
bcpepmut <- data.frame(bc=row.names(cts), 
                       changes=sapply(row.names(cts), barcodeChanges))

## Barcodes with nonesene mutations
stopmut <- read.delim(pipe(sprintf("grep Nonsense %s/barcode-peptide-sequences.txt", bcdir),open="r"),
                      header=FALSE, col.names=c("bc", "nonsense"))
nonsenseBC <- stopmut$bc

## DESeq analysis of changes
## Take the two transformed (-His) and two FOA data points to be equivalent
## Separate 8-hour and 24-hour cycloheximide (don't use 8-hour)
conds <- data.frame(row.names=c("Transform1", "Transform2",
                                "Countersel1", "Countersel2",
                                "Chx1", "Chx2", "Input"),
                    cond=c("his", "his", "foa", "foa", "cyh8", "cyh24", "input"))
dds <- DESeqDataSetFromMatrix(countData = cts,
                              colData = conds,
                              design = ~ cond)
dds <- estimateSizeFactors(dds)
dds <- estimateDispersions(dds, fitType="local")
dds <- nbinomWaldTest(dds, betaPrior=TRUE)

## Abundance change from input DNA to His selection
resXfm <- results(dds, c("cond", "his", "input"))
resXfm$changes <- bcpepmut[match(row.names(resXfm), bcpepmut$bc),"changes"]

## Abundance change from His selection to 5FOA selection
resFoa <- results(dds, c("cond", "foa", "his"))
resFoa$changes <- bcpepmut[match(row.names(resFoa), bcpepmut$bc),"changes"]

## Abundance change from 5FOA selection to Chx selection
resChx24 <- results(dds, c("cond", "cyh24", "foa"))
resChx24$changes <- bcpepmut[match(row.names(resChx24), bcpepmut$bc),"changes"]

## 5FOA effects per barcode
## WT = wild-type, NS = nonsense, SA = splice-acceptor
resFoaWT <- resFoa[row.names(resFoa) %in% perfectBC,]
resFoaNS <- resFoa[row.names(resFoa) %in% nonsenseBC,]
resFoaSA <- resFoa[row.names(resFoa) %in% nucmutSplice$bc,]

binwidth <- 0.25
bins <- seq(floor(min(resFoa$log2FoldChange)), 
            ceiling(max(resFoa$log2FoldChange)), binwidth)

histall <- hist(resFoa$log2FoldChange, breaks=bins, plot=FALSE)
histwt <- hist(resFoaWT$log2FoldChange, breaks=bins, plot=FALSE)
histns <- hist(resFoaNS$log2FoldChange, breaks=bins, plot=FALSE)
histsa <- hist(resFoaSA$log2FoldChange, breaks=bins, plot=FALSE)

pdf(sprintf("%s/Fig5a-foa-hist.pdf", datadir), width=6, height=4, useDingbats=FALSE)
plot(histall$mids, histall$density, 
     type="s", col="#999999", lwd=2, 
     ylim=c(0, 1.1*max(histall$density, histwt$density)),
     ylab=NA, yaxt="n",
     xlab="Fitness")
lines(histwt$mids, histwt$density, type="s", lwd=2, col="#1f78b4")
lines(histsa$mids, histsa$density, type="s", lwd=2, col="#7570b3")
lines(histns$mids, histns$density, type="s", lwd=2, col="#e7298a")
legend(x="topleft", bty="n", lwd=2,
       legend=c("All", "Wild-type", "Nonsense", "Splice"),
       col=c("#999999", "#1f78b4", "#e7298a", "#7570b3"),
       text.col=c("#656565", "#1f78b4", "#e7298a", "#7570b3"))
dev.off()

## Group barcodes representing single-nucleotide changes
## Only include single-base changes with ≥3 representatives
nucChanges <- unique(nucmut$change)
singleNuc <- data.frame()
for (change in nucChanges) {
    singleBC <- nucmutSingle[nucmutSingle$change == change,"bc"]
    if (length(singleBC) > 2) {
        fitness <- median(resFoa[singleBC,"log2FoldChange"])
        resist24 <- median(resChx24[singleBC,"log2FoldChange"])
        covered <- median(resXfm[singleBC,"log2FoldChange"])
        isnonsense <- any(singleBC %in% nonsenseBC)
        ismissense <- any(singleBC %in% pepmut$bc)
        issplacc <- any(singleBC %in% nucmutSplice$bc)
        isshift <- grepl('[-^]', change)
        issilent <- !(isnonsense | ismissense | issplacc | isshift)
        singleNuc <- rbind.data.frame( singleNuc,
                                      data.frame(change=change,
                                                 nsingle=length(singleBC),
                                                 fitness=fitness,
                                                 resist24=resist24,
                                                 covered=covered,
                                                 isnonsense=isnonsense,
                                                 ismissense=ismissense,
                                                 issplacc=issplacc,
                                                 isshift=isshift,
                                                 issilent=issilent) )
        
    }
}
singleNuc <- cbind.data.frame(singleNuc,
                              nucmut[match(singleNuc$change, nucmut$change),c("wt","pos","mut")] )

## Special cases for A1544- converts TAAg into TAG
##   and T1543C converts TAA into CAA...
singleNuc$category <- factor(ifelse(singleNuc$isnonsense, "Nonsense",
                             ifelse(singleNuc$change == "A1544-", "Synonymous",
                             ifelse(singleNuc$ismissense, "Missense",
                             ifelse(singleNuc$issplacc, "Splice Acc",
                             ifelse(singleNuc$pos >= 1096 & singleNuc$pos <= 1102, "Branch Pt",
                             ifelse(singleNuc$pos < 1143, "Intronic",
                             ifelse(singleNuc$isshift | singleNuc$change == "T1543C", "Frameshift", "Synonymous"))))))),
                             levels=c("Synonymous", "Missense", "Frameshift", "Nonsense", "Intronic", "Branch Pt", "Splice Acc"))

write.csv(x=singleNuc, file=sprintf("%s/Fig5b-foa-singlenuc.csv", datadir))

## Define some thresholds based on silent & presumptive nulls
## N.B. T1535A removes only 3 amino acids and may not be null
lowestSilentFoa <- min(singleNuc[singleNuc$category %in% c("Synonymous", "Intronic"),"fitness"])
highestNullFoa <- max(singleNuc[singleNuc$category %in% c("Nonsense", "Frameshift") & singleNuc$change != "T1535A","fitness"])
fitnessClass <- function(f) {
    ifelse(f <= highestNullFoa, "Dead",
    ifelse(f >= lowestSilentFoa, "Okay", "Sick"))
}

pdf(sprintf("%s/Fig5b-foa-singlenuc.pdf", datadir), width=6, height=9, useDingbats=FALSE)
beeswarm(pmax(-7.5, singleNuc$fitness) ~ singleNuc$category,
         pch=20, cex=0.6, horizontal=TRUE, at=c(1,2.25,3.5,4,4.5,5,5.5),
         col=c("#1b9e77", "#a6761d", "#d95f02", "#e7298a", "#66a61e", "#e6ab02", "#7570b3"),
         glab=NA, dlab="Fitness", las=1,
         glim=c(0,5.5))
rect(ybottom=0, ytop=0.5, xleft=lowestSilentFoa, xright=2,
     col="#1b9e7720", border=NA)
text(y=0.25, x=mean(c(lowestSilentFoa,2)), labels="Healthy", col="#1b9e77", srt=0, cex=1.5)
rect(ybottom=0, ytop=0.5, xleft=highestNullFoa, xright=lowestSilentFoa,
     col="#d95f0220", border=NA)
text(y=0.25, x=mean(c(highestNullFoa,lowestSilentFoa)), labels="Sick", col="#d95f02", srt=0, cex=1.5)
rect(ybottom=0, ytop=0.5, xleft=-8, xright=highestNullFoa,
     col="#e7298a20", border=NA)
text(y=0.25, x=mean(c(-8, highestNullFoa)), labels="Dead", col="#e7298a", srt=0, cex=1.5)
dev.off()

## Group barcodes representing single-amino-acid changes
## Only include single-residue changes with ≥3 representatives
pepChanges <- unique(pepmut$change)
singlePep <- data.frame()
for (change in pepChanges) {
    singleBC <- pepmutSingle[pepmutSingle$change == change,"bc"]
    score <- median(pepmutSingle[pepmutSingle$change == change,"score"])
    if (length(singleBC) > 2) {
        fitness <- median(resFoa[singleBC,"log2FoldChange"])
        resist24 <- median(resChx24[singleBC,"log2FoldChange"])
        singlePep <- rbind.data.frame(singlePep,
                                      data.frame(change=change,
                                                 nsingle=length(singleBC),
                                                 fitness=fitness,
                                                 resist24=resist24,
                                                 score=score)
                                      )
    }
}
singlePep <- cbind.data.frame(singlePep,
                              pepmut[match(singlePep$change, pepmut$change),
                                     c("aawt", "aapos", "aamut","pssmWt","pssmMut")] )
singlePep$pssmDiff <- singlePep$pssmMut - singlePep$pssmWt

write.csv(x=singlePep, file=sprintf("%s/Fig5c-foa-singlepep.csv", datadir))

cor(singlePep[,c("fitness", "resist24", "score", "pssmDiff")],
    singlePep[,c("score", "pssmWt", "pssmMut", "pssmDiff")],
    method="spearman", use="complete.obs")              

## Plot KDEs of substitution scores grouped by fitness classes
densplot <- function(x, fitness, lab) {
    lb=min(x,na.rm=TRUE)
    ub=max(x,na.rm=TRUE)
    okayDens <- density(x[fitnessClass(singlePep$fitness) == "Okay"],
                        from=lb, to=ub, na.rm=TRUE, bw=1)
    sickDens <- density(x[fitnessClass(singlePep$fitness) == "Sick"],
                        from=lb, to=ub, na.rm=TRUE, bw=1)
    deadDens <- density(x[fitnessClass(singlePep$fitness) == "Dead"],
                        from=lb, to=ub, na.rm=TRUE, bw=1)
    plot(okayDens$x, okayDens$y, type="l", lwd=2, col="#1b9e77",
         xlab=lab, ylab=NA,
         xlim=c(lb,ub),
         ylim=c(0,1.1*max(okayDens$y, sickDens$y, deadDens$y)), yaxt="n")
    lines(sickDens$x, sickDens$y, lwd=2, col="#d95f02")
    lines(deadDens$x, deadDens$y, lwd=2, col="#e7298a")

    legend(x="topleft", bty="n", lwd=2,
           legend=c("Healthy", "Sick", "Dead"),
           col=c("#1b9e77", "#d95f02", "#e7298a"),
           text.col=c("#1b9e77", "#d95f02", "#e7298a"))
}    

pdf(sprintf("%s/Fig5cd-foa-singlepep-class.pdf", datadir), width=6, height=4, useDingbats=FALSE)
densplot(singlePep$score, singlePep$fitness, "PAM30")
densplot(singlePep$pssmWt, singlePep$fitness, "PSSM WT Residue")
densplot(singlePep$pssmMut, singlePep$fitness, "PSSM Mutant Residue")
densplot(singlePep$pssmDiff, singlePep$fitness, "PSSM Difference")
dev.off()

## Pick only viable barcodes for CHX resistance analysis
resChx24Viable <- resChx24[resFoa$log2FoldChange > highestNullFoa,]
resChx24WT <- resChx24[row.names(resChx24) %in% perfectBC,]

write.csv(x=resChx24Viable, file=sprintf("%s/Fig6a-chx-dist.csv", datadir))

## Threshold for CHX resistance = highest value seen in silent single-base mutation
highestSilentChx <- max(singleNuc[singleNuc$category %in% c("Synonymous", "Intronic"),"resist24"])
resistantPep <- singlePep[singlePep$resist24 > highestSilentChx,]

## Plot KDEs of CHX fitness for different classes
lb=min(resChx24Viable$log2FoldChange, na.rm=TRUE)
ub=max(resChx24Viable$log2FoldChange, na.rm=TRUE)

viableDens <- density(resChx24Viable$log2FoldChange,
                      from=lb, to=ub, na.rm=TRUE, bw=0.5)
sickDens <- density(resChx24[fitnessClass(resFoa$log2FoldChange) == "Sick","log2FoldChange"],
                    from=lb, to=ub, na.rm=TRUE, bw=0.5)
okayDens <- density(resChx24[fitnessClass(resFoa$log2FoldChange) == "Okay" & !(row.names(resChx24) %in% perfectBC)
                            ,"log2FoldChange"],
                    from=lb, to=ub, na.rm=TRUE, bw=0.5)
wildtypeDens <- density(resChx24WT$log2FoldChange,
                        from=lb, to=ub, na.rm=TRUE, bw=0.5)

pdf(sprintf("%s/Fig6a-chx-dist.pdf", datadir), width=5, height=4, useDingbats=FALSE)
plot(viableDens$x, viableDens$y, type="l", lwd=2, col="#cccccc",
     xlab="CHX Fitness", ylab=NA, xlim=c(lb,ub),
     ylim=c(0,1.1*max(viableDens$y, okayDens$y, wildtypeDens$y, sickDens$y)), yaxt="n")
lines(sickDens$x, sickDens$y, lwd=2, col="#d95f02")
lines(okayDens$x, okayDens$y, lwd=2, col="#1b9e77")
lines(wildtypeDens$x, wildtypeDens$y, lwd=2, col="#7570b3")
legend(x="topright", lwd=2, bty="n",
       col=c("#aaaaaa", "#d95f02", "#1b9e77", "#7570b3"),
       legend=c("All viable", "Sick", "Healthy", "Wildtype"),
       text.col=c("#aaaaaa", "#d95f02", "#1b9e77", "#7570b3"))

viableDens$y[viableDens$x >= highestSilentChx]

xmax <- 5
ymax <- 1.1 * max(viableDens$y[viableDens$x >= xmax],
                  okayDens$y[okayDens$x >= xmax],
                  wildtypeDens$y[wildtypeDens$x >= xmax],
                  sickDens$y[sickDens$x >= xmax])

plot(viableDens$x, viableDens$y, type="l", lwd=2, col="#cccccc",
     xlab="CHX Fitness", ylab=NA, xlim=c(xmax,ub),
     ylim=c(0,ymax), yaxt="n")
lines(sickDens$x, sickDens$y, lwd=2, col="#d95f02")
lines(okayDens$x, okayDens$y, lwd=2, col="#1b9e77")
lines(wildtypeDens$x, wildtypeDens$y, lwd=2, col="#7570b3")
dev.off()

## Pick most resistant substitution seen at each position
resistPos <- aggregate(x=singlePep[,c("fitness", "resist24")],
                       by=list(aapos=singlePep$aapos),
                       max, simplify=TRUE)
resistpal <- c("#c0c0c0", brewer.pal(6, "YlOrRd"))
resistPos$colidx <- ifelse(resistPos$resist24 < highestSilentChx, 1,
                           3 + floor(resistPos$resist24 - highestSilentChx))
resistPos$color <- resistpal[resistPos$colidx]

## Plot resistance strength by position
write.csv(x=resistPos, file=sprintf("%s/Fig6b-chx-by-aapos.txt", datadir))

pdf(sprintf("%s/Fig6b-chx-by-aapos.pdf", datadir), width=6, height=4, useDingbats=FALSE)
plot(resistPos$aapos, resistPos$resist24,
     type="p", pch=20, cex=0.67, col=resistPos$color,
     xlab="Pos [aa]", ylab="Max CHX Fitness", ylim=c(-1,9), yaxp=c(0,8,2))
abline(h=highestSilentChx)
dev.off()

## Write pymol commands to color each residue by resistance
pymol <- c()
for (i in seq(1,length(resistpal))) {
    pymol <- c(pymol,
               sprintf("set_color resist%d, [%d/255.0, %d/255.0, %d/255.0]",
                       i,
                       col2rgb(resistpal[[i]])["red",],
                       col2rgb(resistpal[[i]])["green",],
                       col2rgb(resistpal[[i]])["blue",]))
                       
}

for (i in seq(1,nrow(resistPos))) {
    pymol <- c(pymol,
               sprintf("color resist%d, /4u3u//n8/%d",
                       resistPos[i,"colidx"],
                       resistPos[i,"aapos"] + 1))
}

cat(pymol, file=sprintf("%s/chx-resist-pymol.txt", datadir), sep="\n")

## Epistasis analysis
## Group barcodes representing repeated multi-aa changes
allChanges <- table(bcpepmut$changes)
multiChanges <- allChanges[grep(' ', names(allChanges))]
multiRepl <- names(multiChanges[multiChanges > 1])
multiPep <- data.frame()
for (change in multiRepl) {
    bcs <- bcpepmut[bcpepmut$change == change,"bc"]
    if (length(bcs) > 1) {
        fitnesses <- resFoa[bcs, "log2FoldChange"]
        resists <- resChx24[bcs,"log2FoldChange"]
        multiPep <- rbind.data.frame(multiPep,
                                     data.frame(change=change,
                                                fitmin=min(fitnesses),
                                                fitmed=median(fitnesses),
                                                fitmax=max(fitnesses),
                                                resistmin=min(resists),
                                                resistmed=median(resists),
                                                resistmax=max(resists)))
    }
}
multiPep$ch1 <- sub(' .*$', '', multiPep$change)
multiPep$ch2 <- sub('^.* ', '', multiPep$change)
multiPep$fit1 <- singlePep[match(multiPep$ch1, singlePep$change),"fitness"]
multiPep$fit2 <- singlePep[match(multiPep$ch2, singlePep$change),"fitness"]
cor(multiPep$fitmed,
    data.frame(min=pmin(multiPep$fit1,multiPep$fit2),
               avg=(multiPep$fit1 + multiPep$fit2)/2,
               max=pmax(multiPep$fit1,multiPep$fit2)),
    use="complete.obs")
multiPep$fitexp <- pmin(multiPep$fit1,multiPep$fit2)

write.csv(x=multiPep, file=sprintf("%s/Fig-foa-pairs.txt", datadir))

pdf(sprintf("%s/Fig-foa-pairs.pdf", datadir), useDingbats=FALSE)
plot(pmax(-7.5, multiPep$fitexp),
     pmax(-7.5, multiPep$fitmed),
     pch=20, col="black",
     xlim=c(-8,2), ylim=c(-8,2),
     xlab="Lower single-mutant fitness",
     ylab="Double-mutant fitness")
abline(v=lowestSilentFoa, col="#1b9e77", lwd=2)
abline(v=highestNullFoa, col="#e7298a", lwd=2)
rect(xleft=-8, xright=2, ytop=2, ybottom=lowestSilentFoa,
     border=NA, col="#1b9e7718")
text(x=-8, y=2, adj=c(0,1), col="#1b9e77", labels="Healthy")
rect(xleft=-8, xright=2, ytop=lowestSilentFoa, ybottom=highestNullFoa,
     border=NA, col="#d95f0218")
text(x=-8, y=lowestSilentFoa, adj=c(0,1), col="#d95f02", labels="Sick")
rect(xleft=-8, xright=2, ytop=highestNullFoa, ybottom=-8,
     border=NA, col="#e7298a18")
text(x=-8, y=highestNullFoa, adj=c(0,1), col="#e7298a", labels="Dead")
abline(a=0,b=1, col="#00000040")
dev.off()

