#!/bin/bash

FASTQDIR="/PATH/TO/FASTQ/"
DATADIR="/PATH/TO/Framing/"
SAMPLES="NIAM007_1pre NIAM007_1post"

INDEX="${DATADIR}/saccharomyces_cerevisiae_plus_tagbfp"
GENOMEFA="/PATH/TO/saccharomyces_cerevisiae.fa,tagbfp.fa"

if [[ ! -e "${INDEX}.1.bt2" ]];
then
    bowtie2-build "${GENOMEFA}" "${INDEX}"
    bowtie2-inspect "${INDEX}" > "${INDEX}.fa"
else
    echo "${INDEX} exists, skipping bowtie2-build"
fi

for SAMPLE in ${SAMPLES}
do
    FQ1=`ls ${FASTQDIR}/Sample_${SAMPLE}/*_R1_*.fastq.gz | paste -s -d,`
    FQ2=`echo ${FQ1} | sed s/_R1_/_R2_/g`
    SAM="${DATADIR}/${SAMPLE}.sam"
    
    if [[ ! -e "${SAM}" ]];
    then
        bowtie2 -p36 -x "${INDEX}" \
	      --maxins 1200 \
	      --un-conc "${DATADIR}/${SAMPLE}_unaligned.fq" \
	      -1 "${FQ1}" -2 "${FQ2}" \
	      -S "${SAM}" \
	      2>"${DATADIR}/${SAMPLE}_bowtie.txt"
    else
        echo "${SAM} exists, skipping bowtie2 for ${SAMPLE}"
    fi
done
