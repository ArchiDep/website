# Notes

## Simulate a student VM with a Docker container

From the root of the repository:

```bash
# Add the test SSH key to your SSH agent
cat tmp/jde/id_ed25519 | ssh-add -

# Build an SSH server image
cd app/test/docker/ssh-server
docker build -t archidep/ssh-server --build-arg JDE_UID="$(id -u)" .

# Run a container with an SSH server and expose it on local port 2222
cd ../../
docker run --rm -it --init -p 2222:22 -v "$PWD/priv/ssh/id_ed25519.pub:/home/jde/.ssh/authorized_keys:ro" archidep/ssh-server
```
