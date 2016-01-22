#!/usr/bin/env python3
#
# The MIT License (MIT)
#
# Copyright (c) 2016 Olaf Lessenich
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

import argparse
import sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from smtplib import SMTP

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--sender", help="set From address", type=str, required=True)
    parser.add_argument("-b", "--bcc", help="set Bcc address", type=str)
    parser.add_argument("-m", "--mailserver", help="set smtp server", type=str, required=True)
    parser.add_argument("-s", "--subject", help="set subject", type=str, required=True)
    parser.add_argument("-u", "--user", help="set smtp user", type=str, required=True)
    parser.add_argument("-p", "--password", help="set smtp password", type=str, required=True)
    parser.add_argument("recp", default=[], nargs="+", type=str)
    args = parser.parse_args()

    message_text = []

    for line in sys.stdin:
        message_text.append(line)

    sender = args.sender
    bcc = args.bcc
    subject = args.subject
    server = args.mailserver
    user = args.user
    password = args.password
    recp = args.recp
    all_recps = args.recp + [bcc] if bcc else recp

    smtp = SMTP(host=server, port=25)
    smtp.set_debuglevel(0)
    smtp.ehlo()
    smtp.starttls()
    smtp.ehlo()
    smtp.login(user, password)

    msg = MIMEMultipart()
    msg['From'] = sender
    msg['To'] = "".join(recp)
    msg['Subject'] = subject
    msg.attach(MIMEText("".join(message_text)))

    smtp.sendmail(sender, all_recps, msg.as_string())
    smtp.quit()

