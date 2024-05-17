#!/bin/bash
echo "script starts: "
date

### Downloading the illumina sequencing data
sqlite3 -batch /proj/applied_bioinformatics/common_data/sample_collab.db "select run_accession from sample_annot spl left join sample2bioinformatician s2b using(patient_code) where username='x_agama';" -noheader -csv > ./analyses/x_agama_run_accessions.txt
mkdir data/sra_fastq/
singularity exec fastq_analysis_image.sif fastq-dump -h
cat analyses/x_agama_run_accessions.txt | srun --cpus-per-task=1 --time=00:30:00 singularity exec fastq_analysis_image.sif  xargs -I {} fastq-dump -A {} --split-spot --gzip --readids --disable-multithreading --split-files --outdir ./data/sra_fastq/
zcat data/sra_fastq/ERR6913105_1.fastq.gz | grep -c '^@'

### Manipulating raw sequencing FASTQ files with seqkit
singularity exec fastq_analysis_image.sif seqkit -h
ls ./data/sra_fastq/*.fastq.gz | srun --cpus-per-task=1 --time=00:30:00 singularity exec fastq_analysis_image.sif  xargs -I {} seqkit stats {} -T --threads 1
# seqkit sub-command to check if the FASTQ files have been de-replicated: seqkit rmdup 
# seqkit sub-command to check  if the FASTQ files have already been trimmed of their sequencing kit adapters: seqkit locate
zcat ./data/sra_fastq/ERR6913105_1.fastq.gz | singularity exec fastq_analysis_image.sif seqkit locate -p AGATCGGAAGAGCACACGT

### Quality control of raw sequencing FASTQ files with FastQC
mkdir ./analyses/fastqc
srun --cpus-per-task=2 --time=00:30:00 singularity exec fastq_analysis_image.sif xargs -I{} -a ./analyses/x_agama_run_accessions.txt fastqc ./data/sra_fastq/{}_1.fastq.gz ./data/sra_fastq/{}_2.fastq.gz --threads 2 -o ./analyses/fastqc/

### Merging paired end readswith flash
mkdir ./data/merged_pairs
srun --cpus-per-task=2 singularity exec fastq_analysis_image.sif flash --compress --threads 2 --output-prefix ERR6913306 --output-directory ./data/merged_pairs/ ./data/sra_fastq/ERR6913306_1.fastq.gz ./data/sra_fastq/ERR6913306_2.fastq.gz 2>&1 | tee -a ./analyses/x_agama_flash.log
srun --cpus-per-task=2 --time=00:30:00 singularity exec fastq_analysis_image.sif xargs -a .
/analyses/x_agama_run_accessions.txt -I{} flash --compress --threads 2 --output-directory ./data/merged_pairs/ --output-prefix {} ./data/sra_fastq/{}_1.fastq.gz ./data/sra_fastq/{}_2.fastq.gz 2>&1 | tee -a ./analyses/x_agama_flash.log

### Read mapping to check for PhiX contamination
[x_agama@tetralith1 MedBioinfo]$ mkdir ./data/reference_seqssingu
singularity exec fastq_analysis_image.sif efetch -db nuccore -id NC_001422 -format fasta > ./data/reference_seqs/PhiX_NC_001422.fna
head ./data/reference_seqs/PhiX_NC_001422.fna 
mkdir ./data/bowtie2_DBs
srun singularity exec fastq_analysis_image.sif bowtie2-build -f ./data/reference_seqs/PhiX_NC_001422.fna ./data/bowtie2_DBs/PhiX_bowtie2_DB
ls ./data/bowtie2_DBs/
mkdir ./analyses/bowtie
srun --cpus-per-task=8 singularity exec fastq_analysis_image.sif bowtie2 -x ./data/bowtie2_DBs/PhiX_bowtie2_DB -U ./data/merged_pairs/ERR*.extendedFrags.fastq.gz -S ./analyses/bowtie/x_agama_merged2PhiX.sam --threads 8 --no-unal 2>&1 | tee ./analyses/bowtie/x_agama_bowtie_merged2PhiX.log
# No hits against PhiX
# Checking SARS-CoV-2
singularity exec fastq_analysis_image.sif efetch -db nuccore -id NC_045512 -format fasta > ./data/reference_seqs/SC2_NC_045512.fna
head ./data/reference_seqs/SC2_NC_045512.fna
srun singularity exec fastq_analysis_image.sif bowtie2-build -f ./data/reference_seqs/SC2_NC_045512.fna ./data/bowtie2_DBs/SC2_bowtie2_DBs
ls ./data/bowtie2_DBs/
srun --cpus-per-task=8 singularity exec fastq_analysis_image.sif bowtie2 -x ./data/bowtie2_DBs/SC2_bowtie2_DBs -U ./data/
merged_pairs/ERR*.extendedFrags.fastq.gz -S ./analyses/bowtie/x_agama_merged2SC2.sam --threads 8 --no-unal 2>&1 | tee ./analyses/bowtie/x_agama_bowtie_me
rged2SC2.log
# 3994 reads aligned exactly 1 time
head ./analyses/bowtie/x_agama_merged2SC2.sam

### Combine quality control results into one unique report for all samples analysed
srun singularity exec fastq_analysis_image.sif multiqc --force --title "x_agama sample subset" ./data/merged_pairs/ ./analyses/fastqc/ ./analyses/x_agama_flash.log ./analyses/bowtie/

echo "script end."
date
