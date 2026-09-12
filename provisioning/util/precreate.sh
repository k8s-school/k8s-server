#!/bin/bash
# Pré-crée le cluster kind de chaque compte et y précharge les images de la
# démo, SANS installer la démo — le helm install est laissé au participant en
# séance ('up.sh' sans flag, ~1 min sur un cluster déjà prêt).
#
# Lancé sur le serveur par 'make precreate' (via ssh ... bash -s), qui passe :
#   USERS  la liste des comptes ("trainer student1 student2 ...")
#   REPO   le nom du clone dans chaque home (ex. otel-labs)
#   WAVE   la taille des vagues (les 'kind load' simultanés saturent le disque,
#          d'où le lancement par paquets plutôt que tous d'un coup)
set -u
: "${USERS:?}" "${REPO:?}" "${WAVE:=4}"
export LC_ALL=C
log=/tmp/precreate; mkdir -p "$log"

n=0
done_users=""   # seuls les comptes réellement traités : un compte absent n'est pas un échec
for u in $USERS; do
    id "$u" > /dev/null 2>&1 || { echo "[$(date +%T)] $u : compte absent, ignoré"; continue; }
    done_users="$done_users $u"
    # Mettre le clone à jour d'abord : un up.sh trop ancien ne connaîtrait pas le
    # mode -P et échouerait sur « illegal option -- P ». make configure rafraîchit
    # les clones, mais on peut très bien avoir poussé un correctif de lab depuis.
    sudo -u "$u" -i bash -lc "cd ~/$REPO && git pull --ff-only -q" 2>&1 \
        | sed "s/^/  $u (git pull) : /" || true
    echo "[$(date +%T)] $u : up.sh -P (cluster + images, sans déployer)"
    sudo -u "$u" -i bash -lc "cd ~/$REPO && ./scripts/up.sh -P" > "$log/$u.log" 2>&1 &
    n=$((n + 1))
    [ $((n % WAVE)) -eq 0 ] && { echo "  -- vague de $WAVE lancée, on attend --"; wait; }
done
wait

echo
echo "=== Résultat ==="
rc=0
for u in $done_users; do
    last=$(tail -1 "$log/$u.log")
    case "$last" in
        *"ready, images preloaded"*) printf '  %-12s OK\n' "$u" ;;
        *) printf '  %-12s ÉCHEC : %s\n' "$u" "$last"; rc=1 ;;
    esac
done
[ $rc -eq 0 ] && echo "Tous les clusters sont prêts. En séance : ./scripts/up.sh."
exit $rc
