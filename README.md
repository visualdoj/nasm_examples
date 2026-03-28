# NASM examples

|Program  |Description                                                         |Sources                                                                           |
|---------|--------------------------------------------------------------------|----------------------------------------------------------------------------------|
|exit77   |Returns exit code 77, kind of minimal application                   |[unix64](unix64/exit77.asm)  [win64](win64/exit77.asm)  [mac64](mac64/exit77.asm) |
|hello    |Prints "Hello world!", basics of printing to stdout                 |[unix64](unix64/hello.asm)   [win64](win64/hello.asm)   [mac64](mac64/hello.asm)  |
|args     |Prints command line arguments, one per line, in UTF-8 encoding      |[unix64](unix64/args.asm)    [win64](win64/args.asm)    [mac64](mac64/args.asm)   |
|count    |Prints integers from 1 to N, one per line                           |[unix64](unix64/count.asm)   [win64](win64/count.asm)   [mac64](mac64/count.asm)  |
|envvars  |Prints environment variables, one per line, in UTF-8 encoding       |[unix64](unix64/envvars.asm) [win64](win64/envvars.asm) [mac64](mac64/envvars.asm)|
|colors   |Prints colorful output (if supported by TTY)                        |[unix64](unix64/colors.asm)  [win64](win64/colors.asm)  [mac64](mac64/colors.asm) |
|upper    |Converts all lowercase letters in stdin to uppercase                |[unix64](unix64/upper.asm)   [win64](win64/upper.asm)   [mac64](mac64/upper.asm)  |
|reverse  |Reads all of stdin and prints it in reverse                         |[unix64](unix64/reverse.asm) [win64](win64/reverse.asm) [mac64](mac64/reverse.asm)|
|clock    |Prints current UTC date and time in ISO 8601 format                 |[unix64](unix64/clock.asm)   [win64](win64/clock.asm)   [mac64](mac64/clock.asm)  |
|sleep    |Sleeps for the specified number of seconds                          |[unix64](unix64/sleep.asm)   [win64](win64/sleep.asm)   [mac64](mac64/sleep.asm)  |
|hexdump  |Dumps a file in hex dump format                                     |[unix64](unix64/hexdump.asm) [win64](win64/hexdump.asm) [mac64](mac64/hexdump.asm)|
|clear    |Clears the terminal screen                                          |[unix64](unix64/clear.asm)   [win64](win64/clear.asm)   [mac64](mac64/clear.asm)  |
|sqrt     |Prints the square root of a floating-point argument                 |[unix64](unix64/sqrt.asm)    [win64](win64/sqrt.asm)    [mac64](mac64/sqrt.asm)   |
|ctrlc    |Waits for Ctrl+C, acknowledges it, and exits via standard signal    |[unix64](unix64/ctrlc.asm)   [win64](win64/ctrlc.asm)   [mac64](mac64/ctrlc.asm)  |
