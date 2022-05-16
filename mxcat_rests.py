import argparse
import xml.etree.ElementTree as ET

# Sample usage ----
# View help message:        python mxcat.py -h | less 
# Concatenate files:        python mxcat.py file*.mscx > catted.mscx
# Preview result:           python mxcat.py file*.mscx | less -S
# Numbered lines:           python mxcat.py file*.mscx | cat -n
# Search debug comments:    python mxcat.py out*.mscx --debug true | grep [DEBUG]
# -----------------

parser = argparse.ArgumentParser(description='Concatenate Musescore XML files and print on the standard output; mxcat behaves similarly to UNIX cat, where you may redirect output to another file. You can pipe to cat if you want access to cat-like options (such as -n, -v, and so on)')

parser.add_argument('names', metavar='F', type=str, nargs='+', help='Files to concatenate.')
parser.add_argument('--debug', metavar='Debug', type=bool, nargs='?', help='Print debug comments into output, which is grep-able with [DEBUG].', default=False)

# get arguments 
args = parser.parse_args()

# args.names with nargs + as list
files = args.names
debug = args.debug

def count_staff(fname):
    rootst = ET.parse(fname).getroot() # museScore
    count = 0
    for staff in rootst.findall('Score/Part/Staff'):
        count += 1
    #if debug:
        #print("<!--[DEBUG] Staff count:", count, "detected in", fname, "-->")
    return count

# get header + metadata portion as lines
def get_headline(fname, size):
    ls = []
    tfile = open(fname, "r")
    sts = 0
    seenAll = False
    for line in tfile:
        ls.append(line)
        if "</Staff>" in line:
            sts += 1
        if "</Part>" in line and sts == size:
            seenAll = True
            break
    if not seenAll:
        raise SyntaxError("The mscx file %s is broken, not enough Staffs" % (fname)\
            + "found (seen %d, expected %d)." % (sts, size))
    return ls

def print_head(fname):
    larr = get_headline(fname, count_staff(fname))
    for line in larr:
        print(line)

def rest_measure(n, d):
    # generate measure of rest, with time signature n/d
    return ("<Measure><voice><Rest><durationType>measure</durationType><duration>%s/%s</duration></Rest></voice></Measure>" % (n, d))

def rest_measure_ok(n, d):
    return "<Measure><voice><TimeSig><sigN>%s</sigN><sigD>%d</sigD></TimeSig><Rest><durationType>measure</durationType><duration>%s/%d</duration></Rest></voice></Measure>" % (n, d, n, d)


tot_num_staffs, largest_file = 0, files[0]
for f in files:
    ns = count_staff(f)
    if ns > tot_num_staffs:
        largest_file = f
        tot_num_staffs = ns

# header from first score:
root = ET.parse(largest_file).getroot()
print_head(largest_file)


# Add opening tags for each staff
staff_data = []
staff_data.append("")
for num in range(1, tot_num_staffs + 1):
    staff_data.append('<Staff id="' + str(num) + '">\n')

# bodies (extract each staff data from each file)
for f in files:
    if debug:
        print("<!--[DEBUG] Parsing body of", f, "-->")

    num_staffs = count_staff(f)
    root = ET.parse(f).getroot()
    last_timesig, missing_measures = [4, 4], []

    for sf_id in range(1, num_staffs + 1):
        # 1, 2 for 2 staffs.
        for staff in root.findall('Score/Staff'):
            last_timesig = [4, 4] # reset for each staff
            missing_measures = [] # reset for each staff

            # remove default (80 bpm) tempos
            for mevoc in staff.findall("Measure/voice"):
                for tempo in mevoc.findall("Tempo"):
                    if " = 80" in str(ET.tostring(tempo), 'utf-8'):
                        mevoc.remove(tempo)

            # add each line to staff data
            if str(sf_id) == str(staff.get("id")):
                strl = str(ET.tostring(staff), 'utf-8').split("\n")
                
                # Don't want first and last items (<Staff id=> and </Staff>)
                for item in strl:
                    if (not item.lstrip().startswith('<Staff id=')) and (not item.lstrip().startswith("</Staff>")):
                        staff_data[sf_id] += item + "\n"

                        if "sigN" in item:
                            last_timesig[0] = int(str(item).split("<sigN>")[1][0])
                        elif "sigD" in item:
                            last_timesig[1] = int(str(item).split("<sigD>")[1][0])
                        elif "<Measure>" in item:
                            missing_measures += [rest_measure_ok(last_timesig[0], last_timesig[1])]

    for missing_sf_id in range(num_staffs + 1, tot_num_staffs + 1):
        print("<!--[DEBUG] Filling missing staffs in", f,\
            "with", len(missing_measures), "missing measures-->")
        for mm in missing_measures:
            staff_data[missing_sf_id] += mm + "\n"

    del root

# Add closing tag to end of each staff.
for val in range(1, tot_num_staffs + 1):
    staff_data[val] += "\n</Staff>"

# print the staffs
for data in staff_data:
    print(data)

# print footer
print("</Score>\n</museScore>")
