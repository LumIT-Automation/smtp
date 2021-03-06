# See /usr/share/postfix/main.cf.dist for a commented, more complete version


# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# See http://www.postfix.org/COMPATIBILITY_README.html -- default to 2 on
# fresh installs.
compatibility_level = 2

relayhost = RELAYHOST

smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = MYHOST
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mydestination = MYHOST, localhost.localdomain, localhost
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 MYNET
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4
virtual_alias_maps = hash:/etc/postfix/virtual
smtp_generic_maps = hash:/etc/postfix/generic
# enable_original_recipient = no # This doesn't seem to work on debian11, the next one is the workaround.
smtp_header_checks = regexp:/etc/postfix/smtp_header_checks

