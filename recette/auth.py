# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 William MERI — DSIO, CHU de Guyane
"""
PULSAR Ops — authentification de la console (ISO 27001 / A.9).
================================================================
100 % bibliothèque standard, aucune dépendance externe :
  - mots de passe : PBKDF2-HMAC-SHA256 (200 000 itérations, sel par compte)
  - 2FA : TOTP RFC 6238 (HMAC-SHA1, fenêtre ±1) implémenté à la main
  - sessions : cookie autoportant signé HMAC-SHA256 (pas de store serveur)
  - RBAC : rôles admin / operateur / lecteur

Stockage (permissions 600) :
  recette/users.json           — comptes (hash mdp, secret TOTP, rôle)
  recette/session-secret.txt   — clé de signature des sessions
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import struct
import time
from pathlib import Path

RACINE = Path(__file__).parent
USERS = RACINE / "users.json"
SECRET = RACINE / "session-secret.txt"

ROLES = ("admin", "operateur", "lecteur")
# Permissions par rôle : ce que chaque rôle a le droit de FAIRE.
PERMS = {
    "admin": {"voir", "proposer", "approuver", "executer", "mode", "gerer_users"},
    "operateur": {"voir", "proposer", "approuver", "executer", "mode"},
    "lecteur": {"voir"},
}
PBKDF2_ITER = 200_000
SESSION_TTL = 8 * 3600  # 8 h


# --------------------------------------------------------------------------- #
# Secret de session
# --------------------------------------------------------------------------- #
def _secret() -> bytes:
    if SECRET.exists():
        return SECRET.read_bytes()
    s = secrets.token_bytes(32)
    SECRET.write_bytes(s)
    try:
        os.chmod(SECRET, 0o600)
    except OSError:
        pass
    return s


# --------------------------------------------------------------------------- #
# Mots de passe (PBKDF2)
# --------------------------------------------------------------------------- #
def hash_password(pw: str, salt: str | None = None) -> str:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), bytes.fromhex(salt), PBKDF2_ITER).hex()
    return f"{salt}${digest}"


def verify_password(pw: str, stored: str) -> bool:
    try:
        salt, digest = stored.split("$", 1)
        calc = hashlib.pbkdf2_hmac("sha256", pw.encode("utf-8"), bytes.fromhex(salt), PBKDF2_ITER).hex()
        return hmac.compare_digest(calc, digest)
    except Exception:
        return False


# --------------------------------------------------------------------------- #
# TOTP (RFC 6238)
# --------------------------------------------------------------------------- #
def totp_new_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode("ascii").rstrip("=")


def _totp_at(secret: str, counter: int, digits: int = 6) -> str:
    key = base64.b32decode(secret + "=" * (-len(secret) % 8))
    mac = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    off = mac[-1] & 0x0F
    code = (struct.unpack(">I", mac[off:off + 4])[0] & 0x7FFFFFFF) % (10 ** digits)
    return str(code).zfill(digits)


def totp_verify(secret: str, code: str, window: int = 1, step: int = 30) -> bool:
    code = (code or "").strip().replace(" ", "")
    if not code.isdigit():
        return False
    counter = int(time.time()) // step
    return any(hmac.compare_digest(_totp_at(secret, counter + d), code) for d in range(-window, window + 1))


def totp_uri(secret: str, user: str, issuer: str = "PULSAR Ops") -> str:
    from urllib.parse import quote
    label = quote(f"{issuer}:{user}")
    return f"otpauth://totp/{label}?secret={secret}&issuer={quote(issuer)}&algorithm=SHA1&digits=6&period=30"


# --------------------------------------------------------------------------- #
# Comptes
# --------------------------------------------------------------------------- #
def load_users() -> dict:
    if USERS.exists():
        try:
            return json.loads(USERS.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_users(users: dict) -> None:
    USERS.write_text(json.dumps(users, ensure_ascii=False, indent=2), encoding="utf-8")
    try:
        os.chmod(USERS, 0o600)
    except OSError:
        pass


def has_users() -> bool:
    return bool(load_users())


def create_user(username: str, password: str, role: str = "operateur", totp_secret: str | None = None) -> dict:
    username = username.strip().lower()
    if not username:
        raise ValueError("Identifiant requis")
    if role not in ROLES:
        raise ValueError("Rôle inconnu")
    users = load_users()
    if username in users:
        raise ValueError("Cet identifiant existe déjà")
    users[username] = {
        "password": hash_password(password),
        "role": role,
        "totp": totp_secret or "",
        "totp_active": False,
        "cree_le": time.strftime("%Y-%m-%dT%H:%M:%S"),
    }
    save_users(users)
    return users[username]


def set_totp(username: str, secret: str, active: bool = True) -> None:
    users = load_users()
    if username in users:
        users[username]["totp"] = secret
        users[username]["totp_active"] = active
        save_users(users)


def can(role: str, perm: str) -> bool:
    return perm in PERMS.get(role, set())


# --------------------------------------------------------------------------- #
# Sessions (cookie autoportant signé)
# --------------------------------------------------------------------------- #
def make_session(user: str, role: str, ttl: int = SESSION_TTL) -> str:
    payload = base64.urlsafe_b64encode(
        json.dumps({"u": user, "r": role, "exp": int(time.time()) + ttl}).encode("utf-8")
    ).decode("ascii").rstrip("=")
    sig = hmac.new(_secret(), payload.encode("ascii"), hashlib.sha256).hexdigest()
    return f"{payload}.{sig}"


def read_session(cookie: str | None) -> dict | None:
    if not cookie or "." not in cookie:
        return None
    try:
        payload, sig = cookie.rsplit(".", 1)
        expected = hmac.new(_secret(), payload.encode("ascii"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(expected, sig):
            return None
        data = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        if int(data.get("exp", 0)) < time.time():
            return None
        return data
    except Exception:
        return None
