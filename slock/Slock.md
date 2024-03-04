In Manjaro XFCE the suspend and lock process is roughly as follows:

1. logind

logind handles the Lid open and close events, unless you tell xfce4-power-manager this:

```bash
xfconf-query -c xfce4-power-manager -np /xfce4-power-manager/logind-handle-lid-switch -t bool -s false
```

2. xfce4-power-manager

Now xfce4-power-manager handles what should happen on lid events,
and you can control it by setting e.g. `lid-action-on-battery`.

3. xfce4-session

xfce4-session calls the `LockCommand`.
I am not exactly sure how and when it is called, but from my observation
just specifying `slock` directly doesn't work:
When the lid was opened, slock was called, but the system suspended right after.
It looked like xfce4-session waited for the slock command to finish and only after that it suspended the system.

I was able to get slock to work by setting the `LockCommand` to an empty string and using the extra slock service
to make it show up after suspension.
