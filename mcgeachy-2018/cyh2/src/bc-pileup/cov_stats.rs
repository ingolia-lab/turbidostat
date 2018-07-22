use std::fmt::{self,Display,Formatter};
use std::iter::repeat;

use aln_pos::{AlnPos,AlnPosCons};
use offset_vector::{OffsetVector};

#[derive(Debug,Clone,Hash,PartialEq,Eq,PartialOrd,Ord,Copy)]
pub enum CoverClass {
    Good, Gapped, Heterog,
}

impl Display for CoverClass
{
    fn fmt(&self, f: &mut Formatter) -> fmt::Result {
        write!(f, "{}", match *self {
            CoverClass::Good => "Good",
            CoverClass::Gapped => "Gapped",
            CoverClass::Heterog => "Heterog",
        })
    }
}

#[derive(Debug,Clone)]
pub struct Cover {
    wildtype: usize,
    mutant: usize,
    heterog: usize,
    none: usize,
}

impl Cover {
    pub fn new<'a, I>(aln_cons: I) -> Self
        where I: Iterator<Item=&'a AlnPosCons>
    {
        let mut cover = Cover { wildtype: 0, heterog: 0, none: 0, mutant: 0 };
        for apc in aln_cons {
            if apc.is_wildtype() {
                cover.wildtype += 1;
            } else if apc.is_mutant() {
                cover.mutant += 1;
            } else if apc.is_uncovered() {
                cover.none += 1;
            } else {
                panic!("Unclassifiable AlnPosCons {:?}\n", apc);
            }
            
            if apc.is_heterog() {
                cover.heterog += 1;
            }
        }
        cover
    }

    pub fn wildtype(&self) -> usize { self.wildtype }
    pub fn heterog(&self) -> usize { self.heterog }
    pub fn none(&self) -> usize { self.none }
    pub fn mutant(&self) -> usize { self.mutant }

    pub fn classify(&self, max_none: usize, max_heterog: usize) -> CoverClass { 
        if self.none > max_none {
            CoverClass::Gapped
        } else if self.heterog > max_heterog { 
            CoverClass::Heterog 
        } else {
            CoverClass::Good
        }
    }
}

pub struct CoverStats(OffsetVector<CoverAt>);

impl CoverStats {
    pub fn new(start: usize, len: usize, max: usize) -> Self {
        CoverStats(OffsetVector::new(start, repeat(CoverAt::new(max)).take(len).collect()))
    }

    pub fn add_coverage<'a, I>(&mut self, pos_iter: I)
        where I: Iterator<Item=(usize,&'a AlnPos)>
    {
        for (pos, ap) in pos_iter {
            if let Some(at) = self.0.get_mut(pos) {
                at.add_coverage(ap);
            }
        }
    }

    pub fn table(&self) -> String {
        let mut buf = String::new();

        for (pos, at) in self.0.pos_iter() {
            buf.push_str(&pos.to_string());

            for cvg in at.cover() {
                buf.push('\t');
                buf.push_str(&cvg.to_string());
            }

            buf.push('\n');
        }
        
        buf
    }
}

#[derive(Debug,Clone)]
struct CoverAt {
    cover: Vec<u32>,
}

impl CoverAt {
    fn new(max: usize) -> Self { CoverAt { cover: vec![0; (max + 1)] } }

    fn _max(&self) -> usize { self.cover.len() }

    fn cover(&self) -> &[u32] { &self.cover }

    fn add_coverage(&mut self, ap: &AlnPos) {
        let cvg = if AlnPosCons::new(ap).is_good() { ap.nttl() } else { 0 };
        let idx = if cvg >= self.cover.len() { self.cover.len() - 1 } else { cvg };
        self.cover[idx] += 1;
    }
}
