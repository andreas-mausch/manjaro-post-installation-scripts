sudo cp ./20-force_publickey_auth.conf /etc/ssh/sshd_config.d/
sudo cp ./21-deny_root.conf /etc/ssh/sshd_config.d/

# Put this to ~/.ssh/config in case for TPM 2.0 GPG Key issues
# Host *
#  PubkeyAcceptedKeyTypes rsa-sha2-256
