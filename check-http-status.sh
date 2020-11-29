#!/bin/bash
#
# check-http-status.sh
# initial version: 2020/11/28, Nicholas Inabnit
#
# This script uses curl and HTTP status codes to check if web pages are accessible.
#
# If all URLs return a successful HTTP status code, this script returns an exit status of zero.
# If any URL fails for any reason, this script returns a non-zero exit status.
#
###############################################################################################

# Number of seconds curl should try before giving up.
timeout=5

# The file containing the list of URLs to check.
#input_file=list-of-urls
input_file=list-of-urls

# Make sure we have read access to the input file.
if [[ ! -r "$input_file" ]] ; then
   echo "ERROR: Could not read the file '$input_file'."
   exit 1
fi

# Make sure the input file isn't empty.
if [[ ! -s "$input_file" ]] ; then
   echo "ERROR: The file '$input_file' does not contain any URLs."
   exit 1
fi

# Use a hidden file to track if any URL failed.
failed_flag=".failed_flag"

# Remove the flag file if it exists from the previous run.
rm -f "$failed_flag"

# Define terminal text colors, for later use.
# More info can be found in the 'Color Handling' section of the man page
# for 'terminfo'.
red=$(tput setaf 1)
green=$(tput setaf 2)
color_off=$(tput sgr0)

function get_http_status_code {
   # First check if curl can even reach the destination. There could be situations
   # where curl doesn't receive any HTTP status code, such as with bad URLs.
   if ! curl --max-time "$timeout" --output /dev/null --silent "$1" ; then
      echo "${red}FAILED - *** - ${color_off}no HTTP status code received, because curl could not reach $1"
      touch "$failed_flag"
      continue
   fi
   
   # If the check above passed, get the HTTP status code for the URL.
   # The curl command below is set to follow redirects. Usually this works fine, but for some web sites this
   # can result in unexpected behavior. Remove the '--location' option if you don't want curl to follow redirects.
   http_status=$(curl --max-time "$timeout" --location --silent --output /dev/null --write-out "%{http_code}" "$1")
   
   # Color the results based on the HTTP status code.
   # Status codes 4xx and 5xx are bad; everything else is OK.
   # More info at https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
   if [[ "$http_status" == [45][0-9][0-9] ]] ; then
      echo "${red}FAILED - ${http_status} - ${color_off}$1"
      touch "$failed_flag"
   else
      # Add extra white space so that all results (failed and succeeded) line up nicely.
      echo "    ${green}OK - ${http_status} - ${color_off}$1"
   fi
}

# Read in the list of URLs from the input file.
while read -r url ; do
   # Call each instance of 'get_http_status_code' as a separate background process,
   # so that essentially all URLs are checked in parallel, rather than one at a time.
   # This works well unless you are checking hundreds of URLs at once. In that case,
   # remove the ampersand below so that each URL is checked one at a time.
   get_http_status_code "$url" &
done < "$input_file"

# Wait for all background processes to finish.
wait

# Exit with non-zero status if any URL failed.
if [[ -e "$failed_flag" ]] ; then
   exit 1
fi
