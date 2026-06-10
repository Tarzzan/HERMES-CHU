import React, { useState } from 'react';

export function ProvidersSettingsCHU() {
  const [activeProvider, setActiveProvider] = useState('azure_openai');
  const [apiKey, setApiKey] = useState('');
  const [endpoint, setEndpoint] = useState('');

  const handleSave = () => {
    // Appel IPC vers le backend Electron pour sauvegarder la config CHU
    window.postMessage({
      type: 'chu-save-config',
      payload: { provider: activeProvider, apiKey, endpoint }
    }, '*');
  };

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <h2 className="text-2xl font-bold mb-4 text-blue-800">Fournisseurs LLM (HERMES CHU)</h2>
      <p className="text-sm text-gray-600 mb-6">
        Sélectionnez le fournisseur d'intelligence artificielle. Les données de santé (PHI) 
        seront automatiquement anonymisées par le Privacy Engine avant envoi.
      </p>

      <div className="space-y-4">
        {/* Azure OpenAI (Recommandé POC) */}
        <div className={`p-4 border rounded-lg cursor-pointer ${activeProvider === 'azure_openai' ? 'border-blue-500 bg-blue-50' : 'border-gray-200'}`}
             onClick={() => setActiveProvider('azure_openai')}>
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-lg">Azure OpenAI (Recommandé POC)</h3>
            {activeProvider === 'azure_openai' && <span className="text-blue-600">✓ Actif</span>}
          </div>
          <p className="text-sm text-gray-500 mt-1">Hébergement certifié HDS (données anonymisées)</p>
          
          {activeProvider === 'azure_openai' && (
            <div className="mt-4 space-y-3">
              <div>
                <label className="block text-sm font-medium mb-1">Point de terminaison (Endpoint)</label>
                <input type="text" className="w-full p-2 border rounded" placeholder="https://votre-ressource.openai.azure.com/" 
                       value={endpoint} onChange={e => setEndpoint(e.target.value)} />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Clé API</label>
                <input type="password" className="w-full p-2 border rounded" placeholder="sk-..." 
                       value={apiKey} onChange={e => setApiKey(e.target.value)} />
              </div>
            </div>
          )}
        </div>

        {/* vLLM On-Premise (Production) */}
        <div className={`p-4 border rounded-lg cursor-pointer ${activeProvider === 'vllm' ? 'border-blue-500 bg-blue-50' : 'border-gray-200'}`}
             onClick={() => setActiveProvider('vllm')}>
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-lg">vLLM On-Premise (Production)</h3>
            {activeProvider === 'vllm' && <span className="text-blue-600">✓ Actif</span>}
          </div>
          <p className="text-sm text-gray-500 mt-1">Hébergement 100% souverain sur infrastructure CHU</p>
          
          {activeProvider === 'vllm' && (
            <div className="mt-4 space-y-3">
              <div>
                <label className="block text-sm font-medium mb-1">URL du serveur vLLM</label>
                <input type="text" className="w-full p-2 border rounded" placeholder="http://vllm-service:8000/v1" />
              </div>
            </div>
          )}
        </div>

        {/* Ollama Local */}
        <div className={`p-4 border rounded-lg cursor-pointer ${activeProvider === 'ollama' ? 'border-blue-500 bg-blue-50' : 'border-gray-200'}`}
             onClick={() => setActiveProvider('ollama')}>
          <div className="flex items-center justify-between">
            <h3 className="font-semibold text-lg">Ollama (Local)</h3>
            {activeProvider === 'ollama' && <span className="text-blue-600">✓ Actif</span>}
          </div>
          <p className="text-sm text-gray-500 mt-1">Exécution locale sur le poste de travail (GPU requis)</p>
        </div>
      </div>

      <div className="mt-8 flex justify-end">
        <button onClick={handleSave} className="bg-blue-600 text-white px-6 py-2 rounded font-medium hover:bg-blue-700 transition">
          Enregistrer la configuration
        </button>
      </div>
    </div>
  );
}
