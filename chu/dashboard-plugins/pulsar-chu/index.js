/*
 * Plugin web "PULSAR CHU" — preuve de concept.
 * ---------------------------------------------------------------------------
 * Onglet de dashboard DROP-IN : aucune modification du moteur, aucun build npm.
 * Le moteur expose React + ses composants sur window.__HERMES_PLUGIN_SDK__ ;
 * on s'auto-enregistre via window.__HERMES_PLUGINS__.register().
 *
 * Affiche en direct le statut du Privacy Engine RGPD et les metriques
 * d'anonymisation / d'audit ISO 27001 (API CHU, port 8001).
 */
(function () {
  var SDK = window.__HERMES_PLUGIN_SDK__;
  var REG = window.__HERMES_PLUGINS__;
  if (!SDK || !REG) { return; }

  var R = SDK.React;
  var h = R.createElement;
  var C = SDK.components || {};
  var hooks = SDK.hooks || {};
  var Card = C.Card || "div";
  var CardContent = C.CardContent || "div";
  var Badge = C.Badge || "span";

  var CHU_API = "http://127.0.0.1:8001";

  function Metric(props) {
    return h("div", {
      style: {
        padding: "14px 18px", border: "1px solid rgba(128,128,128,.25)",
        borderRadius: 10, minWidth: 150, background: "rgba(128,128,128,.06)"
      }
    },
      h("div", { style: { fontSize: 26, fontWeight: 700, lineHeight: 1.1 } }, String(props.value)),
      h("div", { style: { fontSize: 12, opacity: 0.7, marginTop: 4 } }, props.label));
  }

  function PulsarChu() {
    var st = hooks.useState({ loading: true, data: null, error: null });
    var state = st[0], setState = st[1];

    hooks.useEffect(function () {
      var alive = true;
      fetch(CHU_API + "/api/chu/insights")
        .then(function (r) { if (!r.ok) throw new Error("HTTP " + r.status); return r.json(); })
        .then(function (d) { if (alive) setState({ loading: false, data: d, error: null }); })
        .catch(function (e) { if (alive) setState({ loading: false, data: null, error: String((e && e.message) || e) }); });
      return function () { alive = false; };
    }, []);

    var header = h("div", { style: { marginBottom: 18 } },
      h("h2", { style: { margin: 0, fontSize: 20, fontWeight: 700 } }, "PULSAR CHU — Privacy Engine RGPD"),
      h("p", { style: { margin: "6px 0 0", opacity: 0.7, fontSize: 13 } },
        "Anonymisation PHI + audit ISO 27001. Onglet web drop-in — aucune modification du moteur."));

    var body;
    if (state.loading) {
      body = h("p", { style: { opacity: 0.6 } }, "Chargement des métriques CHU…");
    } else if (state.error) {
      body = h(Card, null, h(CardContent, { style: { padding: 18 } },
        h("p", { style: { color: "#e0a800", margin: 0, fontWeight: 600 } },
          "API CHU (port 8001) injoignable : " + state.error),
        h("p", { style: { fontSize: 12, opacity: 0.7, marginTop: 8 } },
          "Démarrez-la : python -m uvicorn chu.api.serveur_chu:app --port 8001  (CORS du dashboard requis).")));
    } else {
      var d = state.data || {};
      var m = d.metriques || {};
      var a = d.anonymisation || {};
      var alertes = d.alertes || [];
      body = h("div", null,
        h("div", { style: { marginBottom: 14 } },
          h(Badge, null, m.privacy_engine_actif ? "🔒 Privacy Engine ACTIF" : "🔓 INACTIF")),
        h("div", { style: { display: "flex", gap: 12, flexWrap: "wrap" } },
          h(Metric, { value: a.total_anonymisations || 0, label: "Anonymisations" }),
          h(Metric, { value: a.total_entites_phi_detectees || 0, label: "PHI détectées" }),
          h(Metric, { value: m.audit_entrees_total || 0, label: "Événements audit ISO" }),
          h(Metric, { value: m.sessions_glass_break_actives || 0, label: "Glass-break actifs" })),
        alertes.length
          ? h("div", { style: { marginTop: 16 } },
              h("div", { style: { fontWeight: 600, marginBottom: 6 } }, "Alertes qualité"),
              h("ul", { style: { margin: 0, paddingLeft: 18, fontSize: 13 } },
                alertes.map(function (al, i) { return h("li", { key: i, style: { color: "#e0a800" } }, al); })))
          : h("p", { style: { marginTop: 16, fontSize: 13, opacity: 0.6 } }, "Aucune alerte — conformité OK."));
    }

    return h("div", { style: { padding: 24, maxWidth: 920 } }, header, body);
  }

  REG.register("pulsar-chu", PulsarChu);
})();
