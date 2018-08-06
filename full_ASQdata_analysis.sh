#!/bin/bash
#PBS -A UQ-SCI-SCMB
#PBS -l nodes=1:ppn=6,mem=60GB,walltime=55:00:00
#PBS -m n

##### Set Job info
JOB_TITLE=q1_ASQ_SplitThreshold29_withCoreDivAnalysis
QSUB_REQUEST="nodes=1:ppn=6,mem=60GB,walltime=55:00:00"

#Load Modules
module load trimmomatic
module load qiime-modules/1.9.1

#Metrics for the run
TOTAL_START_TIME=$(date +%s)

#Directories and files
#qsub this job from within the /30days/your_uq_username/ so the /30days/your_uq_username/ directory will be set as the job directory
#The illumina primers file will need to be available in the /30days/your_uq_username/
JOB_DIR=$TMPDIR/$JOB_TITLE.${PBS_JOBID%%.awongmgmr1}
INPUT_DIR=$JOB_DIR/input
LOG_FILE=$JOB_DIR/log.txt

#Set up the run
mkdir -p $INPUT_DIR

#Write job_id and start time in log file
printf '=%.0s' {1..40} > $LOG_FILE
nowdate=date

echo -e "\nJob start date & time: $nowdate \n" >> $LOG_FILE
echo -e "JOB_ID: $PBS_JOBID \n" >> $LOG_FILE
echo -e "JOB_TITLE: $JOB_TITLE \n" >> $LOG_FILE

# put matching request info as above #PBS script
echo -e "$QSUB_REQUEST \n" >> $LOG_FILE
printf '=%.0s' {1..40} >> $LOG_FILE
echo -e "\n"

#Specify absolute paths of raw fastq, primer/ref, and all necessary files to copy them to the input directory.

Raw_files=/30days/s4468358/projects/pimelea/data/fastq/ASQ_Pimelea_all_raw_reads/*
Trim_primers=/30days/s4468358/projects/pimelea/data/exp/2_Trimmomatic/primers/illumina_primers_341F_806R_revisedRG13112017.txt
OTU_ref_file=/30days/s4468358/projects/pimelea/data/exp/5_pick_openref_otus/reference_files/silva_132_97_16S.fna
Mapping_file=/30days/s4468358/projects/pimelea/data/exp/mappingfiles/Mapping_file_Pimelea_all_samples_corrected.txt
Parameter_file=/30days/s4468358/projects/pimelea/data/exp/mappingfiles/q1_parameters.txt

#copy them into input dir
cp -pr $Raw_files $INPUT_DIR
cp -pr $Trim_primers $INPUT_DIR
cp -pr $OTU_ref_file $INPUT_DIR
cp -pr $Mapping_file $INPUT_DIR
cp -pr $Parameter_file $INPUT_DIR

#Move to the compute node
cd $INPUT_DIR


##################################################################
## Trimmomatic
##################################################################
# Renamed the output files to use only the Forward and Reverse "Paired" files to $basename_R1_00X in further analysis,
# leaving Forward and Reverse "Unpaired" files named differently to separate.
# The bash script runs through each forward sequence files and finds their matching reverse pairs,
# as inputs for Trimmomatic Paired End script.

# record time logs
START_TIME=$(date +%s)

i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
for f1 in *_R1.fastq.gz
do
        basename=${f1/%-16S*/}
        f2=${f1%%'_R1.fastq.gz'}"_R2.fastq.gz"
        java -jar /opt/biotools/trimmomatic/trimmomatic-0.35.jar PE $f1 $f2 $basename"_R1_$(printf "%03d" $i)"".fq.gz" $basename"_1U.fq.gz" $basename"_R2_$(printf "%03d" $i)"".fq.gz" $basename"_2U.fq.gz" ILLUMINACLIP:illumina_primers_341F_806R_revisedRG13112017.txt:2:40:15 SLIDINGWINDOW:4:15 MINLEN:200
        i=$((i+1))
done


END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo -e "\nTrimmomatic took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE

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


###############################
## QIIME
## join_paired_ends.py
###############################
START_TIME=$(date +%s)
i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
for f1 in $JOB_DIR/trimmomatic_results/paired/*_R1_*
do
        #basename=${{f1##*/}%%_R1_*}
	basename=${f1%%_R1_*}
        f2=$(echo $f1 | sed 's/R1/R2/')
        join_paired_ends.py \
        -f $f1 \
        -r $f2 \
        -o $JOB_DIR/join_output/$basename/ 
        i=$((i+1))
done


END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo -e "join_paired_ends.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE




################################
### QIIME
### multiple_split_libraries_fastq.py
################################
START_TIME=$(date +%s)
#i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
#for f1 in $JOB_DIR/join_output/*_R1_*
#do
#        #basename=${{f1##*/}%%_R1_*}
#        basename=${f1%%_R1_*}
#        f2=$(echo $f1 | sed 's/R1/R2/')
#        split_libraries_fastq.py \
#        -i $f1 \
#        -r $f2 \
#        -o $JOB_DIR/join_output/$basename/
#        i=$((i+1))
#done


multiple_split_libraries_fastq.py \
-i $JOB_DIR/join_output/ \
-o $JOB_DIR/multiple_split_output/ \
-p $INPUT_DIR/q1_parameters.txt \
--include_input_dir_path \
--remove_filepath_in_name




END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo -e "join_paired_ends.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE




###################################################################
### multiple_split_libraries_fastq.py
###################################################################
##sampleid_by_file method uses the file or directory names as sample ids
##include dir path option uses the dir paths for each input files since all input filenames are same
##remove filepath avoids the file paths actually shoing in the output filename
#START_TIME=$(date +%s)
#
#multiple_split_libraries_fastq.py \
#-i $JOB_DIR/join_output/ \
#-o $JOB_DIR/multiple_split_output/ \
#-q 29 \
#--include_input_dir_path \
#--remove_filepath_in_name
#
#END_TIME=$(date +%s)
#DIFF=$(( $END_TIME - $START_TIME ))
#echo "multiple_split_libraries_fastq.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE

##################################################################
## pick_open_reference_otus.py (Computer Intensive)
##################################################################
START_TIME=$(date +%s)

#Run pick_open_reference_otus.py
pick_open_reference_otus.py \
-i $JOB_DIR/multiple_split_output/seqs.fna \
-o $JOB_DIR/pick_otus/ \
-r $INPUT_DIR/silva_132_97_16S.fna

END_TIME=$(date +%s)
echo "pick_open_reference_otus.py took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds" >> $LOG_FILE

##################################################################
## parallel_identify_chimeric_seqs.py
##################################################################
START_TIME=$(date +%s)

parallel_identify_chimeric_seqs.py \
-i $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned.fasta \
-o $JOB_DIR/pick_otus/chimeric_seqs.txt \
-m ChimeraSlayer \
-O 4

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "parallel_identify_chimeric_seqs.py_chimeras took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE

##################################################################
## filter_fasta.py
## -- filter out the chimera sequences that are identified by above code
##################################################################
START_TIME=$(date +%s)

filter_fasta.py \
-f $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned.fasta \
-o $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned_chimerafree.fasta \
-s $JOB_DIR/pick_otus/chimeric_seqs.txt

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "filter_fasta.py (removing chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE


##################################################################
## filter_alignment.py
## one more basic filtering to remove any highly variable regions
## outputs one file with _pfiltered.fasta extension
##################################################################
START_TIME=$(date +%s)

filter_alignment.py \
-i $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned_chimerafree.fasta \
-o $JOB_DIR/pick_otus/

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))

echo "filter_alignment.py (one more basic filtering) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE

##################################################################
## Making New phylogenetic tree without the chimeras
## make_phylogeny.py
##################################################################
START_TIME=$(date +%s)

make_phylogeny.py \
-i $JOB_DIR/pick_otus/rep_set_aligned_chimerafree_pfiltered.fasta \
-o $JOB_DIR/pick_otus/rep_set_chimerafree.tre

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "make_phylogeny.py (without chimeras) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE


##################################################################
## Make new otu table with ChimeraFree output
##################################################################
START_TIME=$(date +%s)

make_otu_table.py \
-i $JOB_DIR/pick_otus/final_otu_map_mc2.txt \
-o $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-t $JOB_DIR/pick_otus/uclust_assigned_taxonomy/rep_set_tax_assignments.txt \
-e $JOB_DIR/pick_otus/chimeric_seqs.txt

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "make_otu_table.py (without chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE


##################################################################
## Return summary of the biom file without chimeras
## biom summarize-table
##################################################################
START_TIME=$(date +%s)

biom summarize-table \
-i $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-o $JOB_DIR/pick_otus/otu_table_nochimera_stats.txt

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))
echo "biom summarize-table (without chimera) took $(($DIFF / 3600)) hours, $((($DIFF / 60) % 60)) minutes and $(($DIFF % 60)) seconds\n\n" >> $LOG_FILE

alpha_rarefaction.py \
-i $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-o $JOB_DIR/pick_otus/alpha_output_folder \
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-t $JOB_DIR/pick_otus/rep_set.tre



beta_diversity_through_plots.py \
-i $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-o $JOB_DIR/pick_otus/bdiv_plots/ \
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-t $JOB_DIR/pick_otus/rep_set.tre 


# Unweighted UniFrac stats
compare_categories.py \
-i $JOB_DIR/pick_otus/bdiv_plots/unweight_unifrac_dm.txt \
-o $JOB_DIR/pick_otus/bdiv_stats_adonis_unweighted/ \
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-c Clinical_signs \
--method adonis

# Weighted UniFrac stats
compare_categories.py \
-i $JOB_DIR/pick_otus/bdiv_plots/weight_unifrac_dm.txt \
-o $JOB_DIR/pick_otus/bdiv_stats_adonis_weighted/ \
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-c Clinical_signs \
--method adonis

make_distance_boxplots.py \
-d $JOB_DIR/pick_otus/bdiv_plots/unweighted_unifrac_dm.txt \
-o $JOB_DIR/pick_otus/bdiv_plots/unweighted_distance_boxplot
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-f "Clinical_signs" \
--save_raw_data



core_diversity_analyses.py \
-i $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-o $JOB_DIR/pick_otus/core_output \
-m $INPUT_DIR/Mapping_file_Pimelea_all_samples_corrected.txt \
-c Clinical_signs \
-t $JOB_DIR/pick_otus/rep_set_chimerafree.tre \
-e 58782  # used the minimum seq depth from biom summarize-table output58782 



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
TAR_FILE_SUFFIX=$JOB_TITLE.${PBS_JOBID%%.awongmgmr1}.tar

cd $JOB_DIR/../
tar -cf $TAR_FILE_SUFFIX -C $JOB_DIR/../ .
gzip $TAR_FILE_SUFFIX
cp -p $TAR_FILE_SUFFIX.gz $PBS_O_WORKDIR
rm -rf $JOB_DIR*

