#!/usr/bin/env bash
# Never suspend Lenovo desktops: they're used headless over SSH/RDP, and Plasma's
# default (suspend after 15 min idle on AC) takes them off the network.
# Laptops keep normal sleep.
#   - system-wide: mask the sleep/suspend/hibernate targets (nothing can suspend)
#   - Plasma: no idle suspend on AC, so Powerdevil doesn't keep trying
# Overrides: NO_SLEEP=1 forces it on any machine, NO_SLEEP=0 skips it.

case "${NO_SLEEP:-auto}" in
    0) info "NO_SLEEP=0: leaving sleep settings alone"; return 0 ;;
    1) ;;
    *) is_lenovo_desktop || { info "not a Lenovo desktop; skipping"; return 0; } ;;
esac

TARGETS="sleep.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target"

if [ -d /run/systemd/system ] || [ "${DRY_RUN:-0}" -eq 1 ]; then
    unmasked=""
    for t in $TARGETS; do
        [ "$(systemctl is-enabled "$t" 2>/dev/null)" = "masked" ] || unmasked="$unmasked $t"
    done
    if [ -n "$unmasked" ]; then
        # shellcheck disable=SC2086
        run $SUDO systemctl mask $unmasked
        ok "suspend and hibernate disabled system-wide"
    else
        info "suspend and hibernate already disabled"
    fi
else
    warn "systemd not running; can't mask the sleep targets"
fi

# Plasma 6 Powerdevil: AutoSuspendAction 0 = do nothing when idle on AC.
if has kwriteconfig6; then
    if [ "$(kreadconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 2>/dev/null)" != "0" ]; then
        run kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
        ok "Plasma: no automatic suspend on AC (takes effect on next login)"
    fi
else
    warn "kwriteconfig6 not found; Plasma will still try to suspend when idle (it will fail)."
fi
true
