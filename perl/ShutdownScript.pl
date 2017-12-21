# Shutdown script to kill Pure Data patches

use v5.10.0;
use warnings;
use strict;

# Kill all pd.exe processes running
system('taskkill /F /IM pd.exe >nul 2>&1');
