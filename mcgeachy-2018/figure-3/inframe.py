import argparse
import collections
import os.path
import re
import sys

parser = argparse.ArgumentParser(description='Collect reading frame statistics')
parser.add_argument('-o', '--output', help='Output filename base')
args = parser.parse_args()

frag_frame_out = open('{}-frag-frame.txt'.format(args.output), 'w')

frame_reads = {}
frame_frags = {}
length_reads = {}

for line in sys.stdin:
    (chrom, startstr, endstr, name, countstr, strand, name, sequrest) = line.split('\t')
    sequ = sequrest.strip()
    frag_len = len(sequ)
    next_frame = len(sequ) % 3
    in_frame_stop = False
    while len(sequ) >= 3:
        codon = sequ[0:3]
        if codon in ['TAA', 'TAG', 'TGA']:
            in_frame_stop = True
            break
        sequ = sequ[3:len(sequ)]
    if sequ in ['TA', 'TG']:
        in_frame_stop = True
    frag_frame_out.write("{}\t{}\t{}\t{}\n".format(name, in_frame_stop, next_frame, frag_len))
    key = (in_frame_stop, next_frame)
    frame_frags[key] = frame_frags.get(key, 0) + 1
    frame_reads[key] = frame_reads.get(key, 0) + int(countstr)
    length_reads[frag_len] = length_reads.get(frag_len, 0) + int(countstr)
    
frame_reads_out = open('{}-frame-reads.txt'.format(args.output), 'w')
for (in_frame_stop, next_frame) in sorted(frame_reads.keys()):
    frame_reads_out.write("{}\t{}\t{}\n"
                          .format(in_frame_stop, next_frame,
                                  frame_reads[(in_frame_stop, next_frame)]))

length_reads_out = open('{}-length-reads.txt'.format(args.output), 'w')
for frag_len in sorted(length_reads.keys()):
    length_reads_out.write("{}\t{}\n"
                           .format(frag_len, length_reads[frag_len]))

frame_frags_out = open('{}-frame-frags.txt'.format(args.output), 'w')
for (in_frame_stop, next_frame) in sorted(frame_frags.keys()):
    frame_frags_out.write("{}\t{}\t{}\n"
                          .format(in_frame_stop, next_frame,
                                  frame_frags[(in_frame_stop, next_frame)]))
