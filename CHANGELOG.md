# Changelog

## 3.1.7

### RELEASE DATE

November 03, 2022

#### RELEASE NOTES

Between MacOS Ventura and Monterey, the version of OpenSSL was updated. In Monterey systems and below, the shipped versions of OpenSSL used the MD5 digest by default for encoding/ decoding strings. In Ventura that default changed. This release specifies that the encryption/ decryption functions should use the MD5 digest thus ensuring compatibility of this script between OS versions of MacOS.

## 3.1.6

### RELEASE DATE

September 30, 2022

#### RELEASE NOTES

Update TimeStamp Format to account for agent logging changes in newer versions of the JumpCloud Agent.

## 3.1.5

### RELEASE DATE

February 04, 2022

#### RELEASE NOTES

Remove Python call to get active user, in 12.3 python will no longer be shipped with macOS. Regular bash commands can be substituted here to provide compatibility moving forward.

## 3.1.4

### RELEASE DATE

July 23, 2021

#### RELEASE NOTES

Fixed a bug for failed enrollments. If the jumpcloud_bootstrap_template.sh were configured improperly, specifically if the launch daemon is named incorrectly it will not "exist" in the specified location. Previously the prestange enrollment script would remove the entire Launch Daemons directory in this case. This release validates that the daemon exists before removing it. If the daemon does not exist the script will not remove any file in that location.

## 3.1.3

### RELEASE DATE

January 25, 2021

#### RELEASE NOTES

Macs with M1 processor support. Update URL to pull latest version of DEPNotify which supports M1 systems. Documentation added to note that the arm64 architecture must be specified when building updated versions of the .pkg installer.

## 3.1.2

### RELEASE DATE

June 4, 2020

#### RELEASE NOTES

Update in script template to specifically use the built in version of OpenSSL in the Encryption and Decryption step of the script. Other versions of OpenSSL may encrypt or decrypt the API Key differently. To ensure the encrypted key can be decrypted by an out-of-the-box macOS system, using the openssl binary located in /usr/bin is necessary.

This patch update will not affect current customers who have successfully encrypted and decrypted their API key.

## 3.1.1

### RELEASE DATE

April 21, 2020

#### RELEASE NOTES

Fix for MDM Prestage User Enrollment workflow where the JumpCloud Agent would occasionally stop logging during enrollment. The JumpCloud Agent is restarted during enrollment if the agent takes longer than 90 seconds to report a new log.

If the JumpCloud Agent hasn't reported a log after a total of 180 seconds and after the JumpCloud Agent has been restarted, the script will terminate by unloading the LaunchDaemon. The enrollment user is informed that the enrollment did not complete and to check the /var/tmp/debug_depnotify.log file. The decrypt user is deleted at this stage to prevent decryption of the JumpCloud API key. Networking connectivity issues at the end stage of enrollment could cause the enrollment to fail as the system needs to contact JumpCloud to verify it's user bindings are set. This fix should allow for the JumpCloud Agent to restart and check connectivity.

## 3.1.0

### RELEASE DATE

February 13, 2020

#### RELEASE NOTES

The MDM Prestage User Enrollment workflow will prompt users to verify their passwords during enrollment. After a user configures a password with the correct complexity requirements a second prompt will ask that the user verify their password. If both password values match, that password will become the enrollment user's JumpCloud password.

The addition of a user agent header is passed through each JumpCloud curl request.

## 3.0.0

### RELEASE DATE

December 19, 2019

#### RELEASE NOTES

Say goodbye to "user configuration modules". The work required to copy and paste user configuration modules has been depreciated in favor of just setting variables at the top of the jumpcloud_bootstrap_template.sh script. A few assumed settings have been applied, namely, all pending users will be required to set a password as part of the enrollment process. Active users are not required to pick a password unless the "self_passwd" variable is set to true. The default setting is to have users self identify with their company email.

Given the changes to the overall flow of the script, the user configuration modules have been removed from the repository. Future development should rely on changes to the jumpcloud_bootstrap_tempate.sh script.

A few lines debugging lines were added to help identify where and when the user was located during the enrollment process.

## 2.1.0

### RELEASE DATE

December 5, 2019

#### RELEASE NOTES

Slight change to the logic at the end of the script for deleting the enrollment and decrypt users. Switch to using `sysadminctl` instead of `dscl` commands to delete enrollment and decrypt users. The sysadminctl command was introduced in 10.13 macOS High Sierra. Thus, High Sierra is the minimum required version of macOS required to run this workflow.

The user deletion step now occurs in the last stage. Deletion should only occur when either a different user other than the enrollment user is logged in or at the login window. This solves the potential issue where remnant files of the enrollment user and decrypt user account remain after deletion. Running the `sysadminctl` command to delete users absolves the need to run `rm -rf /User/EnrollmentUser` to clean up the user files.

The bootstrap script is now caffeinated to prevent systems from falling asleep during the enrollment process. `caffeinate` code blocks the first three gates prevent the system from sleeping. That caffeinate process is killed at the end of each code block. the caffeinate process is not called during the last code block where the launch daemon is deleted.

The user module password prompt should now timeout after thirty minutes rather than the default two minutes. In previous versions of the bootstrap script, the dialogue box would open a new password prompt every two minutes if the enrollment user did not enter their password. This is generally avoidable since the enrollment user must click continue before proceeding to the password prompt. If an enrollment user walked away at this stage, the script should wait thirty minutes before timing out and checking for a password.

## 2.0.0

### RELEASE DATE

October 9, 2019

#### RELEASE NOTES

Change the jumpcloud_bootstrap_template.sh script to run though a LaunchDaemon. Moved jumpcloud_bootstrap_template.sh to /var/tmp. Files left in /private/var are deleted on system restart - we want this script to be resilient on restart.

Added stages to the jumpcloud_bootstrap_template.sh script, should any stage fail the daemon could relaunch the script and it would attempt to execute that block of code again. The script must complete in order for the daemon to unload and remove itself from the system. If a system is restarted during parts of the process, the daemon should relaunch the enrollment script upon next login.

/bin/bash tcc profile changed for the osa password prompt. Since the jumpcloud_bootstrap_template.sh is being called through a daemon, the previous tcc profile is no longer needed. the bash binary needs to be approved for calling osa systemevents in order to suppress the dialogue box during the password prompt.

Updated DEPNotify to 1.1.5.

## 1.1.0

### RELEASE DATE

September 19, 2019

#### RELEASE NOTES

The jumpcloud_bootstrap_template.sh has been updated with logic to delete the `DECRYPT_USER` and the `ENROLLMENT_USER` accounts from the macOS system. This logic has been added to the end of the jumpcloud_bootstrap_template.sh.Removing the `ENROLLMENT_USER` is an important step as this user has a valid Secure Token and while they are disabled via the JumpCloud agent (In Version 1.0) their account will be present at the macOS FileVault decryption screen. By removing this account from the system the Secure Token is invalided and the account does not display at the FileVault decrypt screen.
