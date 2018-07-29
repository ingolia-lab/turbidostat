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

export BCDIR="${DATADIR}/barcoding"
mkdir -p ${BCDIR}

SRR="SRR7594453"

READ1FQ="${BCDIR}/${SRR}_1.fastq"
READ2FQ="${BCDIR}/${SRR}_2.fastq"

if [[ ! -e "${READ1FQ}" ]]; then
    fastq-dump --split-files -O "${BCDIR}" "${SRR}"
else
    echo "Skipping SRA ${SRR} because ${READ1FQ} exists"
fi

CONSTANT='GCGATAAAAG$'

TRIMBASE="${BCDIR}/NINI015_trim"
TRIM_R1="${TRIMBASE}.1.fq"
TRIM_R2="${TRIMBASE}.2.fq"

if [[ ! -e "${TRIM_R1}" ]];
then
    cutadapt -a "${CONSTANT}" \
	   -o "${TRIM_R1}" -p "${TRIM_R2}" \
	   --discard-untrimmed \
	   "${READ1FQ}" "${READ2FQ}" > "${TRIMBASE}-report.txt"
else
    echo "Skipping barcode trim because ${TRIM_R1} exists"
fi

if [[ ! -e ../cyh2/target/debug/bc-seqs ]]; then
    (cd ../cyh2 && cargo build)
fi

BARCODEBASE="${BCDIR}/NINI015"
BARCODED="${BARCODEBASE}_barcoded.fq"

if [[ ! -e "${BARCODED}" ]]; then
    ../cyh2/target/debug/bc-seqs --barcodes "${TRIM_R1}" --sequences "${TRIM_R2}" --outbase "${BARCODEBASE}"
else
    echo "Skipping bc-seqs because ${BARCODED} exists"
fi

REF_FA="RPL28_library.fa"
ALIGNBASE="${BCDIR}/NINI015"
ALIGNED="${ALIGNBASE}.bam"

if [[ ! -e "${ALIGNED}" ]]; then
    ../cyh2/target/debug/bc-align --barcoded-fastq "${BARCODED}" --reference "${REF_FA}" --outbase "${ALIGNBASE}"
else
    echo "Skipping bc-align because ${ALIGNED} exists"
fi

