# pdf-omr-pmerge
Listen to PDF sheet music by converting it to a playable MIDI, MusicXML, or Musescore MSCZ file per page. The script is intended to be a super quick and easy tool, see `Usage` [below](#usage). Thanks to dependencies [listed below](#more-stuff).
<p align="center">
  <img src="media/sample_out.png" style="text-align: center" />
  </br>
  <i>Playable output extracted from original <a href="https://github.com/kaisubr/pdf-omr-pmerge/raw/master/media/original.pdf">PDF file</a></i>
</p>

## Usage
Usage is very simple. You just need to provide a PDF file. 

```bash
./pmerge.sh "path/to/myfile.pdf"
```

The outputs will be `RESULT.mid` in the same directory, and MusicXML files for each page in `musicxml/` (these can be opened with software such as MuseScore or Finale).

## Setting up
All dependencies (p2mp OMR, MIDISox for Perl) are provided in the repository, apart from `pdftk`. Optionally install `qpdf` if you are dealing with encrypted PDFs. Optionally provide MuseScore to generate MIDI files (I've found that this typically outputs a smaller size MIDI file).

```bash
git clone "https://github.com/kaisubr/pdf-omr-pmerge.git"
sudo apt-get install "pdftk"
chmod +x pdftomusicpro-1.7.1d.0.run
./pdftomusicpro-1.7.1d.0.run
which p2mp

# Install module
cd MIDI-Perl-0.83
perl Makefile.PL
make
make test
sudo make install
cd ..

# Install qpdf, optional
sudo apt-get install qpdf 

# Provide MuseScore, optional 
# (Alternatively, you can use mscore3 from the repositories, and adjust script accordingly)
dir = $PWD
cd my/musescore/directory
cp "MuseScore-3.4.2-x86_64.AppImage" "$dir/MuseScore-3.4.2-x86_64.AppImage"
cd $dir
```

## Known issues and solutions
* Password-protected PDFs:
     - They can be decrypted using qpdf. Edit the script to provide a password with `qpdf -password=<password> -decrypt input.pdf decrypted.pdf`

## More stuff
Please use this script for private use only, not commercial or third-party use, and follow licenses provided by authors of dependencies.

Thanks to dependencies: MidiSox (Perl, [readme](https://github.com/kaisubr/pdf-omr-pmerge/blob/master/MIDI-Perl-0.83/README)); p2mp (PDFToMusic, pdftomusicpro-1.7.1d.0.run, included but must be executed, will add to /usr/bin automatically); pdftk (typically pre-installed)
 
Debug mode: Edit the first line of this file to: `#!/bin/bash -x`. You can also disable cleanup by removing the last few lines of this script.
