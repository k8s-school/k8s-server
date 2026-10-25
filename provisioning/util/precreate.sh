#!/bin/bash
# Pré-crée le cluster kind de chaque compte et y précharge les images des labs.
#   otel : 'up.sh -P' du dépôt otel-labs, SANS installer la démo — le helm
#          install est laissé au participant en séance ('up.sh' sans flag, ~1 min
#          sur un cluster déjà prêt).
#   cks  : 'ktbx create -n <compte>' (le nom que porte CLUSTER_NAME), puis les
#          images que les labs k8s-advanced nomment explicitement.
#
# Lancé sur le serveur par 'make precreate' (via ssh ... bash -s), qui passe :
#   FLAVOR la flavor, qui choisit la commande ci-dessus
#   USERS  la liste des comptes ("trainer student1 student2 ...")
#   REPO   le nom du clone dans chaque home (ex. otel-labs)
#   WAVE   la taille des vagues (les 'kind load' simultanés saturent le disque,
#          d'où le lancement par paquets plutôt que tous d'un coup)
set -u
: "${FLAVOR:?}" "${USERS:?}" "${REPO:?}" "${WAVE:=4}"
export LC_ALL=C
log=/tmp/precreate; mkdir -p "$log"

# Dernière ligne attendue dans le log d'un compte réussi.
READY="ready, images preloaded"
case "$FLAVOR" in
    otel)
        CMD="./scripts/up.sh -P" ;;
    cks)
        # Pas falco : falco.sh installe le chart sans version fixée, une image
        # épinglée ici serait vite la mauvaise.
        IMAGES="aquasec/kube-bench:v0.14.1 nginx:alpine nginx"
        # Tirées une seule fois : le démon docker est commun à tous les comptes.
        for img in $IMAGES; do docker pull -q "$img" > /dev/null || exit 1; done
        # Idempotent : relancer precreate ne recrée pas un cluster existant.
        CMD="{ kind get clusters 2>/dev/null | grep -qx \"\$USER\" || ktbx create -n \"\$USER\"; } \
&& kind load docker-image $IMAGES --name \"\$USER\" && echo \"cluster \$USER $READY\"" ;;
    *)
        echo "precreate: rien de prévu pour FLAVOR=$FLAVOR"; exit 1 ;;
esac

n=0
done_users=""   # seuls les comptes réellement traités : un compte absent n'est pas un échec
for u in $USERS; do
    id "$u" > /dev/null 2>&1 || { echo "[$(date +%T)] $u : compte absent, ignoré"; continue; }
    done_users="$done_users $u"
    # Mettre le clone à jour d'abord (otel) : un up.sh trop ancien ne connaîtrait pas le
    # mode -P et échouerait sur « illegal option -- P ». make configure rafraîchit
    # les clones, mais on peut très bien avoir poussé un correctif de lab depuis.
    sudo -u "$u" -i bash -lc "cd ~/$REPO && git pull --ff-only -q" 2>&1 \
        | sed "s/^/  $u (git pull) : /" || true
    echo "[$(date +%T)] $u : cluster + images (sans déployer)"
    sudo -u "$u" -i bash -lc "cd ~/$REPO && $CMD" > "$log/$u.log" 2>&1 &
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
        *"$READY"*) printf '  %-12s OK\n' "$u" ;;
        *) printf '  %-12s ÉCHEC : %s\n' "$u" "$last"; rc=1 ;;
    esac
done
if [ $rc -eq 0 ]; then
    echo "Tous les clusters sont prêts."
    [ "$FLAVOR" = otel ] && echo "En séance : ./scripts/up.sh."
fi
exit $rc
