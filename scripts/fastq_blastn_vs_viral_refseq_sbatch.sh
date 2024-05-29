#!/bin/bash
#SBATCH --job-name=blastn_viral
#SBATCH --array=0-9
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --time=4:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/blastn_viral_%A_%a.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/blastn_viral_%A_%a.err

echo START: `date`

# Set paths and variables
BLASTN_EXEC="/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src/blastn"
DATABASE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/blast_db/refseq_viral_genomic'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/merged_pairs'
WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences'
ACCESSIONS_FILE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/x_agama_run_accessions.txt'

# Read the accession number for this job
ACC_NUM=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$ACCESSIONS_FILE")

# Define input and output files
FASTQ_FILE="${DATA_DIR}/${ACC_NUM}.extendedFrags.fastq.gz"
FASTA_FILE="${DATA_DIR}/${ACC_NUM}.fasta"
BLAST_OUTPUT="${WORKDIR}/${ACC_NUM}_blast.txt"
COMPRESSED_FASTA_FILE="${DATA_DIR}/${ACC_NUM}.fasta.gz"

# Convert FASTQ to FASTA
singularity exec fastq_analysis_image.sif seqkit fq2fa "$FASTQ_FILE" -o "$COMPRESSED_FASTA_FILE"

# Unzip the FASTA file
gunzip "$COMPRESSED_FASTA_FILE"

# Run BLASTn
srun --job-name="$ACC_NUM" -n 1 "$BLASTN_EXEC" -query "$FASTA_FILE" -db "$DATABASE" -out "$BLAST_OUTPUT" -outfmt 6 -num_alignments 5

# Compress the FASTA file after BLAST
gzip "$FASTA_FILE"

echo END: `date`
