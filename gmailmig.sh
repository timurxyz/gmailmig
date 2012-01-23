#!/bin/bash

# gmailmig.sh
# This bash script is a wrapper of imapsync to migrate your mail btw gmail/gapps accounts

# Created by timurx as a peace of copyleft goodies, based on works of others
# VERSION: 2012-01-21 (001b)
# Ad: ***Visit azd.se and secmachine.com for security aware guidelines and stuff!***

										helpAbout="\
A wrapper of the imapsync utility for better migration btw gmail/gapps accounts. Made with security in mind."

										helpUsage="
USAGE:  gmailmig.sh --execute|-X | --test|-T[ logins | folders | dry ]
                          [--dates|-d Latest-Oldest] | [--days Min-Max]
			  [-k <path-to-the-credentials-file> ]
			  [--config|-c <custom-config-file-path> ]
                          [--help] [-o YourImapsyncOptions]
Note:   Expose only temporary passwords in the credential file if possible!
	Delete that file soon."

										helpContd="
PREREQUISITES:
- you have to provide your gmail credentials in a file which by default is
  ~/credentials_gmailmig (this configuration can be overriden by -k)
  the format of the credentials file is provided in the bottom of the script file
  Warning: such vulnerable form of password storage is chosen with
  temporary password usage in mind, if you do not use temporary password for the task,
  you leave your credentials exposed anyway
- you are supposed to run this script in a sequence of test modes first (see --test option):
  1) loginS, 2) folders, 3) dry -- and only then you allow the --execute to run
- examine the log file for the details of the test runs
  log file: ~/gmailmig.log (no option to override, edit the script if ought to)

OPTIONS:
-X, --execute: runs in productive mode
-T, --test: runs in test mode, variants: logins, folders, dry
      the first is to test your credentials (mind the plural form),
      the second is to review folder mismatches, see the log for details
      the last one (dry) is to simulate the final process (combine it with
      limiting the synchronized period, see option --days newest-oldest to shorten the test)
-d, --dates: defines the period to synchronize in form of YYYYMMDD-YYYYMMDD, eg: 20040401-20121221
      on the both sides of '-' you can provide any date string date command understands
      (eg: --dates '1 year ago'-today )
--days: defines the age of messages to synchronize in form of StartFromDay-FinishOnDay
      where both numbers are relative to the current day, so the last year would be: 0-365
      (this definition of the period to synchronize is native to imapsync, though quite useless)
-c, --config:  overrides the default location of the configuration file (~/gmailmig.conf)
-o    : lets define your own set of imapsync paramethers
-k    : overrides the default location of the credentals file (~/credentials_gmailmig)
--help: prints this synopsis

NOTES:
- script sets the temporary folder of imapsync to ~/gmailmig_tmp (hardcoded)
  and removes it on exit anyway
- also see the appendix at the bottom of the script file"

###DO

# Hardcoded configuration

ConfigFile=$HOME'/gmailmig.conf'
kFile=$HOME'/credentials_gmailmig'
LogFile=$HOME'/gmailmig.log'
TempDir=$HOME'/gmailmig_tmp'

## Preprocess the command line, settings round 0

ExeArguments="< ""$*"" >" ; ExeArguments=${ExeArguments/--test/-T} ; ExeArguments=${ExeArguments/--execute/-X} ; ExeArguments=${ExeArguments/--config/-c} ;

if  grep -q "\s--help\s" <<< $ExeArguments ; then
  echo -e "$helpAbout\n$helpUsage\n$helpContd" ; exit 0 # Prints "help"
fi 

if  grep -q "\s-T\s" <<< $ExeArguments &&  grep -q "\s-X\s" <<< $ExeArguments ; then
  echo -e "gmailmig:: Defining both test and productive mode is contradictiry.\n$helpUsage" ; exit 1
fi

if  grep -q "\s-c\s" <<< $ExeArguments ; then   # The custom configuration file case

  if [[ $(  sed -r 's/^.*\s-c\s+([^- ][^ ]*)\s+.*/\1/' <<< $ExeArguments ) == $ExeArguments ]]; then
    echo -e "gmailmig:: Configuration file option is not valid.\n$helpUsage" ; exit 1
  fi

  ConfigFile=$(  sed -r 's/^.*\s-c\s+([^- ][^ ]*)\s+.*/\1/' <<< $ExeArguments )    

  if [ ! -r "$ConfigFile" ]; then
    echo "gmailmig:: Configuration file does not exist or is not accessable: $ConfigFile" ; exit 1
  fi
fi

iMapFolders=0

if [ ! -r "$ConfigFile" ]; then
  echo -e "gmailmig:: Proceed with no configuration file available."
else

## Process the config file, settings round 1

ConfigSection=''
while read ConfigLine ; do

  ConfigLine=${ConfigLine%%#*}
  if [[ "$ConfigLine" =~ ^[\s]*$  ]]; then
    continue
  fi

  if [[ "$ConfigLine" =~ ^\s*::[\ ]*[^\ :]+[\ ]*::\s*.*$  ]]; then

    ConfigSection=$(  sed -r 's/^\s*::[\ ]*([^\ :]+)[\ ]*::\s*/\1/' <<< "$ConfigLine" )

  else
  case $ConfigSection in

  Settings)

    ;;

  FolderNameMapping)

    if [[ "$ConfigLine" =~ ^\s*\"[^\"]+\"[^\"]*:[^\"]*\"[^\"]+\"\s*.*$  ]]; then

      FolderSource[$iMapFolders]=$(  sed -r 's/^\s*\"([^\"]+)\"[\ \t:]*\"([^\"]+)\"\s*/\1/' <<< "$ConfigLine" )
      FolderTarget[$iMapFolders]=$(  sed -r 's/^\s*\"([^\"]+)\"[\ \t:]*\"([^\"]+)\"\s*/\2/' <<< "$ConfigLine" )
      
      (( iMapFolders++ ))

    else
      echo "gmailmig:: Unexpected mapping definition: \"$ConfigLine\"" ; exit 1
    fi ;;

  *)  echo "gmailmig:: Unexpected configuration section: \"$ConfigSection\"" ; exit 1 ;;
  esac
  fi

  #echo "\"$ConfigSection\" \"$ConfigLine\""

done < $ConfigFile
fi

## Process the command line arguments, settings round 2

while [  "$*" ]; do

  ExeOpt=$1
  if [[ $2 != -* ]]; then
  ExeOptSub=$2 ; shift ; else
  ExeOptSub=""
  fi

  case $ExeOpt in

  --test|-T)					# Test mode, see below

    case $ExeOptSub in
      logins|l)  ExeMode=' --justlogin ';;	# Authentication test
      folders|f) ExeMode=' --justfolders --dry ';;  # Dry-run for folders listing, see the logfile
      dry|d)	   ExeMode=' --dry ';;		# Dry-run, see the logfile for details
      "")	   echo -e "gmailmig:: Missing test mode suboption.\n$helpUsage" ; exit 1 ;;
      *)	   echo -e "gmailmig:: Unexpected test mode: $ExeOptSub\n$helpUsage" ; exit 1 ;;
    esac ;;

  --execute|-X) 				# Productive run, if not testing -X must not be omitted

    case $ExeOptSub in
      "")	  ExeMode='*Productive*' ;;
      *)	  echo -e "gmailmig:: Production mode should not have suboptions.\n$helpUsage" ; exit 1 ;;
    esac ;;

  --dates|-d)         # The interval to synchronize, in from-to form, eg. 20040101-20120531

    case $ExeOptSub in
      "")   echo -e "gmailmig:: No interval provided for --dates.\n$helpUsage" ; exit 1 ;;
      *)    MessageDates=$ExeOptSub ;;
    esac ;;

  --days)         # The interval to synchronize, in days, eg. 370-377

    case $ExeOptSub in
      "")   echo -e "gmailmig:: No interval provided for --days.\n$helpUsage" ; exit 1 ;;
      *)    MessageDays=$ExeOptSub ;;
    esac ;;

  -o)   ExeExtraOptions=$ExeOptSub ;; # User defined options to pass to imapsync, not checked

  -k)   kFile=$ExeOptSub ;;   # The custom credentials file

  --help) ;; # Help and config are already preprocessed, see round 0
  --config|-c) ;; 

  *)		echo -e "gmailmig:: Unexpected option: \"$ExeOpt\"\n$helpUsage" ; exit 1 ;;

  esac
  shift
done

## Review settings

if [ -z "$ExeMode" ]; then
  echo -e "gmailmig:: Define test or productive mode.\n$helpUsage" ; exit 1
fi

if [ -r "$kFile" ]; then
  if [ $( stat -c %a $kFile ) -ne 600 ]; then 
    if 
       ! chmod u=rw,go= $kFile ; then
	  echo -e "gmailmig:: Failed to fix permissions to "u=rw,go=" in: $kFile" ; exit 1
    fi
  fi
else
  echo -e "gmailmig:: Credentials file does not exist or is not accessable: $kFile" ; exit 1
fi

if [ -n "$MessageDates" ] && [ -n "$MessageDays" ]; then
  echo -e "gmailmig:: Defining both --dates and --days makes no sense, see --help.\n$helpUsage" ; exit 1
fi

## The credentials
# see the notes regarding the credentials file format

AccountSource=$( sed -r '/^[ \t]*#/d;/source[: \t]/!d;s/^[ \t]*::source::([^:]*)::([^:]*)::.*|^[ \t]*source[ \t]*([^ \t]*)[\t]*([^ \t]*)[\t].*/\1\3/' $kFile )
AccountSourcePassword=$( sed -r '/^[ \t]*#/d;/source[: \t]/!d;s/^[ \t]*::source::([^:]*)::([^:]+)::.*|^[ \t]*source[ \t]*([^ \t]*)[\t]*([^\t]*)[\t].*/\2\4/' $kFile )
AccountTarget=$( sed -r '/^[ \t]*#/d;/target[: \t]/!d;s/^[ \t]*::target::([^:]*)::([^:]*)::.*|^[ \t]*target[ \t]*([^ \t]*)[\t]*([^\t]*)[\t].*/\1\3/' $kFile )
AccountTargetPassword=$( sed -r '/^[ \t]*#/d;/target[: \t]/!d;s/^[ \t]*::target::([^:]*)::([^:]*)::.*|^[ \t]*target[ \t]*([^ \t]*)[\t]*([^\t]*)[\t].*/\2\4/' $kFile )

echo -e "gmailmig:\
	Source account: $AccountSource, pwd length: ${#AccountSourcePassword} \n\t\
	Target account: $AccountTarget, pwd length: ${#AccountTargetPassword}"
			
# uncomment for diagnostics 
# echo -e "\t\t\t\""$AccountSourcePassword"\" \""$AccountTargetPassword"\"\n" 

if [[ $AccountSource != *@* ]] || [[ $AccountTarget != *@* ]]; then
  echo "gmailmig: Could not catch the email addresses identifying accounts properly." ; exit 1
fi

if (( ${#AccountSourcePassword} == 0 || ${#AccountTargetPassword} == 0 )) ; then
  echo "gmailmig: Password length must be not be zero." ; exit 1
fi

## The interval

if [ -n "$MessageDates" ]; then

  MessageDateMax=$(  sed -r 's/(.*)-.*/\1/' <<< $MessageDates )
  MessageDateMin=$(  sed -r 's/.*-(.*)/\1/' <<< $MessageDates )

  if [[ $( date --date "$MessageDateMin" +%s ) =~ ^[0-9]+$ ]] && \
     [[ $( date --date "$MessageDateMax" +%s ) =~ ^[0-9]+$ ]]; then

    MessageDayMin=$(( ( $( date --utc --date 'today' +%s ) - $( date --utc --date "$MessageDateMin" +%s ) )/86400 ))
    MessageDayMax=$(( ( $( date --utc --date 'today' +%s ) - $( date --utc --date "$MessageDateMax" +%s ) )/86400 ))

  else
    echo "gmailmig: --date option must use parameter 20YYMMDD-20YYMMDD or date command strings, cf: \"$MessageDates\"" ; exit 1
  fi

elif [ -n "$MessageDays" ]; then

  MessageDayMin=$(  sed -r 's/([0-9]+)-.*/\1/' <<< $MessageDays )
  MessageDayMax=$(  sed -r 's/.*-([0-9]+)/\1/' <<< $MessageDays )

  if [[ $MessageDayMin =~ ^[0-9]+$ ]] && [[ $MessageDayMax =~ ^[0-9]+$ ]]; then
    MessageDays=$MessageDays
  else
    echo "gmailmig: --day option must use parameter Num-Num, cf: \"$MessageDays\"" ; exit 1
  fi

else
  MessageDays=''
fi

gmailEpochDayAgo=$(( ( $( date --utc --date 'today' +%s ) - $( date --utc --date 20040401 +%s ) )/86400 ))

if [ -n "$MessageDayMin" ]; then 

  if (( $MessageDayMin >= 0 && $MessageDayMin <= $gmailEpochDayAgo )) ; then
  if (( $MessageDayMin <= $MessageDayMax && $MessageDayMax <= $gmailEpochDayAgo )) ; then
  if ! (( $MessageDayMin <= $MessageDayMax )) ; then
    if [ -n "$MessageDays" ]; then
    echo "gmailmig: Minimal age must be no greater than the maximal one, cf: \"$MessageDays\"" ; exit 1
    else
    echo "gmailmig: Latest date must be no greater than the oldest one, cf: \"$MessageDates\"" ; exit 1
    fi
  fi
  else
    if [ -n "$MessageDays" ]; then
    echo "gmailmig: Maximum age must be no less than the minimal one and less then $gmailEpochDayAgo days, cf: \"$MessageDays\"" ; exit 1
    else
    echo "gmailmig: Oldest date must be no less than the latest one and less then $gmailEpochDayAgo days ago, cf: \"$MessageDates\"" ; exit 1
    fi
  fi
  else
    if [ -n "$MessageDays" ]; then
    echo "gmailmig: Minimal age must be between 0-$gmailEpochDayAgo days, cf: \"$MessageDayMin\"" ; exit 1
    else
    echo "gmailmig: Latest date must be between now and $gmailEpochDayAgo days ago, cf: \"$MessageDateMin\"" ; exit 1
    fi
  fi

  MessageDays=' --minage '$MessageDayMin' --maxage '$MessageDayMax' '

else
MessageDayMin=0
MessageDayMax=$gmailEpochDayAgo

fi 

## Logfile

test -e $LogFile && ( rm $LogFile )

## Communicate the task definition
echo "gmailmig: Mode: $ExeMode. Including messages from $( date --utc --date "today -"$MessageDayMax" days" +%Y-%b-%d ) to $( date --utc --date "today -"$MessageDayMin" days" +%Y-%b-%d )."  | tee -a $LogFile

## Preparing the IMAP folder mapping options if needed

ExeMapFolders=''

if (( $iMapFolders > 0 )); then 

  echo -n "gmailmig: Force mapping of:"

  for (( i=0 ; i<$iMapFolders ; i++ ))
  do
   if [ "$FolderSource[${i}]" != "$FolderTarget[${i}]" ]; then
 
     imessage=${FolderTarget[${i}]} ; imessage=${imessage#*Gmail]}
     echo -n " "\""$imessage"\"
 
  	# Escape these: / [ ]
     FolderSource[$i]=$(  sed 's/\[/\\\[/g;s/\]/\\\]/g;s/\//\\\//g' <<< ${FolderSource[${i}]} )
     FolderTarget[$i]=$(  sed 's/\[/\\\[/g;s/\]/\\\]/g;s/\//\\\//g' <<< ${FolderTarget[${i}]} )
     ExeMapFolders=$ExeMapFolders' --regextrans2 "s/'${FolderSource[$i]}'/'${FolderTarget[$i]}'/"'
   fi
  done

  echo "."
fi

## Communicate the log file path
echo "gmailmig: Logfile: $LogFile"  | tee -a $LogFile

## Local temp folder for imapsync
if 
  mkdir $TempDir ; then
  echo "gmailmig: $TempDir created."
  else
  exit 1
fi

### Error handling

function fOnExit() {
        echo "gmailmig: Cleaning up $TempDir."
        rm -rf $TempDir
        echo "gmailmig: Exit."
        exit $1
}

trap fOnExit EXIT ERR 1 2 3 15

### Syncronize messages, copy items not copied yet

imapsynccmd='imapsync '$ExeMode'
   --user1 '$AccountSource' 
   --user2 '$AccountTarget' 
   --host1 imap.gmail.com --port1 993 --ssl1 
   --authmech1 LOGIN
   --host2 imap.googlemail.com --port2 993 --ssl2 
   --authmech2 LOGIN
   --split1 100 --split2 100 --nofoldersizes 
   --useheader "Message-ID"  --useheader "Date" --skipsize --allowsizemismatch 
   '$MessageDays' '$ExeMapFolders' '$ExeExtraOptions' 
   --tmpdir '$TempDir

echo $imapsynccmd

( echo -n "gmailmig: Migration started at:" ; date )  | tee -a $LogFile

ExeRoundMax=25 ; ExeRound=1 ;

while 
! eval $imapsynccmd' --password1 "'$AccountSourcePassword'" --password2 "'$AccountTargetPassword'"' \
		>> $LogFile |& tee -a $LogFile 
do
   if (( ExeRound++ < ExeRoundMax )) ; then
      echo "gmailmig: Synchronization restarted to round $ExeRound of $ExeRoundMax."  | tee -a $LogFile
   else
      echo "gmailmig: Synchronization exeeded maximum rounds ($ExeRoundMax)."  | tee -a $LogFile
      break
   fi
done

echo "gmailmig: Last 4 lines of the log:"
tail -4 $LogFile
( echo -n "gmailmig: Migration was over at:" ; date )  | tee -a $LogFile

###END

#### APPENDIX ####

### credits:	James Furness base6.com, Mark seagrief.co.uk, blog.mcfang.com/author/mcfang, 
#		Tyler Ham www.thamtech.com, Jim Geurts biasecurities.com, Feka feka.hu

### Credentials file format (~/credentials_gmailmig)
# Do not expose your real secrets here, only temporary passwords!
# Format has two variants: tab or :: delimited:
#
# source|target <tab> your@fullgmailorgappsaddress.com <tab> password <tab!!!>
#
# ::source|target::your@fullgmailorgappsaddress.com::password::
#
# Notes:
#   - leading tabs and spaces are allowed in both cases
#   - in the tabbed case you can use even :: in your password
#
# Sample (mind the closing tab after the password in the tabbed varinat!):
# source        cow@gmail.com   pgjzijkohpssaswm
# ::target::boy@westerndomain.com::neverusepassword123::
