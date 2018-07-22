use std::collections::HashMap;
use std::fmt::{Display,Formatter};
use std::rc::Rc;
use std::str;


#[derive(Debug,Clone,Hash,PartialEq,Eq,PartialOrd,Ord)]
pub struct NtMutn {
    pos: usize,
    refnt: u8,
    mutseq: Vec<u8>,
}

static nts: [u8; 4] = [ b'A', b'C', b'G', b'T' ];

impl NtMutn {
    pub fn new(pos: usize, refnt: u8, mutseq: Vec<u8>) -> Self {
        NtMutn { pos: pos, refnt: refnt, mutseq: mutseq }
    }

    pub fn pos(&self) -> usize { self.pos }
    pub fn mutseq(&self) -> &[u8] { &self.mutseq }
    pub fn refnt<T: From<u8>>(&self) -> T { T::from(self.refnt) }

    pub fn all_substs(start: usize, len: usize, refseq: &[u8]) -> Vec<NtMutn> {
        let mut substs = Vec::new();
        for pos in start..(start+len) {
            if let Some(refnt) = refseq.get(pos) {
                for nt in nts.iter().filter(|&nt| nt != refnt) {
                    substs.push(NtMutn::new(pos, *refnt, vec![*nt]));
                }
            }
        }
        substs
    }

    pub fn tsv(&self) -> String {
        format!("{}\t{}\t{}", 
                self.pos, self.refnt::<char>(),
                str::from_utf8(&self.mutseq).unwrap_or("???"))

    }
}

#[derive(Debug,Clone,Hash,PartialEq,Eq,PartialOrd,Ord)]
enum Change {
    Missense(u8),
    Nonsense,
    Frameshift,
}

#[derive(Debug,Clone,Hash,PartialEq,Eq,PartialOrd,Ord)]
pub struct PeptMutn {
    pos_aa: usize,
    ref_aa: u8,
    cons_aa: u8,
}

impl PeptMutn {
    pub fn new(pos_aa: usize, ref_aa: u8, cons_aa: u8) -> Self {
        PeptMutn { pos_aa: pos_aa, ref_aa: ref_aa, cons_aa: cons_aa }
    }

    pub fn tsv(&self) -> String {
        format!("{}\t{}\t{}", self.pos_aa, self.ref_aa as char, 
                self.cons_aa as char)
    }
}

impl Display for PeptMutn {
    fn fmt(&self, f: &mut Formatter) -> ::std::fmt::Result {
        write!(f, "{}{}{}", self.ref_aa as char,
               self.pos_aa, self.cons_aa as char)
    }
}


#[derive(Debug,Clone)]
pub struct MutnBarcodes {
    mut_bc: HashMap<NtMutn,Vec<Rc<String>>>,
    bc_mut: HashMap<Rc<String>,Vec<NtMutn>>,
}

impl MutnBarcodes {
    pub fn new() -> Self {
        MutnBarcodes { mut_bc: HashMap::new(), bc_mut: HashMap::new() }
    }

    pub fn insert(&mut self, mutn: NtMutn, barcode: Rc<String>) {
        let mutn_vec = self.mut_bc.entry(mutn.clone()).or_insert_with(|| Vec::new());
        mutn_vec.push(barcode.clone());
        let bc_vec = self.bc_mut.entry(barcode).or_insert_with(|| Vec::new());
        bc_vec.push(mutn);
    }

    pub fn count_table(&self) -> String {
        let mut buf = String::new();

        let mut mutn_barcodes: Vec<(&NtMutn,&Vec<Rc<String>>)> = self.mut_bc.iter().collect();
        mutn_barcodes.sort_by_key(|&(&ref mutn,_barcodes)| mutn);
        for (&ref mutn,&ref barcodes) in mutn_barcodes.into_iter() {
            buf.push_str(&mutn.tsv());
            buf.push_str(&format!("\t{}\n", barcodes.len()));
        }

        buf
    }

    pub fn barcode_table(&self) -> String {
        let mut buf = String::new();

        let mut mutn_barcodes: Vec<(&NtMutn,&Vec<Rc<String>>)> = self.mut_bc.iter().collect();
        mutn_barcodes.sort_by_key(|&(&ref mutn,_barcodes)| mutn);
        for (&ref mutn,&ref barcodes) in mutn_barcodes.into_iter() {
            buf.push_str(&mutn.tsv());
            for barcode in barcodes {
                buf.push('\t');
                buf.push_str(barcode.as_str());
            }
            buf.push('\n');
        }

        buf
        
    }

    fn is_single_mutn(&self, barcode: &Rc<String>) -> bool {
        self.bc_mut.get(barcode).map_or(false, |&ref muts| muts.len() == 1)
    }
    
    pub fn mutn_table<'a, I>(&self, mutns: I) -> String
        where I: Iterator<Item=&'a NtMutn>
    {
        let mut buf = String::new();
        
        for mutn in mutns {
            let barcodes = self.mut_bc.get(mutn);
            let n_total = barcodes.map_or(0, Vec::len);
            let n_single = barcodes.map_or(0, |&ref bcs| bcs.iter().filter(|&ref bc| self.is_single_mutn(bc)).count());
            //            let n_single = barcodes.map_or(0, |&bcs| bcs.iter().filter(&is_only).count());

            buf.push_str(&mutn.tsv());
            buf.push_str(&format!("\t{}\t{}\n", n_total, n_single));
        }
        
        buf
    }
}
