%post
#!/bin/bash

printf "\n* Post-installing...\n"

# Avoid a failed start if some interface is not ready.
if [ -r /lib/systemd/system/postfix.service ] && ! grep -Lq 'Restart=on-failure' /lib/systemd/system/postfix.service; then
    cp /lib/systemd/system/postfix.service /etc/systemd/system
    cat /lib/systemd/system/postfix.service | (srv=n
        while read line; do
            if echo "$line" | fgrep -q '[Service]'; then
                srv=y
            fi 
            if [ "$srv" == "y" ] && [ -z "$line" ]; then
                echo -e 'Restart=on-failure\nRestartSec=1min'
                srv=n 
            fi
            echo $line
        done) > /etc/systemd/system/postfix.service
    systemctl daemon-reload
    systemctl restart postfix
fi

exit 0

