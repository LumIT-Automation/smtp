#!/bin/bash

HELP="usage: $0 [-d mydomain.com] (default \`automation.local\`)\\n
[-m myhost.mydomain.com] (default \`smtp.automation.local\`)\\n
[-f admin@automation.local] - sender address (default \`admin@automation.local\`)\\n
[-a admin1@destdomain.com,admin2@otherdomain.com] - comma separated root destination addresses\\n
[-r relayhost.relaydomain.com] - relayhost fqdn - mandatory\\n
[-t smtp|authsmtp] - choose plain smtp (tcp port 25) or ssl/smtp-auth (tcp port 587) - mandatory\\n
[-u authsmtpuser:password] - login credentials for authsmtp - mandatory whith -t authsmtp\\n
[-s [1.2|1.3] - set tls policy\\n
[-p port] - change tcp port for smtp auth\\n
[-c certfile] - default /etc/pki/tls/certs/localhost.crt\\n
[-k keyfile] - default /etc/pki/tls/private/localhost.key\\n
[-h] this help\\n
\\n
# Examples:\\n
# use plain smtp (tcp port 25) to route mail messages via smtp.mydomain.com:\\n
./postfix-relay-host.sh -r smtp.mydomain.com -t smtp -f user@mydomain.com -a admin1@destdomain.com,admin2@otherdomain.com\\n
\\n
# use plain authsmtp (tcp port 587) to route mail messages via authsmtp.somedomain.com\\n
./postfix-relay-host.sh -r authsmtp.somedomain.com -t authsmtp -u smtpuser@mydomain.com:password -f user@mydomain.com -a admin1@mydomain.com,admin2@mydomain.com\\n
"

while getopts "d:m:f:a:r:t:s:p:c:k:u:h" opt
     do
        case $opt in
                d  ) myDomain=$OPTARG ;;
                m  ) myHost=$OPTARG ;;
                f  ) myFrom=$OPTARG ;;
                a  ) myTo=$OPTARG ;;
                r  ) relayHost=$OPTARG ;;
                t  ) smtp=$OPTARG ;;
                s  ) tls=$OPTARG ;;
                p  ) port=$OPTARG ;;
                c  ) cert=$OPTARG ;;
                k  ) key=$OPTARG ;;
                u  ) smtpUser=$OPTARG ;;
                h  ) echo -e ${HELP}; exit 0 ;;
                *  ) echo -e ${HELP}; exit 0
              exit 0
        esac
done
shift $(($OPTIND - 1))

postfixHome=/etc/postfix

function bck_conffile() {
    CFG=$1
    if [ -a "${CFG}" ]; then
        n=0
        while [ -a "${CFG}.bck.$n" ]; do
            let n=n+1
        done
        mv "${CFG}" "${CFG}.bck.$n"
    fi
}
function check_mail_addr() {
    if echo $1 | grep -q -E '^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:]]{2,}$'; then
        return 0
    else
        echo "\"$1\" seems not a mail address"
        return 1
    fi
}
function check_hostname() {
    if echo $1 | grep -q -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'; then
        return 0
    else
        echo "\"$1\" seems not a fqdn hostname or domain name"
        return 1
    fi
}

#
# check parameters
if [ -n "$relayHost" ]; then
    if [ "$smtp" == "authsmtp" ]; then
    	if ! check_hostname $relayHost; then
    	    echo "-r option: wrong argument"
    	    exit 1
    	fi
    fi
else
    echo "-r parameter is mandatory"
    exit 1
fi

if [ -n "$myHost" ]; then
    if ! check_hostname $myHost; then
        echo "-m option: wrong argument"
        exit 1
    fi
else
    myHost=`hostname`
    if ! check_hostname $myHost; then
        echo "Error: wrong hostname or hostname not defined"
        exit 1
    fi
fi

if [ -n "$myDomain" ]; then
    if ! check_hostname $myDomain; then
        echo "-m option: wrong argument"
        exit 1
    fi
else
    myDomain=`hostname`
    if ! check_hostname $myDomain; then
        echo "Error: wrong domain name or domain not defined"
        exit 1
    fi
fi

if [ -n "$smtp" ]; then
    if ! echo "$smtp" | grep -q -E "^smtp$|^authsmtp$"; then
        echo "-t option: wrong argument"
        exit 1
    fi
else
    echo "-t parameter is mandatory"
    exit 1
fi

# the sender address of the root account
if [ -n "${myFrom}" ]; then
    check_mail_addr ${myFrom} || exit 1
else
    myFrom='admin@automation.local'
fi

# comma separated recipient address list: destination addresses for messages delivered to root
if [ -n "${myTo}" ]; then
	for RCPT in $(echo ${myTo} | sed -e 's/,/ /g'); do
        check_mail_addr ${RCPT} || exit 1
	done
else
    echo "-a parameter is mandatory"
    exit 1
fi

if [ -z "$cert" ]; then
    cert=localhost.crt
fi

if [ -z "$key" ]; then
    key=localhost.key
fi

if [ "$smtp" == "authsmtp" ];then
    if [ -z "$smtpUser" ]; then
        echo "-u parameter is mandatory with -t authsmtp"
	fi
fi

if [ -n "$tls" ]; then
    if ! echo $tls | grep -Eq '^1.2$|^1.3$'; then
        echo "Error: -s argument can be one of: 1.2, 1.3"
        exit 1
    else
        tls="TLSv${tls}"
    fi
fi

if [ -n "$port" ]; then
    if ! echo $port | grep -Eq '^[0-9]+$'; then
        echo "Error: -p argument must be numeric"
        exit 1
    fi
fi

echo "hostname: $myHost"
echo "domain: $myDomain"
echo "relayhost: $relayHost"

cd $postfixHome || exit 1

# main config file: plain smtp.
if [ "$smtp" == "smtp" ]; then
    bck_conffile main.cf
    echo $myDomain > /etc/mailname
    sed -e "s/MYDOMAIN/${myDomain}/g; s/MYHOST/${myHost}/g; s/RELAYHOST/${relayHost}/g; s/MYCERTFILE/${cert}/g; s/MYKEYFILE/${key}/g" templates/main-smtp.cf.tpl > main.cf
else
# main config file: authsmtp.
    bck_conffile main.cf
    echo $myDomain > /etc/mailname
    sed -e "s/MYDOMAIN/${myDomain}/g; s/MYHOST/${myHost}/g; s/RELAYHOST/${relayHost}/g; s/MYCERTFILE/${cert}/g; s/MYKEYFILE/${key}/g" templates/main-authsmtp.cf.tpl > main.cf

    bck_conffile relay_passwords
    sed -e "s/RELAYHOST/${relayHost}/g; s/SMTPUSER/${smtpUser}/g" templates/relay_passwords.tpl > relay_passwords
    postmap relay_passwords
    chmod 400 relay_passwords relay_passwords.db
    if [ -n "$tls" ]; then
        bck_conffile tls_policy
        sed -i -e "s/# smtp_tls_policy_maps/smtp_tls_policy_maps/g" templates/main.cf
        sed -e "s/RELAYHOST/${relayHost}/g; s/TLS_VERSION/${tls}/g" templates/tls_policy.tpl > tls_policy
        postmap tls_policy
    fi
    if [ -n "$port" ]; then
        sed -i -e "s/:587/:${port}/g" templates/main.cf
        sed -i -e "s/:587/:${port}/g" templates/relay_passwords
        [ -n "$tls" ] && sed -i -e "s/:587/:${port}/g" templates/tls_policy
    fi
fi

# send to root messages with some daemon users as recipient
bck_conffile recipient_canonical
cp templates/recipient_canonical.tpl recipient_canonical
postmap recipient_canonical

# set the sender address
bck_conffile sender_canonical
sed -e "s/MYFROM/${myFrom}/g" templates/sender_canonical.tpl > sender_canonical
postmap sender_canonical

# set the recipient address list for messages delivered to root
bck_conffile virtual
sed -e "s/MYTO/${myTo}/g" templates/virtual.tpl > virtual
postmap virtual

# restore selinux context
if which getenforce > /dev/null; then
    restorecon -RF /etc/postfix
fi

echo "please restart postfix:"
echo "command: systemctl restart postfix"

