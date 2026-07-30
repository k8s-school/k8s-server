# Plan — Guacamole en HTTPS (Caddy + Let's Encrypt)

Préparé le 2026-07-29, implémenté le 2026-07-30 (issue #5, branche
`feat/guacamole-https-ovh-dns`). Reste à dérouler sur le serveur.

Écart avec le plan initial : le DNS n'est plus un prérequis manuel, il est géré
par OpenTofu via le provider OVH — voir le §0 réécrit ci-dessous.

Objectif : servir Guacamole sur `https://training.k8s-school.fr` avec un
certificat Let's Encrypt renouvelé automatiquement, en plaçant un Caddy devant
la stack existante.

Le gain visé n'est pas le cadenas : Chrome et Firefox réservent l'API Clipboard
asynchrone aux contextes sécurisés, donc **le copier-coller entre le poste de
l'étudiant et le bureau distant ne fonctionne correctement qu'en HTTPS**. Effet
de bord bienvenu : les mots de passe des participants ne transitent plus en
clair.

---

## 0. Prérequis

1. **Enregistrement DNS chez OVH** (zone `k8s-school.fr`, `ns19.ovh.net`) :

   | Type | Sous-domaine | Cible                    | TTL |
   |------|--------------|--------------------------|-----|
   | A    | `training`   | IP réservée (Scaleway)   | 300 |

   **Géré par OpenTofu**, pas à la main : `make dns FLAVOR=otel` applique l'état
   dédié `tofu/dns/`, qui crée l'enregistrement à partir de
   `dns_zone`/`dns_subdomain` déclarés dans `tofu/envs/otel.tfvars`, pointé sur
   l'IP réservée. Cette IP est protégée par `prevent_destroy` et conservée par
   `make down`, donc l'enregistrement est écrit une fois et ne bouge plus.
   `make provision` enchaîne `up` → `dns` → `configure`.

   **Pourquoi un état séparé** (c'est le seul écart notable avec le plan
   initial) : le provider OVH valide ses identifiants contre l'API dès qu'il est
   configuré, et OpenTofu configure un provider dès qu'une de ses ressources
   apparaît dans la configuration — vérifié, ni `count = 0` ni un module
   conditionnel n'y changent quoi que ce soit. Dans l'état principal, il aurait
   donc rendu les identifiants OVH obligatoires pour `make up FLAVOR=k8s`, qui
   n'a pourtant aucun nom de domaine.

   Pas de ressource de refresh de zone : le provider OVH poste lui-même le
   `/domain/zone/{zone}/refresh` après chaque création/modification/suppression
   d'enregistrement, et la ressource `ovh_domain_zone_refresh` qui servait à ça
   n'existe plus en v2 du provider.

   Vérifier après `make up` :
   ```
   dig +short A training.k8s-school.fr    # doit renvoyer l'IP réservée
   ```

2. **Identifiants API OVH** dans l'environnement, à créer une fois sur
   <https://api.ovh.com/createToken/> avec `GET`/`POST`/`PUT`/`DELETE` sur
   `/domain/zone/*` :
   `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY`.
   Un flavor sans `dns_zone` n'en a pas besoin : le provider OVH n'est alors
   jamais configuré.

3. **Adresse e-mail du compte ACME** : `fabrice.jammes@k8s-school.fr`. Ce n'est
   pas un secret (elle sert aux avertissements d'expiration), donc elle est dans
   les defaults du rôle, pas dans le vault.

4. **Rien à faire côté Scaleway.** Aucun security group n'est déclaré dans
   `tofu/main.tf`, c'est donc le groupe par défaut qui accepte tout en entrée :
   443 est déjà joignable.

---

## 1. Décision tranchée : la webapp passe à la racine

Le conteneur `guacamole` servait la webapp sous `/guacamole`. Retenu :
`WEBAPP_CONTEXT: ROOT` dans l'environnement du service, donc URL
`https://training.k8s-school.fr/` — plus court à dicter à une classe, et ça
supprime la redirection qu'il aurait fallu écrire dans le Caddyfile pour garder
le contexte. La variable est supportée par l'image officielle.

Appliqué uniquement en mode TLS : sans nom public, la webapp reste sous
`/guacamole`, comme aujourd'hui.

---

## 2. Fichiers touchés

### `tofu/dns/` (nouveau, état séparé)

Provider `ovh/ovh ~> 2.0` (endpoint `ovh-eu` par variable, identifiants par
l'environnement) et un `ovh_domain_zone_record` de type A. Variables `dns_zone`,
`dns_subdomain` (`training`), `target_ip`, `dns_ttl` (300), `ovh_endpoint`.
L'IP lui est passée par `make dns` depuis l'output `public_ip` de l'état
principal.

### `tofu/main.tf`, `variables.tf`, `outputs.tf` — le nom, pas l'enregistrement

`dns_zone`/`dns_subdomain` sont aussi déclarées dans l'état principal, mais sans
aucune ressource OVH : elles servent seulement à composer `local.fqdn`, exposé
en output et écrit dans l'inventaire. C'est ce qui permet aux flavors sans nom
de domaine de ne jamais voir le provider OVH.

### L'inventaire porte le FQDN

Le nom est ajouté au bloc `[<flavor>:vars]` de l'inventaire généré, sous
`guacamole_fqdn`. C'est ce qui évite de le déclarer deux fois : OpenTofu possède
l'enregistrement DNS, donc c'est lui qui dit à Ansible sous quel nom le serveur
répond.

### `Makefile`

Nouvelles cibles `dns` (silencieuse et sans effet si le flavor n'a pas de
`dns_zone`), `delete-dns` et `fqdn` ; `init`, `validate` et `fmt` couvrent
maintenant les deux états ; `provision` enchaîne `up dns configure`.

### `roles/guacamole/defaults/main.yml`

Nouvelles variables :

```yaml
guacamole_fqdn: ""                  # injecté par l'inventaire généré
guacamole_tls_enabled: "{{ guacamole_fqdn | length > 0 }}"
guacamole_acme_email: "fabrice.jammes@k8s-school.fr"
guacamole_caddy_image: "caddy:2-alpine"
guacamole_https_port: 443
```

`guacamole_tls_enabled` suit le nom au lieu d'être un interrupteur séparé : un
nom est exactement ce que Let's Encrypt valide, donc il n'y a rien à décider en
plus. Conséquence utile — un flavor sans DNS garde le comportement actuel sans
qu'on ait à y penser.

`guacamole_http_port: 80` est conservé mais **change de sens** : ce n'est plus
le port de la webapp, c'est celui de Caddy — nécessaire au challenge HTTP-01 et
à la redirection vers HTTPS. Mettre à jour son commentaire, qui explique
aujourd'hui le choix de 80 pour la webapp.

### `roles/guacamole/templates/Caddyfile.j2` (nouveau)

```
# Managed by Ansible (guacamole role) — do not edit by hand.
{
    email {{ guacamole_acme_email }}
}

{{ guacamole_fqdn }} {
    reverse_proxy guacamole:8080
}
```

Caddy fait ACME, le renouvellement, ARI, la redirection 80 → 443 et le passage
du `Upgrade` WebSocket sans rien déclarer. C'est ce dernier point qui compte :
le tunnel Guacamole est un WebSocket, et c'est le piège classique avec nginx
configuré à la main.

### `roles/guacamole/templates/docker-compose.yml.j2`

- Nouveau service `caddy` : image `{{ guacamole_caddy_image }}`, ports
  `80:80` et `443:443`, volumes `./Caddyfile:/etc/caddy/Caddyfile:ro`,
  `caddy_data:/data`, `caddy_config:/config`, `depends_on: [guacamole]`,
  `restart: unless-stopped`.
- Service `guacamole` : **retirer le bloc `ports`** quand
  `guacamole_tls_enabled` est vrai. Il reste joignable par le réseau compose
  sous `guacamole:8080`, ce qui est mieux que l'exposition actuelle sur l'hôte.
  Garder le publish dans le cas `false`, pour que le mode HTTP actuel continue
  de fonctionner.
- Ajouter les volumes nommés `caddy_data` et `caddy_config`.
- `caddy_data` porte le certificat. Le persister est propre, mais sans
  importance opérationnelle : voir la note sur les limites en §5.

### `roles/guacamole/tasks/main.yml`

- **Un `assert` en tête du rôle** : si `guacamole_tls_enabled` est vrai, alors
  `guacamole_fqdn` et `guacamole_acme_email` doivent être non vides. Sans ça,
  le Caddyfile part avec un nom d'hôte vide et l'erreur qui en résulte est
  incompréhensible.
- Une task `template` pour le Caddyfile, **avant** le `docker compose up -d`.
- Enregistrer le résultat du `template` du compose file (`register`) pour la
  bascule du §3.
- Adapter le message final `Show how to reach Guacamole` :
  `https://{{ guacamole_fqdn }}/` au lieu de `http://<ip>:<port>/guacamole`.

### `tofu/envs/otel.tfvars`

```hcl
dns_zone      = "k8s-school.fr"
dns_subdomain = "training"
```

Le nom est une propriété de l'infrastructure, pas du rôle : il est déclaré là où
l'enregistrement DNS est créé, et rien n'en est répété dans les group_vars.

### `provisioning/README.md`

Mentionner la nouvelle URL et le prérequis DNS.

---

## 3. Le seul vrai point de bascule : le port 80

Aujourd'hui le conteneur `guacamole` publie `80:8080`. Au premier run TLS, Caddy
va vouloir binder le 80 alors que l'ancien conteneur le tient encore. Compose
recrée bien `guacamole` (sa définition change), mais **l'ordre entre la
suppression de l'ancien et le démarrage de Caddy n'est pas garanti** → le `up`
peut échouer sur un `address already in use`.

Solution déterministe : un `docker compose down` conditionné au changement du
compose file, avant le `up`.

```yaml
- name: Stop the stack before republishing the ports
  ansible.builtin.command:
    cmd: docker compose down --remove-orphans
    chdir: "{{ guacamole_home }}"
  when: guac_compose_file is changed
  changed_when: true
```

`--remove-orphans` sert au retour en arrière : sans nom public, `caddy` n'est
plus un service du projet et survivrait au `down`, en gardant le port 80.

Conséquences acceptables : la stack redémarre, donc les sessions navigateur
actives sont coupées — même compromis que `sessions.yml` fait déjà pour xrdp.
Le volume `pgdata` est persistant, donc aucun compte ni connexion n'est perdu.

À faire hors formation, évidemment.

---

## 4. Vérifications après coup

```bash
# 1. Le certificat a bien été obtenu
docker compose -f /opt/guacamole/docker-compose.yml logs caddy | grep -i "certificate obtained"

# 2. L'émetteur et les dates
echo | openssl s_client -connect training.k8s-school.fr:443 \
  -servername training.k8s-school.fr 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates

# 3. HTTP redirige vers HTTPS
curl -sI http://training.k8s-school.fr/ | head -3      # attendu : 308

# 4. La webapp répond
curl -sI https://training.k8s-school.fr/ | head -1     # attendu : 200

# 5. Le port 8080 de la webapp n'est plus exposé sur l'hôte
ss -lntp | grep -E ':(80|443|8080)\b'
```

**Et surtout, le test qui justifie l'opération** : ouvrir une session RDP dans
le navigateur et vérifier le copier-coller dans les deux sens entre le poste
local et le bureau distant. C'était l'objectif ; le reste n'est que de la
plomberie.

---

## 5. Limites Let's Encrypt — non bloquantes

Vérifié sur `letsencrypt.org/docs/rate-limits` :

- **50 certificats par domaine enregistré et par 7 jours**, limite globale
  comptée sur `k8s-school.fr` entier (donc partagée avec les autres
  sous-domaines). Avec quelques sessions par semaine, très loin du plafond.
- L'ancienne limite « 5 certificats dupliqués par semaine » — celle qui aurait
  pu mordre puisque la VM est recréée à chaque session — **n'existe plus** dans
  les règles actuelles. Les renouvellements pilotés par ARI sont même exemptés
  de toutes les limites, et Caddy implémente ARI.

Donc réémettre le certificat à chaque nouvelle VM est sans conséquence, même
si `caddy_data` n'est pas conservé entre les sessions.

---

## 6. Rollback

Retirer `dns_zone` de `tofu/envs/otel.tfvars`, puis `make up && make configure
FLAVOR=otel` : l'inventaire regénéré ne porte plus de `guacamole_fqdn`, le rôle
repasse en HTTP, `guacamole` republie sur le 80 et Caddy disparaît. Attention,
cela supprime aussi l'enregistrement DNS.

Pour garder le DNS et ne désactiver que le TLS, forcer
`guacamole_tls_enabled: false` (group_vars ou `-e`) et relancer `make
configure`. Le volume `caddy_data` survit dans les deux cas, donc un retour au
HTTPS ne réémet même pas de certificat.

---

## 7. Risques

| Risque | Impact | Mitigation |
|---|---|---|
| Bind du port 80 pendant la transition | Webapp coupée quelques secondes | Le `down` conditionnel du §3 ; opération hors formation |
| DNS pas encore propagé | Caddy boucle sur le challenge, l'URL HTTPS ne répond pas | Vérifier `dig` au §0 avant de lancer ; rien n'est cassé, Caddy retente |
| `guacamole_fqdn` oublié | Caddyfile invalide | L'`assert` du §2 |
| Identifiants OVH absents ou périmés | `make up` échoue sur le provider OVH, la VM n'est pas créée | Les trois variables `OVH_*` dans l'environnement, au même titre que les `SCW_*` |

---

## Hors périmètre, noté pour plus tard

- **Vraies IP client dans les logs Guacamole** : demanderait `remote-ip-header`
  côté webapp. Sans intérêt immédiat.
- **Passerelle Guacamole mutualisée pour plusieurs serveurs** : discuté
  séparément. Une seule passerelle voudrait dire un seul certificat et une seule
  URL, ce qui se marie bien avec ce plan — mais le coût réel est ailleurs
  (Private Network Scaleway pour ne pas exposer le 3389, et une VM dédiée qui
  survit aux `make down`). À reprendre si plusieurs formations doivent tourner
  en parallèle.
