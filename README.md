ocss
====

OwnCloud Screenshot Sharing

A script to make sharing a screenshot publicly via an Owncloud server easy.


Instructions:

Get ocss.sh by either cloning this repo or downloading the zip.
Edit the CONFIG portion of ocss.sh and fill in your details/preferences.  By default, it's setup to save screenshots locally to $HOME/Pictures/ocss (config setting: file_dir), so either change that to a directory that exists or create that directory.  Also by default, it will upload the screenshots to a folder named "ocss" in your Owncloud root (config setting: ocs_ocss_dir_name)... make sure that exists.  The default open command that opens a browser to display your new upload is chromium (config setting: open_command).

I haven't tested this with OS X, but it's mostly the same code base as imgur-screenshot and that is purported to work in OS X, so it SHOULD work.
