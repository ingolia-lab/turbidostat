options(stringsAsFactors=FALSE)

countdir <- Sys.getenv("COUNTDIR")

samples <- sub("-count.txt", "", list.files(countdir, pattern="*-count.txt"))

allCountList <- list()
for (sample in samples) {
    filename <- sprintf("%s/%s-count.txt", countdir, sample)
    print(c(sample, filename))
    ct <- read.delim(filename, header=FALSE, col.names=c("bc", "count"))
    allCountList[[ sample ]] <- ct
}
allBCs <- unique(unlist(sapply(allCountList, function(l) { l$bc })))

allBCs <- grep('N', x=allBCs, invert=TRUE, value=TRUE)

allcts <- data.frame(row.names=allBCs)
for (sample in samples) {
    allCounts <- allCountList[[sample]]
    allcts[,sample] <- pmax(allCounts[match(allBCs, allCounts$bc),"count"], 0, na.rm=TRUE)
}

write.csv(allcts, sprintf("%s/all-counts.txt", countdir))

realcts <- allcts[allcts$CYH2_input_S20 >= 3,]
write.csv(realcts, sprintf("%s/real-counts.txt", countdir))
