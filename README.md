# CellRangerTE
CellRanger-TE is a modification to the Cell Ranger reference database that enables the software to quantify transposable elements from single-cell and single-nuclei datasets.

It takes the GENCODE FASTA and gene annotations, filters them according to the instructions provided by 10x Genomics regarding reference databases, and adds the TE annotations to create a TE-aware reference database

This is currently only available for mouse (GRCm39) and human (GRCh38).

# Usage
```
sh CellRanger-TE_database_generation.sh -g [genome build] -r [release version]
    genome build: GRCh38 or GRCm39
    default release verson is 35 (human) and M26 (mouse)
```
Please note that GENCODE release 20 (human) and M26 (mouse) are the oldest releases corresponding to GRCh38 and GRCm39 respectively. Specifying older GENCODE releases will throw an error.
