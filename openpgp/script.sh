mkdir -p ~/.gnupg/

# Values are in seconds
# 7200s  = 2h
# 14400s = 4h
echo 'default-cache-ttl 7200' >> ~/.gnupg/gpg-agent.conf
echo 'max-cache-ttl 14400' >> ~/.gnupg/gpg-agent.conf

echo 'default-cache-ttl-ssh 7200' >> ~/.gnupg/gpg-agent.conf
echo 'max-cache-ttl-ssh 14400' >> ~/.gnupg/gpg-agent.conf

# This avoids a problem with my TPM not being capable of doing SHA512
echo 'personal-digest-preferences SHA256' >> ~/.gnupg/gpg.conf
