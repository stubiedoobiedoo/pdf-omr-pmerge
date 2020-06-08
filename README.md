# pdf-omr-pmerge
Convert PDF sheet music to a playable MIDI file, and MusicXML for each page. The script is intended to be a super quick and easy tool, see `Usage` below.

## Usage
Usage is very simple. You just need to provide a PDF file. 

```bash
./pmerge.sh "path/to/myfile.pdf"
```

The outputs will be `RESULT.mid` in the same directory, and MusicXML files for each page in `musicxml/` (these can be opened with software such as MuseScore or Finale).

## Setting up
All dependencies (p2mp OMR, MIDISox for Perl) are provided in the repository, apart from `pdftk`.

```bash
git clone "https://github.com/kaisubr/pdf-omr-pmerge.git"
sudo apt-get install "pdftk"
chmod +x pdftomusicpro-1.7.1d.0.run
./pdftomusicpro-1.7.1d.0.run
p2mp 
# You may kill p2mp if all steps run successfully.
```

## Known issues and solutions
* Password-protected PDFs (or) pdftk does not recognize encryption:
     - They should be decrypted using qpdf. Edit the script to provide a password with `qpdf -password=<your-password> -decrypt input.pdf decrypted.pdf`

## More stuff
Please use this script for private use only, not commercial use.

Dependencies: MidiSox (Perl, included and pre-compiled); p2mp (PDFToMusic, pdftomusicpro-1.7.1d.0.run, included but must be executed, will add to /usr/bin automatically); pdftk (typically pre-installed)
 
Debug mode: Edit the first line of this file to: #!/bin/bash -x . You can also disable cleanup by removing the last few lines of this script.
