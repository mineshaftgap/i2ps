# i2ps (iTunes to Plex on Synology)

The tool i2ps was created due to the lack of documentation and difficulty of trying to migrate from iTunes to Plex on Synology running DSM 7. Currently it imports rating, play and skip counts. At the moment it does not try and import playlists. In order to accomplish this, there are three main tools:
  - The main shell script i2ps.sh
  - The go binary plist2json to convert Apple plists to JSON, you can find the source in this repo. It was shamelessly borrowed from https://github.com/kutani/plist2json. The main changes to it were proper JSON encoding and dode readability.
  - The app "jq" to extract the meta info by querying the converted JSON. This should already be on your Synology.

Please note, while this script does backup the Plex database and the table that it alters, it is always up to you to make proper backups. Using this tool requires more than basic skill level, you will need to be able to ssh into your Plex and run some commands. Finally, use at your own risk.

1. On your computer: Make sure all music files are downloaded in your iTunes library, if you use iTunes this might not be the case.
1. On your computer: Download this tool - https://github.com/mineshaftgap/i2ps/archive/refs/heads/main.zip
1. On your computer: Export iTunes Library info as "Library.xml".
1. On Synology UI: Stop the Plex server.
1. On Synology UI: Upload "i2ps-main.zip" to your admin home directory.
1. On Synology UI: Extract "i2ps-main.zip".
1. On Synology UI: Upload "Library.xml" to the folder "i2ps-main/var/run".
1. On your computer: Access your admin Synology account with ssh.
1. On Synology SSH: Run this script
```
./i2ps.sh
```
