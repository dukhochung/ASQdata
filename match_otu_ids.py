'''
The script matches the ids between OTU table (txt format)
and classification output of Cowpi galaxy workflow step1.
'''
__author__	= "Dukho Chung"
__maintainer__	= "Dukho Chung"
__email__	= "dukhochung89@gmail.com"




import sys
import os.path


### user types absolute file paths of the input files

otutable = input('\nPlease type in Absolute Path of the input OTU table\n Example    :  C:/path/otutable.txt \n OTU table  :  ')
classification = input('\n\nPlease type in Absolute Path of the input classification file \n Classificantion file is the output of R step in CowPi galaxy workflow \n (it may be in the hidden section of the results window) \n Example    :  C:/path/Classification.data\n Classification file :  ')
output_dir = input('\n\nPlease specify Absolute Path of desired output directory \n Example    :  C:/path/ \n Output directory:  ')

user_input_files = [otutable,classification]
user_input_dir = [output_dir]


### check if given input files and directories exist
for i in user_input_files:        
    if os.path.isfile(i) == False:
        print('\n\n')
        raise Exception('FileNotFoundError:\nUser given path does not exist. \nPlease check your path again \nExample    :  C:/path/otutable.txt \nGiven path :  {}'.format(i))
        sys.exit("error")

    else:
        pass

for j in user_input_dir:
    if os.path.isdir(j) == False:
        print('\n\n')
        raise Exception('FileNotFoundError:\nUser given path does not exist. \nPlease check your path again \nExample    :  C:/path/ \nGiven path :  {}'.format(j))
        sys.exit("error")
        
    else:
        print('###################################')



### extract the lines with "Query >" from the Classification file, which contains the extracted ids from original repseq file
extracted_ids=''
with open(classification,'r') as file:
    lines = file.readlines()
    for line in lines:
        if 'Query >' in line:
            extracted_ids += line.replace('Query >','')

extracted_ids = extracted_ids.splitlines()



### match the extracted ids from repseq file to the otu table ids.
### keep only the matching otu from the otu table and save them into 'newfile.txt'
with open('matched_otu_table.txt','w') as newfile:
    with open(otutable) as o:
        otus = o.readlines()
        extracted_ids.sort()
        otus.sort()
        index=0
        hit=0

        for extracted_id in extracted_ids:
            already_set = False
##            print(("\r%.2f" % (index/len(extracted_ids)*100)),'%', '|| hits:', hit, end='')   # prints status
            print(("%.2f" % (index/len(extracted_ids)*100)),'%', '|| hits:', hit)
            sys.stdout.flush()
            index+=1

            for otu in otus:
                if (otu.partition('\t')[0]) == extracted_id.partition('\n')[0] and (not already_set):
                    hit+=1
                    newfile.write(otu)
                    already_set = True
                    otus.remove(otu)
                elif already_set == True:
                    break

