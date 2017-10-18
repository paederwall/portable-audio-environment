# Compute peak RMS values for MIDI velocity

use v5.10.0;
use warnings;
use strict;
use Data::Dumper qw(Dumper);

# Set dynamic range
my $dynamicRange = 60;

# calculations
my $r = 10**($dynamicRange / 20);
my $s = sqrt($r);
my $b = 127 / (126 * $s) - 1 / 126;
my $m = (1 - $b) / 127;

print "\nSquare root of $r = $s";

print "\nr = $r";
print "\nb = $b";
print "\nm = $m";

# using m and b, calculate function using velocity 1 - 127 as input

for my $i (1..127) {
  my $currentValue = ($m * $i + $b)**2;
  print "\n$i $currentValue";
}
