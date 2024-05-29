#!/bin/bash
#SBATCH --job-name=kraken2_bracken
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --array=1-10
#SBATCH --mem=90G
#SBATCH --time=1:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.err

echo START: `date`

# Set paths and variables
ACCESSIONS_FILE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/x_agama_run_accessions.txt'
DATABASE='/proj/applied_bioinformatics/common_data/kraken_database'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/sra_fastq'
KRAKEN_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2'
BRACKEN_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken'

# Read the accession number for this job
ACCESSION=$(sed -n "$SLURM_ARRAY_TASK_ID"p "$ACCESSIONS_FILE")

# Define input and output files
FASTQ_FILE_1="${DATA_DIR}/${ACCESSION}_1.fastq.gz"
FASTQ_FILE_2="${DATA_DIR}/${ACCESSION}_2.fastq.gz"
KRAKEN_OUTPUT_FILE="${KRAKEN_WORKDIR}/${ACCESSION}_kraken2_output.txt"
KRAKEN_REPORT_FILE="${KRAKEN_WORKDIR}/${ACCESSION}_kraken2_report.txt"
BRACKEN_OUTPUT_FILE="${BRACKEN_WORKDIR}/${ACCESSION}_bracken_output.txt"
BRACKEN_REPORT_FILE="${BRACKEN_WORKDIR}/${ACCESSION}_bracken_report.txt"

echo "$FASTQ_FILE_1" 
echo "$FASTQ_FILE_2" 

# Run kraken2 and bracken
srun --job-name="kraken2_$ACCESSION" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif kraken2 --paired --gzip-compressed --threads 2 --db "$DATABASE" --output "$KRAKEN_OUTPUT_FILE" --report "$KRAKEN_REPORT_FILE" "$FASTQ_FILE_1" "$FASTQ_FILE_2" 
srun --job-name="braken_$ACCESSION" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif bracken -d "$DATABASE" -i "$KRAKEN_REPORT_FILE" -o "$BRACKEN_OUTPUT_FILE" -w "$BRACKEN_REPORT_FILE"

echo END: `date`
