"""
Tests unitaires — Privacy Engine HERMES CHU
"""

import asyncio
import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/privacy-engine"))
# memoire_session (TestMemoireSession) vit dans src/orchestrator — chemin requis
# pour que cette suite passe seule, sans dépendre de l'ordre d'exécution
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/orchestrator"))

from anonymizer import PrivacyEngine, StockageMemoire, TypePHI


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def engine():
    return PrivacyEngine(
        stockage=StockageMemoire(),
        sel_hash="sel_test_fixe_pour_reproductibilite",
        activer_ner=False,
    )


SESSION_TEST = "session-test-001"


# ---------------------------------------------------------------------------
# Tests d'anonymisation
# ---------------------------------------------------------------------------

class TestAnonymisation:

    @pytest.mark.asyncio
    async def test_anonymisation_nir(self, engine):
        """Un NIR doit être détecté et remplacé par un token."""
        texte = "Le patient a un NIR : 1 85 12 75 056 123 45"
        texte_anon, mapping = await engine.anonymize(texte, SESSION_TEST)

        assert "1 85 12 75 056 123 45" not in texte_anon
        assert len(mapping) == 1
        token = list(mapping.keys())[0]
        assert token.startswith("[NIR_")

    @pytest.mark.asyncio
    async def test_anonymisation_email(self, engine):
        """Un email doit être détecté et remplacé."""
        texte = "Contacter le Dr. Dupont à jean.dupont@chu-paris.fr pour le suivi."
        texte_anon, mapping = await engine.anonymize(texte, SESSION_TEST + "_email")

        assert "jean.dupont@chu-paris.fr" not in texte_anon
        assert any(k.startswith("[EMAIL_") for k in mapping.keys())

    @pytest.mark.asyncio
    async def test_anonymisation_telephone(self, engine):
        """Un numéro de téléphone doit être détecté et remplacé."""
        texte = "Rappeler le patient au 06 12 34 56 78 avant 18h."
        texte_anon, mapping = await engine.anonymize(texte, SESSION_TEST + "_tel")

        assert "06 12 34 56 78" not in texte_anon
        assert any(k.startswith("[TELEPHONE_") for k in mapping.keys())

    @pytest.mark.asyncio
    async def test_texte_sans_phi_inchange(self, engine):
        """Un texte sans PHI ne doit pas être modifié."""
        texte = "Le patient présente une hypertension artérielle stade 2."
        texte_anon, mapping = await engine.anonymize(texte, SESSION_TEST + "_nophi")

        assert texte_anon == texte
        assert len(mapping) == 0

    @pytest.mark.asyncio
    async def test_token_deterministe(self, engine):
        """Le même texte dans la même session doit produire le même token."""
        texte = "NIR: 2 75 08 69 123 456 78"
        _, mapping1 = await engine.anonymize(texte, "session_det_1")
        _, mapping2 = await engine.anonymize(texte, "session_det_1")

        assert list(mapping1.keys()) == list(mapping2.keys())

    @pytest.mark.asyncio
    async def test_tokens_differents_par_session(self, engine):
        """Le même texte dans des sessions différentes doit produire des tokens différents."""
        texte = "NIR: 1 85 12 75 056 123 45"
        _, mapping1 = await engine.anonymize(texte, "session_A")
        _, mapping2 = await engine.anonymize(texte, "session_B")

        tokens1 = list(mapping1.keys())
        tokens2 = list(mapping2.keys())
        assert tokens1 != tokens2  # Isolation entre sessions


# ---------------------------------------------------------------------------
# Tests de réhydratation
# ---------------------------------------------------------------------------

class TestRehydratation:

    @pytest.mark.asyncio
    async def test_rehydratation_complete(self, engine):
        """La réhydratation doit restaurer le texte original."""
        texte_original = "Email du médecin : marie.martin@chu-lyon.fr"
        texte_anon, _ = await engine.anonymize(texte_original, "session_reh")
        texte_restaure = await engine.rehydrate(texte_anon, "session_reh")

        assert texte_restaure == texte_original

    @pytest.mark.asyncio
    async def test_rehydratation_session_inconnue(self, engine):
        """La réhydratation d'une session inconnue doit retourner le texte tel quel."""
        texte = "Texte avec [NIR_ABCD1234] token."
        texte_restaure = await engine.rehydrate(texte, "session_inconnue_xyz")

        assert texte_restaure == texte


# ---------------------------------------------------------------------------
# Tests de purge
# ---------------------------------------------------------------------------

class TestPurge:

    @pytest.mark.asyncio
    async def test_purge_session(self, engine):
        """Après purge, la réhydratation ne doit plus fonctionner."""
        texte = "NIR: 1 85 12 75 056 123 45"
        texte_anon, _ = await engine.anonymize(texte, "session_purge")

        await engine.purger_session("session_purge")

        texte_restaure = await engine.rehydrate(texte_anon, "session_purge")
        # Après purge, les tokens ne sont plus remplacés
        assert texte_restaure == texte_anon


# ---------------------------------------------------------------------------
# Tests de la mémoire de session
# ---------------------------------------------------------------------------

class TestMemoireSession:

    @pytest.mark.asyncio
    async def test_creation_et_recuperation_session(self):
        """Une session créée doit être récupérable."""
        from memoire_session import MemoireSession
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/orchestrator"))

        memoire = MemoireSession(chemin_db=":memory:")
        id_session = await memoire.creer_session("user_test", "Cardiologie")

        session = await memoire.obtenir_session(id_session)
        assert session is not None
        assert session.id_utilisateur == "user_test"
        assert session.service == "Cardiologie"
        await memoire.fermer()

    @pytest.mark.asyncio
    async def test_ajout_et_recherche_message(self):
        """Les messages doivent être indexés et recherchables via FTS5."""
        from memoire_session import MemoireSession
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../../src/orchestrator"))

        memoire = MemoireSession(chemin_db=":memory:")
        id_session = await memoire.creer_session("user_test")

        await memoire.ajouter_message(id_session, "user", "Synthèse cardiologique du patient")
        await memoire.ajouter_message(id_session, "assistant", "Voici la synthèse demandée")
        await memoire.ajouter_message(id_session, "user", "Bilan biologique complet")

        resultats = await memoire.rechercher(id_session, "cardiologique")
        assert len(resultats) >= 1
        assert "cardiologique" in resultats[0].contenu.lower()

        await memoire.fermer()
