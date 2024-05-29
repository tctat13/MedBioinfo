#!/bin/bash
#
#SBATCH --job-name=viral_refseq_blastn
#SBATCH --account=naiss2024-22-540
#SBATCH --ntasks=1                   # nb of *tasks* to be run in // (usually 1), this task can be multithreaded (see cpus-per-task)
#SBATCH --cpus-per-task=4            # nb of cpu (in fact cores) to reserve for each task /!\ job killed if commands below use more cores
#SBATCH --time=00:30:00              # maximal wall clock duration (D-HH:MM) /!\ job killed if commands below take more time than reservation
#SBATCH --error=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/job.%J.err 
#SBATCH --output=/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences/logs/job.%J.out
# /!\ Note that the ./outputs/ dir above needs to exist in the dir where script is submitted **prior** to submitting this script

#################################################################

echo START: `date`

BLASTN_EXEC="/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src/blastn"
DATABASE='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/blast_db/refseq_viral_genomic'
DATA_DIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/data/merged_viral_sequences'
WORKDIR='/proj/applied_bioinformatics/users/x_agama/MedBioinfo/analyses/blastn_viral_sequences'

# Unzip .fa.gz files if they are compressed if not done already 
#for fasta_file in $DATA_DIR/*.fa.gz; do 
    #gunzip $fasta_file
#done

# Run BLAST for each decompressed .fa file
for fasta_file in $DATA_DIR/*.fa; do
    base_name=$(basename "$fasta_file" .fa)
    echo "Running BLAST for $fasta_file"
    srun -n 1 "$BLASTN_EXEC" -query "$fasta_file" -db "$DATABASE" -out "$WORKDIR/${base_name}.txt" -outfmt 6
done

echo END: `date`