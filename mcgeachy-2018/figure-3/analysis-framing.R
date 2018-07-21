library("RColorBrewer")
options(stringsAsFactors=FALSE)

if (!file.exists("SGD_features.tab")) {
  sgd <- download.file('https://downloads.yeastgenome.org/curation/chromosomal_feature/SGD_features.tab', destfile="SGD_features.tab")
}
sgd <- read.delim("SGD_features.tab", header=FALSE, quote="",
                  col.names=c("sgdid", "type", "qual", "name", "gene", "alias",
                              "parent", "sgdid2", "chrom", "start", "end",
                              "strand", "genpos", "cver", "sver", "desc"))
sgdOrfs <- sgd[sgd$type == "ORF" & sgd$qual != "Dubious",]
sgdOrfs$Length <- ifelse(sgdOrfs$strand == "W", 
                         1 + sgdOrfs$end - sgdOrfs$start,
                         1 + sgdOrfs$start - sgdOrfs$end)

preFrRd <- read.delim("NIAM007_1pre-frame-reads.txt", 
                       header=FALSE,
                       col.names=c("HasStop", "Frame", "Count"))

postFrRd <- read.delim("NIAM007_1post-frame-reads.txt", 
                       header=FALSE,
                       col.names=c("HasStop", "Frame", "Count"))
preOrfRd <- read.delim("NIAM007_1pre-orf-frame-reads.txt", 
                       header=FALSE,
                       col.names=c("PhaseIn", "PhaseOut", "Count"))
postOrfRd <- read.delim("NIAM007_1post-orf-frame-reads.txt", 
                        header=FALSE,
                        col.names=c("PhaseIn", "PhaseOut", "Count"))

orfFrags <- read.delim("NIAM007_1post-orf-frags.txt",
                       header=FALSE, col.names=c("ORF", "NFrag"))
orfFragLengths <- read.delim("NIAM007_1post-orf-frag-lengths.txt",
                             header=FALSE, col.names=c("NtLen", "NFrag"))
# y_i = a_i * x_i / (\sum_j a_j * x_j)
# \sum_j a_j * x_j = a_i * (x_i / y_i)
# a_i = (y_i / x_i) * (\sum_j a_j * x_j) ~ y_i / x_i
postFrRd$Enrich <- (postFrRd$Count / sum(postFrRd$Count)) / (preFrRd$Count / sum(preFrRd$Count))
postOrfRd$Enrich <- (postOrfRd$Count / sum(postOrfRd$Count)) / (preOrfRd$Count / sum(preOrfRd$Count))
  
frpal <- brewer.pal(8, "Paired")

pdf("Fig3-inframe.pdf", useDingbats=FALSE, width=6, height=4)
barplot(height=c(preFrRd$Count/sum(preFrRd$Count),
                 postFrRd$Count/sum(postFrRd$Count)),
        space=c(0.2, 0.2, 0.2, 0.2, 0.2, 0.2, 1.2, 0.2, 0.2, 0.2, 0.2, 0.2),
        col=frpal[c(2,4,6,1,3,5, 2,4,6,1,3,5)],
        names.arg=c("+0", "+1", "+2", "+0", "+1", "+2", "+0", "+1", "+2", "+0", "+1", "+2"),
        ylim=c(0,0.6), ylab="Fraction Reads", axes=FALSE)
axis(side=2, at=c(0, 0.2, 0.4, 0.6))
dev.off()

pdf("Fig3-frame-enrich.pdf", useDingbats=FALSE, width=4, height=6)
barplot(height=log2(postFrRd$Enrich),
        col=frpal[c(2,4,6,1,3,5)],
        names.arg=c("+0", "+1", "+2", "+0", "+1", "+2"),
        ylim=c(-2, 4), ylab="Change in Abundance", axes=FALSE)
axis(side=2, at=seq(-2,4), labels=c("1/4", "1/2", "1", "2", "4", "8", "16"))
dev.off()

bupu <- brewer.pal(6, "Purples")
ylgn <- brewer.pal(6, "Greens")
orrd <- brewer.pal(6, "Oranges")

orfpal <- c("#969696", bupu[6], ylgn[6], orrd[6],
            bupu[5], ylgn[5], orrd[5],
            bupu[3], ylgn[3], orrd[3])

pdf("Fig3-orf-enrich.pdf", useDingbats=FALSE, width=6, height=6)
barplot(height=log2(postOrfRd$Enrich),
        col=orfpal,
        space=c(0.2, 2.2, 0.2, 0.2, 1.2, 0.2, 0.2, 1.2, 0.2, 0.2),
        names.arg=c("None", "+0", "+1", "+2", "+0", "+1", "+2", "+0", "+1", "+2"),
        ylim=c(-2,4), ylab="Change in Abundance", axes=FALSE)
axis(side=2, at=seq(-2,4), labels=c("1/4", "1/2", "1", "2", "4", "8", "16"))
dev.off()

pdf("Fig3-orf-frag-length.pdf", useDingbats=FALSE, width=4, height=4)
plot(x=orfFragLengths$NtLen, y=orfFragLengths$NFrag,
     type="s", lwd=2, xlab="Fragment Length ([nt])nt)", ylab="Number of Fragments", 
     xlim=c(0, 600), ylim=c(0,500), axes=FALSE)
axis(side=1, at=seq(0,600,100))
axis(side=2, at=seq(0,500,250))
dev.off()

sgdOrfs$nfrag <- orfFrags[match(sgdOrfs$name, orfFrags$ORF),"NFrag"]
sgdOrfs$nfrag <- ifelse(is.na(sgdOrfs$nfrag), 0, sgdOrfs$nfrag)
cor(sgdOrfs$nfrag, sgdOrfs$Length)

ttlNOrf <- nrow(sgdOrfs)
nfragCDF <- ecdf(sgdOrfs$nfrag)

pdf("Fig3-orf-frags.pdf", useDingbats=FALSE, width=4, height=4)
plot(x=seq(-1,20), (1 - nfragCDF(seq(-1,20))) * ttlNOrf,
     type="s", lwd=2, xlim=c(0,20), ylim=c(0,6000),
     xlab="Fragments per Gene", ylab="Number of Genes", 
     axes=FALSE)
axis(side=1, at=c(0,5,10,15,20))
axis(side=1, at=seq(0,20), labels=FALSE, tcl=-0.2)
axis(side=2, at=seq(0,6000,2000))
axis(side=2, at=seq(0,6000,500), labels=FALSE, tcl=-0.2)
dev.off()

