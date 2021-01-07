## Sample usage
1. Generate ssh key pair inside ./.ssh directory

```bash
mkdir -p ./.ssh/ && chmod 700 ./.ssh
ssh-keygen -b 4096 -f ./.ssh/id_rsa
```

2. Add public key to [review.tizen.org](https://review.tizen.org/gerrit/#/settings/ssh-keys)
website account.

3. Export review.tizen.org user name as environment variable

```bash
export TIZEN_USER='tizen.org_username'
```

4. Adjust LXC(D) container template using ./adjust-template.sh script.

```bash
./adjust-template.sh
```

It will adjust UID, GID, pulse audio and xorg socket path inside template
to match your host user configuration.

4. Create && Run LXC(D) container

```bash
./lxc.sh
```

5. To launch tizen-emulator execute on host machine:

```bash
lxc exec tizen-emu -- sudo --user ubuntu --login -- bash
```

This will launch interactive shell session. Inside it please execute:

```bash
# Navigate to desired tizen-emulator version && device type directory
cd ~/tes/6.0/mobile
# Download and prepare tizen-emulator image
make latest
# Run tizen-emulator
make run
```

## NOTES
On Archlinux distribution it is necessary to execute `xhost +local:`
before starting gui application such as tizen-emulator inside container.
This allows xorg server from container to talk to xorg socket on host machine.

To start second tizen-emulator, create another LXC(D) container based on tizen-emu.
```bash
# Copy tizen-emu container instance to tizen-emu2
lxc copy tizen-emu tizen-emu2
# Use newly created instance:
lxc exec tizen-emu2 -- sudo --user ubuntu --login -- bash
```
