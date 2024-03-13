a "package manager esc" github program downloader for CC:T (computer craft tweaked), project is currently in its beginnings but has basic functionality available:

addRepo - add a github repo which will be scanned for manifest files
list - show what packages are either installed (arg2 "installed") or what packages are available
install - install a package by using the file mapping list in the manifest, then downloading and running the installer if one is set
remove - uninstalls a package following the install steps in reverse (installer is ran with "remove" arg)


you can download the program by running the following command in a CC:T computer:
```shell
wget run https://raw.githubusercontent.com/hpf3/CCT-GithubDL/main/programSetup.lua
```

if you wish to use the format it should be relatively stable... i may add dependency support in the future, but similar to the installer, it will just be ignored if it doesn't exist.