# Releasing Workon

Workon installations trust only stable, annotated Git tags signed by a key in
`security/release-signers`. The release workflow also requires the tag's commit
to be present on `main` and reruns the complete macOS test suite before it
publishes a GitHub release.

## One-time signing setup

Create a dedicated, passphrase-protected SSH key on the trusted personal Mac:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/workon_release_ed25519 -C workon-release
ssh-add --apple-use-keychain ~/.ssh/workon_release_ed25519
```

The release command unlocks this exact key only while signing and removes it
from the running SSH agent afterward, so it is not offered during ordinary SSH
connections. The encrypted private key remains in macOS Keychain.

Replace the entry in `security/release-signers` with the identity from
`git config user.email`, followed by the key type and key data from
`~/.ssh/workon_release_ed25519.pub`. Make that trust change through a reviewed
pull request before publishing with the key. The private key must never enter
the repository or GitHub Actions.

## Release procedure

1. Change `VERSION` in a pull request and describe the user-visible changes.
2. Wait for `Workon CI / verify` and the required owner approval, then merge.
3. Update the protected local `main` with `git pull --ff-only`.
4. Create, locally verify, and push the signed tag with one command:

   ```bash
   ./scripts/release.sh 0.2.0
   ```

The workflow verifies the signature, ancestry, version, and tests before
creating the GitHub release. Do not create a release manually. GitHub immutable
releases must be enabled in repository settings before the first production
release.
