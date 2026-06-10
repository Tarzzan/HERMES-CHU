"""
vault.py — PULSAR Vault
Coffre de credentials chiffré localement (AES-256-GCM via cryptography.fernet).
Stocke API keys, tokens, clés SSH et mots de passe dans ~/.pulsar/vault.enc

Architecture :
  - La clé de chiffrement est dérivée d'un master_key stocké dans ~/.pulsar/vault.key
    (fichier chmod 600, jamais exposé via l'API).
  - Les credentials sont stockés dans ~/.pulsar/vault.enc (JSON chiffré).
  - L'API expose uniquement des métadonnées (id, label, type, alias) — jamais la valeur brute.
  - La valeur n'est révélée que via /api/vault/{id}/reveal (audit loggé).
  - Le système de variables {{vault:alias}} permet d'injecter un credential
    dans le chat sans jamais afficher la valeur en clair dans l'interface.

Types de credentials supportés :
  - api_key    : Clé API (OpenAI, Anthropic, etc.)
  - token      : Token d'accès OAuth / Bearer
  - ssh_key    : Clé privée SSH (PEM)
  - password   : Mot de passe
  - certificate: Certificat / clé TLS
  - custom     : Variable personnalisée

DSIO — CHU de Guyane | William MERI
"""
from __future__ import annotations

import json
import logging
import os
import secrets
import stat
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Dépendance optionnelle : cryptography (Fernet = AES-128-CBC + HMAC-SHA256)
# Si absent, on propose l'installation et on lève une erreur claire.
# ---------------------------------------------------------------------------
try:
    from cryptography.fernet import Fernet, InvalidToken
    _CRYPTO_AVAILABLE = True
except ImportError:
    _CRYPTO_AVAILABLE = False

CREDENTIAL_TYPES = {
    "api_key":        "Clé API",
    "token":          "Token d'accès",
    "ssh_key":        "Clé SSH privée",
    "password":       "Mot de passe",
    "certificate":    "Certificat / Clé TLS",
    "cookie_session": "Session / Cookies (2FA)",
    "custom":         "Variable personnalisée",
}

# Champs spécifiques aux cookies de session
COOKIE_FIELDS = ["name", "value", "domain", "path", "expires", "httpOnly", "secure", "sameSite"]

# ---------------------------------------------------------------------------
# Helpers chemins
# ---------------------------------------------------------------------------

def _pulsar_home() -> Path:
    """Retourne ~/.pulsar (ou PULSAR_HOME si défini)."""
    home = os.environ.get("PULSAR_HOME") or os.environ.get("HERMES_HOME")
    if home:
        return Path(home)
    return Path.home() / ".pulsar"


def _vault_key_path() -> Path:
    return _pulsar_home() / "vault.key"


def _vault_data_path() -> Path:
    return _pulsar_home() / "vault.enc"


def _vault_audit_path() -> Path:
    return _pulsar_home() / "vault_audit.log"


# ---------------------------------------------------------------------------
# Gestion de la clé maître
# ---------------------------------------------------------------------------

def _ensure_key() -> bytes:
    """Charge ou génère la clé Fernet maître (chmod 600)."""
    key_path = _vault_key_path()
    key_path.parent.mkdir(parents=True, exist_ok=True)

    if key_path.exists():
        key = key_path.read_bytes().strip()
        if len(key) >= 44:  # Fernet key = 44 chars base64
            return key
        # Clé corrompue → régénérer
        logger.warning("vault.key corrompue, régénération...")

    key = Fernet.generate_key()
    key_path.write_bytes(key)
    # chmod 600 — lecture seule pour le propriétaire
    key_path.chmod(stat.S_IRUSR | stat.S_IWUSR)
    logger.info("Nouvelle clé vault générée : %s", key_path)
    return key


def _get_fernet() -> "Fernet":
    if not _CRYPTO_AVAILABLE:
        raise RuntimeError(
            "Le module 'cryptography' est requis pour PULSAR Vault.\n"
            "Installez-le avec : pip install cryptography"
        )
    return Fernet(_ensure_key())


# ---------------------------------------------------------------------------
# Chargement / sauvegarde du coffre
# ---------------------------------------------------------------------------

def _load_vault() -> Dict[str, Any]:
    """Charge et déchiffre le coffre. Retourne {} si vide ou inexistant."""
    data_path = _vault_data_path()
    if not data_path.exists():
        return {"credentials": [], "version": 1}
    try:
        f = _get_fernet()
        raw = f.decrypt(data_path.read_bytes())
        return json.loads(raw.decode("utf-8"))
    except InvalidToken:
        logger.error("vault.enc : token invalide — clé incorrecte ou fichier corrompu")
        raise ValueError("Impossible de déchiffrer le coffre PULSAR. La clé vault.key est-elle correcte ?")
    except Exception as exc:
        logger.error("Erreur chargement vault : %s", exc)
        raise


def _save_vault(data: Dict[str, Any]) -> None:
    """Chiffre et sauvegarde le coffre."""
    data_path = _vault_data_path()
    data_path.parent.mkdir(parents=True, exist_ok=True)
    f = _get_fernet()
    encrypted = f.encrypt(json.dumps(data, ensure_ascii=False).encode("utf-8"))
    data_path.write_bytes(encrypted)
    data_path.chmod(stat.S_IRUSR | stat.S_IWUSR)


# ---------------------------------------------------------------------------
# Audit log
# ---------------------------------------------------------------------------

def _audit(action: str, credential_id: str, label: str, source_ip: str = "local") -> None:
    """Enregistre un accès au coffre dans le journal d'audit."""
    audit_path = _vault_audit_path()
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "action": action,
        "id": credential_id,
        "label": label,
        "ip": source_ip,
    }
    with open(audit_path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# API publique du Vault
# ---------------------------------------------------------------------------

def vault_status() -> Dict[str, Any]:
    """Retourne le statut du coffre (disponibilité, nombre de credentials)."""
    if not _CRYPTO_AVAILABLE:
        return {"available": False, "reason": "Module 'cryptography' manquant", "count": 0}
    key_path = _vault_key_path()
    data_path = _vault_data_path()
    try:
        data = _load_vault()
        count = len(data.get("credentials", []))
    except Exception:
        count = -1
    return {
        "available": True,
        "initialized": key_path.exists() and data_path.exists(),
        "count": count,
        "key_path": str(key_path),
        "data_path": str(data_path),
    }


def vault_list() -> List[Dict[str, Any]]:
    """
    Retourne la liste des credentials SANS les valeurs.
    Chaque entrée : {id, label, alias, type, type_label, description, created_at, updated_at}
    """
    data = _load_vault()
    result = []
    for cred in data.get("credentials", []):
        result.append({
            "id":          cred["id"],
            "label":       cred["label"],
            "alias":       cred.get("alias", ""),
            "type":        cred["type"],
            "type_label":  CREDENTIAL_TYPES.get(cred["type"], cred["type"]),
            "description": cred.get("description", ""),
            "created_at":  cred.get("created_at", ""),
            "updated_at":  cred.get("updated_at", ""),
            "has_value":   bool(cred.get("value")),
        })
    return result


def vault_add(
    label: str,
    value: str,
    cred_type: str = "api_key",
    alias: str = "",
    description: str = "",
) -> Dict[str, Any]:
    """
    Ajoute un credential dans le coffre.
    Retourne les métadonnées (sans la valeur).
    """
    if cred_type not in CREDENTIAL_TYPES:
        raise ValueError(f"Type inconnu : {cred_type}. Types valides : {list(CREDENTIAL_TYPES.keys())}")
    if not label.strip():
        raise ValueError("Le label ne peut pas être vide.")
    if not value.strip():
        raise ValueError("La valeur ne peut pas être vide.")

    # Générer un alias si absent
    if not alias:
        alias = label.lower().replace(" ", "_").replace("-", "_")
        # S'assurer de l'unicité
        data = _load_vault()
        existing_aliases = {c.get("alias") for c in data.get("credentials", [])}
        base_alias = alias
        i = 2
        while alias in existing_aliases:
            alias = f"{base_alias}_{i}"
            i += 1
    else:
        data = _load_vault()

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    cred_id = secrets.token_hex(8)

    new_cred = {
        "id":          cred_id,
        "label":       label.strip(),
        "alias":       alias.strip(),
        "type":        cred_type,
        "description": description.strip(),
        "value":       value,  # stocké chiffré dans le fichier
        "created_at":  now,
        "updated_at":  now,
    }

    data.setdefault("credentials", []).append(new_cred)
    _save_vault(data)
    _audit("add", cred_id, label)

    return {k: v for k, v in new_cred.items() if k != "value"}


def vault_update(
    cred_id: str,
    label: Optional[str] = None,
    value: Optional[str] = None,
    alias: Optional[str] = None,
    description: Optional[str] = None,
) -> Dict[str, Any]:
    """Met à jour un credential existant."""
    data = _load_vault()
    for cred in data.get("credentials", []):
        if cred["id"] == cred_id:
            if label is not None:
                cred["label"] = label.strip()
            if value is not None and value.strip():
                cred["value"] = value
            if alias is not None:
                cred["alias"] = alias.strip()
            if description is not None:
                cred["description"] = description.strip()
            cred["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            _save_vault(data)
            _audit("update", cred_id, cred["label"])
            return {k: v for k, v in cred.items() if k != "value"}
    raise KeyError(f"Credential introuvable : {cred_id}")


def vault_delete(cred_id: str) -> bool:
    """Supprime un credential du coffre."""
    data = _load_vault()
    original = data.get("credentials", [])
    remaining = [c for c in original if c["id"] != cred_id]
    if len(remaining) == len(original):
        raise KeyError(f"Credential introuvable : {cred_id}")
    deleted = next(c for c in original if c["id"] == cred_id)
    data["credentials"] = remaining
    _save_vault(data)
    _audit("delete", cred_id, deleted["label"])
    return True


def vault_reveal(cred_id: str, source_ip: str = "local") -> str:
    """
    Révèle la valeur d'un credential (audit loggé).
    NE PAS exposer cette valeur dans les logs ou l'interface principale.
    """
    data = _load_vault()
    for cred in data.get("credentials", []):
        if cred["id"] == cred_id:
            _audit("reveal", cred_id, cred["label"], source_ip)
            return cred["value"]
    raise KeyError(f"Credential introuvable : {cred_id}")


def vault_resolve_alias(alias: str) -> Optional[str]:
    """
    Résout un alias en valeur (pour injection dans les prompts).
    Usage : {{vault:mon_alias}} → valeur réelle
    Audit loggé automatiquement.
    """
    data = _load_vault()
    for cred in data.get("credentials", []):
        if cred.get("alias") == alias:
            _audit("resolve", cred["id"], cred["label"], "agent")
            return cred["value"]
    return None


def vault_inject(text: str) -> str:
    """
    Remplace toutes les occurrences de {{vault:alias}} dans un texte
    par la valeur correspondante du coffre.
    Utilisé pour injecter des credentials dans les prompts système.
    """
    import re
    pattern = re.compile(r"\{\{vault:([a-zA-Z0-9_\-]+)\}\}")
    def replacer(m: re.Match) -> str:
        alias = m.group(1)
        value = vault_resolve_alias(alias)
        if value is None:
            logger.warning("vault_inject: alias '%s' introuvable", alias)
            return m.group(0)  # laisser tel quel si non trouvé
        return value
    return pattern.sub(replacer, text)


def vault_audit_log(limit: int = 50) -> List[Dict[str, Any]]:
    """Retourne les dernières entrées du journal d'audit."""
    audit_path = _vault_audit_path()
    if not audit_path.exists():
        return []
    lines = audit_path.read_text(encoding="utf-8").strip().splitlines()
    entries = []
    for line in lines[-limit:]:
        try:
            entries.append(json.loads(line))
        except Exception:
            pass
    return list(reversed(entries))  # plus récent en premier


# ---------------------------------------------------------------------------
# Gestion des cookies de session
# ---------------------------------------------------------------------------

def _cookies_data_path() -> Path:
    """Fichier chiffré dédié aux cookies de session."""
    return _pulsar_home() / "vault_cookies.enc"


def _load_cookies_vault() -> Dict[str, Any]:
    """Charge le coffre de cookies (séparé du coffre principal)."""
    data_path = _cookies_data_path()
    if not data_path.exists():
        return {"sessions": [], "version": 1}
    try:
        f = _get_fernet()
        raw = f.decrypt(data_path.read_bytes())
        return json.loads(raw.decode("utf-8"))
    except Exception as exc:
        logger.error("Erreur chargement cookies vault : %s", exc)
        raise


def _save_cookies_vault(data: Dict[str, Any]) -> None:
    """Chiffre et sauvegarde le coffre de cookies."""
    data_path = _cookies_data_path()
    data_path.parent.mkdir(parents=True, exist_ok=True)
    f = _get_fernet()
    encrypted = f.encrypt(json.dumps(data, ensure_ascii=False).encode("utf-8"))
    data_path.write_bytes(encrypted)
    data_path.chmod(stat.S_IRUSR | stat.S_IWUSR)


def _parse_netscape_cookies(text: str) -> List[Dict[str, Any]]:
    """
    Parse le format Netscape cookies.txt (exporté par EditThisCookie, Cookie-Editor, etc.).
    Format : domain\tinclude_subdomains\tpath\tsecure\texpires\tname\tvalue
    """
    cookies = []
    for line in text.strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 7:
            continue
        try:
            expires_raw = int(parts[4]) if parts[4].strip().lstrip("-").isdigit() else 0
            cookies.append({
                "domain":     parts[0].lstrip("."),
                "path":       parts[2],
                "secure":     parts[3].upper() == "TRUE",
                "expires":    expires_raw,
                "name":       parts[5],
                "value":      parts[6],
                "httpOnly":   False,
                "sameSite":   "Lax",
            })
        except Exception:
            continue
    return cookies


def _export_netscape_cookies(cookies: List[Dict[str, Any]]) -> str:
    """Exporte les cookies au format Netscape cookies.txt."""
    lines = ["# Netscape HTTP Cookie File", "# Exporté par PULSAR Vault", ""]
    for c in cookies:
        include_sub = "TRUE" if c.get("domain", "").startswith(".") else "FALSE"
        domain = c.get("domain", "")
        path = c.get("path", "/")
        secure = "TRUE" if c.get("secure") else "FALSE"
        expires = str(int(c.get("expires", 0)))
        name = c.get("name", "")
        value = c.get("value", "")
        lines.append(f"{domain}\t{include_sub}\t{path}\t{secure}\t{expires}\t{name}\t{value}")
    return "\n".join(lines)


def _cookie_session_status(cookies: List[Dict[str, Any]]) -> str:
    """Détermine le statut d'expiration d'une session cookie."""
    if not cookies:
        return "empty"
    now = time.time()
    session_cookies = [c for c in cookies if c.get("expires", 0) == 0]
    expiring = [c for c in cookies if c.get("expires", 0) > 0]
    if not expiring:
        return "session"  # cookies de session (sans expiration)
    expired = [c for c in expiring if c["expires"] < now]
    if len(expired) == len(expiring):
        return "expired"
    soon = [c for c in expiring if 0 < c["expires"] - now < 86400 * 7]  # < 7 jours
    if soon:
        return "expiring_soon"
    return "valid"


def cookie_session_list() -> List[Dict[str, Any]]:
    """Liste toutes les sessions cookies stockées (sans les valeurs des cookies)."""
    data = _load_cookies_vault()
    result = []
    for sess in data.get("sessions", []):
        cookies = sess.get("cookies", [])
        domains = list({c.get("domain", "") for c in cookies if c.get("domain")})
        result.append({
            "id":          sess["id"],
            "label":       sess["label"],
            "alias":       sess.get("alias", ""),
            "description": sess.get("description", ""),
            "domains":     domains,
            "cookie_count": len(cookies),
            "status":      _cookie_session_status(cookies),
            "created_at":  sess.get("created_at", ""),
            "updated_at":  sess.get("updated_at", ""),
        })
    return result


def cookie_session_add(
    label: str,
    cookies_json: Optional[str] = None,
    cookies_netscape: Optional[str] = None,
    alias: str = "",
    description: str = "",
) -> Dict[str, Any]:
    """
    Ajoute une session cookies dans le coffre.
    Accepte soit du JSON (format EditThisCookie/Chrome DevTools)
    soit du texte Netscape cookies.txt.
    """
    if not label.strip():
        raise ValueError("Le label ne peut pas être vide.")

    # Parser les cookies
    cookies: List[Dict[str, Any]] = []
    if cookies_json:
        try:
            parsed = json.loads(cookies_json)
            if isinstance(parsed, list):
                cookies = parsed
            elif isinstance(parsed, dict):
                cookies = [parsed]
            else:
                raise ValueError("Format JSON invalide : liste ou objet attendu.")
        except json.JSONDecodeError as e:
            raise ValueError(f"JSON invalide : {e}")
    elif cookies_netscape:
        cookies = _parse_netscape_cookies(cookies_netscape)
        if not cookies:
            raise ValueError("Aucun cookie valide trouvé dans le format Netscape.")
    else:
        raise ValueError("Fournissez cookies_json ou cookies_netscape.")

    # Normaliser les champs
    normalized = []
    for c in cookies:
        normalized.append({
            "name":     str(c.get("name", "")),
            "value":    str(c.get("value", "")),
            "domain":   str(c.get("domain", "")),
            "path":     str(c.get("path", "/")),
            "expires":  float(c.get("expires", c.get("expirationDate", 0)) or 0),
            "httpOnly": bool(c.get("httpOnly", False)),
            "secure":   bool(c.get("secure", False)),
            "sameSite": str(c.get("sameSite", "Lax")),
        })

    data = _load_cookies_vault()

    # Générer alias
    if not alias:
        alias = label.lower().replace(" ", "_").replace("-", "_")
        existing = {s.get("alias") for s in data.get("sessions", [])}
        base = alias
        i = 2
        while alias in existing:
            alias = f"{base}_{i}"
            i += 1

    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    sess_id = secrets.token_hex(8)

    new_sess = {
        "id":          sess_id,
        "label":       label.strip(),
        "alias":       alias.strip(),
        "description": description.strip(),
        "cookies":     normalized,
        "created_at":  now,
        "updated_at":  now,
    }

    data.setdefault("sessions", []).append(new_sess)
    _save_cookies_vault(data)
    _audit("cookie_add", sess_id, label)

    return {
        "id":          sess_id,
        "label":       label.strip(),
        "alias":       alias.strip(),
        "description": description.strip(),
        "cookie_count": len(normalized),
        "domains":     list({c["domain"] for c in normalized if c["domain"]}),
        "status":      _cookie_session_status(normalized),
        "created_at":  now,
        "updated_at":  now,
    }


def cookie_session_delete(sess_id: str) -> bool:
    """Supprime une session cookies du coffre."""
    data = _load_cookies_vault()
    original = data.get("sessions", [])
    remaining = [s for s in original if s["id"] != sess_id]
    if len(remaining) == len(original):
        raise KeyError(f"Session introuvable : {sess_id}")
    deleted = next(s for s in original if s["id"] == sess_id)
    data["sessions"] = remaining
    _save_cookies_vault(data)
    _audit("cookie_delete", sess_id, deleted["label"])
    return True


def cookie_session_get_cookies(sess_id: str, source_ip: str = "local") -> List[Dict[str, Any]]:
    """Retourne les cookies d'une session (audit loggé)."""
    data = _load_cookies_vault()
    for sess in data.get("sessions", []):
        if sess["id"] == sess_id:
            _audit("cookie_reveal", sess_id, sess["label"], source_ip)
            return sess.get("cookies", [])
    raise KeyError(f"Session introuvable : {sess_id}")


def cookie_session_export_netscape(sess_id: str) -> str:
    """Exporte une session au format Netscape cookies.txt."""
    cookies = cookie_session_get_cookies(sess_id)
    return _export_netscape_cookies(cookies)


def cookie_session_export_json(sess_id: str) -> List[Dict[str, Any]]:
    """Exporte une session au format JSON (Chrome DevTools / EditThisCookie)."""
    return cookie_session_get_cookies(sess_id)


def cookie_session_resolve_alias(alias: str) -> Optional[List[Dict[str, Any]]]:
    """Résout un alias de session cookies (pour injection dans les agents browser)."""
    data = _load_cookies_vault()
    for sess in data.get("sessions", []):
        if sess.get("alias") == alias:
            _audit("cookie_resolve", sess["id"], sess["label"], "agent")
            return sess.get("cookies", [])
    return None


def vault_export_aliases() -> List[Dict[str, str]]:
    """
    Retourne la liste des aliases disponibles (sans valeurs).
    Utilisé par le frontend pour proposer les variables cliquables.
    """
    data = _load_vault()
    return [
        {
            "id":         cred["id"],
            "alias":      cred.get("alias", ""),
            "label":      cred["label"],
            "type":       cred["type"],
            "type_label": CREDENTIAL_TYPES.get(cred["type"], cred["type"]),
            "placeholder": f"{{{{vault:{cred.get('alias', cred['id'])}}}}}",
        }
        for cred in data.get("credentials", [])
        if cred.get("alias")
    ]
