#!/bin/bash
echo "
---------- { Notice } ----------
Please use this script for private use only, not commercial use.

Dependencies: MidiSox (Perl, included and pre-compiled); p2mp (PDFToMusic, pdftomusicpro-1.7.1d.0.run, included but must be executed, will add to PATH automatically); pdftk (typically pre-installed); xml_merge.py (included)

Usage: ./pmerge.sh \"path/to/myfile.pdf\"
 
Debug mode: Edit the first line of this file to: #!/bin/bash -x . You can also disable cleanup by removing the last few lines of this script.
--------------------------------
"
path=$1 # /path/to/stuff/abc.pdf
shelldir=$PWD
file=$(basename "${path}") # abc.pdf
dir=$(dirname "${path}") # /path/to/stuff/ 
cd "$dir"
mkdir musicxml
echo "Directory $PWD"
pages=$(pdftk "$file" dump_data | grep NumberOfPages | sed 's/[^0-9]*//')
echo "[INFO]: Found $pages pages"
for ((i = 1 ; i <= $pages ; i++)); do
    echo "----------[ Parsing page $i of $pages ]----------"
    # Generate page
    pdftk "$file" cat "$i" output "out$i.pdf"
    # Create MID file (https://www.myriad-online.com/resources/docs/pdftomusicpro/english/command.htm) and XML (Music XML) files
    p2mp "out$i.pdf" -format MID -pathdest "$PWD" >> log.txt
    p2mp "out$i.pdf" -format XML -pathdest "$PWD/musicxml/" >> log.txt
done
count=$((pages))

midarr=( $(printf 'out%d.mid\n' $(seq 1 $pages)) )

# Combine midi files
"$shelldir/midisox_pl.pl" "${midarr[@]}" "RESULT.mid"

echo "----------[ Cleanup ]----------"
# Cleanup
rm -rvf out*.pdf
rm -rvf out*.mid
