#!/bin/bash

sudo apt-get install pdftk
sudo apt-get install qpdf 

chmod +x pdftomusicpro-1.7.1d.0.run
./pdftomusicpro-1.7.1d.0.run

which p2mp

wget -nc "https://github.com/musescore/MuseScore/releases/download/v3.4.2/MuseScore-3.4.2-x86_64.AppImage"
chmod +x MuseScore-3.4.2-x86_64.AppImage
