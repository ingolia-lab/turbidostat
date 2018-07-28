#!/bin/bash

if [[ "$#" != "1" ]]; then
    echo "Usage: $0 <DATA-DIRECTORY>"
    exit 1
fi

# Extract path to script directory
SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
DATADIR="$1"

if [[ ! -d "${DATADIR}" ]]; then
    echo "Data directory \"${DATADIR}\" does not exit"
    exit 1
fi

if [[ ! -e "${DATADIR}/NIAM007_1pre.bam" ]]; then
    sam-dump SRR7548447 \
        | samtools sort -n -O BAM -o "${DATADIR}/NIAM007_1pre.bam"
else
    echo "${DATADIR}/NIAM007_1pre exists, skipping sam-dump"
fi

if [[ ! -e "${DATADIR}/NIAM007_1post.bam" ]]; then
    sam-dump SRR7548448 \
        | samtools sort -n -O BAM -o "${DATADIR}/NIAM007_1post.bam" -
else
    echo "${DATADIR}/NIAM007_1post exists, skipping sam-dump"
fi

SAMPLES="NIAM007_1pre NIAM007_1post"

GENOMEFA="saccharomyces_cerevisiae_plus_tagbfp.fa"
GENOMEBED="saccharomyces_cerevisiae.bed"

for SAMPLE in ${SAMPLES}
do
    BAM="${DATADIR}/${SAMPLE}.bam"
    
    if [[ ! -e "${BAM}" ]];
    then
	echo "Missing BAM file ${BAM} for ${SAMPLE}"
	exit 1
    fi

    BED="${DATADIR}/${SAMPLE}.bed"

    if [[ ! -e "${BED}" ]];
    then
        ( samtools view -bf 0x2 ${BAM} \
	    | bedtools bamtobed -bedpe -mate1 -i stdin \
	    | awk -f bedpe-to-bed.awk \
		> ${BED} ) 2>"${DATADIR}/${SAMPLE}_bedtools.txt"
    else
        echo "${BED} exists, skipping samtools/bedtools for ${SAMPLE}"
    fi

    BEDCOUNT="${DATADIR}/${SAMPLE}-count.bed"

    if [[ ! -e "${BEDCOUNT}" ]];
    then
        cut -f1,2,3,6 "${BED}" \
	  | sort | uniq -c \
	  | awk '{ printf("%s\t%d\t%d\t%s_%d_%d_%s\t%d\t%s\n", $2, $3, $4, $2, $3, $4, $5, $1, $5) }' \
	        > "${BEDCOUNT}"
    else
        echo "${BEDCOUNT} exists, skipping cut/sort/uniq for ${SAMPLE}"
    fi

    FRAGFRAME="${DATADIR}/${SAMPLE}-frag-frame.txt"

    if [[ ! -e "${FRAGFRAME}" ]];
    then
        bedtools getfasta -tab -s -fi "${GENOMEFA}" -bed "${BEDCOUNT}" -fo - \
	  | paste "${BEDCOUNT}" - \
	  | python inframe.py -o "${DATADIR}/${SAMPLE}"
    else
        echo "${FRAGFRAME} exists, skipping paste/cut for ${SAMPLE}"
    fi

    BEDORF="${DATADIR}/${SAMPLE}-frag-orf.txt"

    if [[ ! -e "${BEDORF}" ]];
    then
        bedtools intersect -wao -sortout -s -f 1 -nonamecheck \
	       -a "${BEDCOUNT}" \
	       -b "${GENOMEBED}" \
	       | python inorf.py -o "${DATADIR}/${SAMPLE}"
    else
        echo "${BEDORF} exists, skipping bedtools intersect for ${SAMPLE}"
    fi
done

( cd ${DATADIR} && R --no-save < "${SCRIPTDIR}/analysis-framing.R" )
