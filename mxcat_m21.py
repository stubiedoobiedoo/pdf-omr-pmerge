import argparse
import xml.etree.ElementTree as ET
from music21 import *
from music21.musicxml import *
from collections import defaultdict

##### monkey patch start
def warnP(t):
    print("(!) %s" % (t))

def typeToMusicXMLType_PATCH(value):
    if value == 'longa':
        return 'long'
    elif value == '2048th':
        warnP('Cannot convert "2048th" duration to MusicXML (too short).')
        return '1024th'
        # raise MusicXMLExportException('Cannot convert "2048th" duration to MusicXML (too short).')
    elif value == 'duplex-maxima':
        raise MusicXMLExportException(
            'Cannot convert "duplex-maxima" duration to MusicXML (too long).')
    elif value == 'inexpressible':
        warnP("Cannot convert inexpressible durations to MusicXML.")
        return '1024th'
        # raise MusicXMLExportException('Cannot convert inexpressible durations to MusicXML.')
    elif value == 'complex':
        raise MusicXMLExportException(
            'Cannot convert complex durations to MusicXML. '
            + 'Try exporting with makeNotation=True or manually running splitAtDurations()')
    elif value == 'zero':
        raise MusicXMLExportException('Cannot convert durations without types to MusicXML.')
    else:
        return value
# use terminal w/ imports to verify
# module name is m21ToXml:
    # https://github.com/cuthbertLab/music21/blob/master/music21/musicxml/m21ToXml.py#L63
musicxml.m21ToXml.typeToMusicXMLType = typeToMusicXMLType_PATCH
##### monkey patch end

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Concatenate MusicXML files')

    parser.add_argument('-f', metavar='FILES', type=str, nargs='+', help='Files to concatenate.')
    parser.add_argument('-o', metavar='OUT', type=str, nargs=1, help='Output file name.')

    # get arguments
    args = parser.parse_args()
    print(args)

    # args.names with nargs + as list
    files = list(args.f)
    output = str(list(args.o)[0])
    n, parts = 0, []

    parts = defaultdict( lambda: stream.Part(id='part%d' % (len(parts))) )

    sTot = stream.Stream()
    offs = 0
    for f in files:
        sCur = converter.parse(f)
        partitioned = instrument.partitionByInstrument(sCur)
        n = max(n, len(partitioned))
        for k in partitioned:
            pt_name = str(k.getInstrument())
            _ = parts[pt_name]
    print(parts)
    for f in files:
        print(offs, end="", flush=True)
        sCur = converter.parse(f)
        partitioned = instrument.partitionByInstrument(sCur)
        for pt in partitioned:
            pt_name = str(pt.getInstrument())
            # append(pt), insert(offset, item), insertAndShift(offset, item)
            ptSoFar = parts[pt_name]
            ptSoFar.insert(offs, pt.flatten())
            print(".", end="", flush=True)
        for ki in range(len(partitioned), n):
            ptSoFar = parts[list(parts.keys())[ki]]
            eOffs = offs + len(sCur);
            r = note.Rest(); r.duration = duration.Duration(1)
            ptSoFar.insert(eOffs, r)
            print(".", end="", flush=True)
        for k in parts.values():
            k.makeRests(fillGaps=True, inPlace=False)
        offs += len(sCur)
    for pt in parts.values():
        # append(pt)
        pt = pt.flatten()
        print(pt, len(pt))
        sTot.insert(0, pt)

    form = "musicxml" # (musicxml, braille, midi)
    saveto = output
    print("\nSaving... =>", saveto)
    sTot.write(form, saveto)
