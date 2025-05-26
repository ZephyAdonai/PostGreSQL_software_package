# PostGreSQL_software_package
A software package I created, putting it here as an example of my work for anyone to view. 

There are 4 sections in this software package. 

The first section is the pre-install section, that is where my script uninstalls previous version of the PostGreSQL I'm installing, it also dynamically accounts for different name and version variations that may cause an error. 

The second section is the install section, that is where I check if the app is installed or if a greater version exists already. If not, I install the package and create logs for confirmation, though every section has logs. 

The third is the uninstall, this is explicit and targeting the specific app version and it's potential secondary programs it depends on. I usually leave middle-ware installed if it's used widely by other apps like Microsoft Visual C++. Typically, uninstalling middleware is done in the pre-install section. 

Fourth, this is where I repair the application if it has any errors or corrupt files.

If you download this repo then this is how you should handle it

Open up the command line

cd >The path to the SCCMImport folder<
You can then run these list of commands
Deploy-Application -DeploymentType "Install"
Deploy-Application -DeploymentType "Uninstall"
Deploy-Application -DeploymentType "Repair"

To view logs, just go to your C:\Windows\Logs pathing. It can also sometimes generate logs in C:\Windows\Logs\Software. 
I recommend viewing logs with CMTrace, though notepad works too. 

THIS SOFTWARE PACKAGE IS FOR WINDOWS SYSTEMS
