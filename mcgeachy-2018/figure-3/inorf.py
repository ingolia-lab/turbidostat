import argparse
import collections
import os.path
import re
import sys

parser = argparse.ArgumentParser(description='Collect ORF overlap statistics')
parser.add_argument('-o', '--output', help='Output filename base')
args = parser.parse_args()

yorf_frags = {}
yorf_frag_lengths = {}
frame_frags = {}
frame_reads = {}

frag_orf_out = open('{}-frag-orf.txt'.format(args.output), 'w')

for line in sys.stdin:
    fields = line.split('\t')
    frstart = None
    frend = None
    yorf = None
    if fields[9] == ".":
        frstart = None
        frend = None
        yorf = None
    else:
        yorf = fields[9]
        fragstart = int(fields[1])
        fragend = int(fields[2])
        orfstart = int(fields[7])
        orfend = int(fields[8])
        if fields[5] == "+":
            frstart = (fragstart - orfstart) % 3
            frend = (fragend - orfstart) % 3
        elif fields[5] == "-":
            frstart = (orfend - fragend) % 3
            frend = (orfend - fragstart) % 3
        else:
            sys.stderr.write("Unknown frame {}\n".format(fields[5]))
            exit
    frag_orf_out.write('{}\t{}\t{}\t{}\t{}\n'
                       .format(fields[3], fields[4],
                               yorf, frstart, frend))
    key = (frstart, frend)
    frame_frags[key] = frame_frags.get(key, 0) + 1
    frame_reads[key] = frame_reads.get(key, 0) + int(fields[4])
    if (frstart == 0 and frend == 2):
        yorf_frags[yorf] = yorf_frags.get(yorf, 0) + 1
        fraglength = fragend - fragstart
        yorf_frag_lengths[fraglength] = yorf_frag_lengths.get(fraglength, 0) + 1
        
frame_reads_out = open('{}-orf-frame-reads.txt'.format(args.output), 'w')
for (frstart, frend) in sorted(frame_reads.keys()):
    frame_reads_out.write("{}\t{}\t{}\n"
                          .format(frstart, frend,
                                  frame_reads[(frstart, frend)]))

frame_frags_out = open('{}-orf-frame-frags.txt'.format(args.output), 'w')
for (frstart, frend) in sorted(frame_frags.keys()):
    frame_frags_out.write("{}\t{}\t{}\n"
                          .format(frstart, frend,
                                  frame_frags[(frstart, frend)]))

yorf_frags_out = open('{}-orf-frags.txt'.format(args.output), 'w')
for yorf in sorted(yorf_frags.keys()):
    yorf_frags_out.write("{}\t{}\n"
                           .format(yorf, yorf_frags[yorf]))

yorf_frag_lengths_out = open('{}-orf-frag-lengths.txt'.format(args.output), 'w')
for yorf in sorted(yorf_frag_lengths.keys()):
    yorf_frag_lengths_out.write("{}\t{}\n"
                                .format(yorf, yorf_frag_lengths[yorf]))


    
