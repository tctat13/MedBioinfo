#!/bin/bash
#SBATCH --job-name=kraken2_bracken
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --array=1-10
#SBATCH --mem=90G
#SBATCH --time=1:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/krona/logs/krona_%j.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/krona/logs/krona_%j.err

echo START: `date`

# Set paths and variables
ACCESSIONS_FILE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/x_agama_run_accessions.txt'
KRAKEN_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/kraken2'
KRONA_WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/krona'

# Read the accession number for this job
ACCESSION=$(sed -n "$SLURM_ARRAY_TASK_ID"p "$ACCESSIONS_FILE")


# Convert kraken2 report to a format suitable for krona
srun --job-name="convert_$ACCESSION" python /proj/applied_bioinformatics/tools/KrakenTools/kreport2krona.py -r "$KRAKEN_WORKDIR"/"$ACCESSION"_kraken2_report.txt -o ./analyses/krona/"$ACCESSION"_krona_report.txt

# Use sed to remove prefixes
sed 's/[a-zA-Z]__//g' "$KRONA_WORKDIR"/"$ACCESSION"_krona_report.txt > "$KRONA_WORKDIR"/"$ACCESSION"_krona_report_sed.txt 

# Use ktImportText to generate the interactive pie chart
srun --job-name="korna_$ACCESSION" singularity exec kraken2.sif ktImportText "$KRONA_WORKDIR"/"$ACCESSION"_krona_report_sed.txt -o "$KRONA_WORKDIR"/"$ACCESSION"_krona.html

echo END: `date`
