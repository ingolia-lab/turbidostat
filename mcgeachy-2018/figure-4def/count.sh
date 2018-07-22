#!/bin/bash -x

if [[ "$#" != "1" ]]; then
    echo "Usage: $0 <DATA-DIRECTORY>"
    exit 1
fi

export DATADIR="$1"

if [[ ! -d "${DATADIR}" ]]; then
    echo "Data directory \"${DATADIR}\" does not exit"
    exit 1
fi

# Tab-delimited table of SRR<TAB>name
SAMPLETABLE="samples.txt"

ADAPTER='GCGATAAAAGCGTTGGGATCAGATCGGAAGAGCAC'

export COUNTDIR="${DATADIR}/counting"
mkdir -p "${COUNTDIR}"

for SRR in `cut -f1 ${SAMPLETABLE}`
do
    SAMPLE=`grep ${SRR} ${SAMPLETABLE} | cut -f2`
    
    COUNTTRIM="${COUNTDIR}/${SAMPLE}-trim.fq"

    if [[ ! -e ${COUNTTRIM} ]];
    then
        fastq-dump -Z ${SRR} \
	  | cutadapt -a ${ADAPTER} \
		   -o ${COUNTTRIM} \
		   - \
		   > "${COUNTDIR}/${SAMPLE}-trim-report.txt"
    else
        echo "Skipping SRA download and barcode trim because ${COUNTTRIM} exists"
    fi
done

for TRIMFQ in `ls ${COUNTDIR}/*-trim.fq`
do
    SAMPLE=`basename "${TRIMFQ}" -trim.fq`
    
    COUNT="${COUNTDIR}/${SAMPLE}-count.txt"

    if [[ ! -e ${COUNT} ]];
    then
        (cd ../cyh2 && cargo run --bin bc-count "${TRIMFQ}" "${COUNT}") &

        sleep 2
    else
        echo "Skipping barcode count because ${COUNT} exists"
    fi
done

wait

if [[ ! -e "${COUNTDIR}/real-counts.txt" ]]; then
    R --no-save < counttable.R
else
    echo "Skipping counttable because ${COUNTDIR}/real-counts.txt exists"
fi

R --no-save < analysis-counts.R
