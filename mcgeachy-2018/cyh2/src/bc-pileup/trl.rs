struct NtTree<T> {
    a: T,
    c: T,
    g: T,
    t: T,
}

impl<T> NtTree<T> {
    pub fn get(&self, nt: u8) -> Option<&T> {
        match nt {
            b'A' => Some(&self.a),
            b'C' => Some(&self.c),
            b'G' => Some(&self.g),
            b'T' => Some(&self.t),
            _ => None,
        }
    }
}

impl NtTree<NtTree<NtTree<u8>>> {
    pub fn trl(&self, seq: &[u8]) -> Option<u8> {
        let m1: Option<&NtTree<NtTree<u8>>> = seq.get(0).map(|&nt| self.get(nt)).unwrap_or(None);
        let m2: Option<&NtTree<u8>> = m1.map(|m| seq.get(1).map(|&nt| m.get(nt))).unwrap_or(None).unwrap_or(None);
        m2.map(|m| seq.get(2).map(|&nt| m.get(nt))).unwrap_or(None).unwrap_or(None).map(|&aa| aa)
    }
}

const CODONS: NtTree<NtTree<NtTree<u8>>>
    = NtTree { a: NtTree { a: NtTree { a: b'K', c: b'N', g: b'K', t: b'N' },
                           c: NtTree { a: b'T', c: b'T', g: b'T', t: b'T' },
                           g: NtTree { a: b'R', c: b'S', g: b'R', t: b'S' },
                           t: NtTree { a: b'I', c: b'I', g: b'M', t: b'I',}, },

               c: NtTree { a: NtTree { a: b'Q', c: b'H', g: b'Q', t: b'H' },
                           c: NtTree { a: b'P', c: b'P', g: b'P', t: b'P' },
                           g: NtTree { a: b'R', c: b'R', g: b'R', t: b'R' },
                           t: NtTree { a: b'L', c: b'L', g: b'L', t: b'L',}, },
               
               g: NtTree { a: NtTree { a: b'E', c: b'D', g: b'E', t: b'D' },
                           c: NtTree { a: b'A', c: b'A', g: b'A', t: b'A' },
                           g: NtTree { a: b'G', c: b'G', g: b'G', t: b'G' },
                           t: NtTree { a: b'V', c: b'V', g: b'V', t: b'V',}, },

               t: NtTree { a: NtTree { a: b'*', c: b'Y', g: b'*', t: b'Y' },
                           c: NtTree { a: b'S', c: b'S', g: b'S', t: b'S' },
                           g: NtTree { a: b'*', c: b'C', g: b'W', t: b'C' },
                           t: NtTree { a: b'L', c: b'F', g: b'L', t: b'F',}, }, };

pub struct CodonTable(NtTree<NtTree<NtTree<u8>>>);

pub const STD_CODONS: CodonTable = CodonTable(CODONS);

impl CodonTable {
    pub fn trl_codon(&self, codon: &[u8]) -> Option<u8> {
        self.0.trl(codon)
    }

    pub fn trl(&self, seq: &[u8]) -> Vec<u8> {
        let mut pept = Vec::new();

        let mut curr = seq;
        
        while curr.len() >= 3 {
            let (codon, rest) = curr.split_at(3);
            let aa = self.trl_codon(codon).unwrap_or(b'?');
            pept.push(aa);
            if aa < b'A' || aa > b'Y' {
                break;
            }
            curr = rest;
        }

        pept
    }
}
