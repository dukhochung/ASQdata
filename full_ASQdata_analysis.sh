#!/bin/bash
#PBS -A UQ-SCI-SCMB
#PBS -l nodes=1:ppn=6,mem=60GB,walltime=55:00:00
#PBS -m n


#Load Modules
module load trimmomatic
module load qiime-modules/1.9.1

#Directories and files
#qsub this job from within the /30days/your_uq_username/ so the /30days/your_uq_username/ directory will be set as the job directory
#The illumina primers file will need to be available in the /30days/your_uq_username/
JOB_DIR=$TMPDIR/$JOB_TITLE.${PBS_JOBID%%.awongmgmr1}
INPUT_DIR=$JOB_DIR/input

#Set up the run
mkdir -p $INPUT_DIR



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

i=1  #index that will be added at the end of each filename for join_paired_ends identifiers.
for f1 in *_R1.fastq.gz
do
        basename=${f1/%-16S*/}
        f2=${f1%%'_R1.fastq.gz'}"_R2.fastq.gz"
        java -jar /opt/biotools/trimmomatic/trimmomatic-0.35.jar PE $f1 $f2 $basename"_R1_$(printf "%03d" $i)"".fq.gz" $basename"_1U.fq.gz" $basename"_R2_$(printf "%03d" $i)"".fq.gz" $basename"_2U.fq.gz" ILLUMINACLIP:illumina_primers_341F_806R_revisedRG13112017.txt:2:40:15 SLIDINGWINDOW:4:15 MINLEN:200
        i=$((i+1))
done


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



###################################################################
### multiple_split_libraries_fastq.py
###################################################################
#sampleid_by_file method uses the file or directory names as sample ids
#include dir path option uses the dir paths for each input files since all input filenames are same
#remove filepath avoids the file paths actually shoing in the output filename
multiple_split_libraries_fastq.py \
-i $JOB_DIR/join_output/ \
-o $JOB_DIR/multiple_split_output/ \
-q 19 \
-p $INPUT_DIR/q1_parameters.txt \  # parameter file has the -q maximum percent diff value
--include_input_dir_path \
--remove_filepath_in_name


##################################################################
## pick_open_reference_otus.py (Computer Intensive)
##################################################################
#Run pick_open_reference_otus.py
pick_open_reference_otus.py \
-i $JOB_DIR/multiple_split_output/seqs.fna \
-o $JOB_DIR/pick_otus/ \
-r $INPUT_DIR/silva_132_97_16S.fna

##################################################################
## parallel_identify_chimeric_seqs.py
##################################################################
parallel_identify_chimeric_seqs.py \
-i $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned.fasta \
-o $JOB_DIR/pick_otus/chimeric_seqs.txt \
-m ChimeraSlayer \
-O 4

##################################################################
## filter_fasta.py
## -- filter out the chimera sequences that are identified by above code
##################################################################
filter_fasta.py \
-f $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned.fasta \
-o $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned_chimerafree.fasta \
-s $JOB_DIR/pick_otus/chimeric_seqs.txt

##################################################################
## filter_alignment.py
## one more basic filtering to remove any highly variable regions
## outputs one file with _pfiltered.fasta extension
##################################################################
filter_alignment.py \
-i $JOB_DIR/pick_otus/pynast_aligned_seqs/rep_set_aligned_chimerafree.fasta \
-o $JOB_DIR/pick_otus/

END_TIME=$(date +%s)
DIFF=$(( $END_TIME - $START_TIME ))

##################################################################
## Making New phylogenetic tree without the chimeras
## make_phylogeny.py
##################################################################
make_phylogeny.py \
-i $JOB_DIR/pick_otus/rep_set_aligned_chimerafree_pfiltered.fasta \
-o $JOB_DIR/pick_otus/rep_set_chimerafree.tre

##################################################################
## Make new otu table with ChimeraFree output
##################################################################
make_otu_table.py \
-i $JOB_DIR/pick_otus/final_otu_map_mc2.txt \
-o $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-t $JOB_DIR/pick_otus/uclust_assigned_taxonomy/rep_set_tax_assignments.txt \
-e $JOB_DIR/pick_otus/chimeric_seqs.txt


##################################################################
## Return summary of the biom file without chimeras
## biom summarize-table
##################################################################

biom summarize-table \
-i $JOB_DIR/pick_otus/otu_table_nochimera.biom \
-o $JOB_DIR/pick_otus/otu_table_nochimera_stats.txt


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


#Package up the results

# set tar file suffix
TAR_FILE_SUFFIX=${PBS_JOBID%%.awongmgmr1}.tar

cd $JOB_DIR/../
tar -cf $TAR_FILE_SUFFIX -C $JOB_DIR/../ .
gzip $TAR_FILE_SUFFIX
cp -p $TAR_FILE_SUFFIX.gz $PBS_O_WORKDIR
rm -rf $JOB_DIR*

