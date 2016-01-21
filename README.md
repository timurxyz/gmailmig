# gmailmig

A wrapper of the imapsync utility for better migration btw gmail/gapps accounts. Made with security in mind.

USAGE:  gmailmig.sh --execute|-X | --test|-T[ logins | folders | dry ]
                          [--dates|-d Latest-Oldest] | [--days Min-Max]
                          [--source <full-mailaddress> --target <full-mailaddress> [-- ssh-askpass]] |
			  [-k <path-to-the-credentials-file> ]
			  [--config|-c <custom-config-file-path> ]
                          [--help] [-o YourImapsyncOptions]
Note:   Expose only temporary passwords in the credential file if possible!
	Delete that file soon. Or use --source --target (and optionally --ssh-askpass).

PREREQUISITES:
- You are supposed to run this script in a sequence of test modes first (see --test option):
  1) loginS, 2) folders, 3) dry -- and only then you allow the --execute to run.
- Examine the log file for the details of the test runs.
  log file: ~/gmailmig.log (no option to override, edit the script if ought to, pwds are not exposed there)
- Consider the password provision mode that fits your situation: in a trusted environment 
  you may use the credential file feature, using temporary passwords would be a wise choice.
- Instead you may provide the accounts as arguments (see the --source --target options) 
  though typing passwords for test rounds again and again can be a pain.
OPTIONS:
-X, --execute:  runs in productive mode
-T, --test:  runs in test mode, variants: logins, folders, dry
      the first is to test your credentials (mind the plural form),
      the second is to review folder mismatches, see the log for details
      the last one (dry) is to simulate the final process (combine it with
      limiting the synchronized period, see option --days newest-oldest to shorten the test)
-d, --dates:  defines the period to synchronize in form of YYYYMMDD-YYYYMMDD, eg: 20040401-20121221
      on the both sides of '-' you can provide any date string date command understands
      (eg: --dates '1 year ago'-today )
--days:  defines the age of messages to synchronize in form of StartFromDay-FinishOnDay
      where both numbers are relative to the current day, so the last year would be: 0-365
      (this definition of the period to synchronize is native to imapsync, though quite useless)
--source,--target:  instead of using a credentials file obtains accounts definition from these arguments
      and will propt for passwords 
--ssh-askpass:  propts for passwords via ssh-askpass (password is passed then via this script)
-c, --config:  overrides the default location of the configuration file (~/gmailmig.conf)
-o    : lets define your own set of imapsync paramethers
-k    : overrides the default location of the credentals file (~/credentials_gmailmig)
--help: prints this synopsis
NOTES:
- This script sets the temporary folder of imapsync to ~/gmailmig_tmp (hardcoded)
  and erases it on exit anyway.
- In the default case you provide your gmail/gapps credentials in a file which by default is
  ~/credentials_gmailmig (this configuration can be overriden by -k)
  the format of the credentials file is provided in the bottom of the script file.
  Warning: such a vulnerable form of password provision is chosen with temporary password usage in mind.
- Also see the appendix at the bottom of the script file.


Automatically exported from code.google.com/p/gmailmig
