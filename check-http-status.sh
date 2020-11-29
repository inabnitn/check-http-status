#!/bin/bash
#
# check-http-status.sh
# initial version: 2020/11/28, Nicholas Inabnit
#
# This script uses curl and HTTP status codes to check if web pages are accessible.
#
# If all URLs return a successful HTTP status code, this script returns an exit status of zero.
# If any URL fails for any reason, this script exits with non-zero status.
#
###############################################################################################


# Number of seconds curl should try before giving up.
timeout=5

# The file containing the list of URLs to check.
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

# Define terminal text colors, for later use.
# More info can be found in the 'Color Handling' section of the man page
# for 'terminfo'.
red=$(tput setaf 1)
green=$(tput setaf 2)
color_off=$(tput sgr0)

# Flag if any URL fails.
failed=0

# Read in the list of URLs, one line at a time.
while read url ; do

   # First check if curl can even reach the destination. There could be situations
   # where curl doesn't receive any HTTP status code, such as with malformed URLs.
   curl --max-time "$timeout" --output /dev/null --silent "$url"
   if [[ $? -ne 0 ]] ; then
      echo "${red}FAILED - *** - ${color_off}no HTTP status code received, because curl could not reach ${url}"
      echo
      failed=1
      continue
   fi
   
   # If the check above passed, get the HTTP status code for the URL.
   # In the curl command below, the '--location' option means that curl will try the URL's new
   # location if the web server reports that the page has moved, such as with a 301 status code.
   http_status=$(curl --max-time "$timeout" --location --silent --head --output /dev/null --write-out "%{http_code}" "$url")

   # Color the results based on the HTTP status code.
   # Status codes 4xx and 5xx are bad; everything else is OK.
   # More info at https://en.wikipedia.org/wiki/List_of_HTTP_status_codes
   if [[ "$http_status" == [45][0-9][0-9] ]] ; then
      echo "${red}FAILED - ${http_status} - ${color_off}$url"
      failed=1
   else
      # Add extra white space so that all results (failed and succeeded) line up nicely.
      echo "    ${green}OK - ${http_status} - ${color_off}$url"
   fi
   echo

done < "$input_file"

# Exit with non-zero status if any URL failed.
if (( "$failed" )) ; then
   exit 1
fi
