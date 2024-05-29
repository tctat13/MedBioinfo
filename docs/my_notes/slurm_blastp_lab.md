# SLURM: database search with BLASTn

### Create the bastn database
```bash
zcat /proj/applied_bioinformatics/common_data/refseq_viral_split/ | /proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src/makeblastdb -out data/blast_db/refseq_viral_genomic/*genomic.fna.gz -title refseq_viral_genomic -parse_seqids -dbtype nucl
```
### Prepare the input files
Use seqkit to extract 3 subsets of reads from one of your merged reads FASTQ (data/merged_pairs/*.extendedFrags.fastq.gz) files with respectively 100, 1000, 10000 reads.

```bash
singularity exec fastq_analysis_image.sif seqkit head -n 100 data/merged_pairs/ERR6913105.extendedFrags.fastq.gz > analyses/ERR6913105_merged_100.fastq.gz

singularity exec fastq_analysis_image.sif seqkit head -n 1000 data/merged_pairs/ERR6913105.extendedFrags.fastq.gz > analyses/ERR6913105_merged_1000.fastq.gz

singularity exec fastq_analysis_image.sif seqkit head -n 10000 data/merged_pairs/ERR6913105.extendedFrags.fastq.gz > analyses/ERR6913105_merged_10000.fastq.gz
```

Convert FASTQ to FASTA using seqkit

```bash
singularity exec fastq_analysis_image.sif seqkit fq2fa  analyses/ERR6913105_merged_100.fastq.gz -o analyses/ERR6913105_merged_100.fa.gz

singularity exec fastq_analysis_image.sif seqkit fq2fa  analyses/ERR6913105_merged_1000.fastq.gz -o analyses/ERR6913105_merged_1000.fa.gz

singularity exec fastq_analysis_image.sif seqkit fq2fa  analyses/ERR6913105_merged_10000.fastq.gz -o analyses/ERR6913105_merged_10000.fa.gz
```

### Blast the reads subsets against the refseq viral genomes database

```bash
#!/bin/bash
#
#SBATCH --job-name=viral_refseq_blastn
#SBATCH --account=naiss2024-22-540
#SBATCH --ntasks=1                  
#SBATCH --cpus-per-task=4           
#SBATCH --time=00:30:00             
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/job.%J.err 
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/job.%J.out

#################################################################

echo START: `date`

BLASTN_EXEC="/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src/blastn"
DATABASE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/blast_db/refseq_viral_genomic'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/merged_viral_sequences'
WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences'

# Unzip .fa.gz files if they are compressed if not done already 
for fasta_file in $DATA_DIR/*.fa.gz; do 
    gunzip $fasta_file
done

# Run BLAST for each decompressed .fa file
for fasta_file in $DATA_DIR/*.fa; do
    base_name=$(basename "$fasta_file" .fa)
    echo "Running BLAST for $fasta_file"
    srun -n 1 "$BLASTN_EXEC" -query "$fasta_file" -db "$DATABASE" -out "$WORKDIR/${base_name}.txt" -outfmt 6
done

echo END: `date`
```
# Sbatch job array
An sbatch job array is a feature in the SLURM workload manager that allows users to submit multiple jobs simultaneously with a single command. This is particularly useful for running a large number of similar tasks that can be parallelized. 

When submitting a job array with sbatch, you specify a range of job indices. Each index corresponds to a separate job in the array. 

Within your SLURM script, you can access the job array index using the SLURM_ARRAY_TASK_ID environment variable. This variable is automatically set by SLURM for each job in the array.

**Task:** BLASTN of the full FASTQ sequences agains the refseq viral genome database

```bash
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

```
Explanation
- ACCESSIONS_FILE: Specifies the path to a file containing accession numbers.
- SLURM_ARRAY_TASK_ID: This is a SLURM-provided environment variable that contains the index of the current job within the job array.
- `sed command: Reads the accession number from the file corresponding to the current job's index.
    - `-n`: Tells sed to suppress automatic printing of pattern space.
    - `"$((SLURM_ARRAY_TASK_ID + 1))p"`: Uses arithmetic expansion to get the line number (SLURM_ARRAY_TASK_ID is zero-based, so + 1 converts it to one-based).
    - `"$ACCESSIONS_FILE"`: The file from which to read the line.
inside the sbatch script, use `--job-name $ACC_NUM` option after the srun command in order to later relate in the `sacct` accounting table which sample took how long to execute.

### Count of viral genomes
```bash
cut -f 2 ERR6913105_blast.txt | sort | uniq -c | sort -n | tail
```
And repeat this command for all the blast results in the `/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences` directory.

Alternatively:
```bash
for file in /proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/*_blast.txt; do
  cut -f 2 "$file" | sort | uniq -c | sort -nr | head
done
```

