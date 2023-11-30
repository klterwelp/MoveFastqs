#!/bin/bash
# this script copies data into separate folders based on a csv file

data_dir="/hpc/group/kimlab/Qiime2/seqOrder8582"
# must be full path of where the data is stored
projects_csv="pool-table.csv"
# csv that has sample-id and folders as two columns. 
# folders will split the data into the different projects so name accordingly
wrkdir="/hpc/group/kimlab/Qiime2" 
# directory that leads to the directory where the split data folders will go
declare -A FsamplePathArray
declare -A RsamplePathArray
# start declarative arrays that will hold the sample id and path information depending on R1 or R2

while read -r input_file; do
f_suffix=$(echo "$input_file" | awk -F'_' '{for (i=NF-3; i<=NF; i++) printf "%s%s", "_", $i}')
#awk separates the filename into fields with _, takes last four fields and prints them with "_" between each 
sample_id=$(basename "$input_file" "$f_suffix")
absolute_path=$(realpath "$input_file")
    if [[ $f_suffix == *"_R1_"* ]]; then
    direction="forward"
    FsamplePathArray["$sample_id"]="$absolute_path"
    path="${FsamplePathArray[$sample_id]}"
    else 
        if [[ $f_suffix == *"_R2_"* ]]; then
        direction="reverse"
        RsamplePathArray["$sample_id"]=$absolute_path
        path="${RsamplePathArray[$sample_id]}"
        fi
    fi
echo "Sample ID: $sample_id, Path: $path, direction: $direction" 
done < <(find "$data_dir" -type f -name "*.fastq.gz")

# find files in the data directory that match *.fastq.gz 
# for each fastq.gz file, remove the suffix and path to create sample-id
# add to declarative array the sample id as key and the value as the filepath
# < <(find) uses process subsitution so that the declarative array values exist outside a subshell

while IFS=',' read -r sampleID project
# read projects_csv file and separate columns into sample ID and folder
do
    project=$(echo "$project" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # remove trailing spaces from folder name and sampleID
     NewPath="$wrkdir/$project/data" 
        if [ -d "$NewPath" ]; then 
            echo -e "$project data folder exists" 
        else 
            echo -e "$project data folder does not exist, making now..." 
            mkdir -p "$NewPath"
    fi
# Test whether data folder has already been created
# If it doesn't exist, make the folder 

if [ "${FsamplePathArray[$sampleID]+_}" ]
    then 
    # Forward sample exists in data folder
        OldPathF="${FsamplePathArray[$sampleID]}"
        filenameF=$(basename "$OldPathF")
        newfileF="$NewPath/$filenameF"
            if [ ! -f $newfileF ]; then
            cp "$OldPathF" "$NewPath"
            else 
            echo "$newfileF already exists" 
            fi
        else
            echo "$sampleID forward fastq.gz does not exist in data folder"
    fi
if [ "${RsamplePathArray[$sampleID]+_}" ]
    then 
    # Forward sample exists in data folder
        OldPathR="${RsamplePathArray[$sampleID]}"
        filenameR=$(basename "$OldPathR")
        newfileR="$NewPath/$filenameR"
            if [ ! -f "$newfileR" ]; then
            cp "$OldPathR" "$NewPath"
            else 
            echo "$newfileR already exists" 
            fi
        else
            echo "$sampleID reverse fastq.gz does not exist in data folder"
    fi
# Test whether sampleID exists in the associative array 
# If it exists, copy the file to the new folder 
# If it doesn't say it doesn't exist 
done < <(tail -n +2 "$projects_csv")
# tail skips the first line of the csv file

