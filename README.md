# CellRangerTE
CellRanger-TE is a modification to the Cell Ranger reference database that enables the software to quantify transposable elements from single-cell and single-nuclei datasets.

It takes the GENCODE FASTA and gene annotations, filters them according to the instructions provided by 10x Genomics regarding reference databases, and adds the TE annotations to create a TE-aware reference database

This is currently only available for mouse (GRCm39) and human (GRCh38).

Website: [Molly Gale Hammell Lab](https://www.mghlab.org/software)

Contact: mghcompbio@gmail.com

## Requirements

- [Cell Ranger software](https://www.10xgenomics.com/support/software/cell-ranger/latest)
- [wget](https://www.gnu.org/software/wget/) or [curl](https://curl.se/)
- Standard Linux tools (e.g. awk, grep, zcat)

## Usage
```
sh CellRanger-TE_database_generation.sh -g [genome build] -r [release version]
    genome build: GRCh38 or GRCm39
    default release version is 35 (human) and M26 (mouse)
```
Please note that GENCODE release 20 (human) and M26 (mouse) are the oldest releases corresponding to GRCh38 and GRCm39 respectively. Specifying older GENCODE releases will throw an error.

## CPU and memory usage

We recommend providing 10 CPU/cores and 250Gb of memory to ensure successful completion of the script.

## Copying & distribution

CellRangerTE is free softrware: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but *WITHOUT ANY WARRANTY*; without even the implied warranty of *MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE*.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with TEtranscripts.  If not, see [this website](http://www.gnu.org/licenses/).

## Citation

O'Neill K. et al. (2025)  Cell Rep. PMID: [40067829](https://pubmed.ncbi.nlm.nih.gov/40067829/)
