#! /usr/bin/env nextflow

workflow{
	ch_input = Channel.fromFilePairs(params.input_read_pairs, checkIfExists: true )	// it take the file pairs from the input_read_pairs variable in the params.yml file wich are the forward and reverse reads
	// This channel factory authomatically creates a tuple with the id and the path to the file

	// quality control
	FASTQC (ch_input)

	// merging paired-end reads
	FLASH2(ch_input)

	// Map reads to database
	BOWTIE2(Channel.fromPath(params.bowtie2_db, checkIfExists: true).toList(), FLASH2.out.merged_reads) // the .toList() method is used to convert the channel to a list, since bowtie2_db is a single file

	// Microbial classification
	KRAKEN2(Channel.fromPath(params.kraken2_db, checkIfExists: true), ch_input)
	BRACKEN(Channel.fromPath(params.kraken2_db, checkIfExists: true), KRAKEN2.out.kraken2_report, ch_input)
	KRAKEN_2_KRONA(KRAKEN2.out.kraken2_report, ch_input)
	SED_KRONA(KRAKEN_2_KRONA.out.krona_report, ch_input)
	KT_IMPORT_TEXT(SED_KRONA.out.sed_krona_report, ch_input)
	
	// assembling reports
	MULTIQC (FASTQC.out.qc_zip.collect(), FLASH2.out.flash2_log.collect(), BOWTIE2.out.bowtie2_log.collect(), KRAKEN2.out.kraken2_report_dir.collect()) // multiqc will wait for all the fastqc files to be generated, this is archieved by using collect() method

}


// Publish directories are numbered to help understand processing order
// all variables named params.name are listed in params.yml

// fast quality control of fastq files
process FASTQC {

	input:
	tuple val(id), path(reads) // the from.filePairs() method will create a tuple with the id and the path to the file


	// directives
	container 'https://depot.galaxyproject.org/singularity/fastqc:0.11.9--hdfd78af_1' 
	publishDir "$params.outdir/01_fastqc"  // where should the output be saved

	script: 
	"""

	fastqc \\
	    --noextract \\
	    $reads

	"""
	// the reads variable that is passed to the script is the path to the file
	// the --noextract flag is used to avoid extracting the files, since we are only interested in the html and zip files

	output:
	path "${id}*fastqc.html", emit: qc_html 
	// the output is a file with the id and the extension fastqc.html
	// the emit: qc_html is used to name the output file
	// the * is used to match the id and the extension because I don't know the exact name of the file
	path "${id}*fastqc.zip", emit: qc_zip // this will be the input for the multiqc process

}

process FLASH2 {

	input: 
	tuple val(id), path(reads)

	// directives
	container 'https://depot.galaxyproject.org/singularity/flash2:2.2.00--hed695b0_2'
	publishDir "$params.outdir/02_flash"

	script: 
	"""
	flash2 \\
	    $reads \\
	    --output-prefix="${id}.flash2" \\
	    --max-overlap=150 \\
	    | tee -a ${id}_flash2.log
	"""

	output: 
	tuple val(id), path ("${id}.flash2.extendedFrags.fastq"), emit: merged_reads
	path "${id}_flash2.log", emit: flash2_log
	
}

process BOWTIE2 {

	input: 
	path (bowtie2_db)
	tuple val(id), path(merged_reads)

	// directives
	container 'https://depot.galaxyproject.org/singularity/mulled-v2-ac74a7f02cebcfcc07d8e8d1d750af9c83b4d45a:f70b31a2db15c023d641c32f433fb02cd04df5a6-0'
	publishDir "$params.outdir/03_bowtie2"

	script: 
	db_name = bowtie2_db.find{it.name.endsWith('.rev.1.bt2')}.name.minus(".rev.1.bt2")
	"""
	bowtie2 \\
	-x $db_name \\
	-U $merged_reads \\
	-S ${id}_bowtie2_merged_${db_name}.sam \\
	--no-unal \\
	|& tee -a ${id}_bowtie2_merged_${db_name}.log

	"""

	output: 
	path "${id}_bowtie2_merged_${db_name}.log", emit: bowtie2_log
	path "${id}_bowtie2_merged_${db_name}.sam", emit: aligned_reads 

}

process KRAKEN2{
	input:
	path(kraken2_db)
	tuple val(id), path(reads)

	// directives
	container 'https://depot.galaxyproject.org/singularity/mulled-v2-8706a1dd73c6cc426e12dd4dd33a5e917b3989ae:c8cbdc8ff4101e6745f8ede6eb5261ef98bdaff4-0'
	publishDir "$params.outdir/04_kraken2"

	script:
	"""
	kraken2 \\
	--paired \\
	--gzip-compressed \\
	$reads \\
	--db $kraken2_db \\
	--output "${id}_kraken2_output.txt" \\
	--report "${id}_kraken2_report.txt" 
	"""

	output:
	path "${id}_kraken2_output.txt", emit: kraken2_output
	path "${id}_kraken2_report.txt", emit: kraken2_report
	path "*", emit: kraken2_report_dir
}

process BRACKEN{
	input:
	path(kraken2_db)
	path(kraken2_report)
	tuple val(id), path(reads)

	// directives
	container 'https://depot.galaxyproject.org/singularity/bracken:2.9--py38h2494328_0'
	publishDir "$params.outdir/05_braken"

	script:
	"""
	bracken \\
	-d $kraken2_db \\
	-i $kraken2_report \\
	-o "${id}_bracken_output.txt" \\
	-w "${id}_bracken_report.txt" 
	"""

	output:
	path "${id}_bracken_output.txt", emit: bracken_output
	path "${id}_bracken_report.txt", emit: bracken_report
}

process KRAKEN_2_KRONA{
	input:
	path(kraken2_report)
	tuple val(id), path(reads)
	
	// directives
	container 'https://depot.galaxyproject.org/singularity/krakentools:1.2--pyh5e36f6f_0'
	publishDir "$params.outdir/06_krona"

	script:
	"""
	kreport2krona.py -r $kraken2_report -o ${id}_krona_report.txt
	"""

	output:
	path "${id}_krona_report.txt", emit: krona_report
}

process SED_KRONA{
	input:
	path(krona_report)
	tuple val(id), path(reads)

	// directives
	publishDir "$params.outdir/06_krona"

	script:
	"""
	sed 's/[a-zA-Z]__//g' $krona_report > ${id}_krona_report_sed.txt
	"""

	output:
	path "${id}_krona_report_sed.txt", emit: sed_krona_report

}

process KT_IMPORT_TEXT{
	input:
	path(sed_krona_report)
	tuple val(id), path(reads)

	// directives
	container 'https://depot.galaxyproject.org/singularity/krona:2.8.1--pl5321hdfd78af_1'
	publishDir "$params.outdir/07_krona_html"

	script:
	"""
	ktImportText $sed_krona_report -o ${id}_krona_report.html 
	"""

	output:
	path "${id}_krona_report.html", emit: krona_report_html

}

process MULTIQC {

	input: 
	path(fastqc_zips) 
	path(bowtie2_log)
	path(flash2_log)
	path(kraken2_report_dir)

	// directives
	container 'https://depot.galaxyproject.org/singularity/multiqc:1.9--pyh9f0ad1d_0'
	publishDir "$params.outdir/08_multiqc"

	script: 
	"""
	multiqc \\
    	    --force \\
    	    --title "metagenomics" \\
		.
	"""

	output: 
	path "*" // the output is whatever multiqc generates
}

