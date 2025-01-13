# On demand / manual mount in fstab

Edit the `/etc/fstab` file:

```{filename=/etc/fstab}
sshfs#nas@nas:/mnt/nas                    /mnt/nas       fuse    noauto,defaults,user,_netdev,comment=x-gvfs-show 0 0
koofr:                                    /mnt/koofr     rclone  rw,noauto,nofail,defaults,user,_netdev,args2env,vfs_cache_mode=writes,config=/home/neonew/.config/rclone/rclone.conf,password-command='bash\040-c\040"PASSWORD_STORE_DIR=/home/neonew/.password-store/\040pass\040rclone/config"',comment=x-gvfs-show 0 0
```

`\040` escapes spaces.

To mount and unmount:

```bash
mount /mnt/nas
fusermount3 -u /mnt/nas
```
