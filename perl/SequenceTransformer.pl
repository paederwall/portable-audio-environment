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

# Total lines in input file
my $totalLines = 0;

# Values for each line, entries for each datum
my @values;
my @entries;

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

# Read the input file handlers
{
	my $channel = 0;
	my $index = 0;
	for my $inputFile (@inputHandles) {
		# Parse name of file to get channel number
		my @textNames = split /\./, $inputFiles[$index];
		$channel = $textNames[0];
		# Reset line counter
		$totalLines = 1;
		# Read the input file, split lines into datum and copy data to arrays
		while (my $line = <$inputFile>) {
			# Split the line by space character
			@entries = split / /, $line;
			for my $datum (@entries) {
				# Check for parenthesis, if so get the multiplier
				my $multiplier = 1;
				if ($datum =~ m/(\d+)\((.*)\)/) {
					$multiplier = $1;
					$datum = $2;
				}
				# Split the datum by dot character
				@values = split /\./, $datum;
				# 0 position
				my $position = 0;
				# Multiplier loop
				for my $m (1..$multiplier) {
					# Check if at least 3 elements in values array (note, velocity and length, optional offset)
					if ((scalar @values) >= 3) {
						# Set note position offset to 0, then check if there is offset data
						my $offset = 0;
						if (defined $values[3]) {
							$offset = ($ppqn * 4) / $values[3];
						}
						# Check if note needs look up in hash table
						if ($values[0] =~ m/[a-g].*/) {
							$values[0] = $noteHash{$values[0]};
						}
						# Check if velocity needs look up in hash table
						if ($values[1] =~ m/[pmf].*/) {
							$values[1] = $velocityHash{$values[1]};
						}
						# Get initial position for note in array
						if ($m == 1) {
							$position = ($totalLines * $ppqn) + $offset;
						} else {
							$position = $position + 1;
						}
						# Counter to track array in use
						my $counter = 0;
						# Check if start data already in position, if so increment counter
						while (defined $noteArray[$counter][$position]) {
							++$counter;
							# Track total arrays used
							if ($totalArrays < ($counter + 1)) {
								$totalArrays = ($counter + 1);
							}
						}
						# Copy start channel, note, and velocity to array
						$channelArray[$counter][$position] = $channel;
						$noteArray[$counter][$position] = $values[0];
						$velocityArray[$counter][$position] = $values[1];
						# Get end of note position
						$position = ($position + (($ppqn * 4) / $values[2]) - 1);
						# Reset counter
						$counter = 0;
						# Check if end data already in position, if so increment counter
						while (defined $noteArray[$counter][$position]) {
							++$counter;
							# Track total arrays used
							if ($totalArrays < ($counter + 1)) {
								$totalArrays = ($counter + 1);
							}
						}
						# Copy end channel, note, and velocity to array
						$channelArray[$counter][$position] = $channel;
						$noteArray[$counter][$position] = $values[0];
						$velocityArray[$counter][$position] = 0;
					}
				}
			}
			# Track total number of lines in input file
			++$totalLines;
			# Empty values array (in case next line is empty)
			@values = ();
		}
		++$index;
	}
}

# Remove blank leading 96 elements (results from ppqn calculations above)
{
	for my $array (@channelArray) {
		for my $e (0..95) {
			shift @$array;
		}
	}
	for my $array (@noteArray) {
		for my $e (0..95) {
			shift @$array;
		}
	}
	for my $array (@velocityArray) {
		for my $e (0..95) {
			shift @$array;
		}
	}
}

# Set totalarrays to 1 if still 0
if ($totalArrays == 0) {
	$totalArrays = 1;
}

# Create needed channel, note, and velocity output file handlers
my @channelHandles;
for my $h (0..($totalArrays - 1)) {
	open $channelHandles[$h], '>', "transform/c$h.txt";
}
my @noteHandles;
for my $h (0..($totalArrays - 1)) {
	open $noteHandles[$h], '>', "transform/n$h.txt";
}
my @velocityHandles;
for my $h (0..($totalArrays - 1)) {
	open $velocityHandles[$h], '>', "transform/v$h.txt";
}

# Create loader output handler
my $loaderHandle;
open $loaderHandle, '>', "transform/loader.txt";

#print Dumper \@channelArray;

# Copy array data to channel file
{
	my $counter = 0;
	for my $array (@channelArray) {
		for my $channel (@$array) {
			if (defined $channel) {
				print {$channelHandles[$counter]} "$channel\n";
			} else {
				print {$channelHandles[$counter]} "0\n";
			}
		}
	++$counter;
	}
}

# Copy array data to note file
{
	my $counter = 0;
	for my $array (@noteArray) {
		for my $note (@$array) {
			if (defined $note) {
				print {$noteHandles[$counter]} "$note\n";
			} else {
				print {$noteHandles[$counter]} "0\n";
			}
		}
	++$counter;
	}
}

# Copy array data to velocity file
{
	my $counter = 0;
	for my $array (@velocityArray) {
		for my $velocity (@$array) {
			if (defined $velocity) {
				print {$velocityHandles[$counter]} "$velocity\n";
			} else {
				print {$velocityHandles[$counter]} "0\n";
			}
		}
	++$counter;
	}
}

# Copy data to loader file
my $arrayLength = scalar @{ $noteArray[0] };
print {$loaderHandle} "length $arrayLength\n";
print {$loaderHandle} "totalfiles $totalArrays\n";

print "\n$arrayLength lines in output files.";
print "\n$totalArrays arrays created.";
