#!/bin/sh

### This script is used to the generate a Cell Ranger database with GENCODE and TE annotations. It will work with the primary assembly, as recommended by Cell Ranger/10x Genomics

GENOME=""
RELEASE=""

# Usage message

usage()
{
    echo "sh $0 -g [genome build] -r [release version]" >&2
    echo "    genome build: GRCh38 or GRCm39" >&2
    echo "    default release verson is 35 (human) and M26 (mouse)" >&2
    exit 1
}

# Check for required arguments

ARGS=$(getopt -o "g:r:" -- "$@")
if [ $? -ne 0 ]; then
    echo "Invalid command-line parameters" >&2
    usage
fi

eval set -- "$ARGS"

while [ $# -gt 0 ];
do
    case "$1" in
	-g) GENOME="$2"
	    shift 2
	    ;;
	-r) RELEASE="$2"
	    shift 2
	    ;;
	--) shift
	    break
	    ;;
    esac
done

if [ -z "${GENOME}" ]; then
    echo "No genome build provided" >&2
    usage
else
    case "${GENOME}" in
	GRCh38)
	    GCURL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human"
	    TEURL="https://www.dropbox.com/scl/fi/xir79nlnkpuydh8w33f7w/GRCh38_GENCODE_rmsk_TE.gtf.gz?rlkey=58x8t4jlewu5dessqoy6mlt9j&dl=1"
	    ;;
	GRCm39)
	    GCURL="https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse"
	    TEURL="https://www.dropbox.com/scl/fi/5d95o6h8na9sntlzx03b6/GRCm39_GENCODE_rmsk_TE.gtf.gz?rlkey=ymoesp2nm75vmzt6xqucdlje4&dl=1"
	    ;;
	*)
	    echo "Genome ${GENOME} not available" >&2
	    usage
	    ;;
    esac
fi

if [ -z "${RELEASE}" ]; then
    if [ "${GENOME}" == "GRCh38" ]; then
	RELEASE="35"
    else
	RELEASE="M26"
    fi
fi

# Confirm GENCODE release is valid

if ! [[ ${RELEASE} =~ ^[0-9M]*$ ]]; then
    echo "GENCODE release ${RELEASE} invalid. Please check" >&2
    usage
fi

if [ "${GENOME}" == "GRCm39" ]; then
    if ! [[ ${RELEASE} =~ ^M ]]; then
	RELEASE="M${RELEASE}"
    fi
    REL=$(echo ${RELEASE} | sed 's/^M//')
    if [ "${REL}" -lt "26" ]; then
	echo "GENCODE mouse release ${RELEASE} is not for GRCm39, but an older genome build. Please specify a later release" >&2
	usage
    fi
else
    if [ "${RELEASE}" -lt "20" ]; then
	echo "GENCODE human releae ${RELEASE} is not for GRCh38, but an older genome build. Please specify a later release" >&2
    fi
fi

# setup URL

GCURL="${GCURL}/release_${RELEASE}"

# Download primary assembly of genome sequence from GENCODE
wget "${GCURL}/${GENOME}.primary_assembly.genome.fa.gz"
if [ $? -ne 0 ]; then
    echo "Error downloading FASTA" >&2
fi

FASTA="${GENOME}.primary_assembly.genome.fa.gz"

# Download GENCODE primary assembly, comprehensive annotation GTF from GENCODE
wget "${GCURL}/gencode.v${RELEASE}.primary_assembly.annotation.gtf.gz"

if [ $? -ne 0 ]; then
    echo "Error downloading gene GTF" >&2
fi

GTF_IN="gencode.v${RELEASE}.primary_assembly.annotation.gtf.gz"

# Download TE GTF from Molly Hammell lab website
TE_IN="${GENOME}_GENCODE_rmsk_TE.gtf.gz"

wget -O "${TE_IN}" "${TEURL}"

if [ $? -ne 0 ]; then
    echo "Error downloading TE GTF" >&2
fi

# Remove version suffix from transcript, gene, and exon IDs in order to match
# previous Cell Ranger reference packages
#
# Input GTF:
#     ... gene_id "ENSG00000223972.5"; ...
# Output GTF:
#     ... gene_id "ENSG00000223972"; gene_version "5"; ...

GTF_MOD="$(basename "${GTF_IN}" \.gz).modified"

## Pattern matches Ensembl gene, transcript, and exon IDs for human or mouse:
ID="(ENS(MUS)?[GTE][0-9]+)\.([0-9]+)"
zcat "${GTF_IN}" \
    | sed -E 's/gene_id "'"$ID"'";/gene_id "\1"; gene_version "\3";/' \
    | sed -E 's/transcript_id "'"$ID"'";/transcript_id "\1"; transcript_version "\3";/' \
    | sed -E 's/exon_id "'"$ID"'";/exon_id "\1"; exon_version "\3";/' \
	  > "${GTF_MOD}"

if [ $? -ne 0 ]; then
    echo "Error fixing gene GTF" >&2
fi

## Define string patterns for GTF tags
### NOTES:
### - Since GENCODE release 31/M22 (Ensembl 97), the "lincRNA" and "antisense"
###   biotypes are part of a more generic "lncRNA" biotype.
### - These filters are relevant only to GTF files from GENCODE. The GTFs from
###   Ensembl release 98 have the following differences:
###   - The names "gene_biotype" and "transcript_biotype" are used instead of
###     "gene_type" and "transcript_type".
###   - Readthrough transcripts are present but are not marked with the
###     "readthrough_transcript" tag.
###   - Only the X chromosome versions of genes in the pseudoautosomal regions
###     are present, so there is no "PAR" tag.
BIOTYPE_PATTERN=\
"(protein_coding|lncRNA|lincRNA|antisense\
IG_C_gene|IG_D_gene|IG_J_gene|IG_LV_gene|IG_V_gene|\
IG_V_pseudogene|IG_J_pseudogene|IG_C_pseudogene|\
TR_C_gene|TR_D_gene|TR_J_gene|TR_V_gene|\
TR_V_pseudogene|TR_J_pseudogene)"
GENE_PATTERN="gene_type \"${BIOTYPE_PATTERN}\""
TX_PATTERN="transcript_type \"${BIOTYPE_PATTERN}\""
READTHROUGH_PATTERN="tag \"readthrough_transcript\""
PAR_PATTERN="tag \"PAR\""

## Construct the gene ID allowlist.
### We filter the list of all transcripts based on these criteria:
###   - allowable gene_type (biotype)
###   - allowable transcript_type (biotype)
###   - no "PAR" tag (only present for Y chromosome PAR)
###   - no "readthrough_transcript" tag
### We then collect the list of gene IDs that have at least one associated
### transcript passing the filters.

ALLOWLIST="$(basename "${GTF_IN}" \.gtf\.gz).allowed"
cat "${GTF_MOD}" \
    | awk '$3 == "transcript"' \
    | grep -E "${GENE_PATTERN}" \
    | grep -E "${TX_PATTERN}" \
    | grep -Ev "${READTHROUGH_PATTERN}" \
    | grep -Ev "${PAR_PATTERN}" \
    | sed -E 's/.*(gene_id "[^"]+").*/\1/' \
    | sort \
    | uniq \
	  > "${ALLOWLIST}"

if [ $? -ne 0 ]; then
    echo "Error creating allowed list" >&2
fi

## Filter the GTF file based on the gene allowlist
GTF_FILTERED="$(basename "${GTF_IN}" \.gtf\.gz)_CRfiltered.gtf"

### Copy header lines beginning with "#"
grep -E "^#" "${GTF_MOD}" > "${GTF_FILTERED}"

### Filter to the gene allowlist
grep -Ff "${ALLOWLIST}" "${GTF_MOD}" \
     >> "${GTF_FILTERED}"

if [ $? -ne 0 ]; then
    echo "Error filtering GTF" >&2
fi

## Remove intermediate files
rm "${GTF_MOD}" "${ALLOWLIST}"

## Identify chromosomes present in the genome fasta file
CHRFILES="${GENOME}_GENCODE_chrNames.txt"
grep ">" "${FASTA}" | sed 's/>//;s/ .*$//' | sort -k1,1 > "${CHRFILES}"

## Filter TE GTF file to include only primary assembly chromosomes
TE_FILTERED="$(basename "${TE_IN}" \.gtf\.gz)_filtered.gtf"
zcat "${TE_IN}" | sort -k1,1 | join -t "	" -j 1 "${CHRFILES}" - > "${TE_FILTERED}"

if [ $? -ne 0 ]; then
    echo "Error filtering TE GTF" >&2
fi


## Combine the two GTF into a single file for Cell Ranger
COMBINED_GTF="${GENOME}_GCv${RELEASE}_TE.gtf"
cat "${GTF_FILTERED}" "${TE_FILTERED}" > "${COMBINED_GTF}"

## Build the custom Cell Ranger reference database
cellranger mkref --genome="${GENOME}_GCv${RELEASE}_TE" --fasta="${FASTA}" --genes="${COMBINED_GTF}" --memgb=40 --nthreads=10

if [ $? -ne 0 ]; then
    echo "Error building database" >&2
else
    echo "All steps completed"
fi
