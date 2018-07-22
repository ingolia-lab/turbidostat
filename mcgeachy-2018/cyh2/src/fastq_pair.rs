extern crate bio;

use std::io;
use std::io::{Error, ErrorKind};
use std::io::Write;
use bio::io::fastq::Record;

pub struct PairRecords<R: io::Read, S: io::Read> {
    r1_records: bio::io::fastq::Records<R>,
    r2_records: bio::io::fastq::Records<S>,
}

impl<R: io::Read, S: io::Read> PairRecords<R, S> {
    pub fn new(r1_records: bio::io::fastq::Records<R>, r2_records: bio::io::fastq::Records<S>) -> Self {
        PairRecords { r1_records: r1_records, 
                      r2_records: r2_records,
        }
    }
}

impl<R: io::Read, S: io::Read> Iterator for PairRecords<R, S> {
    type Item = io::Result<(Record, Record)>;

    fn next(&mut self) -> Option<io::Result<(Record, Record)>> {
        match(self.r1_records.next(), self.r2_records.next()) {
            (None,         None)           => None,
            (Some(Err(e)), _)              => Some( Err(e) ),
            (_,            Some( Err(e) )) => Some( Err(e) ),
            (None,         Some(_))        => Some( Err(Error::new(ErrorKind::Other, "R1 ended before R2")) ),
            (Some(_),      None)           => Some( Err(Error::new(ErrorKind::Other, "R2 ended before R1")) ),
            (Some(Ok(r1)), Some( Ok(r2) )) => Some( Ok( (r1, r2) ) ),
        }
    }
}
