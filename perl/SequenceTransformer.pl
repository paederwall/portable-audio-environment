# Sequence transformer, used to convert my homemade music script to a numerical array format (to be played in Pure Data sequencer program).

use v5.10.0;
use warnings;
use strict;
use Data::Dumper qw(Dumper);

use Cwd;

#use NoteHash qw(getNoteHash);

# set current directory
#use constant DIR => q{"/Users/Pae/Desktop/portable-audio-environment/perl/sequencer"};
use constant DIR => getcwd;
chdir DIR;

# Pulse per quarter note resolution
my $ppqn = 96;

# Total arrays used to store data (multiple arrays are used for events that occur simultaneously
my $totalArrays = 0;

# Arrays to copy data to output files
my @channelArray;
my @noteArray;
my @velocityArray;

# Get # of input files (each file is its own channel i.e. MIDI)
#my $currentDir = "/Users/Pae/Desktop/portable-audio-environment/perl/input";
my $currentDir = DIR . "/input/";
opendir my $dir, $currentDir or die $1;
my @inputFiles = readdir $dir;
closedir $dir;
# Remove . and .. entries from directory list
shift @inputFiles;
shift @inputFiles;

#print Dumper \@inputFiles;

# Build hash table of notation note to midi note (e.g. C5 to 60)
my @noteNames = ("c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b");
my %noteHash;
for my $n (0..127) {
	my $index = 0;
	my $octave = 0;
	if ($n > 0) {
		$index = $n % 12;
		{
			use integer;
			$octave = $n / 12;
		}
	}
	my $noteNumber = "$noteNames[$index]" . "$octave";
	$noteHash{$noteNumber} = $n;
}

# Build hash table of dynamics to midi velocity(e.g. mf to 72)
my %velocityHash = (
	pppp	=> 1,
	ppp		=> 8,
	pp		=> 24,
	p			=> 40,
	mp		=> 56,
	mf		=> 72,
	f			=> 88,
	ff		=> 104,
	fff		=> 120,
	ffff	=> 127,
);


# Create needed channel, note, and velocity input file handlers
my @inputHandles;
{
	my $counter = 0;
	for my $text (@inputFiles) {
		open $inputHandles[$counter], '<', "input/$text";
		++$counter;
	}
}

# Main array building loop
readFiles(@inputHandles);

sub readFiles {
	my $index = 0;
	for my $file (@_) {
		# Parse name of file to get channel number
		my @textNames = split /\./, $inputFiles[$index];
		my $channel = $textNames[0];

		readLines($file, \$channel);
		++$index;
	}
}

sub readLines {
	my ($fileRef, $channelRef) = @_;
	my $totalLines = 1;
	while (my $line = <$fileRef>) {
		# If line is blank, skip it
		if ($line !~ m/^\s*$/) {
			readEntries(\$line, $channelRef, \$totalLines);
		}
		++$totalLines;
	}
}

sub readEntries {
	my ($lineRef, $channelRef, $totalLinesRef) = @_;
	# Split the line by space character
	my @entries = split / /, $$lineRef;
	for my $datum (@entries) {
		# Check for parenthesis, if so get the multiplier
		my $multiplier = 1;
		if ($datum =~ m/(\d+)\((.*)\)/) {
			$multiplier = $1;
			$datum = $2;
		}
		# Split the datum by dot character
		my @values = split /\./, $datum;

		my $notes = $values[0];
		if ($notes =~ m/-/) {

		}
		my $velocities = $values[1];
		my $length = $values[2];
		my $offset = 0;
		if (defined $values[3]) {
			$offset = $values[3];
		}

		loopMultiplier(
			$channelRef, $totalLinesRef, \$multiplier,
			\$notes, \$velocities, \$length,
			\$offset
		);
	}
}

sub loopMultiplier {
	my (
		$channelRef, $totalLinesRef, $multiplierRef,
		$notesRef, $velocitiesRef, $lengthRef,
		$offsetRef
	) = @_;

	# $position is used to specify where notes are positioned
	# in output arrays.  The $multiplier and multiple values
	# in the $datum (e.g. c6,c5.127.4) allow sequencial
	# placement of notes.
	my $position = 0;
	for my $m (1..$$multiplierRef) {

		my $note = $$notesRef;
		my $velocity = $$velocitiesRef;

		# Check if notes contain - , which tells us to interpolate
		if ($$notesRef =~ m/([^-].*)-([^-].*)/) {
			my $y0 = $1;
			my $y1 = $2;
			# Check if note and velocity values need to be converted from
			# symbols to numbers (e.g. note c5 -> 60,  velocity mf -> 72)
			lookupNoteHash(\$y0);
			lookupNoteHash(\$y1);
			$note = interp(\$m, $multiplierRef, \$y0, \$y1);
		}

		# Check if velocities contain - , which tells us to interpolate
		if ($$velocitiesRef =~ m/([^-].*)-([^-].*)/) {
			my $y0 = $1;
			my $y1 = $2;
			# Check if note and velocity values need to be converted from
			# symbols to numbers (e.g. note c5 -> 60,  velocity mf -> 72)
			lookupVelocityHash(\$y0);
			lookupVelocityHash(\$y1);
			$velocity = interp(\$m, $multiplierRef, \$y0, \$y1);
		}

		setNoteData(
			$channelRef, $totalLinesRef, \$m,
			\$note, \$velocity, $lengthRef,
			$offsetRef, \$position
		);

		#loopNotes(
		#	$channelRef, $totalLinesRef, \$m,
		#	$notesRef, $velocitiesRef, $lengthRef,
		#	$offsetRef, \$position
		#);
	}
}

=pod
sub loopNotes {
	my (
		$channelRef, $totalLinesRef, $multiplierRef,
		$notesRef, $velocitiesRef, $lengthRef,
		$offsetRef, $positionRef
	) = @_;

	# Split note value by comma
	my @splitNotes = split /,/, $$notesRef;
	my $noteCounter = 0;
	for my $currentNote (@splitNotes) {
		setNoteData(
			$channelRef, $totalLinesRef, $multiplierRef,
			\@splitNotes, $velocitiesRef, $lengthRef,
			$offsetRef, $positionRef, \$noteCounter
		);

		++$noteCounter;
	}
}
=cut

sub setNoteData {
	my (
		$channelRef, $totalLinesRef, $multiplierRef,
		$noteRef, $velocityRef, $lengthRef,
		$offsetRef, $positionRef
	) = @_;

	# Set the start position
	setStartPosition(
		$totalLinesRef, $multiplierRef, $offsetRef,
		$positionRef
	);

	# Check if note and velocity values need to be converted from
	# symbols to numbers (e.g. note c5 -> 60,  velocity mf -> 72)
	lookupNoteHash($noteRef);
	lookupVelocityHash($velocityRef);

	# Handle simultaneous events by incrementing arrays in use
	my $arrayCounter = 0;
	checkDefined(\$arrayCounter, $positionRef);

	# Set the actual channel, note, and velocity start data in
	# the array and position calculated above
	setChannelArray(\$arrayCounter, $positionRef, $channelRef);
	setNoteArray(\$arrayCounter, $positionRef, $noteRef);
	setVelocityArray(\$arrayCounter, $positionRef, $velocityRef);

	# Set the end position
	setEndPosition($lengthRef, $positionRef);

	# Reset $arrayCounter to 0 and check simultaneous events
	# for end data
	$arrayCounter = 0;
	checkDefined(\$arrayCounter, $positionRef);

	# Set the actual channel, note, and velocity (0) end data in
	# the array and position calculated above
	setChannelArray(\$arrayCounter, $positionRef, $channelRef);
	setNoteArray(\$arrayCounter, $positionRef, $noteRef);
	setEndVelocityArray(\$arrayCounter, $positionRef);
}

sub interp {
	my ($xRef, $x1Ref, $y0Ref, $y1Ref) = @_;
	my $x0 = 1;
	# Interpolate for y to calculate the current note or velocity
	# using current multiplier as x, 1 as x0, max multiplier as x1,
	# y0 and y1 as the input values

	my $y = 0;
	$y = ($$y0Ref * ($$x1Ref - $$xRef) + $$y1Ref * ($$xRef - $x0)) / ($$x1Ref - $x0);

	return $y;
}

sub setStartPosition {
	my (
		$totalLinesRef, $multiplierRef, $offsetRef,
		$positionRef
	) = @_;

	# Get initial position for note in array
	if ($$multiplierRef == 1) {
		if ($$offsetRef == 0) {
			$$positionRef = ($$totalLinesRef * $ppqn);
		} else {
			$$positionRef = ($$totalLinesRef * $ppqn) + (($ppqn * 4) / $$offsetRef);
		}
	} else {
		$$positionRef = $$positionRef + 1;
	}
}

sub lookupNoteHash {
	my ($noteRef) = @_;
	# Check if note needs look up in hash table
	if ($$noteRef =~ m/[a-g].*/) {
		$$noteRef = $noteHash{$$noteRef};
	}
}

sub lookupVelocityHash {
	my ($velocityRef) = @_;
	# Check if velocity needs look up in hash table
	if ($$velocityRef =~ m/[pmf].*/) {
		$$velocityRef = $velocityHash{$$velocityRef};
	}
}

sub checkDefined {
	my ($arrayCounterRef, $positionRef) = @_;
	# Check if start data already in position, if so increment counter
	while (defined $noteArray[$$arrayCounterRef][$$positionRef]) {
		++$$arrayCounterRef;
		# Track total arrays used
		if ($totalArrays < $$arrayCounterRef) {
			$totalArrays = $$arrayCounterRef;
		}
	}
}

sub setChannelArray {
	my ($arrayCounterRef, $positionRef, $channelRef) = @_;
	$channelArray[$$arrayCounterRef][$$positionRef] = $$channelRef;
}

sub setNoteArray {
	my ($arrayCounterRef, $positionRef, $noteRef) = @_;

	$noteArray[$$arrayCounterRef][$$positionRef] = $$noteRef;
}

sub setVelocityArray {
	my ($arrayCounterRef, $positionRef, $velocityRef) = @_;
	$velocityArray[$$arrayCounterRef][$$positionRef] = $$velocityRef;
}

sub setEndVelocityArray {
	my ($arrayCounterRef, $positionRef) = @_;
	$velocityArray[$$arrayCounterRef][$$positionRef] = 0;
}

sub setEndPosition {
	my ($lengthRef, $positionRef) = @_;
	# Get end of note position
	$$positionRef = $$positionRef + (($ppqn * 4) / $$lengthRef) - 1;
}

# Remove blank leading 96 elements (results from ppqn calculations above)
{
	my @outputArrays = (@channelArray, @noteArray, @velocityArray);
	for my $array (@outputArrays) {
		for my $e (0..95) {
			shift @$array;
		}
	}
}

# Clear transform folder
my $errors;
while ($_ = glob('transform/*.txt')) {
   next if -d $_;
   unlink($_)
      or ++$errors, warn("Can't remove $_: $!");
}

exit(1) if $errors;


# Open output file handlers
my @channelHandles;
my @noteHandles;
my @velocityHandles;
{
	my %outputHandlesFilenameHash = (
		"c" => \@channelHandles,
		"n" => \@noteHandles,
		"v" => \@velocityHandles,
	);

	keys %outputHandlesFilenameHash;
	while (my ($k, $v) = each %outputHandlesFilenameHash) {
		for my $array ($v) {
			for my $h (0..$totalArrays) {
				open $$array[$h], '>', "transform/$k$h.txt";
			}
		}
	}
}

# Create loader output handler
my $loaderHandle;
open $loaderHandle, '>', "transform/loader.txt";

#print Dumper \@velocityArray;

# Copy data from output arrays to output handlers
my @outputArrays = (@channelArray, @noteArray, @velocityArray);
my @outputHandles = (@channelHandles, @noteHandles, @velocityHandles);

my $count = 0;
for my $array (@outputArrays) {
	for my $data (@$array) {
		if (defined $data) {
			print {$outputHandles[$count]} "$data\n";
		} else {
			print {$outputHandles[$count]} "0\n";
		}
	}
	++$count;
}

# Copy data to loader file
++$totalArrays;
my $arrayLength = scalar @{ $noteArray[0] };
print {$loaderHandle} "length $arrayLength\n";
print {$loaderHandle} "totalfiles $totalArrays\n";

print "\n$arrayLength lines in output files.";
print "\n$totalArrays arrays created.";
