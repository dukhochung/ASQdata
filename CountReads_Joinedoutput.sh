##!/bin/bash
"""
This bash script goes through each 'multiple_join_output.py' joined output, 
which are located in separate directories for each sequence samples.
**NOTE**
The extraction of the 'keyword' is done according to their sample naming.
for example, for AJM-239-3-1-16S_AVUVT_ACTGAGCG-ACTGCATA_L001_R1_001/
we use the keyword 'AVUVT', which are included in every header lines, to count the number of joined reads.
"""

##specify the location of the multiple_join_output result directories
Join_output_dir=/30days/s4468358/projects/pimelea/job_submissions/74046.awongmgmr1.TrimJoinSplit/multiple_join_output

#empty the text files if they exist already
truncate -s 0 basenames11
truncate -s 0 dir11
truncate -s 0 ids_samples11
truncate -s 0 sequence_counts_joined.txt
truncate -s 0 counts



#list multiple_join_output directory names (joined read names) into a text file
for dir in $Join_output_dir/*
do
	echo $dir >> dir11
done

#extract the 5 letter characters that will be used as keyword in word count
#**NOTE** the sed command may be editted according to the sample names (sections to remove may be different)
cat dir11 | sed 's/.*16S_//' | sed 's/_.*//' > basenames11
#extract id names to use them as sample ids
cat dir11 | sed 's/.+?(?=[a-zA-Z]{3,}-)//' >  ids_samples11

#search join.fastq files for each joined read samples and search for the number of lines that contain the keyword
for dir in $Join_output_dir/*; do
	if [[ -d "$dir" ]]; then
		grep -f basenames11 $dir/fastqjoin.join.fastq | wc -l >> counts
	fi
done

#paste the id and counts files
paste ids_samples11 counts >> sequence_counts_joined.txt

#clean unnecessary files
rm dir11 basenames11 ids_samples11 counts
