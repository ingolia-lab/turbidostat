#[macro_use]
extern crate error_chain;

extern crate bio;
extern crate rust_htslib;

use std::env;
use std::fs;
use std::io::{Write};
use std::path::{Path,PathBuf};
use std::rc::Rc;
use std::str;

use bio::io::fasta;

use rust_htslib::bam;
use rust_htslib::prelude::*;

use aln_pos::{Aln,AlnCons,AlnPos,AlnPosCons};
use cov_stats::{Cover,CoverClass,CoverStats};
use mutn::{PeptMutn,NtMutn,MutnBarcodes};
use trl::{CodonTable,STD_CODONS};

mod aln_pos;
mod cov_stats;
mod mutn;
mod offset_vector;
mod trl;

mod errors {
    error_chain!{
        foreign_links {
            IO(::std::io::Error);
            FromUtf8(::std::string::FromUtf8Error);
            Utf8(::std::str::Utf8Error);
            BamRead(::rust_htslib::bam::ReadError);
            BamReaderPath(::rust_htslib::bam::ReaderPathError);
            BamWrite(::rust_htslib::bam::WriteError);
            BamWriterPath(::rust_htslib::bam::WriterPathError);
            Pileup(::rust_htslib::bam::pileup::PileupError);
        }
    }
}

use errors::*;

#[derive(Debug)]
struct Config {
    ref_fa: PathBuf,
    bowtie_bam: PathBuf,
    tmpfile: PathBuf,
    outbase: PathBuf,
    reqstart: usize,
    reqend: usize,
    exon_start: usize,
    exon_upstream: Vec<u8>,
    mutstart: usize,
    mutend: usize,
    refreverse: bool,
    min_qual: u8,
    max_none: usize,
    max_heterog: usize,
}

impl Config {
    pub fn outfile<T>(&self, filename: T) -> PathBuf 
        where T: std::convert::AsRef<std::path::Path>
    {
        self.outbase.join(filename)
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let bam_path = &args[1];
    
    let ref_fa = "RPL28_library.fa";
    
    let config = Config {
        ref_fa: PathBuf::from(ref_fa),
        bowtie_bam: PathBuf::from(bam_path).join("NINI015.bam"),
        tmpfile: PathBuf::from(bam_path).join("NINI015-group.bam"),
        outbase: PathBuf::from(bam_path),
        reqstart: 1096,
        reqend: 1545,
        exon_start: 1145,
        exon_upstream: "ATGCCTTCCAGATTCACTAAGACTAGAAAGCACAGAGGTCACGTCTCAG".as_bytes().to_vec(),
        mutstart: 1032,
        mutend: 1706,
        refreverse: false,
        min_qual: 30,
        max_none: 2,
        max_heterog: 1,
    };

    if let Err(ref e) = run(&config) {
        println!("error: {}", e);
        
        for e in e.iter().skip(1) {
            println!("caused by: {}", e);
        }
        
        if let Some(backtrace) = e.backtrace() {
            println!("backtrace: {:?}", backtrace);
        }
        
        ::std::process::exit(1);
    }
}

fn run(config: &Config) -> Result<()> {
    let refrec = read_reference(&config.ref_fa)?;
    pileup_targets(config, &refrec)
}

fn pileup_targets(config: &Config, refrec: &fasta::Record) -> Result<()> {
    let refseq = refrec.seq();

    let mut ref_cds = config.exon_upstream.clone();
    ref_cds.extend_from_slice(&refseq[config.exon_start..]);
    let ref_pept = STD_CODONS.trl(&ref_cds);
    
    let mut class_out = fs::File::create(config.outfile("barcode-classify.txt"))?;
    let mut seq_out = fs::File::create(config.outfile("barcode-sequencing.txt"))?;
    let mut mut_out = fs::File::create(config.outfile("barcode-mutations.txt"))?;
    let mut single_out = fs::File::create(config.outfile("barcode-singletons.txt"))?;

    let mut mut_pept_out = fs::File::create(config.outfile("barcode-peptide-mutations.txt"))?;
    let mut pept_sequ_out = fs::File::create(config.outfile("barcode-peptide-sequences.txt"))?;
    let mut pept_out = fs::File::create(config.outfile("barcode-peptides.txt"))?;
    write!(pept_out, "REFERENCE\t")?;
    for aa in ref_pept.iter() { write!(pept_out, "{}", *aa as char)?; }
    write!(pept_out, "\n")?;
    
    let mut mutn_barcodes = MutnBarcodes::new();
    
    let mut cov_stats = CoverStats::new(0, refseq.len(), 10);

    let mut bam_reader = bam::Reader::from_path(&config.bowtie_bam)?;
    let header = bam::Header::from_template(bam_reader.header());
    let header_view = bam::HeaderView::from_header(&header);
    
    let barcode_groups = BarcodeGroups::new(&mut bam_reader)?;

    let reftid = match header_view.tid(refrec.id().as_bytes()) {
        Some(uid) => uid as i32,
        None => bail!("No target {} in {:?}", refrec.id(), config.bowtie_bam),
    };

    for barcode_group in barcode_groups {
        let (bc, qall) = barcode_group?;
        let bc_str = str::from_utf8(bc.as_slice()).unwrap_or("???");

        if qall.len() == 1 {
            write!(single_out, "{}\n", bc_str)?;
            continue;
        }

        let mut qvec = qall.into_iter()
            .filter(|r| (median_qual(r) >= config.min_qual) 
                    && (r.tid() == reftid) 
                    && (r.is_reverse() == config.refreverse))
            .collect::<Vec<bam::Record>>();
        qvec.sort_by_key(|r| (r.tid(), r.pos()));
        
        {
            let mut tmpout = bam::Writer::from_path(&config.tmpfile, &header)?;
            for r in qvec {
                tmpout.write(&r)?;
            }
        };
        
        let mut tmp_reader = bam::Reader::from_path(&config.tmpfile)?;
        let aln = Aln::new_aln(config.reqstart, config.reqend, refseq, tmp_reader.pileup())?;
        let aln_cons = aln.map_to(AlnPosCons::new);
        
        let cover = Cover::new(aln_cons.iter());
        let cover_class = cover.classify(config.max_none, config.max_heterog);

        write!(class_out, "{}\t{}\t{}\t{}\t{}\t{}\n", 
               bc_str, cover.wildtype() + cover.mutant(), cover.mutant(), cover.heterog(), cover.none(), cover_class)?;

        cov_stats.add_coverage(aln.pos_iter());
        
        write!(seq_out, "{}\t{}\t{}\n", bc_str, cover_class, aln.seq_desc())?;
        
        if cover_class == CoverClass::Good {        
            let mut_posn = aln_cons.pos_iter().filter(|&(_pos,apc)| !apc.is_wildtype());
            let bc_rc = Rc::new(bc_str.to_owned());
            for (pos, apc) in mut_posn {
                let mutn = NtMutn::new(pos, apc.ref_nt(), apc.mutseq());
                write!(mut_out, "{}\t{}\t{}\t{}\n",
                       bc_str, mutn.pos(), mutn.refnt::<char>(),
                       str::from_utf8(mutn.mutseq()).unwrap_or("???"))?;
                mutn_barcodes.insert(mutn, bc_rc.clone());
            }

            let mut cds_cons = config.exon_upstream.clone();
            let mut frameshift = None;
            for (pos,apc) in aln_cons.pos_iter().filter(|&(pos,_apc)| pos >= config.exon_start) {
                apc.push_cons_seq(&mut cds_cons);
                if apc.is_frameshift() && frameshift.is_none() {
                    frameshift = Some(pos);
                }
            }

            let pept_cons = STD_CODONS.trl(&cds_cons);

            let mut nonsense = None;
            let mut pept_mutns = Vec::new();
            write!(pept_out, "{}\t", bc_str)?;
            for (pos, (ref_aa, cons_aa)) in ref_pept.iter().zip(pept_cons.iter()).enumerate() {
                let aa = if ref_aa == cons_aa { '.' } else { *cons_aa as char };
                write!(pept_out, "{}", aa)?;

                if cons_aa != ref_aa {
                    if *cons_aa == b'*' {
                        nonsense = Some(pos);
                    } else {
                        pept_mutns.push(PeptMutn::new(pos, *ref_aa, *cons_aa));
                    }
                }
            }
            write!(pept_out, "\n")?;

            write!(pept_sequ_out, "{}", bc_str)?;
            if let Some(fs) = frameshift {
                let fs_codon = (fs + config.exon_upstream.len() - config.exon_start) / 3;
                write!(pept_sequ_out, "\tFrameshift{}\n", fs_codon)?;
            } else if let Some(ns) = nonsense {
                write!(pept_sequ_out, "\tNonsense{}\n", ns)?;
            } else {
                for pept_mutn in pept_mutns {
                    write!(mut_pept_out, "{}\t{}\n", bc_str, pept_mutn.tsv())?;
                    write!(pept_sequ_out, "\t{}", pept_mutn)?;
                }
                write!(pept_sequ_out, "\n")?;
            }
        }
    }

    let mut cov_out = fs::File::create(config.outfile("coverage.txt"))?;
    write!(cov_out, "{}", cov_stats.table())?;

    let mut mut_count_out = fs::File::create(config.outfile("mutation-barcode-counts.txt"))?;
    write!(mut_count_out, "{}", mutn_barcodes.count_table())?;
    
    let mut mut_barcodes_out = fs::File::create(config.outfile("mutation-barcodes.txt"))?;
    write!(mut_barcodes_out, "{}", mutn_barcodes.barcode_table())?;

    let mut subst_coverage_out = fs::File::create(config.outfile("substitution-coverage.txt"))?;
    let all_substs = NtMutn::all_substs(0, refseq.len(), &refseq);
    write!(subst_coverage_out, "{}", mutn_barcodes.mutn_table(all_substs.iter()))?;
    
    Ok( () )
}

pub struct BarcodeGroups<'a> {
    bam_reader: &'a mut bam::Reader,
    next_record: Option<bam::Record>,
}

impl <'a> BarcodeGroups<'a> {
    pub fn new(bam_reader: &'a mut bam::Reader) -> Result<Self> {
        let mut bg = BarcodeGroups{ bam_reader: bam_reader, next_record: None };
        bg.next_record = bg.read_next_record()?;
        Ok( bg )
    }

    fn read_next_record(&mut self) -> Result<Option<bam::Record>> {
        let mut rec = bam::Record::new();
        match self.bam_reader.read(&mut rec) {
            Ok( () ) => Ok( Some(rec) ),
            Err( bam::ReadError::NoMoreRecord ) => Ok( None ),
            Err( e ) => Err( e.into() ),
        }
    }

    fn barcode_group(&mut self, curr: bam::Record) -> Result<(Vec<u8>, Vec<bam::Record>)>
    {
        let curr_bc = barcode(curr.qname())?.to_vec();
        let mut bc_group = Vec::new();
        bc_group.push(curr);
        
        loop {
            let next = self.read_next_record()?;
            if let Some(rec) = next {
                if rec.qname().starts_with(&curr_bc) {
                    bc_group.push(rec);
                } else {
                    self.next_record = Some(rec);
                    break;
                }
            } else {
                self.next_record = None;
                break;
            }
        }
        
        Ok( (curr_bc, bc_group) )
    }
}

impl <'a> Iterator for BarcodeGroups<'a> {
    type Item = Result<(Vec<u8>, Vec<bam::Record>)>;

    fn next(&mut self) -> Option<Self::Item> {
        if let Some(curr) = self.next_record.take() {
            Some(self.barcode_group(curr))
        } else {
            None
        }
    }
}

fn median_qual(r: &bam::Record) -> u8 {
    let mut quals = r.qual().to_vec();
    quals.sort();
    quals.get(quals.len() / 2).map_or(0, |q| *q)
}

fn barcode(qname: &[u8]) -> Result<&[u8]> {
    qname.split(|&ch| ch == b'_').next()
        .ok_or_else(|| format!("No barcode for {}", str::from_utf8(qname).unwrap_or("???")).into())
}

fn read_reference(ref_fa: &Path) -> Result<fasta::Record> {
    let mut reader = fasta::Reader::from_file(ref_fa)?;
    let mut rec = fasta::Record::new();
    reader.read(&mut rec)?;
    Ok(rec)
}

