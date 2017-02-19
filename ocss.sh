#!/usr/bin/env sh

# ocss - OwnCloud Screenshot Sharing
# https://github.com/rage311/ocss

# Based heavily on JonApps's imgur-screenshot script:
# https://github.com/JonApps/imgur-screenshot

############# CONFIG ############

# owncloud username
username='yourusername'
# owncloud password
password='yourpassword'

# base url of the owncloud server
oc_base="http://www.example.com/owncloud"
# directory name where you want the screenshots uploaded
oc_ocss_dir_name="ocss"
# local path and filename of an icon you would like to use
# for desktop notifications
oc_icon_path="$HOME/Pictures/ocss/owncloud_logo.png"
# Allows showing owncloud icon instead of terminal icon on OS X notifications. ID can be found in info.plist within the Owncloud package contents.
oc_application_id="com.owncloud.desktopclient"


# also save screenshot locally
save_file="true"
# file names will be: $file_prefixYYYY-mm-dd_HH.MM.SS.png
file_prefix="ocss_"
# where to save pictures locally (used as temp storage for
# upload even if $save_file is "false"
file_dir="$HOME/Pictures/ocss"

# command to run to edit screenshot before upload
# leave commented out to disable functionality
#edit_command="kolourpaint %img"

# timeout on upload connection in seconds
upload_connect_timeout="5"
# timeout on file upload in seconds
upload_timeout="120"
# number of upload retries
upload_retries="1"
# copy URL to clip board -- true/false
copy_url="true"
# command to open the uploaded screenshot in a browser
open_command="chromium %url"
# path and filename for the logfile
log_file="$HOME/.ocss.log"

######### END CONFIG ###########


is_mac() {
  uname | grep -q "Darwin"
}

if [ "$1" = "check" ]; then
  (which grep &>/dev/null && echo "OK: found grep") || echo "ERROR: grep not found"
  if is_mac; then
    (which terminal-notifier &>/dev/null && echo "OK: found terminal-notifier") || echo "ERROR: terminal-notifier not found"
    (which screencapture &>/dev/null && echo "OK: found screencapture") || echo "ERROR: screencapture not found"
    (which pbcopy &>/dev/null && echo "OK: found pbcopy") || echo "ERROR: pbcopy not found"
  else
    (which notify-send &>/dev/null && echo "OK: found notify-send") || echo "ERROR: notify-send (from libnotify-bin) not found"
    (which scrot &>/dev/null && echo "OK: found scrot") || echo "ERROR: scrot not found"
    (which xclip &>/dev/null && echo "OK: found xclip") || echo "ERROR: xclip not found"
  fi
  (which curl &>/dev/null && echo "OK: found curl") || echo "ERROR: curl not found"
  exit 0
fi

notify() {
  if is_mac; then
    terminal-notifier -title "$2" -message "$3" -sender "$oc_application_id"
  else
    if [ "$1" = "error" ]; then
      notify-send -a ocss -u critical -c "im.error" -i "$oc_icon_path" -t 500 "$2" "$3"
    else
      notify-send -a ocss -u low -c "transfer.complete" -i "$oc_icon_path" -t 500 "$2" "$3"
    fi
  fi
}

take_screenshot() {
  echo "Please select area"
  is_mac || sleep 0.1 # https://bbs.archlinux.org/viewtopic.php?pid=1246173#p1246173

  if ! (scrot -s "$1" || screencapture -s "$1"); then #takes a screenshot with selection
    echo "Couldn't make selective shot (mouse trapped?). Trying to grab active window instead"
    if ! (scrot -u "$1" &>/dev/null || screencapture -oWa "$1" &>/dev/null); then
      echo "Error for image '$1'!" | tee -a "$log_file"
      notify error "Something went wrong :(" "Information has been logged"
      exit 1
    fi
  fi
}

upload_image() {
  echo "Uploading '${1}'..."
  file_basename="$(basename $1)"
  curl --connect-timeout "$upload_connect_timeout" -m "$upload_timeout" --retry "$upload_retries" --insecure --user "$username:$password" -T "$1" "$oc_base/remote.php/webdav/$oc_ocss_dir_name/$file_basename"
  response="$(curl --insecure --user "$username:$password" -X POST --data 'path='$oc_ocss_dir_name'/'$file_basename'&shareType=3' "$oc_base/ocs/v1.php/apps/files_sharing/api/v1/shares")"

  # response contains <status>ok</status> when successful
  if (echo "$response" | grep -q "<status>ok</status>"); then
    # cutting the url from the xml response
    img_url="$(echo "$response" | egrep -o "<url>.*</url>" | cut -d ">" -f 2 | cut -d "<" -f 1 | sed -e "s/\&amp;/\&/")"
    echo "image link: $img_url"

    if [ "$copy_url" = "true" ]; then
      if is_mac; then
        echo "$img_url" | pbcopy
      else
        echo "$img_url" | xclip -selection clipboard
      fi
      echo "URL copied to clipboard"
    fi

    notify ok "ocss: Upload done!" "$img_url"

    if [ ! -z "$open_command" ]; then
      open_command=${open_command/\%img/$1}
      open_command=${open_command/\%url/$img_url}
      echo "Opening '$open_command'"
      $open_command
    fi

  else # upload failed
    err_msg="$(echo "$response" | egrep -o "<message>.*</message>" | cut -d ">" -f 2 | cut -d "<" -f 1)"
    img_url="Upload failed: \"$err_msg\"" # using this for the log file
    echo "$img_url"
    notify error "ocss: Upload failed :(" "$err_msg"
  fi
}

which="$(which "$0")"

if [ -z "$1" ]; then # screenshot
  cd $file_dir

  #filename with date
  img_file="${file_prefix}$(date +"%Y-%m-%d_%H.%M.%S.png")"
  take_screenshot "$img_file"
else # upload file, no screenshot
  img_file="$1"
fi

if [ ! -z "$edit_command" ]; then
  edit_command=${edit_command/\%img/$img_file}
  echo "Opening editor '$edit_command'"
  $edit_command
fi

# ensure file exists
if [ ! -f "$img_file" ]; then
  echo "file '$img_file' doesn't exist!"
  exit 1
fi

upload_image "$img_file"

if [ "$save_file" = "false" ]; then
  echo "Deleting temp file ${file_dir}/${img_file}"
  rm "$img_file"
fi

echo -e "${img_url}\t${file_dir}/${img_file}" >> "$log_file"
