#!/bin/bash
echo "
---------- { Notice } ----------
 _  _ _  _  _ _  _ 
|_)| | |(/_| (_|(/_     
|             _|   

Please use this script for private use only, not commercial use.
Usage: conda activate velo && ./pmerge_m21.sh \"path/to/myfile.pdf\"
 
Debug mode: Edit the first line of this file to: #!/bin/bash -x . You can also disable cleanup by removing the last few lines of this script.
--------------------------------
"
path=$(readlink -f $1) # /path/to/stuff/abc.pdf # path=$1
shelldir=$PWD
file=$(basename "${path}") # abc.pdf
dir=$(dirname "${path}") # /path/to/stuff/ 
cd "$dir"
mkdir -p musicxml
echo "Directory $PWD"
qpdf --decrypt "$file" "decrypted.pdf"
pages=$(pdftk "decrypted.pdf" dump_data | grep NumberOfPages | sed 's/[^0-9]*//')
echo "[INFO]: Found $pages pages"
for ((i = 1 ; i <= $pages ; i++)); do
    echo "----------[ Parsing page $i of $pages ]----------"
    # Generate page
    pdftk "decrypted.pdf" cat "$i" output "out$i.pdf"
    # Create MID file (https://www.myriad-online.com/resources/docs/pdftomusicpro/english/command.htm) and XML (Music XML) files
    # p2mp "out$i.pdf" -format MID -pathdest "$PWD" >> log.txt # $PWD is same as $dir
    p2mp "out$i.pdf" -format XML -pathdest "$PWD/musicxml/" >> log.txt
done
count=$((pages))

echo "----------[ Cleanup p2mp ]----------"
# Cleanup temp pdf & individual mid
rm -rvf out*.pdf
rm -rvf decrypted.pdf
rm -rvf out*.mid
rm -rvf log.txt

# Combine xml files
cd musicxml
xmlarr=( $(printf 'out%d.xml\n' $(seq 1 $pages)) )
python "$shelldir/mxcat_m21.py" -f "${xmlarr[@]}" -o "$dir/result.xml"

# Convert final xml to a compressed format
"$shelldir/MuseScore-3.4.2-x86_64.AppImage" -o "$dir/result_compressed.mscz" "$dir/result.xml"

# Generate high-quality MuseScore midi
"$shelldir/MuseScore-3.4.2-x86_64.AppImage" -o "$dir/result.mid" "$dir/result_compressed.mscz"

echo "----------[ Cleanup mscore3 ]----------"
# Cleanup individual mid, but must keep XML files!
rm -rvf out*.mid

# cd musicxml && clear && echo -e "\n\n\n\n\n" && ls -1 && cd .. && ls | grep "result" && echo -e "\n\n\n\n\n\n\n\n"
