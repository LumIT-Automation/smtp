#!/bin/bash

from=$1
to=$2
myHost=`hostname`
smtp='mta'

[ -z "$to" ] && echo "Usage: $0 from to" && exit 1

smtp_send() {
    echo "helo $myHost"
    sleep .1
    echo "mail from: $from"
    sleep .1
    echo "rcpt to: $to"
    sleep .1
    echo "data"
    sleep .1
    echo "To: $to"
    sleep .1
    echo "Subject: prova"
    sleep .1
    echo "provo"
    sleep .1
    echo .
    sleep 3
    echo "quit"
}

smtp_send | nc $smtp 25

