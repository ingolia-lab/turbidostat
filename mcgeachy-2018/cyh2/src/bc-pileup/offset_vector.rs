use std::default::Default;
use std::iter::{Enumerate,repeat};
use std::slice::Iter;

#[derive(Debug,Clone)]
pub struct OffsetVector<T> {
    start: usize,
    vec: Vec<T>,
}

impl<T> OffsetVector<T> {
    pub fn new(start: usize, vec: Vec<T>) -> Self {
        OffsetVector { start: start, vec: vec }
    }

    pub fn len(&self) -> usize { self.vec.len() }
    pub fn start(&self) -> usize { self.start }
    pub fn end(&self) -> usize { self.start + self.vec.len() }
    
    pub fn get(&self, index: usize) -> Option<&T> {
        if index >= self.start {
            self.vec.get(index - self.start)
        } else {
            None
        }
    }

    pub fn get_mut(&mut self, index: usize) -> Option<&mut T> {
        if index >= self.start {
            self.vec.get_mut(index - self.start)
        } else {
            None
        }
    }

    pub fn iter<'a>(&'a self) -> Iter<'a,T> { self.vec.iter() }

    pub fn pos_iter(&self) -> PosIter<T> { 
        PosIter { start: self.start, inner: self.vec.iter().enumerate() }
    }

    pub fn map_to<F,S>(&self, f: F) -> OffsetVector<S> 
        where F: FnMut(&T) -> S
    {
        OffsetVector { start: self.start, vec: self.vec.iter().map(f).collect() }
    }
}

impl<T> OffsetVector<T>
    where T: Default
{
    pub fn new_with_default(start: usize, len: usize) -> Self {
        let mut vec = Vec::with_capacity(len);
        for _ in 0..len { vec.push(Default::default()) };
        Self::new(start, vec)
    }
}

#[derive(Debug,Clone)]
pub struct PosIter<'a, T> where T: 'a {
    start: usize,
    inner: Enumerate<Iter<'a,T>>
}

impl<'a,T> Iterator for PosIter<'a,T> {
    type Item = (usize,&'a T);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(pos,ap)| (pos + self.start, ap))
    }
}

