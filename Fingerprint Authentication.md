See [ArchLinux Wiki](https://wiki.archlinux.org/title/fprint).

```bash
paru -S pam-fprint-grosshack
```

Add a line before `auth      include   system-login`

```{data-filename=/etc/pam.d/system-local-login}
auth      sufficient pam_fprintd.so
```

```{data-filename=/etc/pam.d/sudo}
auth		sufficient  	pam_fprintd_grosshack.so
auth		sufficient  	pam_unix.so try_first_pass nullok
```

