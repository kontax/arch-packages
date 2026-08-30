# Fetches a personal GPG key's public half from a keyserver and sets it to
# ultimately trusted, matching what the old private dotfiles' base.sh did.
# keys.openpgp.org won't work as the keyserver here - it strips UIDs from
# keys whose email hasn't been verified there, so lookups by ID still
# succeed but come back with no user ID attached (and lookup by email
# finds nothing at all); keyserver.ubuntu.com serves the full key.
#
# This only ever gets the *public* key - keyservers never distribute
# secret key material. If the corresponding secret key lives on a YubiKey
# (as it does for the couldinho setup), actually signing anything still
# needs that YubiKey physically present - see `gpg --card-status`.
#
# Also turns on gpg-agent's SSH support, so the card's Authenticate subkey
# doubles as an SSH identity (`ssh-add -L` / `gpg --export-ssh-key`) with no
# separate keypair to generate or store - used to auth the password-store
# clone in password-store.nix instead of a file-based deploy key. Every use
# prompts a physical touch on the card, same as commit signing already does.
#
# The key ID is personal information that doesn't belong hardcoded in this
# public repo - only does anything if couldinho.gpg.keyId is set via
# ~/.config/couldinho/local.nix (see local.nix.example).
{ osConfig, lib, pkgs, ... }:
let
  keyId = osConfig.couldinho.gpg.keyId;
in
lib.mkIf (keyId != null) {
  services.gpg-agent.enableSshSupport = true;

  home.activation.trustPersonalGpgKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Runs during early boot (system-level home-manager-james.service, no
    # After=network-online.target), so the keyserver isn't reliably reachable
    # yet - confirmed on real hardware, this raced NetworkManager-wait-online
    # and lost. Warn and carry on rather than aborting the rest of activation
    # (sway/waybar/dotfiles linking etc. all run after this in the same
    # activation script) - worst case the key is just missing/untrusted until
    # the next activation succeeds in fetching it.
    if ! $DRY_RUN_CMD ${pkgs.gnupg}/bin/gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "${keyId}"; then
      echo "trustPersonalGpgKey: keyserver fetch of ${keyId} failed (network not up yet?) - skipping for this activation" >&2
    fi

    # `gpg --edit-key trust` (even scripted via --command-fd) still opens
    # /dev/tty and fails outright when run from activation with no
    # controlling terminal. --import-ownertrust sets the same ultimate
    # trust (value 6) without ever touching a tty; it wants the full
    # fingerprint rather than whatever ID form keyId happens to be, so
    # resolve that first - only set trust if the key is actually present
    # locally (this run or a previous one), an empty $fpr would otherwise
    # write a bogus ":6:" line to the trustdb.
    fpr="$(${pkgs.gnupg}/bin/gpg --with-colons --fingerprint "${keyId}" 2>/dev/null | ${pkgs.gawk}/bin/awk -F: '/^fpr:/ { print $10; exit }')"
    if [ -n "$fpr" ]; then
      $DRY_RUN_CMD bash -c "echo \"$fpr:6:\" | ${pkgs.gnupg}/bin/gpg --import-ownertrust"
    else
      echo "trustPersonalGpgKey: ${keyId} not present locally - cannot set trust, skipping" >&2
    fi
  '';
}
