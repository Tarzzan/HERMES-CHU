import { useLayoutEffect } from "react";
import { ExternalLink } from "lucide-react";
import { useI18n } from "@/i18n";
import { usePageHeader } from "@/contexts/usePageHeader";
import { cn } from "@/lib/utils";
import { PluginSlot } from "@/plugins";

export const PULSAR_DOCS_URL = "https://github.com/Tarzzan/PULSAR-CHU/wiki";

const DS_BUTTON_OUTLINED_LINK_CN = cn(
  "group relative inline-grid grid-cols-[auto_1fr_auto] items-center",
  "px-[.9em_.75em] py-[1.25em] gap-2",
  "leading-0 font-bold tracking-[0.2em] uppercase",
  "text-midground bg-transparent shadow-midground",
  "shadow-[inset_-1px_-1px_0_0_#00000080,inset_1px_1px_0_0_#ffffff80]",
);

export default function DocsPage() {
  const { t } = useI18n();
  const { setEnd } = usePageHeader();

  useLayoutEffect(() => {
    setEnd(
      <a
        href={PULSAR_DOCS_URL}
        target="_blank"
        rel="noopener noreferrer"
        className={DS_BUTTON_OUTLINED_LINK_CN}
      >
        <ExternalLink className="size-3.5" />
        {t.app.openDocumentation}
      </a>,
    );
    return () => { setEnd(null); };
  }, [setEnd, t]);

  return (
    <div className={cn("flex min-h-0 w-full min-w-0 flex-1 flex-col items-center justify-center", "pt-1 sm:pt-2 px-6")}>
      <PluginSlot name="docs:top" />
      <div className={cn(
        "w-full max-w-3xl rounded-lg border border-current/20 p-8",
        "bg-background/60 backdrop-blur-sm flex flex-col gap-6",
      )}>

        {/* En-tete PULSAR */}
        <div className="flex flex-col gap-2">
          <h1 className="text-3xl font-bold tracking-tight text-midground uppercase">PULSAR</h1>
          <p className="text-sm text-text-tertiary tracking-widest uppercase">
            Plateforme Unifiee de Liaison, de Surveillance et d&apos;Assistance en temps Reel
          </p>
          <p className="text-xs text-text-tertiary">
            DSIO &mdash; CHU de Guyane &nbsp;&bull;&nbsp; v2.3.0
          </p>
        </div>

        {/* Description */}
        <p className="text-sm text-text-secondary leading-relaxed">
          PULSAR est le systeme agentique medical du DSIO du CHU de Guyane.
          Il integre un moteur d&apos;IA avance, un Privacy Engine RGPD, six agents
          specialises et un deploiement multi-postes securise.
        </p>

        {/* Liens rapides */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            { href: PULSAR_DOCS_URL, label: "Documentation en ligne" },
            { href: "https://github.com/Tarzzan/PULSAR-CHU", label: "Depot GitHub PULSAR" },
            { href: "https://www.chu-guyane.fr", label: "CHU de Guyane" },
            { href: "mailto:dsio@chu-guyane.fr", label: "Support DSIO" },
          ].map(({ href, label }) => (
            <a key={label} href={href} target="_blank" rel="noopener noreferrer"
              className="flex items-center gap-2 rounded border border-current/20 px-4 py-3 text-sm hover:bg-current/5 transition-colors">
              <ExternalLink className="size-4 shrink-0" />
              <span>{label}</span>
            </a>
          ))}
        </div>

        {/* Agents CHU */}
        <div className="flex flex-col gap-2">
          <h2 className="text-xs font-bold tracking-widest uppercase text-text-tertiary">Agents specialises</h2>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-xs">
            {["Clinique", "Administratif", "Logistique", "Recherche", "Qualite", "Formation"].map((agent) => (
              <span key={agent} className="rounded border border-current/15 px-3 py-1.5 text-center text-text-secondary">
                {agent}
              </span>
            ))}
          </div>
        </div>

        {/* Footer */}
        <p className="text-xs text-text-tertiary border-t border-current/10 pt-4">
          Developpe par William MERI &mdash; DSIO, CHU de Guyane &nbsp;&bull;&nbsp;
          Souverainete numerique &amp; conformite RGPD
        </p>
      </div>
      <PluginSlot name="docs:bottom" />
    </div>
  );
}
