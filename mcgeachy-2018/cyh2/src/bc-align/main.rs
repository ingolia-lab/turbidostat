extern crate bio;
extern crate rust_htslib;
extern crate itertools;

use std::collections::HashMap;
use std::fs;                                                                                                                                                                      
use std::io::{self,Write};
use std::path::{Path,PathBuf};
use std::process;
use std::string;

use itertools::Itertools;

use bio::io::fasta;

use rust_htslib::bam::Read;

#[derive(Debug)]
struct Config {
    bowtie_index: PathBuf,
    barcoded_fastq: PathBuf,
    bowtie_bam: PathBuf,
}

fn main() {
    let config = Config {
        bowtie_index: PathBuf::from("/mnt/ingolialab/ingolia/Cyh2/CYH2"), 
        barcoded_fastq: PathBuf::from("/mnt/ingolialab/ingolia/Cyh2/171009_barcoded.fq"),
        bowtie_bam: PathBuf::from("/mnt/ingolialab/ingolia/Cyh2/171009-bowtie.bam"),
    };

    match run(&config) {
        Ok(_) => (),
        Err(e) => panic!(e),
    }
}

fn run(config: &Config) -> Result<(), ProgError> {
    align_targets(config)
}

fn align_targets(config: &Config) -> Result<(), ProgError> {
    let bowtie_err = fs::File::create(config.bowtie_bam.with_extension(".txt"))?;
    let bowtie_sam_path = config.bowtie_bam.with_extension("sam");

    let bowtie_index_str = config.bowtie_index.to_str().else_string_error(|| "bowtie_index to path".to_owned())?;
    let barcoded_fastq_str = config.barcoded_fastq.to_str().else_string_error(|| "barcoded_fastq to path".to_owned())?;
    let bowtie_sam_str = bowtie_sam_path.to_str().else_string_error(|| "bowtie_sam to path".to_owned())?;

    let mut bowtie = process::Command::new("bowtie2")
        .args(&["-p36", "-a", "--np", "0", "-L", "20",
                "-x", bowtie_index_str,
                "-U", barcoded_fastq_str,
                "-S", bowtie_sam_str])
        .stderr(bowtie_err)
        .spawn()?;

    let bowtie_exit = bowtie.wait()?;

    if !bowtie_exit.success() {
        return Err(ProgError::MyErr("bowtie exited with error".to_string()));
    }

    let bam_unsorted = config.bowtie_bam.with_extension("unsorted-bam");
    let bam_unsorted_str = bam_unsorted.to_str().else_string_error(|| "bam_unsorted to path".to_owned())?;
    let mut samtools_view = process::Command::new("samtools")
        .args(&["view", "-b", "-S", "-o", bam_unsorted_str, bowtie_sam_str])
        .spawn()?;
    let samtools_exit = samtools_view.wait()?;
    
    if !samtools_exit.success() {
        return Err(ProgError::MyErr("samtools view exited with error".to_string()));
    }

    let bowtie_bam_str = config.bowtie_bam.to_str().else_string_error(|| "bowtie_bam to path".to_owned())?;
    let mut samtools_sort = process::Command::new("samtools")
        .args(&["sort", "-n", "-o", bowtie_bam_str, bam_unsorted_str])
        .spawn()?;

    let samtools_exit = samtools_sort.wait()?;
    
    if !samtools_exit.success() {
        return Err(ProgError::MyErr("samtools sort exited with error".to_string()));
    }

    
    Ok( () )
}

#[derive(Debug)]
pub enum ProgError {
    MyErr(String),
    IOError(io::Error),
    Utf8Error(string::FromUtf8Error),
}

impl From<io::Error> for ProgError {
    fn from(err: io::Error) -> ProgError { ProgError::IOError(err) }
}

impl From<string::FromUtf8Error> for ProgError {
    fn from(err: string::FromUtf8Error) -> ProgError { ProgError::Utf8Error(err) }
}

pub trait ToProgErrorResult<T> {
    fn else_string_error<F>(self, f: F) -> Result<T,ProgError>
        where F: FnOnce() -> String;
}

impl <T> ToProgErrorResult<T> for Option<T> {
    fn else_string_error<F>(self, f: F) -> Result<T,ProgError>
        where F: FnOnce() -> String
    {
        self.ok_or_else(|| ProgError::MyErr(f()))
    }
}

