mkdir -p ~/.gnupg/

# Values are in seconds
# 7200s  = 2h
# 14400s = 4h
echo 'default-cache-ttl 7200' >> ~/.gnupg/gpg-agent.conf
echo 'max-cache-ttl 14400' >> ~/.gnupg/gpg-agent.conf

echo 'default-cache-ttl-ssh 7200' >> ~/.gnupg/gpg-agent.conf
echo 'max-cache-ttl-ssh 14400' >> ~/.gnupg/gpg-agent.conf
