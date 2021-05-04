REM Written by Aleem Cummins - Splunk Study Club
REM aleem@cummins.me
REM https://github.com/SplunkStudyClub/splunk-on-aws
REM Example usage:

@echo off
REM example usage C:\Users\Aleem\Documents\GitHub\splunk-on-aws/restrict_pem_key.bat "D:\AWS_Keys\test\SplunkStudyClub.pem" "aleem"
echo Set parameter variables
Set Key=%1
Set UserName=%2
echo Remove Permission Inheritance
cmd /c Icacls %Key% /inheritance:d
echo Change ownership to desired user
cmd /c Icacls %Key% /c /grant %UserName%:F
echo Remove all access permissions, except for desired used
cmd /c Icacls %Key% /c /Remove Administrator "Authenticated Users" BUILTIN\Administrators BUILTIN Everyone System Users
echo Verify file permission is set to only the desired user
cmd /c Icacls %Key%