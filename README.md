# microbiome_analysis
Scripts in this repository include the following:
  - batch scripts for qiime 1.9.1 workflow 
  - batch scripts for qiime2 workflow
  - create_manifest_from_fastq.py : creates manifest file from the raw illumina fastq files (paired or single end), 
  which is necessary for qiime2 data import step (.qza file)


# create_manifest_from_fastq.py USAGE
create_manifest_from_fastq.py: creates a manifest file from raw illumina fastq files (paired or single end),
which is needed for qiime2 data import step (.qza file)

  1. download the file 'create_manifest_from_fastq.py' and place it into the unix environment to desired directory.
  2. Within the directory, make the script file executable by typing following command <br>
      `chmod +x create_manifest_from_fastq.py`
  3. Execute file with input directory (the one with all fastq files) and output file (manifest file with desired name) given. <br>
    **Use absolute path for 'input directory' and 'output file'")**

    Usage: 
      ./create_manifest_from_fastq.py -i <input directory> -o <output file>

    Example: 
      ./create_manifest_from_fastq.py -i /absolute_path_to_inputdir -o /absolute_path_to_outputdir/manifest.txt
