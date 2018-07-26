extern crate bio;
extern crate clap;
extern crate itertools;
extern crate rust_htslib;

use std::fs;                                                                                                                                                                      
use std::ffi::OsString;
use std::io;
use std::path::PathBuf;
use std::process;
use std::string;

use clap::{Arg, App};

#[derive(Debug)]
struct Config {
    reference_fasta: String,
    barcoded_fastq: String,
    out_bam: String,
}

fn main() {
    let matches = App::new("bc-align")
        .version("1.0")
        .author("Nick Ingolia <ingolia@berkeley.edu>")
        .about("Match R1 barcode sequences with R2 insert sequences")
        .arg(Arg::with_name("barcodedfq")
             .short("b")
             .long("barcoded-fastq")
             .value_name("BARCODED-FQ")
             .help("FastQ file with barcodes in sequence names")
             .takes_value(true)
             .required(true))
        .arg(Arg::with_name("referencefa")
             .short("r")
             .long("reference")
             .value_name("REFERENCE-FA")
             .help("Fasta format reference sequence")
             .takes_value(true)
             .required(true))
        .arg(Arg::with_name("outbase")
             .short("o")
             .long("outbase")
             .value_name("OUTBASE")
             .help("Output filename base")
             .takes_value(true)
             .required(true))
        .get_matches();

    let outbase = matches.value_of("outbase").unwrap();
    
    let config = Config {
        reference_fasta: matches.value_of("referencefa").unwrap().to_string(),
        barcoded_fastq: matches.value_of("barcodedfq").unwrap().to_string(),
        out_bam: outbase.to_string() + ".bam",
    };

    match run(&config) {
        Ok(_) => (),
        Err(e) => panic!(e),
    }
}

fn run(config: &Config) -> Result<(), ProgError> {
    let index = index_reference(config)?;
    align_targets(config, &index)
}

fn index_reference(config: &Config) -> Result<PathBuf, ProgError> {
    let reference_fb = PathBuf::from(&config.reference_fasta);
    let default_file_name = OsString::from("bc-align-index");
    let index_file_name = reference_fb.file_stem().unwrap_or(&default_file_name);
    let index_base = PathBuf::from(&config.out_bam).with_file_name(index_file_name);

    { 
        let index_base_str = index_base.to_str().else_string_error(|| "index_base to string".to_owned())?;
        
        let bowtie_build_err = fs::File::create(index_base.with_extension("bowtie-build.txt"))?;
        
        let mut bowtie_build = process::Command::new("bowtie2-build")
            .args(&[&config.reference_fasta, index_base_str, "-q"])
            .stderr(bowtie_build_err)
            .spawn()?;
        
        let bowtie_build_exit = bowtie_build.wait()?;
        
        if !bowtie_build_exit.success() {
            return Err(ProgError::MyErr("bowtie-build exited with error".to_string()));
        }
    }

    return Ok(index_base)
}

fn align_targets(config: &Config, index: &PathBuf) -> Result<(), ProgError> {
    let bowtie_err = fs::File::create(PathBuf::from(&config.out_bam).with_extension("bowtie.txt"))?;
    let bowtie_sam_path = PathBuf::from(&config.out_bam).with_extension("sam");

    let bowtie_index_str = index.to_str().else_string_error(|| "bowtie_index to str".to_owned())?;
    let bowtie_sam_str = bowtie_sam_path.to_str().else_string_error(|| "bowtie_sam to str".to_owned())?;

    let mut bowtie = process::Command::new("bowtie2")
        .args(&["-p36", "-a", "--np", "0", "-L", "20",
                "-x", bowtie_index_str,
                "-U", &config.barcoded_fastq,
                "-S", bowtie_sam_str])
        .stderr(bowtie_err)
        .spawn()?;

    let bowtie_exit = bowtie.wait()?;

    if !bowtie_exit.success() {
        return Err(ProgError::MyErr("bowtie exited with error".to_string()));
    }

    let bam_unsorted = PathBuf::from(&config.out_bam).with_extension("unsorted.bam");
    let bam_unsorted_str = bam_unsorted.to_str().else_string_error(|| "bam_unsorted to path".to_owned())?;
    let mut samtools_view = process::Command::new("samtools")
        .args(&["view", "-b", "-S", "-o", bam_unsorted_str, bowtie_sam_str])
        .spawn()?;
    let samtools_exit = samtools_view.wait()?;
    
    if !samtools_exit.success() {
        return Err(ProgError::MyErr("samtools view exited with error".to_string()));
    }

    let mut samtools_sort = process::Command::new("samtools")
        .args(&["sort", "-n", "-o", &config.out_bam, bam_unsorted_str])
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

