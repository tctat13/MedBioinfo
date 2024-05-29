#!/bin/bash
#SBATCH --job-name=kraken2_bracken
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=90G
#SBATCH --time=1:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.err

echo START: `date`

# Set paths and variables
DATABASE='/proj/applied_bioinformatics/common_data/kraken_database'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/sra_fastq'
KRAKEN_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2'
BRACKEN_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken'

# Define input and output files
ACCESSION="ERR6913240"
FASTQ_FILE_1="${DATA_DIR}/${ACCESSION}_1.fastq.gz"
FASTQ_FILE_2="${DATA_DIR}/${ACCESSION}_2.fastq.gz"
KRAKEN_OUTPUT_FILE="${KRAKEN_WORKDIR}/${ACCESSION}_kraken2_output.txt"
KRAKEN_REPORT_FILE="${KRAKEN_WORKDIR}/${ACCESSION}_kraken2_report.txt"
BRACKEN_OUTPUT_FILE="${BRACKEN_WORKDIR}/${ACCESSION}_bracken_output.txt"
BRACKEN_REPORT_FILE="${BRACKEN_WORKDIR}/${ACCESSION}_bracken_report.txt"

# Run kraekn2
echo "$FASTQ_FILE_1" 
echo "$FASTQ_FILE_2" 
srun --job-name="kraken2" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif kraken2 --paired --gzip-compressed --threads 1 --db "$DATABASE" --output "$KRAKEN_OUTPUT_FILE" --report "$KRAKEN_REPORT_FILE" "$FASTQ_FILE_1" "$FASTQ_FILE_2" 
srun --job-name="braken" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif bracken -d "$DATABASE" -i "$KRAKEN_REPORT_FILE" -o "$BRACKEN_OUTPUT_FILE" -w "$BRACKEN_REPORT_FILE"

echo END: `date`
