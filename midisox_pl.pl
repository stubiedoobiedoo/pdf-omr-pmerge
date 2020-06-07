#!/usr/bin/perl

my $Version = '5.7  for Perl5';
my $VersionDate = '20160702';

# 20150628 5.6 absent any set_tempo, default is 120bpm (see MIDI filespec 1.1)
# 20130507 5.5 quantise effect gets channels too
# 20130321 5.4 bug fixed in quantise effect
# 20120211 5.3 score2stats returns also %num_notes_by_channel
# 20111225 5.2 pitch effect gets channels too
# 20111224 5.1 introduce vol effect, with channels like compand
# 20111201 5.0 mixer effect with negative channel suppresses that channel
# 20111129 5.0 introduce new quantise effect and compand effect
# 20100922 4.9 fade with stop_time == 0 fades at end of file
# 20100710 4.7 opus2score terminates unended notes at the end of the track
# 20100709 4.6 opus2score() must interpret note_on with vol=0 as a note_off
# 20101005 4.5 timeshift() must not pad the set_tempo command
# 20101003 4.4 pitch2note_event must be chapitch2note_event
# 20100926 4.3 python version bug fixed appending to tuple in mixer()
# 20100910 4.2 python version fade effect handles absent params
# 20100802 4.1 bug fixed in mixer effect
# 20100306 4.0 bug fixed in pan effect
# 20100203 3.9 pitch as synonym for key effect
# 20091128 3.8 fetches URLs as input-filenames
# 20091127 3.7 '|cmd' pipe-style input files
# 20091113 3.6 -d output-file plays through aplaymidi
# 20091112 3.5 pad shifts from 0 ticks, stat output tidied
# 20091107 3.4 mixer effect does channel-remapping e.g. 3:1
# 20091021 3.3 warns about mixing GM on and GM off or bank-select
# 20091018 3.2 stat -freq detects screen width
# 20091018 3.1 does the pan effect
# 20091018 3.0 stat effect gets the -freq option
# 20091015 2.9 does the mixer effect (channels ?)
# 20091014 2.8 echo channels get panned right and left
# 20091014 2.7 does the echo effect
# 20091013 2.6 does the key effect
# 20091013 2.5 midi2ms_score not opus2ms_score
# 20091012 2.4 uses midi2ms_score
# 20091011 2.3 fixed infinite loop in pad at the end
# 20091010 2.2 to_millisecs() must now be called on the opus
# 20091010 2.1 stat effect sorted, and more complete
# 20091010 2.0 vol_mul() improves defensiveness and clarity
# 20091010 1.9 the fade effect fades-out correctly
# 20091010 1.8 does the fade effect, and trim works with one arg
# 20091009 1.7 will read from - (i.e. stdin)
# 20091009 1.6 does the repeat effect
# 20091008 1.5 does -h, --help and --help-effect=NAME
# 20091007 1.4 does the pad effect
# 20091007 1.3 does the tempo effect
# 20091007 1.2 will write to - (i.e. stdout), and does trim
# 20091006 1.1 does sequence, concatenate and stat
# 20091003 1.0 first working version, does merge and mix

use Data::Dumper; $Data::Dumper::Indent = 0; $Data::Dumper::Sortkeys = 1;
eval 'require MIDI'; if ($@) {
    die "you'll need to install the MIDI-Perl module from www.cpan.org\n";
}

#----------------------------- Event stuff --------------------------

my %_sysex2midimode = (
    "\x7E\x7F\x09\x01\xF7"=> 1,
    "\x7E\x7F\x09\x02\xF7"=> 0,
    "\x7E\x7F\x09\x03\xF7"=> 2,
);

my %Event2channelindex = ( 'note'=>3, 'note_off'=>2, 'note_on'=>2,
 'key_after_touch'=>2, 'control_change'=>2, 'patch_change'=>2,
 'channel_after_touch'=>2, 'pitch_wheel_change'=>2
);

sub print_help {
    my $topic = $_[$[] || 'global';
    my %help_dict = (
    'global'=><<EOT
midisox [global-options]  \\
   [format-options] infile1 [[format-options] infile2] ...  \\
   [format-options] outfile  \\
   [effect [effect-options]] ...

Global Options:
   -h, --help
       Show version number and usage information.
   --help-effect=NAME
       Show usage information on the specified effect (or "all").
   --interactive
       Prompt before overwriting an existing file
   -m|-M|--combine concatenate|merge|mix|sequence
       Select the input file combining method; -m means â€˜mixâ€™, -M â€˜mergeâ€™
   --version
       Show version number and exit.

Input & Output Files and their Options:
   Files can be either filenames, or:
   "-" meaning STDIN or STDOUT accordingly
   "|program [options] ..."  uses the program's stdout as an input file
   "http://etc/etc"  will fetch any valid URL as an input file
   "-d" meaning the default output-device; will be played through aplaymidi
   "-n" meaning a null output-device (useful with the "stat" effect)
   There is only one file-format-option available:
   -v, --volume FACTOR
       Adjust volume by a factor of FACTOR.  A number less
       than 1 decreases the volume; greater than 1 increases it.
EOT
    , 'compand'=><<EOT
compand   gradient {channel:gradient}
    Adjusts the velocity of all notes closer to (or away from) 100.
    If the gradient parameter is 0 every note gets volume 100, if it
    is 1.0 there is no effect, if it is greater than 1.0 there is
    expansion, and if negative the loud notes become soft and the soft
    notes loud.  Individual channels can be given individual gradients.
    The syntax of this effect is not the same as its SoX equivalent.

EOT
    , 'echo'=><<EOT
echo   gain-in gain-out  <delay decay>
    Add echoing to the audio.  Each  delay decay  pair gives the
    delay in milliseconds  and the decay of that echo.  Gain-in and
    gain-out are ignored, they are there for compatibilty with SoX.
    The echo effect triples the number of channels in the MIDI, so
    doesn't work well if there are more than 5 channels initially.
    E.g.:   echo 1 1 240 0.6 450 0.3
EOT
    , 'fade'=><<EOT
fade   fade-in-length   [stop-time [fade-out-length]]
    Add a fade effect to the beginning, end, or both of the MIDI.
    Fade-ins start from the beginning and ramp the volume (specifically,
    the velocity parameter of all the notes) from zero to full over
    fade-in-length seconds. Specify 0 seconds if no fade-in is wanted.
    For fade-outs, the MIDI is truncated at stop-time, and the volume
    ramped from full down to zero, starting at fade-out-length seconds
    before the stop-time. If fade-out-length is not specified, it defaults
    to the same as fade-in-length. No fade-out is performed if stop-time
    is not specified. If the stop-time is specified as 0, it will be
    set to the end of the MIDI.  Times are specified in seconds: ss.frac
EOT
    , 'key'=><<EOT
key  shift { channel:shift }
    Changes the key (i.e. pitch but not tempo).
    This is just a synonym for the pitch effect.
EOT
    , 'mixer'=><<EOT
mixer < channel[:to_channel] >
    Reduces the number of MIDI channels, by selecting just some
    of them and combining these (if necessary) into one track.
    The channel parameters are the channel-numbers 0...15,
    for example  mixer 9  selects just the drumkit.
    If an optional to_channel is specified, the selected channel
    will be remapped to the to_channel; for example,  mixer 3:1
    will select just channel 3 and renumber it to channel 1.
    If a channel number begins with a minus (including -0 !) then
    that channel will be suppressed and the others transmitted.
    The syntax of this effect is not the same as its SoX equivalent.
EOT
    , 'pad'=><<EOT
pad { length[@position] }
pad  length_at_start  length_at_end
    Pads the audio with silence, at the beginning, the end, or any
    specified points through the audio.  Both length and position
    are specified in seconds.  length is the amount of silence to
    insert, and position the position at which to insert it.
    Any number of lengths and positions may be specified, provided
    that each specified position is not less that the previous one.
    position is optional for the first and last lengths specified,
    and if omitted correspond to the beginning and end respectively.
    For example:   pad 1.5 1.5   adds 1.5 seconds of silence at each
    end of the MIDI,  whilst   pad 2.5@180   inserts 2.5 seconds of
    silence 3 minutes into the MIDI. If silence is wanted only at
    the end of the audio, specify a zero-length pad at the start.
EOT
    , 'pan'=><<EOT
pan  direction
    Pans all the MIDI-channels from one side to another.
    The direction is a value from -1 to 1;
    -1 represents far left and 1 represents far right.
EOT
    , 'pitch'=><<EOT
pitch  shift { channel:shift }
    Changes the pitch (i.e. key but not tempo). shift gives the pitch
    shift as positive or negative "cents" (i.e. 100ths of a semitone).
    However, currently, all pitch-shifts are round to the nearest 100
    cents, i.e. to the nearest semitone.
    Individual channels (0..15) can be given individual shifts.
EOT
    , 'quantise'=><<EOT
quantise  length { channel:length }
    Adjusts the beginnings of all the notes to be a
    a multiple of length seconds since the previous note.
    If length>30 then it is deemed to be be milliseconds.
    Channels for which length is zero do not get quantised.
    quantize is a synonym.
    This is a MIDI-related effect, and is not present in Sox.
EOT
    , 'quantize'=><<EOT
quantize  length { channel:length }
    Adjusts the beginnings of all the notes to be
    a multiple of length seconds since the previous note.
    If length>30 then it is deemed to be be milliseconds.
    Channels for which length is zero do not get quantised.
    quantise is a synonym.
    This is a MIDI-related effect, and is not present in Sox.
EOT
    , 'repeat'=><<EOT
repeat  count
    Repeat the entire MIDI "count" times. Note that repeating once
    doubles the length: the original MIDI plus the one repeat.
EOT
    , 'stat'=><<EOT
stat  [ -freq ]
    Do a statistical check on the input file, and print results on
    stderr. The MIDI is passed unmodified through the processing chain.
    The -freq option calculates the input's MIDI-pitch-spectrum 
    (60=middle-C) and prints it to stderr before the rest of the stats
EOT
    , 'tempo'=><<EOT
tempo  factor
    Change the tempo (but not the pitch).
    "factor" gives the ratio of new tempo to the old tempo.
EOT
    , 'trim'=><<EOT
trim  start [length]
    Outputs only the segment of the file starting at "start" seconds,
    and ending "length" seconds later, or at the end if length is
    not specified.  Patch-setting events, however, are preserved,
    even if they occurred before the start of the segment.
EOT
    , 'vol'=><<EOT
vol  increment { channel:increment }
    Adjusts the velocity (volume) of all notes by a fixed increment.
    If "increment" is -15 every note has its velocity reduced by
    fifteen, if it is 0 there is no effect, if it is +10 the velocity is
    increased by ten. Individual channels (0..15) can be given individual
    adjustments.  The syntax of this effect is not the same as SoX's vol.
EOT
    );
    if ($topic eq 'global') {
        _print("midisox version $Version $VersionDate");
        _print($help_dict{'global'});
        delete $help_dict{'global'};
        #help_dict.pop('unimplemented')
        _print("Available effects:\n    ".join(', ',sort keys %help_dict));
    } elsif ($topic eq 'all') {
        delete $help_dict{'global'};
        foreach $key (sort keys %help_dict) {
            _print($help_dict{$key});
        }
    } else {
        if ($help_dict{$topic}) {
            _print($help_dict{$topic});
        } else {
            delete $help_dict{'global'};
            #help_dict.pop('unimplemented')
            _print("Available effects:\n    ".join(', ',sort keys %help_dict));
        }
    }
}


# ----------------------- infrastructure --------------------
sub _print {
    print ($_[$[]."\n");
}
sub _warn {
    warn ($_[$[]."\n");
}

sub warning {
    _warn('warning: '.$_[$[]);
}

sub _die {
    die($_[$[]."\n");
}
sub round { my $x = $_[$[];
    if ($x > 0.0) { return int ($x + 0.5); }
    if ($x < 0.0) { return int ($x - 0.5); }
    return 0;
}
sub deepcopy {
    use Storable;
    if (1 == @_ and ref($_[$[])) {
        return Storable::dclone($_[$[]);
    } else {
        my $b_ref = Storable::dclone(\@_);
        return @$b_ref;
    }
}

sub vol_mul {
    my $vol = $_[$[] || 100;
    my $mul = $_[$[+1] || 1.0;
    my $new_vol = round($vol*$mul);
    if ($new_vol < 0) {
        $new_vol = 0 - $new_vol;
    }
    if ($new_vol > 127) {
        $new_vol = 127;
    } elsif ($new_vol < 1) {
        $new_vol = 1;   # some synths interpret vol=0 as vol=default
    }
    return $new_vol;
}

my $UsingStdinAsAFile = 0;
sub file2millisec {  my $filename = $_[$[];
    if ($filename eq '-n') {
        return([1000,[]]);
    }
    if ($filename =~ /^\|\s*(.+)/) {  # 3.7
        if (!open(P, "$1 |")) { _die("can't run $1: $!"); }
        my $opus_ref = MIDI::Opus->new({'from_handle' => *P{IO}});
        # ugly cut-and-paste of file2opus code :-(
        my @my_opus = (${$opus_ref}{'ticks'},);
        foreach my $track ($opus_ref->tracks) {
            push @my_opus, $track->events_r;
        }
        close P;
        return opus2score(to_millisecs(@my_opus));
    }
	if ($filename eq '-') {
		if ($UsingStdinAsAFile) {
			_die("can't read STDIN twice");
		}
		$UsingStdinAsAFile = 1;
	}
	return file2ms_score($filename);
}

# ------------------------- effects ---------------------------

sub compand { my ($score_ref, @params) = @_;
	my $h = ', see midisox --help-effect=compand';
    my @score = @$score_ref;
	if (@params < 1) { $params[$[] = '0.5' }
	my $default_gradient;
	my %channel_gradient = ();
	my $iparam = $[;
	while ($iparam <= $#params) {
		my $param = $params[$iparam];
		if ($param =~ /^-?\.?\d+$|^-?\d+\.\d*$/) {
			$default_gradient = 0 + $param;
		} elsif ($param =~ '^(\d+):(-?[.\d]+)$') {
			$channel_gradient{0+$1} = 0+$2;
		} else {
			_die("compand: strange parameter $param$h");
		}
		$iparam = $iparam + 1;
	}
	if (! defined $default_gradient) {
		if (%channel_gradient) {  # test for empty table
			$default_gradient = 1.0;   # 5.3
		} else {
			$default_gradient = 0.5;
		}
	}
	# warn("channel_gradient=".Dumper(\%channel_gradient));
	for my $itrack ($[+1, $#score) {
		my $previous_note_time = 0;
        foreach $event_ref (@{$score[$itrack]}) {
			if ($$event_ref[$[] eq 'note') {
				my $gradient = $default_gradient;
				if ($channel_gradient{$$event_ref[$[+3]}) {
					$gradient = $channel_gradient{$$event_ref[$[+3]};
				}
				$$event_ref[$[+5]=100+round($gradient*($$event_ref[$[+5]-100));
				if ($$event_ref[$[+5] > 127) {
					$$event_ref[$[+5] = 127;
				} elsif ($$event_ref[$[+5] < 1) {
					$$event_ref[$[+5] = 1; # v=0 sometimes means v=default
				}
			}
		}
	}
	return @score;
}

sub echo { my ($score_ref, @params) = @_;
	$h = ', see midisox --help-effect=echo';
	if (4 > @params) {
		_die("echo needs at least 4 parameters$h");
	}
	if (@params%2 == 1) {
		_die("echo needs an even number of parameters$h");
	}
	my @score = @$score_ref;
	my %stats = score2stats(@score);
	my $nchannels = @{$stats{'channels_total'}};
	if ($nchannels > 5) {
		warning("$nchannels channels is too many for echo effect");
	}
	my @echo_scores = ($score_ref,);
	my $iparam = 2;
	my $iecho_score = 1;
	while ($iparam < @params) {
		my $param = $params[$iparam];
		if ($param !~ /^[.0-9]+$/) {
			_die("echo: strange delay parameter $param$h");
		}
		my $delay = round($param);
		$iparam += 1;
		$param = $params[$iparam];
		if ($param !~ /^[.0-9]+$/) {
			_die("echo: strange decay parameter $param$h")
		}
		my $decay = 1.0 * $param;
		if ($iparam < 6) {
			my @delayed_score = timeshift(deepcopy(\@score), {'shift'=>$delay});
			push @echo_scores, \@delayed_score;
		}
		my $itrack = 1;
		my $pan = 10 + 107*($iecho_score%2);
		while ($itrack < @{$echo_scores[-1]}) {
			my @extra_events = ();
			# pan the echo_tracks Left and Right respectively
			for $event_ref (@{$echo_scores[$iecho_score][$itrack]}) {
				my @event = @$event_ref;
	            if ($event[0] eq 'note') {
                    ${$event_ref}[5] = vol_mul($event[5], $decay);
                } elsif ($event[0] eq 'patch_change') {
                    push @extra_events,
                     ['control_change', $event[1]+6, $event[2], 10, $pan];
                } elsif ($event[0] eq 'control_change' and $event[3] == 10) {
                    ${$event_ref}[4] = $pan;
                }
            }
            push @{$echo_scores[$iecho_score][$itrack]}, @extra_events;
            $itrack += 1;
        }
        $iparam += 1;
        $iecho_score += 1;
        if ($iecho_score > 2) {
            $iecho_score = 1;
        }
    }
    return merge_scores(@echo_scores);
}

sub fade { my ($score_ref, @params) =@_;
    if (!@params) {
        _die('the fade effect needs a fade-in length');
    }
    my $fade_in_ticks = round(1000*$params[0]);
    my $fade_out_ticks = $fade_in_ticks;  # default
    my $stop_time_ticks = 0;
    if (1 < @params) {
        if ($params[1] eq '0' or $params[1] eq '0.0') {  # 4.9
			my %stats = score2stats(@$score_ref);
			$stop_time_ticks = $stats{'nticks'};
        } elsif ($params[1] =~ /^[.0-9]+$/) {
            $stop_time_ticks = round(1000*$params[1]);
        } else {
            _die("the fade effect's stop_time unrecognised: $params[1]");
        }
        if (2 < @params) {
            if ($params[2] =~ /^[.0-9]+$/) {
                $fade_out_ticks = round(1000*$params[2]);
            } else {
              _die("the fade effect's fade_out_time unrecognised: $params[2]");
            }
        }
    }
    if (($fade_in_ticks+$fade_out_ticks) > $stop_time_ticks) {
        warning('the fade-in overlaps the fade-out; see midisox --help-effect=fade');
    }

    my @score = segment($score_ref, {'start_time'=>0, 'end_time'=>$stop_time_ticks});
    my $itrack = 1;
    while ($itrack <= $#score) {
        foreach $event_ref (@{$score[$itrack]}) {
            my @event = @$event_ref;
            if ($event[0] eq 'note') {
                if ($event[1] < $fade_in_ticks) {
                    ${$event_ref}[5] = vol_mul($event[5],
                     $event[1]/$fade_in_ticks);
                }
                if ($event[1] > ($stop_time_ticks - $fade_out_ticks)) {
                    ${$event_ref}[5] = vol_mul($event[5],
                     ($stop_time_ticks-$event[1]) / $fade_out_ticks);
                }
            }
        }
        $itrack += 1;
    }
    return @score;
}

sub key { my ($score_ref, @params) = @_;   # 5.2
    my $h = ', see midisox --help-effect=pitch';
    if (! @params) { return @$score_ref; }
    my $default_incr;
    my %channel_incr = ();
    foreach my $param (@params) {
        if ($param =~ /^[-+]?\d+$/) {
            $default_incr = round($param/100);
        } else {
            if ($param =~ /^(\d+):([-+]?\d+)$/) {
                $channel_incr{0+$1} = round($2/100);
            } else {
                die "pitch: strange parameter $param$h\n";
            }
        }
    }
    if (not $default_incr) {
        if (%channel_incr) { $default_incr = 0; } else { return @$score_ref; }
    }
    # warn("channel_incr=",Dumper(\%channel_incr),"\n");
    # warn("default_incr=$default_incr\n");
    my @score = @$score_ref;
    my $itrack = $[+1;
    while ($itrack <= $#score) {
        foreach my $event_ref (@{$score[$itrack]}) {
            my @event = @{$event_ref};
            if ($event[0] eq 'note' and $event[3] != 9) { # don't shift drumkit
				my $incr = $default_incr;
                if ($channel_incr{$event[3]}) {
                    $incr = $channel_incr{$event[3]};
                }
                ${$event_ref}[4] += $incr;
                if    (${$event_ref}[4] > 127) { ${$event_ref}[4] = 127;
                } elsif (${$event_ref}[4] < 0) { ${$event_ref}[4] = 0;
                }
            }
        }
        $itrack += 1;
    }
    return @score;
}

sub mixer { my ($score_ref, @params) = @_;
    my $h = ', see midisox --help-effect=mixer';
    my @pos_params = ();
    my %neg_params = ();
    my %remap = ();
    if (!@params) {
        _die("mixer effect needs parameters$h");
    }
    foreach my $param (@params) {
        if ($param =~ /^(\d+):(\d+)$/) {
            $remap{0+$1} = 0+$2;
            push @pos_params, 0+$1;
        } elsif ($param =~ /^-(\d+)$/) {
            $neg_params{0+$1} = 1;
        } elsif ($param =~ /^(\d+)$/) {
            push @pos_params, 0+$1;
        } else {
            _die("mixer: unrecognised channel number $param$h");
        }
    }
    if (%neg_params) {
        # if params are mixed positive and negative then die
        if (@pos_params) {
            _die("mixer channels must be either all positive or all negative");
        }
        # if params are all negative then use the complement list
        for my $cha (0..15) {
            if (!$neg_params{$cha}) {
                push @pos_params, $cha;
            }
        }
    }
    # _warn("remap = ".Dumper(\%remap));
    # _warn("pos_params = ".Dumper(\@pos_params));
    # _warn("neg_params = ".Dumper(\%neg_params));
    my @grepped_score = _grep($score_ref, {'channels'=>[@pos_params],});
    my $itrack = 1;
    while ($itrack < @grepped_score) {
        my $ievent = $[;
        foreach my $event_ref (@{$grepped_score[$itrack]}) {
            my @event = @$event_ref;
            my $channel_index = $Event2channelindex{$event[0]};
            if ($channel_index and defined $remap{$event[$channel_index]}) {
                $grepped_score[$itrack][$ievent][$channel_index]
                 = $remap{$event[$channel_index]};
            }
            $ievent += 1;
        }
        $itrack += 1;
    }
    return mix_scores((\@grepped_score,));
}

sub pad { my ($score_ref, @params) = @_;
    my @score      = @$score_ref;
    if (2 > @$score_ref) {
        return (1000, [],);
    }
    my $i = 0;
    while ($i <= $#params) {
        my $param = $params[$i];
        if ($param =~ /^(\d+\.?\d*)@(\d+\.?\d*)$/) {
            # XXX must apply these intermediate pads after any beginning pad
            my $shift     = round(1000 * $1);
            my $from_time = round(1000 * $2);
            @score = timeshift(\@score,
             {'shift'=>$shift, 'from_time'=>$from_time});
        } elsif ($param =~ /^[+.0-9]+$/) {
            my $shift = round(1000 * $param);
            if ($i == 0) {
                @score = timeshift(\@score, {'shift'=>$shift, 'from_time'=>0});
            } elsif ($i == $#params) {
                my %stats = score2stats(@score);
                my $new_end_time = $shift + $stats{'nticks'};
                my $itrack = 1;
                my $mark_string = "pad $param";
                while ($itrack <= $#score) {
                    push @{$score[$itrack]},
                     ['marker',$new_end_time,$mark_string];
                    $itrack += 1;
                }
            } else {
                _die('pad parameter $param should be either first or last');
            }
        } else {
            _die("unrecognised pad parameter: $param");
        }
        $i += 1;
    }
    return @score;
}

sub pan { my ($score_ref, $direction) = @_;
    my @score = @$score_ref;
    if ($direction > 1.00000001 or $direction < -1.00000001
     or !defined $direction) {
        _die("pan parameter must be [-1.0 ... 1.0], was: $direction");
    }
    my $itrack = 1;
    while ($itrack <= $#score) {
		my @extra_events = ();
        foreach my $event_ref (@{$score[$itrack]}) {
            my @event = @$event_ref;
            if ($event[0] eq 'control_change' and $event[3] == 10) {
                if ($direction < -0.00000001) {
                    ${$event_ref}[4] = round($event[4] * (1.0+$direction));
                } elsif ($direction > 0.00000001) {
                    ${$event_ref}[4] += round((127-$event[4]) * $direction);
                }
            } elsif ($event[0] eq 'patch_change') {
                my $new_pan = round(63.5 + 63.5*$direction);
                push @extra_events,
                 ['control_change', $event[1]+6, $event[2], 10, $new_pan];
            }
        }
		push @{$score[$itrack]}, @extra_events;
        $itrack += 1;
    }
    return @score;
}

sub quantise { my ($score_ref, @params) = @_;  #5.0
	my @score = @$score_ref;
	my $h = ', see midisox --help-effect=quantise';
	my $default_quantum;
	my %channel_quantum = ();
	my $iparam = $[;
	while ($iparam <= $#params) {
		my $param = $params[$iparam];
		if ($param =~ /^-?\.?\d+$|^-?\d+\.\d*$/) {
			my $quantum = 0 + $param;
			if ($quantum < 0)  { $quantum = 0 - $quantum; }
			if ($quantum < 30) { $quantum = 1000 * $quantum; }  # to ms
			$default_quantum = round($quantum);
		} elsif ($param =~ '^(\d+):(-?[.\d]+)$') {
			my $quantum = 0 + $2;
			if ($quantum < 0)  { $quantum = 0 - $quantum; }
			if ($quantum < 30) { $quantum = 1000 * $quantum; }  # to ms
			$channel_quantum{0+$1} = $quantum;
		} else {
			_die("quantise: strange parameter $param$h");
		}
		$iparam = $iparam + 1;
	}
	if (! defined $default_quantum) { $default_quantum = 0; }

	my $itrack = $[+1;
	while ($itrack <= $#score) {
		# the score track appears sorted by THE END TIMES of the notes
		# but here I need them sorted by the START times ....
		my @track = sort { $a[$[+1] <=> $b[$[+1]; } @{$score[$itrack]};
		my $old_previous_note_time = 0;
		my $new_previous_note_time = 0;
		my $k = $[; while ($k <= $#track) {
			if ($track[$k][$[] eq 'note') {
				my $quantum = $channel_quantum{$track[$k][$[+3]};
				if (! defined $quantum) { $default_quantum; }
				my $old_this_note_time = $track[$k][$[+1];
				my $dt = $old_this_note_time - $old_previous_note_time;
				if ($quantum > 0.5) {  # quantum must not be zero
					my $dn = round($dt/$quantum);
					$track[$k][$[+1] = $new_previous_note_time + $quantum*$dn;
					my $new_this_note_time = $track[$k][$[+1];
					# readjust non-notes to lie between the adjusted times
					# in same proportion as they lay between the old times
					my $k2 = $k - 1;
					while ($k2 >= $[ and $track[$k2][$[] ne 'note') {
						my $old_non_note_time = $track[$k2][$[+1];
						if ($old_this_note_time > $old_previous_note_time) {
							$track[$k2][$[+1] = round(
							  $new_previous_note_time +
				 			  ($old_non_note_time - $old_previous_note_time) *
							  ($new_this_note_time - $new_previous_note_time) /
							  ($old_this_note_time - $old_previous_note_time)
							);
						} else {
							$track[$k2][$[+1] = $new_previous_note_time;
						}
						$k2 = $k2 - 1;
					}
					if ($dn>0 and !defined $channel_quantum{$track[$k][$[+3]}){
						$old_previous_note_time = $old_this_note_time;
						$new_previous_note_time = $new_this_note_time;
					}
				}
            }
			$k += 1;
        }
		$score[$itrack] = \@track;
		$itrack += 1;
    }
    return @score;
}


sub repeat { my ($score_ref, $count) = @_;
    my @score      = @$score_ref;
    if (2 > @$score_ref) {
        return (1000, [],);
    }
    if ($count < 1) {
        _die("repeat's count parameter must be an integer: $count");
    }
    $count = round($count);
    my @scores = ($score_ref,);
    my $i = 0;
    while ($i < $count) {
        push @scores, $score_ref;
        $i += 1;
    }
    return concatenate_scores(@scores);
}

sub _stat { my ($score_ref, @params) = @_;
    my %stats = score2stats(@{$score_ref});
    if ($params[0] eq '-freq') {
        my $pmin = 127;
        my $pmax = 0;
        foreach my $p (keys %{$stats{'pitches'}}) {
             if ($p < $pmin) {
                 $pmin = $p;
            }
             if ($p > $pmax) {
                 $pmax = $p;
            }
        }
        my $nmax = 0;
        $p = $pmax;
        while ($p >= $pmin) {
            my $n = $stats{'pitches'}{$p};
            if ($nmax < $n) {
                $nmax = $n;
            }
            $p -= 1;
        }
        my $nwidth = 1 + round(log($nmax)/log(10));
        _warn('Pitch N');
        # http://bytes.com/groups/python/607757-getting-terminal-display-size
        #s = struct.pack("HHHH", 0, 0, 0, 0)
        #try {
        #    x = fcntl.ioctl(sys.stderr.fileno(), termios.TIOCGWINSZ, s)
        #    [maxrows, maxcols, xpixels, ypixels] = struct.unpack("HHHH", x)
        #except {
        my $maxcols = 80;
        $p = $pmax;
        while ($p >= $pmin) {
            my $n = $stats{'pitches'}{$p};
            my $bar;
            if ($nmax > ($maxcols-10-$nwidth)) {
                $bar = '#' x round(($maxcols-10-$nwidth)*$n/$nmax);
            } else {
                $bar = '#' x $n;
            }
            my $fmt = "%3d %".$nwidth."d $bar\n";
            printf STDERR $fmt, $p,$n;
            $p -= 1;
        }
    }
    foreach $stat (sort keys %stats) {
        my $val = $stats{$stat};
        if ($stat eq 'nticks') {
            print STDERR "nticks: $val  = ". (0.001*$val) ." sec\n";
        } elsif ($stat eq 'patch_changes_total') {
            my @l = ();
            foreach my $patchnum (sort {$a <=> $b} keys %$val) {
                # push @l, "$patchnum: $MIDI::number2patch{$patchnum}";
                push @l, $patchnum;
            }
            _warn('patch_changes_total: {' . join(', ',@l) . '}');
        } elsif (ref $val) {
            my $dump = Dumper($val);
            $dump =~ s/^\$VAR1 = //;
            $dump =~ s/ => /:/g;
            $dump =~ s/'(\d+)'/$1/g;
            $dump =~ s/,(\d+)/, $1/g;
            $dump =~ s/;$//g;
            print STDERR "$stat: $dump\n";
        } else {
            print STDERR "$stat: $val\n";
        }
    }
    return @score;
}

sub tempo { my ($score_ref, $tempo) = @_;
    if ($tempo < 0.1) {
       $tempo = 0.1;
    }
    foreach my $track_ref (@$score_ref) {
        for my $event_ref (@$track_ref) {
            ${$event_ref}[1] = round(${$event_ref}[1]/$tempo);
            if (${$event_ref}[0] eq 'note') {
                ${$event_ref}[2] = round(${$event_ref}[2]/$tempo);
            }
        }
    }
    return @$score_ref;
}

sub trim { my ($score_ref, $start, $_length) = @_;
    my $start_ticks = round(1000*$start);
    my $end_ticks = 100000000000;
    if ($_length) {
        $end_ticks = $start_ticks + round(1000*$_length);
    }
    my @tmp = segment($score_ref, {'start_time'=>$start_ticks, 'end_time'=>$end_ticks});
    return timeshift(\@tmp, {'start_time'=>1});
}

sub vol { my ($score_ref, @params) = @_;   # 5.1
    my $h = ', see midisox --help-effect=vol';
    if (! @params) { return @$score_ref; }
    my $default_incr;
    my %channel_incr = ();
    foreach my $param (@params) {
        if ($param =~ /^[-+]?\d+$/) {
            $default_incr = 0 + $param;
        } else {
            if ($param =~ /^(\d+):([-+]?\d+)$/) {
                $channel_incr{0+$1} = 0+$2;
            } else {
                die "vol: strange parameter $param$h\n";
            }
        }
    }
    if (not $default_incr) {
        if (%channel_incr) {  # test for empty table
            $default_incr = 0;
        } else {
            return @$score_ref;
        }
    }
    # warn("channel_incr=",Dumper(\%channel_incr),"\n");
    # warn("default_incr=$default_incr\n");
    foreach my $track_ref (@$score_ref) {
        foreach my $event_ref (@$track_ref) {
            if (${$event_ref}[0] eq 'note') {
                my $incr = $default_incr;
                if ($channel_incr{${$event_ref}[3]}) {
                    $incr = $channel_incr{${$event_ref}[3]};
                }
                ${$event_ref}[5] = $incr + ${$event_ref}[5];
                if (${$event_ref}[5] > 127) {
                    ${$event_ref}[5] = 127;
                } elsif (${$event_ref}[5] < 1) {
                    ${$event_ref}[5] = 1;  # some synths see v=0 as v=default
                }
            }
        }
    }
    return @$score_ref;
}

# --------------------------main -----------------------------
my %Possible_Combine = map { $_, 1 } ('concatenate','merge','mix','sequence');
my %Possible_Effect  = map { $_, 1 } (
 'compand','echo', 'fade','key','mixer','pad','pan','pitch','quantise',
 'quantize','repeat','silence','stat','stats','tempo','trim','vol');
my @global_options = ();
my @input_files    = ();
my @output_file    = ([], '');
my @effects        = ();

# command-line options:
my $Interactive_mode = 0;
my $Combine_mode = 'sequence';

my $i = 0;
while ($i < @ARGV) {
    $arg = $ARGV[$i];
    if ($arg eq '--interactive') {
        $Interactive_mode = 1;
    } elsif ( $arg eq '--version') {
        _print("midisox version $Version $VersionDate");
        exit(0);
    } elsif ( $arg eq '-h' or $arg eq '--help') {
        print_help();
        exit(0);
    } elsif ($arg =~ /^--help-effect=([a-z]+)/) {
        print_help($1);
        exit(0);
    } elsif ( $arg eq '-m') {
        $Combine_mode = 'mix';
    } elsif ( $arg eq '-M') {
        $Combine_mode = 'merge';
    } elsif ( $arg eq '--combine') {
        $i += 1;
        if ($i >= @ARGV) {
            _die('--combine must be followed by something');
        }
        $arg = $ARGV[$i];
        if ($Possible_Combine{$arg}) {
            $Combine_mode = $arg;
        } else {
            _die('--combine must be followed by concatenate, merge, mix, or sequence');
        }
    } else {
        last;
    }
    $i += 1;
}


my $volume = 1.0;
# warn "i=$i ARGV=@ARGV\n";
while ($i < @ARGV) {   # loop through all files, input and output...
    my $arg = $ARGV[$i];
# warn "arg=$arg\n";
    if ($arg eq '--volume' or $arg eq '-v') {
        $i += 1;
        if ($i >= @ARGV) {
            _die("$arg must be followed by a volume, and an input file")
        }
        my $volume = 1.0 * $ARGV[$i];
        if ($volume < 0.00000001) {
            _die('-v must be followed by a number (default volume is 1.0)')
        }
    } elsif ($Possible_Effect{$arg}) {
        last;
        # os.path.exists(arg) or arg eq '-':   # or a pipe...
        # die('input file ' + arg + ' does not exist')   might be output...
    # it's a filename
    } else {
        push @input_files, [$volume, $arg];
        $volume = 1.0;
    }
    $i += 1;
}

# then the last of these files must be the output-file; pop it
if (@input_files < 2) {
    _die('midisox needs at least one input-file and one output-file');
}
my $output_file = pop @input_files;

while ($i < @ARGV) {   # loop through all effects...
    my $arg = $ARGV[$i];
    if ($Possible_Effect{$arg}) {
        push @effects, [$arg];
    } else {
        push @{$effects[-1]}, $arg;
    }
    $i += 1;
}

#print('Combine_mode = ' + str(Combine_mode))
#print('input_files='+str(input_files))
#print('output_file='+str(output_file))
#print "effects is ", Dumper(@effects), "\n";

# read input files in, and apply the input effects
my @input_scores = ();
my $gm_on_already  = '';
my $gm_off_already = '';
my $bank_already   = '';

foreach my $input_file_ref (@input_files) {
    my @input_file = @{$input_file_ref};
    my @score = file2millisec($input_file[1]);
    # print "input_file[1]=$input_file[1] score is ", Dumper(@score), "\n";
    # 3.3 detect incompatible GM-modes and warn...
    my %stats = score2stats(@score);
    foreach my $gm_mode (@{$stats{'general_midi_mode'}}) {
        if ($gm_mode == 0 and $gm_on_already) {
            warning("$gm_on_already turns GM on, but $input_file[1] turns it off");
        } elsif ($gm_mode > 0 and $gm_off_already) {
            warning("$gm_off_already turns GM off, but $input_file[1] turns it on");
        } elsif ($gm_mode > 0 and $bank_already) {
            warning("$bank_already selects a bank, but $input_file[1] turns GM on");
        } elsif ($gm_mode == 0) {
            $gm_off_already = $input_file[1];
        } elsif ($gm_mode > 0) {
            $gm_on_already = $input_file[1];
        }
    }
    if ($stats{'bank_select'}) {
        if ($gm_on_already) {
            warning("$gm_on_already turns GM on, but $input_file[1] selects a bank");
        }
        $bank_already = $input_file[1];
    }
    $volume = 1.0 * $input_file[0];
    if ($volume < 0.99 or $volume > 1.01) {
        my $itrack = 1;
        while ($itrack < @score) {
            my $ievent = 0;
            while ($ievent < @{$score[$itrack]}) {
                if ($score[$itrack][$ievent][0] eq 'note') {
                    $score[$itrack][$ievent][5] = vol_mul($volume, $score[$itrack][$ievent][5]);
                }
                $ievent += 1;
            }
            $itrack += 1;
        }
    }
    push @input_scores, \@score;
}

# print "input_scores is ", Dumper(@input_scores);

# combine the input scores into an output score
if ($Combine_mode eq 'merge') {
    @output_score = merge_scores(@input_scores);
} elsif ($Combine_mode eq 'mix') {
    @output_score = mix_scores(@input_scores);
} elsif ($Combine_mode eq 'sequence' or $Combine_mode eq 'concatenate') {
    @output_score = concatenate_scores(@input_scores);
} else {
    _die("unsupported combine mode: $Combine_mode");
}
# print "output_score is ", Dumper(@output_score);

# apply effects to the output score
for my $effect_ref (@effects) {
    my @effect = @{$effect_ref};
    if ($effect[0] eq 'compand') {
        @output_score = compand(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'echo') {
        @output_score = echo(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'fade') {
        @output_score = fade(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'key' || $effect[0] eq 'pitch') {
        @output_score = key(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'mixer') {
        @output_score = mixer(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'pad') {
        @output_score = pad(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'pan') {
        @output_score = pan(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'quantise' or $effect[0] eq 'quantize') {
        @output_score = quantise(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'repeat') {
        @output_score = repeat(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'stat' or $effect[0] eq 'stats') {
        _stat(\@output_score, @effect[1 .. $#effect]);
    } elsif ($effect[0] eq 'tempo') {
        my $effect1 = $effect[1] || 1.0;
        @output_score = tempo(\@output_score, $effect1);
    } elsif ($effect[0] eq 'trim') {
        my $effect1 = $effect[1] || 0;
        my $effect2 = $effect[2];
        @output_score = trim(\@output_score, $effect1, $effect2);
    } elsif ($effect[0] eq 'vol') {
        @output_score = vol(\@output_score, @effect[1 .. $#effect]);
    } else {
        _die("unrecognised effect: @effect");
    }
}

# open the output file and print the output score to it
if (${$output_file}[1] eq '-n') {
    exit(0);
}
if (${$output_file}[1] eq '-') {
    score2file('-', @output_score);
    exit 0;
}
if ($Interactive_mode and -e ${$output_file}[1]) {
    require Term::Clui;
    Term::Clui::confirm("OK to overwrite ${$output_file}[1] ?") or exit 0;
}

score2file(${$output_file}[1], @output_score);
# if ($PID) { warn "waiting\n"; wait $PID; }
exit(0);


#------------------------------- Encoding stuff --------------------------

sub opus2file {
    my ($filename, @opus) = @_;
    # print "opus2file: filename=$filename opus = ", Dumper(@opus);
    my $format = 1;
    if (2 == @opus) { $format = 0; }
    my $cpan_opus = MIDI::Opus->new(
        {'format'=>$format, 'ticks'  => 1000, 'tracks' => []});
    # my $tracks_r = $cpan_opus->tracks_r();
    my @list_of_tracks = ();
    my $itrack = $[+1;
    while ($itrack <= $#opus) {
        push @list_of_tracks,
         MIDI::Track->new({ 'type' => 'MTrk', 'events' => $opus[$itrack]});
        $itrack += 1;
    }
    # print "opus2file: list_of_tracks = ", Dumper(@list_of_tracks);
    $cpan_opus->tracks(@list_of_tracks);
    # $cpan_opus->dump({'dump_tracks'=>1});
    if ($filename eq '-') {
        $cpan_opus->write_to_file( '>-' );
        # $cpan_opus->write_to_handle({'to_handle' => *STDOUT{IO}});
    } elsif ($filename eq '-d') {
        my $PID = fork;
        if (! $PID) {
            if (!open(P, '| aplaymidi -')) { die "can't run aplaymidi: $!\n"; }
            $cpan_opus->write_to_handle( *P{IO}, {} );
            close P;
            exit 0;
        }
    } else {
        $cpan_opus->write_to_file($filename);
    }
}

sub score2opus {
    if (2 > @_) { return (1000, []); }
    my ($ticks, @tracks) = @_;
    # print "score2opus: tracks is ", Dumper(@tracks);
    my @opus = ($ticks,);
    my $itrack = $[;
    while ($itrack <= $#tracks) {
        # MIDI::Score::dump_score( $_[$itrack] );
        # push @opus, MIDI::Score::score_r_to_events_r($_[$itrack]);
        my %time2events = ();
        foreach my $scoreevent_ref (@{$tracks[$itrack]}) {
            my @scoreevent = @{$scoreevent_ref};
            # print "score2opus: scoreevent = @scoreevent\n";
            if ($scoreevent[0] eq 'note') {
                my @note_on_event = ('note_on',$scoreevent[1],
                 $scoreevent[3],$scoreevent[4],$scoreevent[5]);
                my @note_off_event = ('note_off',$scoreevent[1]+$scoreevent[2],
                 $scoreevent[3],$scoreevent[4],$scoreevent[5]);
                if ($time2events{$note_on_event[1]}) {
                   push @{$time2events{$note_on_event[1]}}, \@note_on_event;
                } else {
                   @{$time2events{$note_on_event[1]}} = (\@note_on_event,);
                }
                if ($time2events{$note_off_event[1]}) {
                   push @{$time2events{$note_off_event[1]}}, \@note_off_event;
                } else {
                   @{$time2events{$note_off_event[1]}} = (\@note_off_event,);
                }
            } elsif ($time2events{$scoreevent[1]}) {
               push @{$time2events{$scoreevent[1]}}, \@scoreevent;
            } else {
               @{$time2events{$scoreevent[1]}} = (\@scoreevent,);
            }
        }

        my @sorted_events = (); # list of event_refs sorted by time
        for my $time (sort {$a <=> $b} keys %time2events) {
            push @sorted_events, @{$time2events{$time}};
        }

        my $abs_time = 0;
        for my $event_ref (@sorted_events) {  # convert abs times => delta times
            my $delta_time = ${$event_ref}[1] - $abs_time;
            $abs_time = ${$event_ref}[1];
            ${$event_ref}[1] = $delta_time;
        }
        push @opus, \@sorted_events;
        $itrack += 1;
    }
    return (@opus);
}

sub score2file { my ($filename, @score) = @_;
    my @opus = score2opus(@score);
    return opus2file($filename, @opus);
}

#--------------------------- Decoding stuff ------------------------

sub file2opus {
    my $opus_ref;
    if ($_[$[] eq '-') {
        $opus_ref = MIDI::Opus->new({'from_handle' => *STDIN{IO}});
    } elsif ($_[$[] =~ /^[a-z]+:\//) {
		eval 'require LWP::Simple'; if ($@) {
    		_die "you'll need to install libwww-perl from www.cpan.org";
		}
    	my $midi = LWP::Simple::get($_[$[]);
		if (! defined $midi) { _die("can't fetch $_[$[]"); }
		open(P, '<', \$midi) or _die("can't open FileHandle, need Perl5.8");
        $opus_ref = MIDI::Opus->new({'from_handle' => *P{IO}});
		close P;
    } else {
        $opus_ref = MIDI::Opus->new({'from_file' => $_[$[]});
    }
	# $opus_ref->dump({'dump_tracks'=>1});
    my @my_opus = (${$opus_ref}{'ticks'},);
    foreach my $track ($opus_ref->tracks) {
        push @my_opus, $track->events_r;
    }
	# print "3:\n", Dumper(\@my_opus);
    return @my_opus;
}

sub opus2score {  my ($ticks, @opus_tracks) = @_;
    # print "opus2score: ticks=$ticks opus_tracks=@opus_tracks\n";
    if (!@opus_tracks) {
        return (1000,[],);
    }
    my @score = ($ticks,);
    #foreach my $i ($[+1 .. $#_) {
    #    push @score, MIDI::Score::events_r_to_score_r($score[$i]);
    #}
    my @tracks = deepcopy(@opus_tracks); # couple of slices probably quicker...
	# print "opus2score: tracks is ", Dumper(@tracks);
    foreach my $opus_track_ref (@tracks) {
        my $ticks_so_far = 0;
        my @score_track = ();
        my %chapitch2note_on_events = ();    # 4.4 XXX!!! Must be by Channel !!
        foreach my $opus_event_ref (@{$opus_track_ref}) {
            my @opus_event = @{$opus_event_ref};
            $ticks_so_far += $opus_event[1];
            if ($opus_event[0] eq 'note_off'
			 or ($opus_event[0] eq 'note_on' and $opus_event[4]==0)) { # YY
                my $cha = $opus_event[2];
                my $pitch = $opus_event[3];
				my $key = $cha*128 + $pitch;
                if ($chapitch2note_on_events{$key}) {
                    my $new_event_ref = shift @{$chapitch2note_on_events{$key}};
                    ${$new_event_ref}[2] = $ticks_so_far - ${$new_event_ref}[1];
                    push @score_track, $new_event_ref;
                } else {
                    _warn("note_off without a note_on, cha=$cha pitch=$pitch")
                }
            } elsif ($opus_event[0] eq 'note_on') {
                my $cha = $opus_event[2];  # 4.4
                my $pitch = $opus_event[3];
                my $new_event_ref = ['note', $ticks_so_far, 0,
                 $cha, $pitch, $opus_event[4]];
				my $key = $cha*128 + $pitch;
                push @{$chapitch2note_on_events{$key}}, $new_event_ref;
            } else {
                $opus_event[1] = $ticks_so_far;
                push @score_track, \@opus_event;
            }
        }
    	# 4.7 check for unterminated notes, see: ~/lua/lib/MIDI.lua
		while (my ($k1,$v1) = each %chapitch2note_on_events) {
			foreach my $new_e_ref (@{$v1}) {
				${$new_e_ref}[2] = $ticks_so_far - ${$new_e_ref}[1];
                push @score_track, $new_e_ref;
				warn("opus2score: note_on with no note_off cha="
				 . ${$new_e_ref}[3] . ' pitch='
				 . ${$new_e_ref}[4] . "; adding note_off at end\n");
			}
		}
        push @score, \@score_track;
    }
	# print "opus2score: score is ", Dumper(@score);
    return @score;
}

sub file2score {
	return opus2score(file2opus($_[$[]));
}

sub file2ms_score {
	#print "file2ms_score(@_)\n";
	# return opus2score(to_millisecs(file2opus($_[$[])));
	my @opus = file2opus($_[$[]);
	my @ms = to_millisecs(@opus);
	my @score = opus2score(@ms);
	return @score;
}

#------------------------ Other Transformations ---------------------

sub to_millisecs {   # 20160702 rewrite, following MIDI.lua 6.7
	my @old_opus = @_;
	if (!@old_opus) { return (1000,[],); }
	my $old_tpq  = $old_opus[$[];
	my @new_opus = (1000,);
	# 6.7 first go through building a table of set_tempos by absolute-tick
	my %ticks2tempo = ();
	$itrack = $[+1;
	while ($itrack <= $#old_opus) {
		my $ticks_so_far = 0;
		foreach my $old_event_ref (@{$old_opus[$itrack]}) {
			my @old_event = @{$old_event_ref};
			if ($old_event[0] eq 'note') {
				_die 'to_millisecs needs an opus, not a score';
			}
			$ticks_so_far += $old_event[1];
			if ($old_event[0] eq 'set_tempo') {
				$ticks2tempo{$ticks_so_far} = $old_event[2];
			}
		}
		$itrack += 1;
	}
	# then get the sorted-array of their keys
	my @tempo_ticks = sort { $a <=> $b; } keys %ticks2tempo;
	#  then go through converting to millisec, testing if the next
	#  set_tempo lies before the next track-event, and using it if so.
	$itrack = $[+1;
	while ($itrack <= $#old_opus) {
		my $ms_per_old_tick = 1000.0 / $old_tpq;  # will round later
		my $i_tempo_ticks = 0;
		my $ticks_so_far = 0;
		my $ms_so_far = 0.0;
		my $previous_ms_so_far = 0.0;
		my @new_track = (['set_tempo',0,1000000],);  # new "crochet" is 1 sec
		foreach my $old_event_ref (@{$old_opus[$itrack]}) {
			# detect if ticks2tempo has something before this event
			# 20160702 if ticks2tempo is at the same time, leave it
			my @old_event = @{$old_event_ref};
			my $event_delta_ticks = $old_event[1];
			if ($i_tempo_ticks <= $#tempo_ticks and
			  $tempo_ticks[$i_tempo_ticks] < ($ticks_so_far+$old_event[1])) {
				my $delta_ticks = $tempo_ticks[$i_tempo_ticks]-$ticks_so_far;
				$ms_so_far += ($ms_per_old_tick * $delta_ticks);
				$ticks_so_far = $tempo_ticks[$i_tempo_ticks];
				$ms_per_old_tick=$ticks2tempo{$ticks_so_far}/(1000*$old_tpq);
				$i_tempo_ticks += 1;
				$event_delta_ticks -= $delta_ticks;
			}   # now handle the new event
			my @new_event = deepcopy(@old_event);  # copy.deepcopy ?
			$ms_so_far += ($ms_per_old_tick * $old_event[1]);
			$new_event[1] = round($ms_so_far-$previous_ms_so_far);
			if ($old_event[0] ne 'set_tempo') { # set_tempos already handled!
				$previous_ms_so_far = $ms_so_far;
				push @new_track, \@new_event;
			}
			$ticks_so_far += $event_delta_ticks;
		}
		push @new_opus, \@new_track;
		$itrack += 1;
	}
	# print "to_millisecs new_opus = ", Dumper(\@new_opus);
	return @new_opus;
}


sub _grep {
	my ($score_ref, $args_ref) = @_;
    my @score    = @$score_ref;
    my @channels = @{${$args_ref}{'channels'}};
    my %channels = map { $_, 1 } @channels;
    if (2 > @$score_ref) {
        return (1000, [],);
    }
    my @new_score = ($score[0],);
    if (!%channels) {
        return @new_score;
    }
    $itrack = 1;
    while ($itrack <= $#score) {
        push (@new_score, []);
        foreach my $event_ref (@{$score[$itrack]}) {
            my @event = @$event_ref;
            my $channel_index = $Event2channelindex{$event[0]};
            if ($channel_index) {
                if ($channels{$event[$channel_index]}) {
                    push @{$new_score[$itrack]}, $event_ref;
                }
            } else {
                push @{$new_score[$itrack]}, $event_ref;
            }
        }
        $itrack += 1;
    }
    return @new_score;
}

sub timeshift { my ($score_ref, $args_ref) = @_;
    my @score      = @$score_ref;
    my $shift      = ${$args_ref}{'shift'};
    my $start_time = ${$args_ref}{'start_time'};
    my $from_time  = ${$args_ref}{'from_time'};
    my @tracks     = @{${$args_ref}{'tracks'}};
    if (2 > @$score_ref) {
        return (1000, [],);
    }
    my @new_score = ($score[0],);
    my $my_type = score_type(@score);
    if (!$my_type) {
        return @new_score;
    }
    if ($my_type eq 'opus') {
        _warn("timeshift: opus format is not supported\n");
        return @new_score;
    }
    if ($shift and $start_time) {
        _warn("timeshift: shift and start_time specified: ignoring shift");
        undef $shift;
    }
    if (!defined $shift) {
        if ($start_time <= 0) {
            $start_time = 0;
        }
        # shift = start_time - from_time
    }

    my $itrack = 1;  # ignore first element (ticks)
    my %tracks = map { $_, 1 } @tracks;
    my $earliest = 1000000000;
    if ($start_time or $shift<0) {  # first find the earliest event
        while ($itrack < @score) {
            if (@tracks and !$tracks{$itrack-1}) {
                $itrack += 1;
                next;
            }
            foreach my $event_ref (@{$score[$itrack]}) {
                if (${$event_ref}[1] < $from_time) {
                     next;  # just inspect the to_be_shifted events
                }
                if (${$event_ref}[1] < $earliest) {
                     $earliest = ${$event_ref}[1];
                }
            }
            $itrack += 1;
        }
    }
    if (!$shift) {
        $shift = $start_time - $earliest;
    } elsif (($earliest + $shift) < 0) {
        $start_time = 0;
        $shift = 0 - $earliest;
    }
        
    $itrack = 1;   # ignore first element (ticks)
    while ($itrack < @score) {
        if (@tracks and !$tracks{$itrack-1}) {
            push @new_score, $score[$itrack];
            $itrack += 1;
            next;
        }
        my @new_track = ();
        foreach my $event_ref (@{$score[$itrack]}) {
            my @new_event = @$event_ref;
            if ($new_event[1] >= $from_time) {
				# 4.5 must not rightshift set_tempo
				if ($new_event[0] ne 'set_tempo' or $shift<0) {
                	$new_event[1] += $shift;
				}
            } elsif ($shift < 0 and $new_event[1] >= ($from_time+$shift)) {
                next;
            }
            push @new_track, \@new_event;
        }
        if (@new_track) {
            push @new_score, \@new_track;
        }
        $itrack += 1;
    }
    return @new_score;
}

sub segment { my ($score_ref, $args_ref) = @_;
    # Returns a "score" which is a segment of the one supplied as
    # the argument, beginning at "start" ticks and ending  at "end"
    # ticks (or at the end if "end" is not supplied). If the listref
    # "tracks" is specified, only those tracks will be returned.
    my @score  = @$score_ref;
    my $start  = ${$args_ref}{'start_time'};
    my $end    = ${$args_ref}{'end_time'};
    my @tracks = @{${$args_ref}{'tracks'}};
    if (2 > @$score_ref) {
        return (1000, [],);
    }
    #print('score: start='+str(start)+' end='+str(end), file=sys.stderr)
    my @new_score = ($score[0],);
    my $my_type = score_type(@score);
    if (!$my_type) {
        return @new_score;
    }
    if ($my_type eq 'opus') {
        # more difficult (disconnecting note_on's from their note_off's)...
        _warn("segment: opus format is not supported");
        return @new_score;
    }
    my $itrack = 1; # ignore first element (ticks); we count in ticks anyway
    my %tracks = map { $_, 1 } @tracks;
    while ($itrack <= $#score) {
        if (@tracks and !$tracks{$itrack-1}) {
            $itrack += 1;
            next;
        }
        my @new_track = ();
        my %channel2cc_num;    # most recent controller change before start
        my %channel2cc_val;
        my %channel2cc_time;
        my %channel2patch_num; # keep most recent patch change before start
        my %channel2patch_time;
        my $set_tempo_num = 1000000; # most recent tempo change before start
        my $set_tempo_time = 0;
        my $earliest_note_time = $end;
        for my $event_ref (@{$score[$itrack]}) {
            my @event = @$event_ref;
            if ($event[0] eq 'control_change') {   # 5.7
                my $cc_time = $channel2cc_time{$event[2]} || 0;
                if ($event[1] < $start and $event[1] >= $cc_time) {  # 2.0
                    $channel2cc_num{$event[2]}  = $event[3];
                    $channel2cc_val{$event[2]}  = $event[4];
                    $channel2cc_time{$event[2]} = $event[1];
                }
            } elsif ($event[0] eq 'patch_change') {
                my $patch_time = $channel2patch_time{$event[2]} || 0;
                if ($event[1] < $start and $event[1] >= $patch_time) {  # 2.0
                    $channel2patch_num{$event[2]}  = $event[3];
                    $channel2patch_time{$event[2]} = $event[1];
                }
            } elsif ($event[0] eq 'set_tempo') {
                if ($event[1] < $start and $event[1] >= $set_tempo_time) {
                    $set_tempo_num  = $event[2];
                    $set_tempo_time = $event[1];
                }
            }
            if ($event[1] >= $start and $event[1] <= $end) {
                push @new_track, \@event;
                if ($event[0] eq 'note' and $event[1] < $earliest_note_time) {
                    $earliest_note_time = $event[1];
                }
            }
        }
        if (@new_track) {
            push @new_track, ['set_tempo', $start, $set_tempo_num];
            foreach my $c (sort keys %channel2patch_num) {
                push @new_track,
                 ['patch_change',$start,$c,$channel2patch_num{$c}];
            }
            foreach my $c (sort keys %channel2cc_num) {
                push @new_track, ['control_change',$start,$c,
				  $channel2cc_num{$c},$channel2cc_val{$c}];
            }
            push @new_score, \@new_track;
        }
        $itrack += 1;
    }
    return @new_score;
}

sub score_type { my @opus_or_score = @_;
    # Returns a string, either 'opus' or 'score' or ''
    if (@opus_or_score < 2) {
        return '';
    }
    my $itrack = $[+1;   # ignore first element
    while ($itrack <=$#opus_or_score) {
        foreach my $event_ref (@{$opus_or_score[$itrack]}) {
            my @event = @$event_ref;
            if ($event[0] eq 'note') {
                return 'score';
            } elsif ($event[0] eq 'note_on') {
                return 'opus';
            }
        }
        $itrack += 1;
    }
    return '';
}

#sub sort_score(score=None):
#    for each track,
#        $score2_r = MIDI::Score::sort_score_r( $score_r)  LoL
#    return [ticks, [],]

sub concatenate_scores {  my @input_scores = @_;
    # Concatenates a list of scores into one score.
    # the deepcopys are needed if the input_scores are refs to the same obj
    # e.g. if invoked by midisoxs repeat()
    # print "concatenate_scores: input_scores is ", Dumper(@_);
    my @output_score = (1000,);

    my $iscore = $[;
    while ($iscore <= $#input_scores) {
        my @input_score = @{$input_scores[$iscore]};
        my %output_stats = score2stats(@output_score);
        my $delta_ticks = $output_stats{'nticks'};
        my $itrack = $[+1;
        while ($itrack < @input_score) {
            if ($itrack >= @output_score) { # new track if doesnt exist
                push @output_score, [];
            }
            for $event (@{$input_score[$itrack]}) {
                push @{$output_score[$itrack]}, deepcopy($event);
                $output_score[$itrack][-1][1] += $delta_ticks;
            }
            $itrack += 1;
        }
        $iscore += 1;
    }
    # print "concatenate_scores: output_score is ", Dumper(@output_score);
    return @output_score;
}

sub merge_scores {
    # Merges a list of scores into one score.  A merged score comprises
    # all of the tracks from all of the input scores; un-merging is possible
    # by selecting just some of the tracks.  The scores should be in
    # millisecond-tick format; they will get converted if necessary, but
    # this is a slow process.  merge_scores attempts to resolve channel-
    # -conflicts, but there are of course only 15 available channels...
    my @output_score = (1000,);
    my %channels_so_far = ();
    my %all_channels = map { $_, 1 } (0,1,2,3,4,5,6,7,8,10,11,12,13,14,15);
    foreach $input_score_ref (@_) {
        my @input_score = @$input_score_ref;
        if ($input_score[0] != 1000) {
            _warn("not millisecs already?");
            @input_score = opus2score(to_millisec(score2opus(@input_score)));
        }
        my %stats = score2stats(@input_score);
        my %new_channels = map { $_, 1 } @{$stats{'channels_total'}};
        delete $new_channels{9};  # 2.8 cha9 must remain cha9 (in GM)
        my @so_far_and_new = ();
        foreach (sort keys %all_channels) {
            if ($channels_so_far{$_} and $new_channels{$_}) {
                push @so_far_and_new, $_;
            }
        }
        foreach my $channel (@so_far_and_new) {
            # free_channels = all_channels - (channels_so_far|new_channels)
            my @free_channels = ();
            foreach (keys %all_channels) {
                if (!$channels_so_far{$_} and !$new_channels{$_}) {
                    push @free_channels, $_;
                }
            }
            @free_channels = sort {$a<=>$b} @free_channels;
            # print "free_channels is ", Dumper(\@free_channels), "\n";
            last unless @free_channels;
            my $free_channel = $free_channels[$[];
            my $itrack = 1;
            while ($itrack <= $#input_score) {
                for my $input_event_ref (@{$input_score[$itrack]}) {
                    my @input_event = @$input_event_ref;
                    $channel_index = $Event2channelindex{$input_event[0]};
                    if ($channel_index and $input_event[$channel_index]==$channel) {
                        ${$input_event_ref}[$channel_index] = $free_channel;
                    }
                }
                $itrack += 1;
            }
            $channels_so_far{$free_channel} = 1;
        }
        # channels_so_far |= new_channels
        foreach (keys %new_channels) { $channels_so_far{$_} = 1; }
        push @output_score, @input_score[1..$#input_score];
    }
    return @output_score;
}

sub mix_scores {
    my @output_score = (1000, []);
    for my $input_score_ref (@_) {
        my @input_score = @$input_score_ref;
        my $itrack = $[+1;
        while ($itrack <= $#input_score) {
            push @{$output_score[1]}, @{$input_score[$itrack]};
            $itrack += 1;
        }
    }
    return @output_score;
}

sub score2stats {   my @opus_or_score = @_;
    #Returns a dict of some basic stats about the score, like
    #bank_select (list of tuples (msb,lsb)),
    #channels_by_track (list of lists), channels_total (set),
    #general_midi_mode (list),
    #ntracks, nticks, patch_changes_by_track (list of dicts),
    #patch_changes_total (set),
    #percussion (dict histogram of channel 9 events),
    #pitches (dict histogram of pitches on channels other than 9),
    #pitch_range_by_track (list, by track, of two-member-tuples),
    #pitch_range_sum (sum over tracks of the pitch_ranges),
    my $bank_select_msb = -1;
    my $bank_select_lsb = -1;
    my $bank_select = [];
    my @channels_by_track = ();
    my %channels_total    = ();
    my @general_midi_mode = ();
    my %num_notes_by_channel = ();
    my @patches_used_by_track  = ();
    my %patches_used_total     = ();
    my @patch_changes_by_track = ();
    my %patch_changes_total    = ();
    my %percussion = (); # histogram of channel 9 "pitches"
    my %pitches    = (); # histogram of pitch-occurrences channels 0-8,10-15
    my $pitch_range_sum = 0;   # u pitch-ranges of each track
    my @pitch_range_by_track = ();
    my $is_a_score = True;
    if (!@opus_or_score) {
        return {'bank_select'=>[], 'channels_by_track'=>[],
         'channels_total'=>[],
         'general_midi_mode'=>(), 'ntracks'=>0, 'nticks'=>0,
		 'num_notes_by_channel' => [],
         'patch_changes_by_track'=>[], 'patch_changes_total'=>[],
         'percussion'=>{}, 'pitches'=>{}, 'pitch_range_by_track'=>[],
         'ticks_per_quarter'=>0, 'pitch_range_sum'=>0};
    }
    $ticks_per_quarter = $opus_or_score[0];
    $i = $[+1;   # ignore first element, which is ticks
    $nticks = 0;
    while ($i < @opus_or_score) {
        $highest_pitch = 0;
        $lowest_pitch = 128;
        %channels_this_track = ();
        %patch_changes_this_track = ();
        for $event_ref (@{$opus_or_score[$i]}) {
            my @event = @$event_ref;
            if ($event[0] eq 'note') {
				$num_notes_by_channel{$event[3]} += 1;
                if ($event[3] == 9) {
                    $percussion{$event[4]} += 1;
                } else {
                    $pitches{$event[4]} += 1;
                    if ($event[4] > $highest_pitch) {
                        $highest_pitch = $event[4];
                    } elsif ($event[4] < $lowest_pitch) {
                        $lowest_pitch = $event[4];
                    }
                }
                $channels_this_track{$event[3]} = 1;
                $channels_total{$event[3]} = 1;
                my $finish_time = $event[1] + $event[2];
                if ($finish_time > $nticks) {
                    $nticks = $finish_time;
                }
            } elsif ($event[0] eq 'note_on') {
                $is_a_score = 0;
				$num_notes_by_channel{$event[2]} += 1;
                if ($event[2] == 9) {
                    $percussion{$event[3]} += 1;
                } else {
                    $pitches{$event[3]} += 1;
                    if ($event[3] > $highest_pitch) {
                        $highest_pitch = $event[3];
                    } elsif ($event[3] < $lowest_pitch) {
                        $lowest_pitch = $event[3];
                    }
                }
                $channels_this_track{$event[2]} = 1;
                $channels_total{$event[2]} = 1;
            } elsif ($event[0] eq 'note_off') {
                my $finish_time = $event[1];
                if ($finish_time > $nticks) {
                    $nticks = $finish_time;
                }
            } elsif ($event[0] eq 'patch_change') {
                $patch_changes_this_track{$event[2]} = $event[3];
                $patch_changes_total{$event[3]} = 1;
            } elsif ($event[0] eq 'control_change') {
                if ($event[3] == 0) {  # bank select MSB
                    $bank_select_msb = $event[4];
                } elsif ($event[3] == 32) {  # bank select LSB
                    $bank_select_lsb = $event[4];
                }
                if ($bank_select_msb >= 0 and $bank_select_lsb >= 0) {
                    $bank_select{"$bank_select_msb, $bank_select_lsb"} = 1;
                    $bank_select_msb = -1;
                    $bank_select_lsb = -1;
                }
            } elsif ($event[0] eq 'sysex_f0') {
                if (defined $_sysex2midimode{$event[2]}) {
                    push @general_midi_mode, $_sysex2midimode{$event[2]};
                }
            }
            if ($is_a_score) {
                if ($event[1] > $nticks) {
                    $nticks = $event[1];
                }
            } else {
                $nticks += $event[1];
            }
        }
        if ($lowest_pitch == 128) {
            $lowest_pitch = 0;
        }
        my @channels_this_track_list = sort keys %channels_this_track;
        $channels_by_track[$i-1] = \@channels_this_track_list;

        my @patch_changes_this_track_list = sort keys %patch_changes_this_track;
        push @patch_changes_by_track, \%patch_changes_this_track;

        push @pitch_range_by_track, [$lowest_pitch,$highest_pitch];
        $pitch_range_sum += ($highest_pitch-$lowest_pitch);
        $i += 1;
    }

    my @channels_total = sort {$a<=>$b} keys %channels_total;
    my @bank_select    = sort {$a<=>$b} keys %bank_select;
    return ('bank_select' => \@bank_select,
            'channels_by_track' => \@channels_by_track,
            'channels_total' => \@channels_total,
            'general_midi_mode' => $general_midi_mode,
            'ntracks' => (-1 + @opus_or_score),
            'nticks' => $nticks,
			'num_notes_by_channel' => \%num_notes_by_channel,
            'patch_changes_by_track' => \@patch_changes_by_track,
            'patch_changes_total' => \%patch_changes_total,
            'percussion' => \%percussion,
            'pitches' => \%pitches,
            'pitch_range_by_track' => \@pitch_range_by_track,
            'pitch_range_sum' => $pitch_range_sum,
            'ticks_per_quarter' => $ticks_per_quarter
    );
}

=pod

=head1 NAME

midisox - a SoX-like workalike, for handling MIDI files

=head1 SYNOPSIS

 > midisox [global-options]   \
   [format-options] infile1 [[format-options] infile2] ...   \
   [format-options] outfile   \
   [effect [effect-options]] ...

 > sox chorus.wav chorus.wav mid8.wav chorus.wav out.wav
 > play out.wav
 > midisox chorus.mid chorus.mid mid8.mid chorus.mid out.mid
 > aplaymidi out.mid
 > midisox -M bass.mid pno.mid -v 1.1 horns.mid soar.mid verse.mid
 > midisox -M bass.mid pno.mid voice.mid - | aplaymidi -
 > muscript -midi chords | midisox -M - bass.mid - | aplaymidi -
 > muscript -midi chords | midisox - -n stat
 > midisox -M "|midisox chords.mid - pitch -200" solo.mid out.mid
 > midisox impro.mid riff.mid trim 37.2 3.4
 > midisox --help ; midisox --help-effect=all

=head1 DESCRIPTION

Midisox is a tool for working on MIDI files, with a calling interface
modelled, as far as possible, on that of SoX, which is a
well-established tool for working on audio files.

Midisox standardises all its files to a tick-rate of 1000 ticks/sec.
This makes it possible to mix them together. But it does make it hard
to load them into music-typesetting software afterwards and have the
beats recognised. . .

Midisox assumes at various places that it is working on a General-Midi
file: for example, the pitch effect will not try to transpose the drumkit
on Channel 9.

Midisox is now available in two versions, one written in Python3 and
the other in Perl.

This is midisox version 5.5

=head1 GLOBAL OPTIONS

=over 3

=item I<-h, --help>

Show version number and B<H>elpful usage information,

=item I<--help-effect=NAME>

Show usage information on the specified effect (or "all").

=item I<--interactive>

Prompt before overwriting an existing file.

=item I<-m | -M | --combine concatenate|merge|mix|sequence>

Select the input file combining method; -m means I<mix>, -M I<merge>.
If the I<mix> combining method is selected (with B<-m>) then two or
more input files must be given and will all be mixed together
into one MIDI-track. A mixed file cannot be un-mixed.

If the I<merge> combining method is selected (with B<-M>), then the
merged file contains all of the MIDI-tracks from all of the
input files; un-merging is possible using multiple invocations
of I<midisox> with the I<mixer> effect. The merging process attempts
to avoid channel-conflicts by renumbering channels in the later
files as necessary (however, a total of only fifteen
MIDI-channels is available).

The default is I<sequence>.


=item I<--version>

Displays the version number.

=back

=head1 INPUT AND OUTPUT FILES AND THEIR OPTIONS

There is only one file-format-option available:

=over 3

=item I<-v, --volume FACTOR>

Adjust the volume (specifically, the velocity parameter of all
the notes) by a factor of FACTOR. A factor less than 1 decreases
the volume; greater than 1 increases it.

=back

Files can be either filenames, or
 B<- >   meaning STDIN or STDOUT accordingly, or
 B<"|program [options] ...">   uses I<program>'s stdout as an input file
 B<http://wherever/whatever.mid>   will fetch a URL as an input file
 B<-d>   meaning the "default" output, i.e. will feed into I<aplaymidi ->
 B<-n>   meaning a null output-device (useful with the stat effect).

=head1 EFFECTS:   compand, echo, fade, key, mixer, pad, pan, pitch, quantise, repeat, stat, tempo, trim, vol

=over 3

=item compand  gradient  {channel:gradient}

Adjusts the velocity of all notes closer to (or away from) 100.
If the I<gradient> parameter
is 0 every note gets volume 100, if it is 1.0 there is no effect,
if it is greater than 1.0 there is expansion,
and if it is negative the loud notes become soft and the soft notes loud.
The default value is 0.5.
Individual channels can be given individual gradients.
The syntax of this effect is not the same as its SoX equivalent.

=item echo  gain-in gain-out  <delay decay>

Add echoing to the audio. Each I<delay decay> pair gives the delay
in milliseconds and the decay of that echo. I<Gain-in> and I<gain-out>
are ignored, they are there for compatibilty with SoX. The echo
effect triples the number of channels in the MIDI, so doesn't
work well if there are more than 5 channels initially.  E.g.:
 echo 1 1 240 0.6 450 0.3

=item fade   fade-in-length   [stop-time [fade-out-length]]

Adds a fade effect to the beginning, end, or both of the MIDI.
Fade-ins start from the beginning and ramp the volume
(specifically, the I<velocity> parameter of all the notes) from
zero to full, over I<fade-in-length> seconds. Specify 0 seconds if
no fade-in is wanted.

For fade-outs, the MIDI will be truncated at I<stop-time>, and the
volume will be ramped from full down to zero starting at
I<fade-out-length> seconds before the I<stop-time>. If I<fade-out-length>
is not specified, it defaults to the same value as I<fade-in-length>.
No fade-out is performed if I<stop-time> is not specified.
If the I<stop-time> is specified as 0, it will be set to the end of the midi.
Times are specified in seconds: I<ss.frac>

=item key    shift { channel:shift }

Change the key (i.e. pitch but not tempo).
This is just an alias for the B<pitch> effect.

=item mixer   < channel[:to_channel] >

Reduces the number of MIDI channels, by selecting just some of
them and combining these (if necessary) into one track. The
I<channel> parameters are the channel-numbers 0 ... 15, for example
I<mixer 9>   selects just the drumkit. If an optional I<to_channel> is
specified, the selected I<channel> will be remapped to the I<to_channel>;
for example, I<mixer 3:1> will select just channel 3 and renumber
it to channel 1.
The syntax of this effect is not the same as its SoX equivalent.

=item    pad { length[@position] }   or   pad length_at_start length_at_end

Pads the MIDI with silence, at the beginning, the end, or at
specified points within the file. Both length and position are
specified in seconds. I<length> is the amount of silence to insert,
and position the position at which to insert it. Any number of
lengths and positions may be specified, provided that each
specified I<position> is not less that the previous one. I<position>
is optional for the first and last lengths specified, and if
omitted they correspond to the beginning and end respectively.
For example:   I<pad 2 2>   adds two seconds of silence at each
end, whilst   I<pad 2.5@180>   inserts 2.5 seconds of silence 3
minutes into the MIDI. If silence is wanted only at the end,
specify a zero-length pad at the start.

=item  pan   direction

Pans all the MIDI-channels from one side to another. The
I<direction> is a value from -1 to 1; -1 represents far-left and 1
represents far-right.

=item  pitch  shift  { channel:shift }

Changes the pitch (i.e. key but not tempo). I<shift> gives the
pitch-shift, as positive or negative "cents" (i.e. 100ths of a
semitone). However, currently all pitch-shifts get rounded to the
nearest 100 cents, i.e. to the nearest semitone.
Individual channels (0..15) can be given individual shifts.

=item  quantise  length  { channel:length }

=item  quantize  length  { channel:length }

Adjusts the beginnings of all the notes to be a multiple of I<length>
seconds since the previous note.   If the I<length> is greater than 30
then it is considered to be in milliseconds.  Channels for which length
is zero do not get quantised.  I<quantise> and I<quantize> are synonyms.
This is a MIDI-related effect, and is not present in Sox.

=item  repeat   count

Repeat the entire MIDI I<count> times. Note that repeating one time
doubles the length: the original MIDI plus the one repeat.

=item  stat   [-freq]

Does a statistical check on the MIDI, and prints results on
stderr. The MIDI is passed unmodified through the processing
chain.
The I<-freq> option calculates the input's MIDI-pitch-spectrum
(60 = middle-C) and prints it to stderr before the rest of the
stats.

=item  tempo   factor

Changes the tempo (but not the pitch). I<factor> gives the ratio of
new tempo to the old tempo. So if I<factor> > 1.0, then the MIDI
will be speeded up.

=item  trim   start [length]

Outputs only the segment of the file starting at I<start> seconds,
and ending I<length> seconds later, or at the end if I<length> is not
specified. To preserve instruments, however, the lastest
patch-setting event in each channel is preserved, even if it
occurred before the start of the segment.

=item  vol  increment { channel:increment }

Adjusts the velocity (volume) of all notes by a fixed increment.
If "increment" is -15 every note has its velocity reduced by
fifteen, if it is 0 there is no effect, if it is +10 the velocity is
increased by ten. Individual channels (0..15) can be given individual
adjustments.  The syntax of this effect is not the same as SoX's vol.

=back

=head1 DOWNLOAD

B<Python3>   The current version of midisox is available by http at
http://www.pjb.com.au/midi/free/midisox
To install midisox, save it to disc, move it into your $PATH, make it
executable, and if necessary edit the first line to reflect where
python3 is installed on your system. You will also need to install the
MIDI.py and TermClui.py modules in your $PYTHONPATH.

B<Perl>   The current version of midisox_pl is available by http at
http://www.pjb.com.au/midi/free/midisox_pl
To install it, save it to disc, rename it midisox, move it into your
$PATH, make it executable, and if necessary edit the first line to
reflect where perl is installed on your system. You will also need to
install the MIDI-Perl and Term::Clui CPAN modules


=head1 AUTHOR

Peter J Billam www.pjb.com.au/comp/contact.html

=head1 REQUIREMENTS

 * The Python 3 version requires MIDI.py and TermClui.py
 * The Perl version requires MIDI-Perl and Term::Clui
     __________________________________________________________________

=head1 SEE ALSO

 http://sox.sourceforge.net
 http://www.pjb.com.au/midi/MIDI.html
 http://www.pjb.com.au/midi/TermClui.html
 http://search.cpan.org/~sburke
 http://search.cpan.org/perldoc?Term::Clui
 http://www.pjb.com.au/midi

=cut
