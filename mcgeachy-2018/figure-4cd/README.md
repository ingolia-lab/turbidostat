The [`count.sh`](count.sh) script will download the barcode sequencing
data from the NCBI SRA, trim the reads, and count the barcodes. This
script will then run [`counttable.R`](counttable.R) in order to
collate barcode counts from individual samples into a single
table. Finally, it will run [`analysis-counts.R`](analysis-counts.R)
in order to plot graphs based on the barcode count table. A copy of
the barcode count table is provided in the
[`real-counts.txt`](real-counts.txt) data file.

The `count.sh` script requires a working directory where ~10 GB of sequence files will be downloaded and processed. The name of this directory is specified in the command, like so:
```
mkdir /path/to/data
./count.sh /path/to/data
```

Barcode counting relies on the [`../cyh2`](../cyh2) project, a
collection of compiled [Rust](https://www.rust-lang.org/) programs
that handle barcode counting and assignment. The Rust environment
[must be installed](https://www.rust-lang.org/en-US/install.html) in
order to compile and run them.
