# Startup script to load Pure Data patches

# Certain patches (fftUnit) need to load first to
# start a localhost socket host.  Then the
# remaining patches are loaded and if applicable
# (Sequencer) connect to the socket host.

# Ports used:
# 3001 - 30??
# UDP Binary (Pure Data options)

use v5.10.0;
use warnings;
use strict;
use Data::Dumper qw(Dumper);

use Cwd;

# set current directory
#use constant DIR => q{"/Users/Pae/Desktop/portable-audio-environment/perl/sequencer"};
use constant DIR => getcwd;
chdir DIR;

# Set number of fftUnit samplers to initialize
my $fftNum = 1;

# Loop fftUnits, incrementer is the UDP port + 3000
for (my $n = 1; $n <= $fftNum; ++$n) {
  my @cmd = (1);
  push @cmd , 'C:/Program Files (x86)/Pd/bin/pd.exe';
  push @cmd, '-send';
  push @cmd, '"initmsg "' . $n;
  push @cmd, DIR . '/../pd/patch/fftUnit.pd';

  system(@cmd);
}

# Start Sequencer, which connects to fftUnits started above
my @cmd = (1);
push @cmd, 'C:/Program Files (x86)/Pd/bin/pd.exe';
push @cmd, DIR . '/../pd/patch/Sequencer.pd';

system(@cmd);
