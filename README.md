# uncollider
Resolves filename collision problems by a few methods, including moving colliding files and directories to another folder.

# Compatibility
It's suited for BASH only. Was developed and tested with Bash v 4.4 on Ubuntu GNU/Linux. I can't say if it would work on other operating systems, but I hope it works on most Unixes.

# Resolution Methods
- Move colliding files and directories to another directory, while preserving relative path.
- Add a suffix.

# Safeguards
- Option to backup a copy of the original "source directory" (with its filename collisions) as it was, before uncollider starts manipulating those files.
- Log operations on a text file.
- Option to use a custom "trash" command.
- Checks for sane filename parsing. (But it's limited by bash's restrictions on variables characters.)
- Option to suppress confirmation and other promts from standard output - thus making it somewhat suitable for unattended invokation.

# Other features
- "Move" files using rsync (and then deletes the copyied files, if you want to), which provide many options (if you are willing to edit the script).
- Can operate over networked machines. So you can get all the colliding names moved from a machine to another one.
- Has a "manual" and a "help" option to offer some guidance.
