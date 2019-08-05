#!/bin/bash

# by samy , started in may 15 019 (tue).


# purpose: 1) find all files whose names would collide if filesystem was not case sensitive.
#        : 2) rsync them, partially preserving relative path, to a secondary folder.
#        : 3) delete one of the potentially colliding files from source-dir.

#     HOW DOES THIS SCRIPT WORKS? See the help instructions and also the notes section, written 
#  after the "exit" command (thus, they are not executed).


### PENDING: thanks to ~~woodknowledge wiki, bashhackers https://brettterpstra.com/2015/02/20/shell-trick-printf-rules/ and opensource communities.

### PENDING/IDEAS:
# try to use existing functions to parse directories and links
# different confirmation message for add-suffix (no sense in showing nor requiring target dir)
# harden filename parsing by using tempfiles instead of bash variables?
# put all used options on log
# stopped doing... : line 351, about sdirbakpath. current state makes into invokerr (at least when invoked without bakpath on cmdline).
#                    strategically: creating function "asktops" to ask options for the parameters without options on invocation. then, respective functions will only execute option intentions, if activated - they wont anymore parse if argument/option were invoked.


#set -x
#set -e

function prbox {

	msgboxw="$(( 2 * $(tput cols) / 3 ))"

	printf -v mblen "%*s" "$(( msgboxw + 5  ))"
	echo ""
	printf '  =%s=\n' "${mblen// /'='}"

	while IFS= read -r -d $'\n' line 
	do
		txwt="${#line}"
		wsdelta="$(( "$msgboxw" - "$txwt" ))"
		
		printf '  #   %s %*s #\n' "$line" "$wsdelta"
	
	done < <(fmt -t -w "$msgboxw" <( printf '%s' "$@" ))

	printf '  #%s#\n' "${mblen}"
	printf '  =%s=\n' "${mblen// /'='}"
	echo ""
}

function shwman {

prbox '
          MANUAL for The Uncollider Script

   This script will "move" all files that have a filename that would "collide" (thus not alowed) in a case insensitive filesystem, as seen in some cloud providers (as Tresorit) and some non-fre Operating Systems (like Windows®). The colliding files (except the first one of them) will be copyed from "source-dir" to "target-dir" and then removed or trashed from "target-dir".
   If possible it will not "remove", but "trash" the colliding files, (in "source-dir") using the "gio" command-line tool (currenty present on Ubuntu® and other free operating systems), so you can recover the trashed files afterwards, if you want to.
   "Moved" files on the "target-dir" will be placed in a relative path on "source-dir" - meaning they will be in the same directory hierarchy that they were in "source-dir". This way, if you do some kind of "merge mount" (a.k.a. "union mount") you could have all your files correctly placed on a single directory (the merged directory).
   There are a handful well known tools that allows such kind of mounts - and all of them are actual binary programs, dealing with complex filesystem things. Therefore providing such feature is out of scope of this script. However, they do not provide (as of my current knowledge) a way to create a secondary directory with colliding filenames on their relative path to a primary directory, as this script does. So this script provides a working ground for this kind of usage, if you want to.
   Also Worth noting that this script parses the filenames using the "NULL" character as filename delimiter. Therefore it is expected to sanely deal with filenames containing white spaces and other uncommon charaters.

   Usage: ./script <source-dir> <target-dir>
'
	exit 0
}

function shwhelp {

prbox '
            HELP for The Uncollider Script

    Uncollider works by "moving" the files, in a directory (That we call "source-dir"), that have colliding names ( for example "friends.jpg" and "Friends.jpg" ) to a "target-dir" (of your choice) that accepts those names.
    Usually, one of those files will be kept on "source-dir", and all the others go to "target-dir" - but relatively preserving its path. This way you can easily navigate in the "target-dir" tree, and even use some kind of "merge mount" (which is not provided by Uncollider) to have all of the colliding files in a single directory.
    
    ===>> WARNINGS !!! <<===
    --->> There are a hanful of parameter options available, and they can substantially change Uncollider behavior.
    --->> Uncollider does NOT have any kind of "undo" operation! However, it supports some parameters that may significantly guard your system from unwanted (and/or unforseen) changes.
    --->> This way, we STRONGLY recommend that you read the Manual, before actually using Uncollider for real.
    
    --->> You can read the manual by giving the command (quotes not necessary):
    $ "./uncollider.sh --man"'

    exit 0

}

function invokerr {

	prbox '
   ERROR

   There was something wrong with Uncollider invokation parameters.

   Please check if you have written the command correctly and try again.

   Some possible causes for this error are: mistyping some parameter, giving a not executable binary "--customcmd", giving a not writeable directory for "--sourcedir-backup", or misplacing the double-quotes (if used).

   Mind you that Uncollider requires an atypical placement for double (or single) quotes (if you need them, maybe in order to use a path containing a "space" character). So instead of writing something like:
   [ $ ./uncollider.sh --customcmd="/bin/some program" ],
   you should write something like:
   [ $ ./uncollider.sh "--customcmd=/bin/some program" ]. You can use single quotes instead, as well.

   You can see the help by running: $ "./uncollider.sh --help" (or with "-h" instead).
   
   You can see the manual by running: $ "./uncollider.sh --man" (or with "-m" instead).'

   exit 1
}


function crcolgp {
		# creates collision groups

	nforcgpname=$(( ${#colgpnames[@]} + 1 )) # number for collision group name
	currcgp="colgp$nforcgpname" #### MAYBE declaring as indirect reference again would broke it!
	colgpnames+=( $currcgp )
}

function addfilename {
		# adds filenames as elements of the colgp array

		eval $currcgp+=\( "\"$1\"" \)
}


function mvcolnames {
		# moves colliding names to a local directory

if [[ "$opsavelog" == yes ]] && [[ "$initlogdone" != "yes" ]]
then
	touch uncollider.log
	echo "" >> uncollider.log
	echo '###  Log File of the Uncollider script  ###' >> uncollider.log
	echo "Please note that this log file could contain logs from past invokations of the Uncollider script." >> uncollider.log
	echo "Date and time of this invokation: ""$(date '+%m/%B/%y, %H:%M:%S')" >> uncollider.log
	echo "The files listed below were transfered to \"""$targetdir""\" by the Uncollider script:" >> uncollider.log
	initlogdone="yes"
	mvcolnames
else
	for cgp in "${colgpnames[@]}"
	do
		necgp=$(eval echo \$\{\#$cgp\[\@\]\}) # necgp = number of elements in the array of the $(iterating collision group array)
		i=0
		while [[ i -lt $necgp ]]
		do
			cfile="$(eval echo \$\{$cgp\[$i\]\})"
			if [[ "$cfile" == "$(eval echo \$\{$cgp\[0\]\})" ]] # loop 3 if ;if filename is index 0 on filename array
			then # then, skip this iteration
					:
			else # else, copy it to target-dir ; then trash them from source-sir
				if [[ "$opaddsuff" == "yes"  ]]
				then
					echo "hello $cfile"
					cbnfile="${cfile##*/}"
					if [[ "$cbnfile" == "${cbnfile%.*}" ]]
					then
						echo "$cbnfile equals ${cbnfile%.*}" 
						mv "$cfile" "${cfile}_${i}"
					else
						newname="${cfile%/*}""/""${cbnfile%.*}_${i}"".""${cbnfile##*.}"
						echo "hello $newname"
						mv "$cfile" "$newname"
					fi
				else
					rsync -aR "$rsyncprefix${cfile#*$srcdirbasename}" "$targetdir"
					if [[ "$optrashcmd" == "yes"  ]]
					then
						"${custinvok[*]}" "$cfile"
					else
						if [[ -x /usr/bin/gio ]] && ! [[ "$opforcerm" == "yes" ]]
						then
							gio trash "$cfile"
						elif [[ "$opforcerm" == "yes"  ]]
						then
							rm "$cfile"
						else
							rm "$cfile"
						fi
					fi
				fi
			fi
			i=$(( i + 1  ))
			if [[ "$opsavelog" == "yes"  ]]
			then
				printf "\n%s" "$cfile" >> uncollider.log
			else
				:
			fi
		done
	done
fi
}

function getcolfilenames {

	while IFS= read -r -d $'\0' line
	do
		if ! [[ -n $line ]] # true if length of $line is "zero" (so will return true if something in the lines)
		then # this arm is for blank lines
			crcolgp
		else # this arm is for non-blank lines
			cksanenameparsing "$line"
			addfilename "${line[@]}"
		fi
done < <(uniq --zero-terminated --ignore-case --all-repeated=prepend <(sort --zero-terminated <(find "$sourcedir" -type f -print0 )))
}

function pargtrash {

	if [[ "$optrashcmd" == "yes" ]] && [[ -x "${custinvok%% *}" ]]
		then
			:
		elif [[ "$optrashcmd" == "no" ]]
		then
			:
		else
			prbox '
    You chose to run a custom command on the remaining colliding files at "source-dir".
    Mind you that Uncollider will run the exact command you write below, including invokation parameters, placing the filename at the end of the command-line. 
    For example, if you type like the line below (quotes not necessary for Uncollider to work):
    The custom command is: "/bin/foo --param1 --param2"
    And Uncollider have a colliding file named "bar.txt" remaining at "source-dir", Uncollider will do:
    $ "/bin/foo --param1 --param2 bar.txt"

    If you wish to leave "source-dir" with all the files it already had, just type ":", wich is a kind of empty command. For example (again, quotes are not necessary):
    The custom command is: ":"

    Please type, below, the command you wish to run.'

		IFS= read -r -t 60 -p "The custom command is: " custinvok
		if ! [[ -x "${custinvok%% *}" ]]
		then
   			invokerr
		else
				:
		fi
	fi

}

function pargsdirbak {

	if [[ "$opsourcedirbak" == "yes" ]]
	then
		if [[ -d "$sdirbakpath" ]] && [[ -w "$sdirbakpath" ]]
		then
			rsync -aHAX --progress --info=stats2 "$sourcedir" "$sdirbakpath"
			prbox '
Backup finished. Now proceeding.'
			echo -e "\a"
			sleep 2
		else
			prbox '
    You chose to save a backup copy of "source-dir" before Uncollider starts running file operations.

    Please type, below, the FULL PATH of the directory were this backup should be placed:'

    			IFS= read -r -t 60 -p "The chosen path is: " -i "$PWD" sdirbakpath 

			if [[ -d "$sdirbakpath" ]] && [[ -w "$sdirbakpath" ]]
			then
				rsync -aHAX --progress --info=stats2 "$sourcedir" "$sdirbakpath"
				prbox '
   Backup finished. Now proceeding.'
				echo -e "\n"
				sleep 2
			else
				invokerr
			fi
		fi
	else
		:

	fi
}

function pargnoconfirm {


	if [[ "$opnoconfirm" == "yes" ]]
	then
		:
	else
		prbox "
   CONFIRMATION NEEDED

   Before actually starting file operations we need you to confirm your settings.
   Please check tem carefully.

   Source Directory:
${sourcedir}
   Target Directory:
${targetdir}
   --add-suffix activated?           ${opaddsuff}
   --save-log activated?             ${opsavelog}
   --sourcedir-backup activated?     ${opsourcedirbak}
   -   Path to source-dir backup:    ${sdirbakpath[*]}
   --force-rm activated?             ${opforcerm}
   --trashcmd activated?             ${optrashcmd}
   -   Custom trash command:         ${custinvok[*]} 

   ===>> You are running Uncollider as the user: $(whoami)

   In case of any doubts, we recommend that you abort this execution and go check in the detailed help.
   
   --->> Do you wish to continue? Type \"yes\" to continue, or anything else to abort."

		echo -e "\n"
		IFS= read -r -t 60 -p "Please answer here: " confirmrun
		if [[ "$confirmrun" == "yes"  ]]
		then
			prbox '
    You chose to run Uncollider with the currently provided parameters (as shown above).
    
    It will start running the file operations in 5 seconds.'
			echo -e "\n"
			sleep 5
		else
			prbox '
   You did not confirm that Uncollider should run its file operations.

   For this reason, Uncollider is now exiting.

   Feel free to use Uncollider afterwards.'
			echo -e "\n"
		fi
	fi
}

function askopts {

	for pendopt in "${pendingopts[@]}"
	do
		if [[ $pendopt == "--sourcedir-backup" ]]
		then
			prbox '

			PARAMETER REQUIRED: path of backup from "source-dir".
    
    You chose to save a backup copy of "source-dir" before Uncollider starts running file operations.

    Please type, below, the FULL PATH of the directory were this backup should be placed:'

    			IFS= read -r -t 60 -p "The chosen path is: " -i "$PWD" sdirbakpath

				if [[ -d "$sdirbakpath" ]] && [[ -w "$sdirbakpath" ]]
				then
					:
				else
					echo "ERROR: INVALID BACKUP PATH."
					invokerr
				fi



		elif [[ $pendopt == "--trashcmd" ]]
		then
			prbox '
			PARAMETER REQUIRED: custom trash command.

    You chose to run a custom command on the remaining colliding files at "source-dir".
    Mind you that Uncollider will run the exact command you write below, including invokation parameters, placing the filename at the end of the command-line. 
    For example, if you type like the line below (quotes not necessary for Uncollider to work):
    The custom command is: "/bin/foo --param1 --param2"
    And Uncollider have a colliding file named "bar.txt" remaining at "source-dir", Uncollider will do:
    $ "/bin/foo --param1 --param2 bar.txt"

    If you wish to leave "source-dir" with all the files it already had, just type ":", wich is a kind of empty command. For example (again, quotes are not necessary):
    The custom command is: ":"

    Please type, below, the command you wish to run.'
	
       			IFS= read -r -t 60 -p "The custom command is: " custinvok

				if [[ -x "${custinvok%% *}" ]]
				then
   					:
				else
					invokerr
				fi

		else
			invokerr
		fi
	done
}


function pargparams {

	for opt in "${args[@]}"
	do
		case "${opt%%=*}" in
			--add-suffix)
				noargopt "${opt}"
				ckreparg "opaddsuff"
				opaddsuff="yes"
				;;
			--save-log)
				noargopt "${opt}"
				ckreparg "opsavelog"
				opsavelog="yes"
				;;
			--sourcedir-backup)
				ckreparg "opsourcedirbak"
				opsourcedirbak="yes"
				withargopt "${opt}" "sdirbakpath" 
					if [[ "$sdirbakpath" != "not_effective" ]] && ! [[ -d "$sdirbakpath" ]]
					then
						invokerr
					elif [[ "$sdirbakpath" != "not_effective" ]] && ! [[ -w "$sdirbakpath"  ]]
					then
						invokerr
					else
						:
					fi
				;;
			--force-rm)
				noargopt "${opt}"
				ckreparg "opforcerm"
				opforcerm="yes"
				;;
			--trashcmd)
				ckreparg "optrashcmd"
				optrashcmd="yes"
				withargopt "${opt}" "custinvok"
					if [[ "$custinvok" != "not_effective" ]] && ! [[ -x "${custinvok%% *}" ]]
					then
						invokerr
					else
						:
					fi
				;;
			--no-confirm)
				noargopt "${opt}"
				ckreparg "opnoconfirm"
				opnoconfirm="yes"
				;;
			* )
				invokerr
				exit 1
				;;
		esac
	done
}

function pargonlylisting {

	rfcount=0 ; dircount=0 ; lncount=0 ; evtgcount=0
	
	echo ""
	echo "  #  Listing colliding regular files below:"
	while IFS= read -r -d $'\0' rfline
	do
		cksanenameparsing "$rfline"
		rfcount=$(( "$rfcount" + 1  ))
		echo "$rfline"
	done < <(uniq --zero-terminated --ignore-case --all-repeated=none <(sort --zero-terminated <(find "$sourcedir" -type f -print0 )))
	echo "  #  Total: ""$rfcount"" regular files."

	echo ""
	echo "  #  Listing colliding directories below:"
	while IFS= read -r -d $'\0' dirline
	do
		cksanenameparsing "$dirline"
		dircount=$(( "$dircount" + 1  ))
		echo "$dirline"
	done < <(uniq --zero-terminated --ignore-case --all-repeated=none <(sort --zero-terminated <(find "$sourcedir" -type d -print0 )))
	echo "  #  Total: ""$dircount"" directories."
	
	echo ""
	echo "  #  Listing colliding symbolic link files below:"
	while IFS= read -r -d $'\0' lnline
	do
		cksanenameparsing "$lnline"
		lncount=$(( "$lncount" + 1  ))
		echo "$lnline"
	done < <(uniq --zero-terminated --ignore-case --all-repeated=none <(sort --zero-terminated <(find "$sourcedir" -type l -print0 )))
	echo "  #  Total: ""$lncount"" symlink files."

	echo ""
	echo "  #  Listing colliding files of other kinds (special files that are not link files) below:"
	while IFS= read -r -d $'\0' evtgline
	do
		cksanenameparsing "$evtgline"
		evtgcount=$(( "$evtgcount" + 1  ))
		#echo "$evtgline"
	done < <(uniq --zero-terminated --ignore-case --all-repeated=none <(sort --zero-terminated <(find "$sourcedir" -print0 )))
	echo "  #  Total: ""$(( 0 + "$evtgcount" - "$lncount" - "$dircount" - "$rfcount" ))"" files of other kinds."
	echo "  #    [ Those other kinds  may be any of: block (buffered) special, character (unbuffered) special, named pipe (FIFO), socket, door (Solaris only) ]"
	echo ""
	echo "  #  Total: ""$(( "$evtgcount" + 0  ))"" files of all kinds."
	echo ""
	exit 0


}


function noargopt {

	if [[ "${1%%=*}" != "$1" ]]
	then
		invokerr
	else
		:
	fi
}

function withargopt {

	if [[ "${1%%=*}" != "$1" ]] # if optname ("prefix") not equal to $1 (meaning: if it was given a parameter/suffix)
	then
		echo "$1"
		eval echo "$2"="${1##*=}"
	else                        # if no param was given, remember this option as pending a parameter
		eval pendingopts+=\( "\"$1\"" \)
		#echo "pending opts are: " "${pendingopts[@]}"
	fi
}

function cksanenameparsing {

	ckname="$1"
	if ! [[ -e "$ckname" ]]
		then
			echo '  #  PARSING ERROR  #'
			exit 4
		else
			#echo "parsed $1"
			:
		fi
}


function ckreparg {

	if [[ "$1" == "yes" ]]
	then
		invokerr
	else
		:
	fi
}


#####              #####
#  INVOKATION PARSING  #
#####              #####


for str in "$@"
do
	args+=( "$str" )
	export args
done

ta="${#args[@]}"

export ta

if [[ "$ta" == 1 ]] && [[ "${args[0]}" == '--help' ]] || [[ "${args[0]}" == '-h' ]]
then
	shwhelp
	exit 0

elif [[ "$ta" == 1 ]] && [[ "${args[0]}" == '--man' ]] || [[ "${args[0]}" == '-m' ]]
then
	shwman
	exit 0

elif [[ -d "${args[ $(( "$ta" - 1 )) ]}" ]] && [[ -d "${args[ $(( "$ta" - 2 )) ]}" ]]
then
	lastarg="${args[ $(( "$ta" - 1 )) ]}"
	rbflarg="${args[ $(( "$ta" - 2 )) ]}"
	opadsuff="no" ; opsavelog="no" ; opsourcedirbak="no" ; sdirbakpath="not_effective" ;
	opforcerm="no" ; optrashcmd="no" ; custinvok="not_effective" ; opnoconfirm="no"

	unset -v "args[ $(( "$ta" - 1 )) ]" && unset -v "args[ $(( "$ta" - 2 )) ]"

	pargparams

	targetdir="$(realpath "$lastarg")"
	sourcedir="$(realpath "$rbflarg")"
	srcdirbasename="${sourcedir##*/}"
	rsyncprefix="$sourcedir/."

	askopts

	pargnoconfirm
	#pargtrash
	#pargsdirbak

	#getcolfilenames
	#mvcolnames

	exit 0



elif [[ "$ta" -eq "2"  ]] && [[ -d "${args[ $(( "$ta" - 1 )) ]}" ]] && [[ "${args[ $(( "$ta" - 2 )) ]}" = "--only-listing" ]]
then
	sourcedir="$(realpath "$2")"
	export sourcedir
	pargonlylisting
else
	invokerr
	exit 1
fi

#EOF#
