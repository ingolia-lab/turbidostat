extern crate bio;
extern crate clap;
extern crate cyh2lib;

use std::fs::File;
use std::io::{Write};
use std::collections::HashMap;
//use std::string;

use clap::{Arg, App};

use bio::io::fastq;
use cyh2lib::fastq_pair;

#[derive(Debug)]
struct Config {
    barcode_fastq: String,
    sequ_fastq: String,
    out_fastq: String,
    out_barcodes: Option<String>,
    out_barcode_freqs: Option<String>,
}

#[derive(Debug)]
enum ProgError {
    IOError(std::io::Error),
    Utf8Error(std::string::FromUtf8Error),
}

fn main() {
    let matches = App::new("bc-seqs")
        .version("1.0")
        .author("Nick Ingolia <ingolia@berkeley.edu>")
        .about("Match R1 barcode sequences with R2 insert sequences")
        .arg(Arg::with_name("barcodes")
             .short("b")
             .long("barcodes")
             .value_name("BARCODE-FQ")
             .help("FastQ file of barcode sequences")
             .takes_value(true)
             .required(true))
        .arg(Arg::with_name("sequences")
             .short("s")
             .long("sequences")
             .value_name("SEQUENCE-FQ")
             .help("FastQ file of insert sequences")
             .takes_value(true)
             .required(true))
        .arg(Arg::with_name("outbase")
             .short("o")
             .long("outbase")
             .value_name("OUTBASE")
             .help("Output filename base")
             .takes_value(true)
             .required(true))
        .arg(Arg::with_name("bclist")
             .short("l")
             .long("barcode-list")
             .help("Write list of barcodes"))
        .arg(Arg::with_name("bcfreq")
             .short("f")
             .long("barcode-freq")
             .help("Write table of barcode frequencies"))
        .get_matches();

    let outbase = matches.value_of("outbase").unwrap();
    
    let config = Config {
        barcode_fastq: matches.value_of("barcodes").unwrap().to_string(),
        sequ_fastq: matches.value_of("sequences").unwrap().to_string(),
        out_fastq: outbase.to_string() + "_barcoded.fq",
        out_barcodes: if matches.is_present("bclist") { Some(outbase.to_string() + "-barcodes.txt") } else { None },
        out_barcode_freqs: if matches.is_present("bcfreq") { Some(outbase.to_string() + "-barcode-freqs.txt") } else { None },
    };

    match run(config) {
        Ok(_) => (),
        Err(e) => panic!(e),
    }
}

fn run(config: Config) -> Result<(), ProgError> {
    let barcode_reader = fastq::Reader::from_file(&config.barcode_fastq).map_err(ProgError::IOError)?;
    let sequ_reader = fastq::Reader::from_file(&config.sequ_fastq).map_err(ProgError::IOError)?;

    let mut fastq_writer = fastq::Writer::to_file(&config.out_fastq).map_err(ProgError::IOError)?;

    let mut barcode_counts = HashMap::new();

    let pair_records = fastq_pair::PairRecords::new(barcode_reader.records(), sequ_reader.records());

    for pair_result in pair_records {
        let (barcode_record, sequ_record) = pair_result.map_err(ProgError::IOError)?;

        let name = sequ_barcoded_name(&config, &mut barcode_counts, &barcode_record)?;

        let named_record = fastq::Record::with_attrs(&name, None, sequ_record.seq(), sequ_record.qual());

        fastq_writer.write_record(&named_record).map_err(ProgError::IOError)?;
    }

    if let Some(barcode_filename) = config.out_barcodes {
        let mut barcode_writer = File::create(barcode_filename).map_err(ProgError::IOError)?;
        write_barcode_table(barcode_writer, &barcode_counts)?;
    }

    if let Some(freq_filename) = config.out_barcode_freqs {
        let mut freq_writer = File::create(freq_filename).map_err(ProgError::IOError)?;
        write_freq_table(freq_writer, &barcode_counts)?;
    }
    
    Ok(())
}

fn write_barcode_table<W>(barcode_out: W, barcode_counts: &HashMap<String, usize>) -> Result<(), ProgError>
    where W: std::io::Write
{
    let mut bcout = std::io::BufWriter::new(barcode_out);
    
    for (barcode, count) in barcode_counts.iter() {
        bcout.write(barcode.as_bytes()).map_err(ProgError::IOError)?;
        bcout.write("\t".as_bytes()).map_err(ProgError::IOError)?;
        bcout.write(count.to_string().as_bytes()).map_err(ProgError::IOError)?;
        bcout.write("\n".as_bytes()).map_err(ProgError::IOError)?;
    }

    Ok(())
}

fn write_freq_table<W>(freq_out: W, barcode_counts: &HashMap<String, usize>) -> Result<(), ProgError>
    where W: std::io::Write
{
    let mut fout = std::io::BufWriter::new(freq_out);

    let mut freq_counts = HashMap::new();

    for freq in barcode_counts.values() {
        let freq_count = freq_counts.entry(freq).or_insert(0);
        *freq_count += 1;
    }
    
    let mut freqs: Vec<usize> = freq_counts.keys().map(|&&k| k).collect();
    freqs.sort();

    for freq in freqs {
        write!(fout, "{}\t{}\n", freq, freq_counts.get(&freq).unwrap_or(&0)).map_err(ProgError::IOError)?;
    }
    
    Ok(())
}

fn sequ_barcoded_name(_config: &Config, barcode_counts: &mut HashMap<String, usize>, barcode_record: &fastq::Record) -> Result<String, ProgError>
{
    let barcode = String::from_utf8(barcode_record.seq().to_vec()).map_err(ProgError::Utf8Error)?;
    let barcode_count = barcode_counts.entry(barcode.to_string()).or_insert(0);
    *barcode_count += 1;

    Ok(barcode + "_" + &barcode_count.to_string())
}

