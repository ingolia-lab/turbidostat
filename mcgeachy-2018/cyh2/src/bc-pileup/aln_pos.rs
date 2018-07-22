use std::ops::Index;
use std::str;

use rust_htslib::bam::Reader;
use rust_htslib::bam::pileup::{Indel,Alignment,Pileup,Pileups};

use errors::*;
use offset_vector::OffsetVector;

#[derive(Debug,Clone,Hash,PartialEq,Eq)]
enum AlnReadPos {
    Nt(u8),
    NtTerm(u8),
    NtIns(u8,Vec<u8>),
}

impl AlnReadPos {
    fn new(aln: &Alignment) -> Result<Self> {
        if aln.is_refskip() || aln.is_del() {
            if let Indel::Ins(_) = aln.indel() {
                bail!("Ins() at refskip position")
            } else {
                Ok( AlnReadPos::Nt(if aln.is_del() { b'-' } else { b'N' }) )
            }
        } else if let Some(qp) = aln.qpos() {
            let &nt = aln.record().seq().index(qp as usize);
            if aln.is_head() || aln.is_tail() {
                Ok( AlnReadPos::NtTerm(nt) )
            } else if let Indel::Ins(l) = aln.indel() {
                let start = (qp + 1) as usize;
                let end = start + l as usize;
                Ok( AlnReadPos::NtIns(nt, aln.record().seq().as_bytes()[start..end].to_owned()) )
            } else {
                Ok( AlnReadPos::Nt(nt) )
            }
        } else {
            bail!("Missing qpos() for non-del alignment")
        }
    }

    fn nt(&self) -> u8 {
        match *self {
            AlnReadPos::Nt(nt) | AlnReadPos::NtTerm(nt) | AlnReadPos::NtIns(nt,_) => nt
        }
    }
    
    fn is_ins(&self) -> bool {
        match *self {
            AlnReadPos::NtIns(_,_) => true,
            _ => false,
        }
    }

    fn is_term(&self) -> bool {
        match *self {
            AlnReadPos::NtTerm(_) => true,
            _ => false,
        }        
    }

    fn ins<'a>(&'a self) -> Option<&'a [u8]> {
        match self {
            &AlnReadPos::Nt(_) => None,
            &AlnReadPos::NtTerm(_) => None,
            &AlnReadPos::NtIns(_,ref ins) => Some(&ins),
        }
    }
}

#[derive(Debug,Clone)]
pub struct AlnPos {
    refnt: u8,
    arps: Vec<AlnReadPos>,
}

impl AlnPos {
    pub fn new(refnt: u8) -> Self {
        AlnPos { refnt: refnt, arps: Vec::new() }
    }

    pub fn add_pileup(&mut self, pile: &Pileup) -> Result<()> {
        self.arps = pile.alignments().
            map(|a| AlnReadPos::new(&a)).
            collect::<Result<Vec<AlnReadPos>>>()?;
        Ok( () )
    }
    
    pub fn refnt(&self) -> u8 { self.refnt }
    
    pub fn nttl(&self) -> usize { self.arps.len() }

    pub fn all_match(&self) -> bool {
        let is_match = |&ref arp: &AlnReadPos| (arp.nt() == self.refnt) && !arp.is_ins();
        (self.arps.len() > 0) && self.arps.iter().all(&is_match)
    }
    
    pub fn nt_counts(&self) -> Vec<(u8, usize)> {
        let mut counts = Vec::new();
        for arp in self.arps.iter() {
            let arp_nt = arp.nt();
            let mut extant = false;
            for &mut(ref mut nt, ref mut cts) in counts.iter_mut() {
                if arp_nt == *nt {
                    *cts += 1;
                    extant = true;
                }
            }
            if !extant {
                counts.push((arp_nt, 1));
            }
        }
        counts
    }

    pub fn ins_counts(&self) -> Vec<(Vec<u8>, usize)> {
        let mut counts: Vec<(Vec<u8>,usize)> = Vec::new();
        for arp in self.arps.iter() {
            if arp.is_term() {
                continue;
            }
            let arp_ins = arp.ins().unwrap_or("".as_bytes()).to_vec();
            let mut extant = false;
            for &mut(ref mut ins, ref mut cts) in counts.iter_mut() {
                if arp_ins == *ins {
                    *cts += 1;
                    extant = true;
                }
            }
            if !extant {
                counts.push((arp_ins, 1));
            }
        }
        counts
    }
    
    pub fn seq_desc(&self) -> String {
        if self.arps.is_empty() {
            return ":0".to_owned();
        }

        let mut desc = String::new();

        for (nt, count) in self.nt_counts().into_iter() {
            desc = format!("{}:{},{}", desc, nt as char, count);
        }

        if self.arps.iter().any(AlnReadPos::is_ins) {
            for (ins, count) in self.ins_counts().into_iter() {
                desc = format!("{}:^{},{}", desc,
                               str::from_utf8(ins.as_slice()).unwrap_or("???"), count);
            }
        }
        
        desc
    }
}

#[derive(Debug,Clone)]
pub struct AlnPosCons {
    ref_nt: u8,
    cons_nt: u8,
    heterog: bool,
    cons_ins: Vec<u8>,
}

impl AlnPosCons {
    pub fn new(aln_pos: &AlnPos) -> Self {
        let nt_cts = aln_pos.nt_counts();
        if let Some(&(max_nt,max_nt_cts)) = nt_cts.iter().max_by_key(|&&(nt,cts)| (cts, nt == aln_pos.refnt())) {
            let penult_cts = nt_cts.iter().filter(|&&(nt,_cts)| nt != max_nt)
                .map(|&(_nt,cts)| cts).max().unwrap_or(0);
            let heterog_nt = (penult_cts == max_nt_cts) || (penult_cts > 1);

            let ins_cts = aln_pos.ins_counts();
            let (cons_ins, heterog_ins) = 
                if let Some(&(ref max_ins,max_ins_cts)) = ins_cts.iter().max_by_key(|&&(ref ins,cts)| (cts, ins.is_empty())) {
                    let penult_cts = ins_cts.iter().filter(|&&(ref ins,_cts)| ins != max_ins)
                        .map(|&(ref _ins,cts)| cts).max().unwrap_or(0);
                    let heterog_ins = (penult_cts == max_ins_cts) || (penult_cts > 1);
                    (max_ins.clone(), heterog_ins)
                } else {
                    (Vec::new(), false)
                };

            let heterog = heterog_nt || heterog_ins;

            AlnPosCons { ref_nt: aln_pos.refnt(), cons_nt: max_nt,
                         heterog: heterog, cons_ins: cons_ins }
        } else {
            AlnPosCons { ref_nt: aln_pos.refnt(), cons_nt: b'_',
                         heterog: false, cons_ins: Vec::new() }
        }

    }

    pub fn is_uncovered(&self) -> bool { self.cons_nt == b'_' }
    pub fn is_wildtype(&self) -> bool { self.ref_nt == self.cons_nt && self.cons_ins.is_empty() }
    pub fn is_mutant(&self) -> bool { !self.is_uncovered() && !self.is_wildtype() }
    pub fn is_heterog(&self) -> bool { self.heterog }
    pub fn is_insertion(&self) -> bool { !self.cons_ins.is_empty() }
    pub fn is_frameshift(&self) -> bool { (self.cons_nt == b'-') || (!self.cons_ins.is_empty()) }
    
    pub fn is_good(&self) -> bool { !self.is_uncovered() & !self.is_heterog() }

    pub fn ref_nt(&self) -> u8 { self.ref_nt }
    pub fn cons_nt(&self) -> u8 { self.cons_nt }
    pub fn cons_ins(&self) -> &[u8] { &self.cons_ins }

    pub fn mutseq(&self) -> Vec<u8> {
        let mut mutseq = vec![self.cons_nt];
        if !self.cons_ins.is_empty() {
            mutseq.push(b'^');
            mutseq.extend_from_slice(&self.cons_ins);
        }
        mutseq
    }

    pub fn push_cons_seq(&self, seq: &mut Vec<u8>) {
        match self.cons_nt {
            b'_' => seq.push(self.ref_nt),
            b'-' => (),
            _ => seq.push(self.cons_nt),
        };
        seq.extend_from_slice(&self.cons_ins);
    }
}

pub type Aln = OffsetVector<AlnPos>;

impl OffsetVector<AlnPos> {
    pub fn new_aln(start: usize, end: usize, refseq: &[u8], pileups: Pileups<Reader>) -> Result<Self> {
        let mut aln_posns = Vec::new();
        
        for pos in start..end {
            let refnt = refseq.get(pos).ok_or_else(|| format!("Pos {} out of bounds", pos))?;
            aln_posns.push(AlnPos::new(*refnt));
        }

        for pres in pileups {
            let pile = pres?;
            let pos = pile.pos() as usize;
            if pos >= start {
                if let Some(ap) = aln_posns.get_mut(pos - start) {
                    ap.add_pileup(&pile)?;
                }
            }
        }

        Ok( Self::new(start, aln_posns) )
    }

    pub fn seq_desc(&self) -> String {
        let mut desc = String::new();
        
        for (pos, ap) in self.pos_iter() {
            if !ap.all_match() {
                desc = format!("{}\t{}{:04}{}", desc, ap.refnt() as char, pos, ap.seq_desc());
            }
        }

        desc
    }
}

pub type AlnCons = OffsetVector<AlnPosCons>;

impl OffsetVector<AlnPosCons> {
    pub fn push_cons_seq(&self, seq: &mut Vec<u8>) {
        for apc in self.iter() {
            apc.push_cons_seq(seq);
        }
    }
}

// At an insertion:
//   no pileup entry for inserted nucleotides
//   indel => Ins(len)
//   aln.qpos() jumps by len+1 from one pileup to the next

