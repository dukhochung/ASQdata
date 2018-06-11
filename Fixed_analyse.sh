#!/bin/bash
#PBS -A UQ-SCI-SCMB
#PBS -l nodes=1:ppn=6,mem=60GB,walltime=03:00:00
#PBS -m n



##### Set Job info
JOB_TITLE=Test_data-join_multsplit_otu
QSUB_REQUEST="nodes=1:ppn=6,mem=60GB,walltime=03:00:00"


#Load Modules
module load trimmomatic
module load qiime-modules/1.9.1



#Metrics for the run
TOTAL_START_TIME=$(date +%s)


#Directories and files
#qsub this job from within the /30days/your_uq_username/ so the /30days/your_uq_username/ directory will be set as the job directory
#The illumina primers file will need to be available in the /30days/your_uq_username/
JOB_DIR=$TMPDIR/$PBS_JOBID.$JOB_TITLE
INPUT_DIR=$JOB_DIR/input
LOG_FILE=$JOB_DIR/log.txt


#Set up the run
mkdir -p $INPUT_DIR


#Write job_id and start time in log file
printf '=%.0s' {1..40} > $LOG_FILE
nowdate=$(date +"%d-%m-%Y")
nowtime=$(date +"%H:%M")
echo -e ""
echo -e "\nJob start date & time: $nowdate \t $nowtime \n" >> $LOG_FILE
echo -e "JOB_ID: $PBS_JOBID \n" >> $LOG_FILE
echo -e "JOB_TITLE: $JOB_TITLE \n" >> $LOG_FILE

# put matching request info as above #PBS script
echo -e "$QSUB_REQUEST \n" >> $LOG_FILE
printf '=%.0s' {1..40} >> $LOG_FILE



#Specify absolute paths of raw fastq, primer/ref, and all necessary files to copy them to the input directory.

Raw_files=/30days/s4468358/projects/pimelea/job_submissions/raw_files_for_test/*
Trim_primers=/30days/s4468358/projects/pimelea/data/exp/2_Trimmomatic/primers/illumina_primers_341F_806R_revisedRG13112017.txt
OTU_ref_file=/30days/s4468358/projects/pimelea/data/exp/5_pick_openref_otus/reference_files/silva_132_97_16S.fna
Mapping_file_for_SplitLib=/30days/s4468358/projects/pimelea/data/exp/4_split_reads/ASQ_data_mapping.txt # copied after joining step

#copy them into input dir
cp -pr $Raw_files $INPUT_DIR
cp -pr $Trim_primers $INPUT_DIR
cp -pr $OTU_ref_file $INPUT_DIR
cp -pr $Mapping_file_for_SplitLib $INPUT_DIR

#Move to the compute node
cd $INPUT_DIR


##################################################################
## Trimmomatic Code
##################################################################
# Renamed the output files to use only the Forward and Reverse "Paired" files to $basename_R1_00X in further analysis,
# leaving Forward and Reverse "Unpaired" files named differently to separate.
# The bash script runs through each forward sequence files and finds their matching reverse pairs,
# as inputs for Trimmomatic Paired End script.

#record time logs
START_TIME=$(date +%s)

i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
for f1 in *_R1.fastq.gz

do
        #basename='s'
        #f2=${f1%%_R1.fastq.gz}"_R2.fastq.gz"
        #java -jar /opt/biotools/trimmomatic/trimmomatic-0.35.jar PE $f1 $f2 $basename$i"_R1"".fq.gz" $basename"_1U.fq.gz" $basename$i"_R2"".fq.gz" $basename"_2U.fq.gz" ILLUMINACLIP:illumina_primers_341F_806R_revisedRG13112017.txt:2:40:15 SLIDINGWINDOW:4:15 MINLEN:200
        #i=$((i+1))

	#original
	#basename=${f1%%'_R1.fastq.gz'}
	basename=${f1/%-*/}"s$i"
	f2=${f1%%_R1.fastq.gz}"_R2.fastq.gz"
	java -jar /opt/biotools/trimmomatic/trimmomatic-0.35.jar PE $f1 $f2 $basename"_R1_$(printf "%03d" $i)"".fq.gz" $basename"_1U.fq.gz" $basename"_R2_$(printf "%03d" $i)"".fq.gz" $basename"_2U.fq.gz" ILLUMINACLIP:illumina_primers_341F_806R_revisedRG13112017.txt:2:40:15 SLIDINGWINDOW:4:15 MINLEN:200
        i=$((i+1))
done


END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo -e "\n Trimmomatic took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE

#the trimmomatic results end up in $INPUT_DIR
#transfer trimmomatic output to a directory called 'trimmomatic_results'
#separate 'paired' and'unpaired' output to a different directories, called 'paired' and 'unpaired'
mkdir $JOB_DIR/trimmomatic_results/
mkdir $JOB_DIR/trimmomatic_results/paired/
mkdir $JOB_DIR/trimmomatic_results/unpaired/
for file in $INPUT_DIR/*; do
	if [[ $file == *"U.fq.gz" ]]; then
		mv $file $JOB_DIR/trimmomatic_results/unpaired/
	elif [[ $file == *[0-9].fq.gz ]]; then
		mv $file $JOB_DIR/trimmomatic_results/paired/
	fi
done

##rename paired files to replace any '-' in the file names to '.'
#cd $JOB_DIR/trimmomatic_results/paired/
#for f in ./*; do 
#	mv $f $JOB_DIR/trimmomatic_results/paired/"$(echo $f | sed s/-/./g)"; 
#	done
##echo 80956.awongmgmr1.Test_data-dots_split/trimmomatic_results/paired/* | xargs -n 1 basename

###############################
## QIIME
## join_paired_ends.py
###############################
START_TIME=$(date +%s)
cd $JOB_DIR/trimmomatic_results/paired/
i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
for f1 in *_R1_*
do
        basename=${f1%%_R1_*}
        f2= $(echo $f1 | sed 's/R1/R2/')
	join_paired_ends.py \
	-f $f1 \
	-r $f2 \
	-o $JOB_DIR/multiple_join_output/$basename \
        i=$((i+1))
done


END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "join_paired_ends.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE


###################################################################
### QIIME
### multiple_join_paired_ends.py Code
###################################################################
##modules are already loaded in the beginning of the script
#START_TIME=$(date +%s)
#
##Run multiple_join_paired_ends.py
#multiple_join_paired_ends.py \
#-i $JOB_DIR/trimmomatic_results/paired/ \
#-o $JOB_DIR/multiple_join_output/ \
##--include_input_dir_path \
##--remove_filepath_in_name 
#
###remove all fastq.un1, fastq.un2 files, leaving only fastq joined files
#for dir in $JOB_DIR/multiple_join_output/*/; do 
#	for i in $dir/*; do 
#		if [[ $i == *"un"[1-2]* ]]; then 
#			rm $i
#		fi 
#		done 
#	done
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "multiple_join_paired_ends.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE


################################
### QIIME
### split_libraries_fastq.py
################################
#START_TIME=$(date +%s)
#
##get all the join files in each output directory and have them in a variable called 'input' (comma-separated)
##-- to input all files as a whole in one script
#joinfiles=($JOB_DIR/multiple_join_output/*)
#input=$(echo "${join_files[@]}" | sed 's/ /,/g')
#
#split_libraries_fastq.py \
#-i $(echo $input) \
#-o $JOB_DIR/multiple_split_output/ \
#-m $INPUT_DIR/ASQ_data_mapping.txt \
#--barcode_type 'not-barcoded' \
#--sample_ids $(echo $input)
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "split_libraries_fastq.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE


##################################################################
## QIIME
## multiple_split_libraries_fastq.py Code
##################################################################
START_TIME=$(date +%s)

##copy mapping file into the output dir for split libraries step
#cp -pr $Mapping_file_for_SplitLib $JOB_DIR/multiple_join_output/

#delete log file
rm $JOB_DIR/multiple_join_output/*.txt 

#Run multiple_split_libraries_fastq.py
#sampleid_by_file method uses the file or directory names as sample ids
#include dir path option uses the dir paths for each input files since all input filenames are same
#remove filepath avoids the file paths actually shoing in the output filename
multiple_split_libraries_fastq.py \
-i $JOB_DIR/multiple_join_output/ \
-o $JOB_DIR/multiple_split_output/ \
--include_input_dir_path \
--remove_filepath_in_name

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "multiple_split_libraries_fastq.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE

##################################################################
## QIIME
## pick_open_reference_otus.py (Computer Intensive)
##################################################################
START_TIME=$(date +%s)

#Run pick_open_reference_otus.py
pick_open_reference_otus.py \
-i $JOB_DIR/multiple_split_output/seqs.fna \
-o $JOB_DIR/pick_openref_otus_output/ \
-r $INPUT_DIR/silva_132_97_16S.fna

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "pick_open_reference_otus.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE


###################################################################
### QIIME
### parallel_identify_chimeric_seqs.py
###################################################################
#START_TIME=$(date +%s)
#
##Use this code for running in batch
#parallel_identify_chimeric_seqs.py \
#-i $JOB_DIR/pick_openref_otus_output/pynast_aligned_seqs/rep_set_aligned.fasta \
#-o $JOB_DIR/id_chimeric_seqs/chimeric_seqs.txt \
#-m ChimeraSlayer \
#-O 4
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "parallel_identify_chimeric_seqs.py_chimeras took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE
#
#
###################################################################
### QIIME
### filter_fasta.py
### -- filter out the chimera sequences that are identified by above code
###################################################################
#START_TIME=$(date +%s)
#
#filter_fasta.py \
#-f $JOB_DIR/pick_openref_otus_output/pynast_aligned_seqs/rep_set_aligned.fasta \
#-o $JOB_DIR/chimerafree/rep_set_aligned_chimerafree.fasta \
#-s $JOB_DIR/id_chimeric_seqs/chimeric_seqs.txt
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "filter_fasta.py (removing chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE
#
#
###################################################################
### QIIME
### filter_alignment.py
### one more basic filtering to remove any highly variable regions
### outputs one file with _pfiltered.fasta extension
###################################################################
#START_TIME=$(date +%s)
#
#filter_alignment.py \
#-i $JOB_DIR/chimerafree/rep_set_aligned_chimerafree.fasta \
#-o $JOB_DIR/chimerafree/
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "filter_alignment.py (one more basic filtering) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE
#
###################################################################
### QIIME
### Making New phylogenetic tree without the chimeras
### make_phylogeny.py
###################################################################
#START_TIME=$(date +%s)
#
#make_phylogeny.py \
#-i $JOB_DIR/pick_openref_otus_output/pynast_aligned_seqs/rep_set_aligned_pfiltered.fasta \
#-o $JOB_DIR/chimerafree/rep_set_chimerafree.tre
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "make_phylogeny.py (without chimeras) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE
#
#
###################################################################
### QIIME
### Make new otu table with ChimeraFree output
###################################################################
#START_TIME=$(date +%s)
#
#make_otu_table.py \
#-i $JOB_DIR/pick_openref_otus_output/final_otu_map_mc2.txt \
#-o $JOB_DIR/chimerafree/otu_table_nochimera.biom \
#-t $JOB_DIR/pick_openref_otus_output/uclust_assigned_taxonomy/rep_set_tax_assignments.txt \
#-e $JOB_DIR/chimeric_seqs.txt
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "make_otu_table.py (without chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE
#
#
###################################################################
### QIIME
### Return summary of the biom file without chimeras
### biom summarize-table
###################################################################
#START_TIME=$(date +%s)
#
#biom summarize-table \
#-i $JOB_DIR/chimerafree/otu_table_nochimera.biom \
#-o $JOB_DIR/chimerafree/otu_table_nochimera_stats.txt
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "biom summarize-table (without chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE


##################################################################
## Wrap up results ---------------
##################################################################

#delete the original input fastq files and the illumina primers text file to reduce the size and tidy up the output directory
rm -rf $INPUT_DIR/

#put total time taken into the log file

TOTAL_END_TIME=$(date +%s)
TOTAL_DIFF=$(($TOTAL_END_TIME - $TOTAL_START_TIME))
echo "Everything took $(($TOTAL_DIFF / 3600)) hours, $((($TOTAL_DIFF / 60) % 60)) minutes and $(($TOTAL_DIFF % 60)) seconds" >> $LOG_FILE


#Package up the results

# set tar file suffix
TAR_FILE_SUFFIX=$JOB_TITLE.tar

cd $JOB_DIR/../
tar -cf $PBS_JOBID.$TAR_FILE_SUFFIX -C $JOB_DIR/../ .
gzip $PBS_JOBID.$TAR_FILE_SUFFIX
cp -p $PBS_JOBID.$TAR_FILE_SUFFIX.gz $PBS_O_WORKDIR
rm -rf $JOB_DIR*



