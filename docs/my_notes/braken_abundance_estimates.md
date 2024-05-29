# Bracken abundance estimates

Bracken performs normalization to get ***relative abundance*** of a species compared to all the other species.

## A dual kraken2 + bracken sbatch on a single sample
```bash
#!/bin/bash
#SBATCH --job-name=kraken2_bracken
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=90G
#SBATCH --time=1:00:00
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/bracken/logs/bracken_%j.err

echo START: `date`

# Set paths
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

# Run kraken2 and bracken
srun --job-name="kraken2" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif kraken2 --paired --gzip-compressed --threads 1 --db "$DATABASE" --output "$KRAKEN_OUTPUT_FILE" --report "$KRAKEN_REPORT_FILE" "$FASTQ_FILE_1" "$FASTQ_FILE_2" 
srun --job-name="braken" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif bracken -d "$DATABASE" -i "$KRAKEN_REPORT_FILE" -o "$BRACKEN_OUTPUT_FILE" -w "$BRACKEN_REPORT_FILE"

echo END: `date`

```
## kraken2 + bracken sbatch job array on all your samples
```bash
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

# Set paths
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

# Run kraken2 and bracken

srun --job-name="kraken2_$ACCESSION" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif kraken2 --paired --gzip-compressed --threads 2 --db "$DATABASE" --output "$KRAKEN_OUTPUT_FILE" --report "$KRAKEN_REPORT_FILE" "$FASTQ_FILE_1" "$FASTQ_FILE_2" 
srun --job-name="braken_$ACCESSION" singularity exec -B /proj:/proj /proj/applied_bioinformatics/users/x_agama/MedBioinfo/kraken2.sif bracken -d "$DATABASE" -i "$KRAKEN_REPORT_FILE" -o "$BRACKEN_OUTPUT_FILE" -w "$BRACKEN_REPORT_FILE"

echo END: `date`

```

Check coverage of the serach = the ratio of classified versus unclassified reads

Each sequence classified by Kraken 2 results in a single line of output. Kraken 2's output lines contain five tab-delimited fields; from left to right, they are:

- "C"/"U": a one letter code indicating that the sequence was either classified or unclassified.
- The sequence ID
- The taxonomy ID Kraken 2 used to label the sequence
- The length of the sequence in bp. In the case of paired read data, this will be a string containing the lengths of the two sequences in bp, separated by a pipe character.
- A space-delimited list indicating the LCA mapping of each k-mer in the sequence(s)

For one file
```bash
grep '^C' -c ERR6913345_kraken2_output.txt
1117671 # Number of classified reads
grep '^U' -c ERR6913345_kraken2_output.txt
257526 # Number of unclassified reads
```

---
Use the unix sort command to display the bracken report in order of increasing species abundance in each sample.
```bash
sort -n -r -k1 ERR6913345_bracken_report.txt | head 
```
Try and figure out if any of your samples contain any traces of bacterial or eukaryotic pathogens (there is a list of known human pathogens in our dataset's study's associated publication)
```bash 
grep 'pseudomonas aeruginosa' -c ERR6913345_bracken_report.txt
0
```
use grep to check if any of your samples contain any reads assigned to human
```bash
grep 'human ' -c ERR6913345_bracken_report.txt
0
```

## Load the SLURM resources used for the full kraken2 computation into the shared central DB

```bash
sacct
sacct -P --format=JobID%15,JobName%18,ReqCPUS,ReqMem,Timelimit,State,ExitCode,Start,elapsedRAW,CPUTimeRAW,MaxRSS,NodeList  -j 35187369 | grep ERR > kraken2_vs_viral.sacct

sqlite3 -batch -separator "|" /proj/applied_bioinformatics/common_data/sample_collab.db ".import ./kraken2_vs_viral.sacct kraken2_viral_resources_used"

sqlite3 -box -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select * from kraken2_viral_resources_used where JobID like '35187369%';"
```
