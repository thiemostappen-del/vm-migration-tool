import { useState } from 'react';
import './App.css';
import Dashboard from './components/Dashboard';
import MigrationWizard from './components/MigrationWizard';

type Tab = 'dashboard' | 'migrate' | 'scheduled' | 'history';

function App() {
  const [activeTab, setActiveTab] = useState<Tab>('dashboard');

  return (
    <div className="app">
      <header className="header">
        <h1>🔄 VMware → Proxmox Migration Tool</h1>
        <div className="subtitle">Intelligente VM-Migration mit Validierung</div>
      </header>

      <nav className="nav-tabs">
        <button 
          className={`nav-tab ${activeTab === 'dashboard' ? 'active' : ''}`}
          onClick={() => setActiveTab('dashboard')}
        >
          📊 Dashboard
        </button>
        <button 
          className={`nav-tab ${activeTab === 'migrate' ? 'active' : ''}`}
          onClick={() => setActiveTab('migrate')}
        >
          🖥️ Neue Migration
        </button>
        <button 
          className={`nav-tab ${activeTab === 'scheduled' ? 'active' : ''}`}
          onClick={() => setActiveTab('scheduled')}
        >
          ⏰ Geplant
        </button>
        <button 
          className={`nav-tab ${activeTab === 'history' ? 'active' : ''}`}
          onClick={() => setActiveTab('history')}
        >
          📋 Verlauf
        </button>
      </nav>

      <div className="container">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'migrate' && <MigrationWizard />}
        {activeTab === 'scheduled' && <div>Geplante Migrationen</div>}
        {activeTab === 'history' && <div>Migrations-Verlauf</div>}
      </div>
    </div>
  );
}

export default App;
