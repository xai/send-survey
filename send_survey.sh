#!/bin/bash
#
# The MIT License (MIT)
#
# Copyright (c) 2014 Olaf Lessenich
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# CHANGE THIS: mail settings
MAILFROM=me@example.com
MAILSERVER=localhost
MAILUSER=me
MAILPASSWORD=mypassword

# global settings
TIMEOUT="30m"
COUNT=1
TMPDIR=/tmp/survey
LOG=/tmp/survey/summary.log
MAILLOG=/tmp/survey/mail.log

# templates
# body template contains the placeholders $PROJECT, $REVISION, and $URL
BODYTEMPLATEFILE=email_body.txt
SUBJECTTEMPLATE="community study"

usage () {
	echo >&2
	echo >&2 "Usage: $0 [-p] <recipientfile>"
	echo >&2 "   -p: pretend. Do not really send mails."
	echo >&2
	echo >&2 "BE CAREFUL! WRONG USAGE OF THIS SCRIPT CAN RESULT IN SERIOUS DAMAGE!"
	echo >&2
	echo >&2 "The recipientfile contains one line for each recipient."
	echo >&2
	echo >&2 "Each line of the recipientfile looks like this:"
	echo >&2 "\"email address\" \"survey url\" \"project\" \"revision\""
	echo >&2
	echo >&2 "This would be a valid line:"
	echo >&2 "\"john.doe@example.com\" \"https://example.com/link/to/survey.php?some.params=42&other.params=42\" \"Perl\" \"v5.19.0\""
	echo >&2
	echo >&2 "Also, make sure to configure the script before executing it!"
}

safety_countdown () {
	echo "WARNING: You are going to automatically send $1 mails."
	echo "         If you made any mistake, $1 people will be angry at you."
	echo
	echo "         This is your last chance to cancel. Press Ctrl-C to cancel."
	echo

	seconds=$2
	while [ $seconds -gt 0 ]; do
		echo -ne "Safety countdown: $seconds\033[0K\r"
		sleep 1
		seconds=$[$seconds -1]
	done

	echo
}

while getopts "hp" opt; do
	case "${opt}" in
		p) PRETEND="true"; shift ;;
		h) usage; exit 0 ;;
		'?') usage; exit 1 ;;
	esac
done

if [ -z $1 ] || [ ! -f $1 ]; then echo "Recipient file not found!"; usage; exit 1; fi
if [ ! -f $BODYTEMPLATEFILE ]; then echo "BODYTEMPLATEFILE not found: $BODYTEMPLATEFILE"; usage; exit 1; fi

[ -d $TMPDIR ] || mkdir $TMPDIR || ( echo "$TMPDIR could not be created." && exit 2 )
[ "$(ls -A $TMPDIR)" ] && rm $TMPDIR/*

NUMTOTAL=$(wc -l $1 | awk '{ print $1 }')

if [ -z $PRETEND ]; then
	safety_countdown $NUMTOTAL 60
fi

while read -r line; do
	TIMESTAMP=$(date +%H:%M:%S)
	PROGRESS="($COUNT of $NUMTOTAL)"

	# parse input
	read -r RECIPIENT URL PROJECT REVISION <<< "${line//\"/}"
	URL=${URL//\?/\\\?}
	URL=${URL//\./\\\.}
	URL=${URL//\//\\\/}
	URL=${URL//\&/\\\&}
	SUBJECT="${PROJECT} ${SUBJECTTEMPLATE}"

	[ $COUNT -eq 1 ] && [ $RECIPIENT == "email" ] && ( echo "$TIMESTAMP skipping header" | tee -a $LOG ) && NUMTOTAL=$[$NUMTOTAL -1] && echo && continue

	if [ $PRETEND ]; then
		# fill data into placeholders and print message to stdout
		echo "> Subject: $SUBJECT" | tee -a ${TMPDIR}/mail.$COUNT
		echo "> From: $MAILFROM" | tee -a ${TMPDIR}/mail.$COUNT
		echo "> To: $RECIPIENT" | tee -a ${TMPDIR}/mail.$COUNT
		echo "> " | tee -a ${TMPDIR}/mail.$COUNT
		sed -e "s/\$PROJECT/$PROJECT/" -e "s/\$REVISION/$REVISION/" -e "s/\$URL/$URL/" -e "s/^/> /" < $BODYTEMPLATEFILE | tee -a ${TMPDIR}/mail.$COUNT
		echo
	else
		# fill data into placeholders and fire
		sed -e "s/\$PROJECT/$PROJECT/" -e "s/\$REVISION/$REVISION/" -e "s/\$URL/$URL/" < $BODYTEMPLATEFILE | tee -a ${TMPDIR}/mail.$COUNT | ./send_mail.py -m $MAILSERVER -u $MAILUSER -p $MAILPASSWORD -s "$SUBJECT" -f "\"$MAILFROM\"" -b "\"$MAILFROM\"" "\"$RECIPIENT\"" 2>&1 | tee -a $MAILLOG
	fi
	RET=$?
	if [ $RET -eq 0 ]; then STATUS="OK"; else STATUS="ERROR"; fi
	echo "$TIMESTAMP $STATUS $PROGRESS mail sent to "\"$RECIPIENT\"" with return code $(echo $RET)" | tee -a $LOG

	COUNT=$[$COUNT +1]

	# give the mailserver a break
	[ $(( $COUNT % 100 )) -eq 0 ] && ( echo "$TIMESTAMP sleeping for $TIMEOUT" | tee -a $LOG ) && sleep $TIMEOUT

	echo
done < $1

