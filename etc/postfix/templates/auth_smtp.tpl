# TLS parameters
smtp_tls_CApath=/etc/ssl/certs
smtpd_tls_cert_file = MYCERTFILE
smtpd_tls_key_file = MYKEYFILE
smtpd_use_tls = yes
smtpd_tls_security_level=may
smtp_tls_security_level=may
# smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
# smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/relay_passwords
smtp_sasl_security_options = noanonymous
smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_policy_maps = hash:/etc/postfix/tls_policy
