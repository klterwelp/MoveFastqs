#!/bin/bash
# this script copies data into separate folders based on a csv file
# INPUT: 
#   - data_dir: location of downloading sequencing data
#   - projects_csv: location of csv containing sample names and associated projects
#   - wrkdir: directory where the data will be moved to (subfolders named after projects)
# OUTPUT: 
#   - Project folder[s] containing fastq, checksum, and .rtf files split based on .csv input
#   - log file with information on stderr / stdout 
#---------------fill out variables ------------------------------------------------#
data_dir="/hpc/group/kimlab/Qiime2/seqOrder8799"
# must be full path of where the data is stored
projects_csv="sorting.csv"
# csv that has sample-id and folders as two columns. 
# folders will split the data into the different projects so name accordingly
# script skips the first line. 
# Assumes sampleID is in the first column and project folder is in the second column
wrkdir="/hpc/group/kimlab/Qiime2" 
# directory that leads to the directory where the split data folders will go
# ---------------- automatic variables --------------------------------------------#
current_time=$(date "+%Y%m%d_%H%M%S")
# acquire current time
checksumFile=$(find $data_dir/*.checksum)
# checksum file in the data directory
READMEfile=$(find $data_dir/*.rtf)
# readme file in the data directory 
outputChk="${data_dir}/00-checksum"
outputMv="${data_dir}/00-log"

# ---------------- script start ------------------------------------- # 
exec &>> "${data_dir}"/00-log/movefiles_"${current_time}".log
# all output will go to a file called movefiles_*.log 

# making new output folder
echo -e "creating new output folders" 
mkdir -p "${data_dir}"/{"00-log","00-checksum"}

# CHECKING CHECKSUMS ------------------------------------------------- #

# if previous output folder exists, delete it 
echo -e "checking for old folders, will remove to rerun analysis if md5sums are not identical" 

if [ -d "$outputChk" ]
then 
    echo -e "Previous output folder exists. Verifying existing checksum file. " 
    current_time=$(date "+%Y%m%d_%H%M%S")
    md5sum "${data_dir}/"*.fastq.gz > "${outputChk}/dwnld_${current_time}.checksum"
        if cmp -s "${outputChk}/dwnld_${current_time}.checksum" "${outputChk}/"dwnld.checksum; then
            echo "The md5sum files are identical."
            if cmp -s "$checksumFile" "${outputChk}/seq.checksum"; then 
                echo "The sequencing checksum files are also identicial."
            else
                echo "The sequencing checksum files are not identical. Need to test checksums again. Deleting old output folders"
                rm -Rfv -- "$outputChk"
            fi
        else
            echo "The md5sum files are not identical. Need to generate new md5sums. Deleting old output folders"
            echo "Listing non-matching lines..."
            grep -Fxvf "${outputChk}/dwnld_${current_time}.checksum" "${outputChk}/"dwnld.checksum
            rm -Rfv -- "$outputChk"
        fi
fi 
    # -R deletes recursively, -f ignore non-existant files, -v verbose
    # '--'' : no more flags for rm command 

# making new import folders 
echo -e "creating new output folders" 
mkdir -p "${outputChk}"

# Does sequencing checksum file exist? 
echo "Sequencing checksum text file: $checksumFile"
if [ ! -f "$checksumFile" ]; then
    echo "Error: File $checksumFile not found. Exiting script."
    exit 1
    else
        echo "File: $checksumFile found. Copying to output folder"
        cp "$checksumFile" "${outputChk}/seq.checksum"
fi

# Make declarative array to hold sequencing checksum information
declare -A seqChecksumsArray

echo "Making declarative array to hold sequencing checksum info..."

while IFS=' ' read -r filename checksum; do
    seqChecksumsArray["$filename"]=$checksum
done < "$checksumFile"

# Make checksum array for downloaded fastq.gz files 
echo "Generate downloaded fastq file checksums"

md5sum "${data_dir}/"*.fastq.gz > "${outputChk}/"dwnld.checksum

echo "Making declarative array to hold downloaded checksum info..."

declare -A dwnlChecksumsArray 

while IFS=' ' read -r checksum fullpath; do
    filename=$(basename "$fullpath")
    dwnlChecksumsArray["$filename"]=$checksum
    done < "${outputChk}/dwnld.checksum"

# Test that filenames match 
echo "Identifying any files not downloaded..."

for filename in "${!seqChecksumsArray[@]}"; do
    dwnlChk=${dwnlChecksumsArray["$filename"]}

    if [ -z "$dwnlChk" ]; then 
        match="FALSE"
        echo "$filename" >> "${outputChk}/"not_downloaded.txt 
        else
        match="TRUE"
        echo "$filename" >> "${outputChk}/"downloaded.txt 
    fi
echo "$filename $match" >> "${outputChk}/"files.checksum
done
notdwl=$(wc -l < "${outputChk}/"not_downloaded.txt)
dwl=$(wc -l < "${outputChk}/"downloaded.txt)

echo "There are $notdwl files that were not downloaded but exist as files in seq checksum 
List of files in not_downloaded.txt"
echo "There are $dwl files that were downloaded AND exist as files in seq checksum. 
List of files in downloaded.txt"

echo "$dwl/${#dwnlChecksumsArray[@]} downloaded files exist within the sequencing checksum"

# Test that checksums match
echo "Testing checksums for matches between seq and downloaded checksums..."

for filename in "${!dwnlChecksumsArray[@]}"; do
    dwnlChk=${dwnlChecksumsArray["$filename"]}
    sqtChk=${seqChecksumsArray["$filename"]}

    if [ -z "$sqtChk" ]; then 
       match="not in seq.checksum"
       else 
        if [[ "$sqtChk" == "$dwnlChk" ]]; then
        match="TRUE"
        else
        match="FALSE"
        fi
    fi
    echo "$filename $match" >> "${outputChk}/"match.checksum
    done

numTrue=$(grep -c "TRUE" "${outputChk}/"match.checksum)
numFalse=$(grep -c "FALSE" "${outputChk}/"match.checksum)
echo "There are $numTrue fastq that match seq checksums.
There are $numFalse fastq that do NOT match seq checksums."

# MOVING FILES ---------------------------- # 
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
    checksumProj=$(find "$wrkdir/$project/data"/*.checksum)
    READMEProj=$(find "$wrkdir/$project/data"/*.rtf)
        if [ -d "$NewPath" ]; then 
            echo -e "$project data folder exists" 
            echo -e "adding checksum and README to data folder, if not added" 
            if [ -f "$checksumProj" ]; then 
                echo -e "checksum already in folder"
                else
                echo -e "adding checksum to $NewPath" 
                cp "$checksumFile" "$NewPath"
            fi
                # add checksum if not in the existing folder
            if [ -f "$READMEProj" ]; then 
                echo -e "README already in folder"
                else 
                echo -e "adding README to $NewPath"
                cp "$READMEfile" "$NewPath"
            fi
                # add readme file if not in the existing folder
        else 
            echo -e "$project data folder does not exist, making now..." >> "${outputMv}"/folders_created.txt
            mkdir -p "$NewPath"
            echo -e "adding checksum and README to data folder" 
            cp "$checksumFile" "$NewPath"
            cp "$READMEfile" "$NewPath"
    fi
# Test whether data folder has already been created
# If it doesn't exist, make the folder 

if [ "${FsamplePathArray[$sampleID]+_}" ]
    then 
    # Forward sample exists in data folder
        OldPathF="${FsamplePathArray[$sampleID]}"
        filenameF=$(basename "$OldPathF")
        newfileF="$NewPath/$filenameF"
            if [ ! -f "$newfileF" ]; then
            cp "$OldPathF" "$NewPath"
            else 
            echo "$newfileF already exists" >> "${outputMv}"/existing_names.txt
            fi
        else
            echo "$sampleID forward fastq.gz does not exist in data folder" >> "${outputMv}"/no_data_names.txt 
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
            echo "$newfileR already exists" >> "${outputMv}"/existing_names.txt
            fi
        else
            echo "$sampleID reverse fastq.gz does not exist in data folder" >> "${outputMv}"/no_data_names.txt 
    fi
# Test whether sampleID exists in the associative array 
# If it exists, copy the file to the new folder 
# If it doesn't say it doesn't exist 
done < <(tail -n +2 "$projects_csv")
# tail skips the first line of the csv file

