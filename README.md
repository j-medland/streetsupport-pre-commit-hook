# Pre-Commit Checks
A bash script to check for potentially sensitive information in a commit

## Usage
Git Hooks live in the '.git/hooks' repository which is *not* synchronized across all repository users. To allow for changes to the pre-commit script to be easily shared, place the it in a directory under the project root called `git-hooks` and use the relevant install script.

On *nix systems 'installation' creates a soft-link from the git-hooks script into the .git/hooks directory. On Windows a small script is placed in .git/hooks directory which calls the script in git-hooks.

On initiating a commit, the hooks should run and provide some useful output

The script checks if a line containing a sensitive key has changed in the configuration files via the git diff command. It does not check if the value has changed so it might detect false positives. If you are 100% sure that this is the case then add the "--no-verify" flag when committing to prevent the checks being used.

### Adding Files/Keys to Check
 The files and keys to check are specified within the sensitive.keys and sensitive.files text-documents which should be under the git-root. These files support comments 