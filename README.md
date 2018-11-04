# microbiome_analysis
Scripts in this repository include the following:
  - batch scripts for qiime 1.9.1 workflow 
  - batch scripts for qiime2 workflow
  - create_manifest_from_fastq.py : creates manifest file from the raw illumina fastq files (paired or single end), 
  which is necessary for qiime2 data import step (.qza file)



# create_manifest_from_fastq.py USAGE
The script is an automation of “Fastq manifest” formats section from QIIME2(version 2018.6)'s [Importing data tutorial](https://docs.qiime2.org/2018.8/tutorials/importing/)

create_manifest_from_fastq.py: creates a manifest file from raw illumina fastq files (paired or single end),
which is needed for qiime2 data import step (.qza file)

  1. download the file 'create_manifest_from_fastq.py' and place it into the unix environment to desired directory.
  2. Within the directory, make the script file executable by typing following command <br>
      `chmod +x create_manifest_from_fastq.py`
  3. Execute file with specified input directory (the one with all fastq files) and output file (manifest file with desired name) <br>
    **Use absolute path for 'input directory' and 'output file'")**
    
    Usage: 
      ./create_manifest_from_fastq.py -i <input directory> -o <output file>

    Example: 
      ./create_manifest_from_fastq.py -i /absolute_path_to_inputdir -o /absolute_path_to_outputdir/manifest.txt




# match_otu_ids.py USAGE
Script was written as a workaround for the error following the 'R step':

![cowpi_error_message](https://user-images.githubusercontent.com/40154523/47962693-38de9080-e06c-11e8-948b-585b52bef422.JPG)

  with the message stating something close to:
    Fatal error: Exit code 1 ()
    Error in `$<-.data.frame`(`*tmp*`, "NEW", value = c(130L, 55L, 154L, 95L,  : 
      replacement has 1003 rows, data has 1040

match_otu_ids.py matches the ids between OTU table (txt format) and classification output of Cowpi galaxy workflow 'R step'.


 
  1. match_otu_ids.py takes two input files:
    the classification file output from CowPi’s ‘Extract names’ step <br>
    (file is automatically hidden after running) that contains extracted sequence ids 
    the input feature table file. 

  2. download match_otu_ids.py to desired path
    
  3. execute match_otu_ids.py with python scripting tool (i.e., IDLE)
  
  4. follow the interactive instructions
    **Use absolute path for 'input directory' and 'output file'")**
    
    
    Usage: 
      The user will type in the script interactively following the pop-up instructions in the terminal, once executed.

    Example: 
      ![example_match_ids](https://user-images.githubusercontent.com/40154523/47962862-c622e480-e06e-11e8-8b94-be8e7329da6e.JPG)

      
       

  To change the format of your OTU table from '.biom' to a text file, please use [Convert BIOM formats (Galaxy Version 2.1.5.0)](https://share-galaxy.ibers.aber.ac.uk/?tool_id=toolshed.g2.bx.psu.edu%2Frepos%2Fiuc%2Fbiom_convert%2Fbiom_convert%2F2.1.5.0&version=2.1.5.0&__identifer=bdshirne0e)
