#!/bin/bash
#SBATCH --job-name=kraken2
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=90G
#SBATCH --time=1:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2/logs/kraken2_%j.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2/logs/kraken2_%j.err

echo START: `date`

# Set paths and variables
DATABASE='/proj/applied_bioinformatics/common_data/kraken_database'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/sra_fastq'
WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2'

# Define input and output files
FASTQ_FILE_1="${DATA_DIR}/ERR6913240_1.fastq.gz"
FASTQ_FILE_2="${DATA_DIR}/ERR6913240_2.fastq.gz"
OUTPUT_FILE="${WORKDIR}/ERR6913240_kraken2_output.txt"
REPORT_FILE="${WORKDIR}/ERR6913240_kraken2_report.txt"

# Run kraekn2
echo "$FASTQ_FILE_1" 
echo "$FASTQ_FILE_2" 
singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif kraken2 --paired --gzip-compressed --threads 1 --db "$DATABASE" --output "$OUTPUT_FILE" --report "$REPORT_FILE" "$FASTQ_FILE_1" "$FASTQ_FILE_2" 

echo END: `date`
