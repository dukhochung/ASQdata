#!/usr/bin/python

"""create_manifest_from_fastq.py: creates a manifest file from raw illumina fastq files (paired or single end),
which is needed for qiime2 data import step (.qza file)"""

__author__	= "Dukho Chung"
__maintainer__	= "Dukho Chung"
__email__	= "dukhochung89@gmail.com"


import re
import os
import sys, getopt

# set script execution method as 'script -i input -o output'
# source: tutorialspoint (http://www.tutorialspoint.com/python/python_command_line_arguments.htm)
def main(argv):
   inputfile = ''
   outputfile = ''
   try:
      opts, args = getopt.getopt(argv,"hi:o:",["ifile=","ofile="])
   except getopt.GetoptError:
      print('./create_manifest_from_fastq.py -i <input directory> -o <output file>')
      sys.exit(2)
   for opt, arg in opts:
      if opt == '-h':
	 print('\n')
         print('##### create_manifest_from_fastq.py Manual#####')
         print("\tPlease use absolute path for 'input directory' and 'output file'")
 	 print('\tUsage: ./create_manifest_from_fastq.py -i <input directory> -o <output file>')
	 print('\tExample: ./create_manifest_from_fastq.py -i /absolute_path_to_inputdir -o /absolute_path_to_outputdir/manifest.txt')
         sys.exit()
      elif opt in ("-i", "--ifile"):
         inputfile = arg
      elif opt in ("-o", "--ofile"):
         outputfile = arg
	 break


# check if given input directory exists. If not, return error message.
#if no fastq files are present in input directory, no output will be given
   if os.path.isdir(inputfile) == True:
	pass
   elif os.path.isdir(inputfile) == False:
	print('error: the input directory does not exist\n\t input absolute file path')

# check if output directory exists, if not, return error message
# also, check if output filename exists already, if so, return error message because we don't want to overwrite.
   # set output_dir as from given '-i' input's beginning to the last '/' match
   output_dir = outputfile[0:outputfile.rindex('/')]

   if os.path.isdir(output_dir) == True:
        pass
   elif os.path.isdir(output_dir) == False:
        print('error: the output directory does not exist\n\t input absolute file path')

   if os.path.isfile(outputfile) == True: 
	print('error: the output file already exists')
   elif os.path.isfile(outputfile) == False:
	pass


# if above usage is satisfied, execute command to create manifest file
   # see if there are R1 or R2 read files in the given input dir
   check_readfiles=[]
   fastq_file_names=['R','fastq']
   for filename in os.listdir(inputfile):
	if all(i in filename for i in fastq_file_names):
		check_readfiles.append(filename)
   # if the list 'check_readfiles' is empty, there are no fastq files in the given input directory
   # therefore return error message

   if not check_readfiles:
	print('error: There are no fastq read files in the given input directory')
	exit() 
   # if there are fastq files present in input directory, proceed to next steps
   elif check_readfiles:
        cmd_abspath = "for s in " + str(inputfile) + "*R*.fastq.gz; do readlink -f $s; done > absfilepath_tempfile_12312312123.txt"
	cmd_sampleid = "for s in " + str(inputfile) + "*R*.fastq.gz; do echo `basename ${s/%-16S*/}`; done > sample-id_tempfile_12312312123.txt"
	cmd_direction = "for s in " + str(inputfile) + "*R*.fastq.gz; do if [[ $s == *'R1'* ]]; then echo 'forward'; elif [[ $s == *'R2'* ]]; then echo 'reverse'; fi done > direction_tempfile_12312312123.txt"
	cmd_paste = "paste -d ',' sample-id_tempfile_12312312123.txt absfilepath_tempfile_12312312123.txt direction_tempfile_12312312123.txt"

	os.system(cmd_abspath)
	os.system(cmd_sampleid)
	os.system(cmd_direction)
	out_base=re.sub(r'.*/','',outputfile)
	os.system(cmd_paste + " > " + out_base)
   #os.system(sed -i '1s/^/sample_id,absolute_filepath,direction\n/' a)
   
# write the header line in the manifest output file.
   with open(out_base, "r+") as f:
        old = f.read() # read everything in the file
        f.seek(0) # rewind
        f.write("sample-id,absolute-filepath,direction\n" + old) # write the new line before

        # remove temp files
        cmd_rm_tempfile="rm *tempfile_12312312123.txt"
        os.system(cmd_rm_tempfile)


if __name__ == "__main__":
   main(sys.argv[1:])

