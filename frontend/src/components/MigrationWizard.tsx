import React, { useState } from 'react';
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

interface VM {
  id: string;
  name: string;
  status: string;
  cpu_cores: number;
  memory_mb: number;
  disk_size_gb: number;
}

const MigrationWizard: React.FC = () => {
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [vmError, setVmError] = useState<string | null>(null);
  
  // Form state
  const [formData, setFormData] = useState({
    name: '',
    sourceHost: '',
    sourceUser: '',
    sourcePassword: '',
    targetHost: '',
    targetUser: '',
    targetPassword: '',
    targetNode: '',
    targetStorage: '',
    selectedVMs: [] as string[],
  });

  const [availableVMs, setAvailableVMs] = useState<VM[]>([]);

  const handleNext = async () => {
    if (step === 1) {
      // Test VMware connection and load VMs
      const success = await loadVMs();
      if (!success) {
        return;
      }
    }
    setStep(step + 1);
  };

  const handleBack = () => {
    setStep(step - 1);
  };

  const loadVMs = async (): Promise<boolean> => {
    setLoading(true);
    setVmError(null);
    try {
      const response = await axios.post(`${API_URL}/api/vmware/list-vms`, {
        host: formData.sourceHost,
        user: formData.sourceUser,
        password: formData.sourcePassword,
      });
      setAvailableVMs(response.data);
      return true;
    } catch (error) {
      console.error('Failed to load VMs:', error);
      setVmError('Fehler beim Laden der VMs. Bitte Zugangsdaten prüfen.');
      return false;
    } finally {
      setLoading(false);
    }
  };

  const renderVmError = () =>
    vmError ? <div className="error-message">{vmError}</div> : null;

  const toggleVM = (vmName: string) => {
    setFormData({
      ...formData,
      selectedVMs: formData.selectedVMs.includes(vmName)
        ? formData.selectedVMs.filter((v) => v !== vmName)
        : [...formData.selectedVMs, vmName],
    });
  };

  const handleSubmit = async () => {
    setLoading(true);
    try {
      await axios.post(`${API_URL}/api/migrations/`, {
        name: formData.name || 'Migration ' + new Date().toISOString(),
        source_host: formData.sourceHost,
        source_user: formData.sourceUser,
        source_password: formData.sourcePassword,
        source_vms: formData.selectedVMs,
        target_host: formData.targetHost,
        target_user: formData.targetUser,
        target_password: formData.targetPassword,
        target_node: formData.targetNode,
        target_storage: formData.targetStorage,
        schedule_type: 'immediate',
        validate_transfer: true,
      });
      alert('Migration gestartet!');
      window.location.reload();
    } catch (error) {
      console.error('Failed to start migration:', error);
      alert('Fehler beim Starten der Migration');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="wizard-container">
      <div className="wizard-steps">
        {[1, 2, 3, 4].map((s) => (
          <div key={s} className={`wizard-step ${s === step ? 'active' : s < step ? 'completed' : ''}`}>
            <div className="step-circle">{s < step ? '✓' : s}</div>
            <div className="step-label">
              {s === 1 && 'Quelle'}
              {s === 2 && 'VM-Auswahl'}
              {s === 3 && 'Ziel'}
              {s === 4 && 'Bestätigung'}
            </div>
          </div>
        ))}
      </div>

      {step === 1 && (
        <div className="form-section">
          <h2>VMware-Verbindung</h2>
          <div className="form-group">
            <label>Host/vCenter</label>
            <input
              type="text"
              value={formData.sourceHost}
              onChange={(e) => setFormData({ ...formData, sourceHost: e.target.value })}
              placeholder="vcenter.company.local"
            />
          </div>
          <div className="form-group">
            <label>Benutzername</label>
            <input
              type="text"
              value={formData.sourceUser}
              onChange={(e) => setFormData({ ...formData, sourceUser: e.target.value })}
              placeholder="administrator@vsphere.local"
            />
          </div>
          <div className="form-group">
            <label>Passwort</label>
            <input
              type="password"
              value={formData.sourcePassword}
              onChange={(e) => setFormData({ ...formData, sourcePassword: e.target.value })}
            />
          </div>
          {renderVmError()}
        </div>
      )}

      {step === 2 && (
        <div className="form-section">
          <h2>VMs auswählen</h2>
          {renderVmError()}
          {loading ? (
            <div>Lade VMs...</div>
          ) : (
            <div className="vm-list">
              {availableVMs.map((vm) => (
                <div key={vm.id} className="vm-item" onClick={() => toggleVM(vm.name)}>
                  <input
                    type="checkbox"
                    checked={formData.selectedVMs.includes(vm.name)}
                    onChange={() => {}}
                  />
                  <div className="vm-info">
                    <span className="vm-name">{vm.name}</span>
                    <span className="vm-stat">{vm.cpu_cores} vCPU</span>
                    <span className="vm-stat">{Math.round(vm.memory_mb / 1024)} GB RAM</span>
                    <span className="vm-stat">{vm.disk_size_gb} GB</span>
                    <span className={`vm-status ${vm.status.toLowerCase()}`}>{vm.status}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
          <div style={{ marginTop: '1rem' }}>
            <strong>Ausgewählt:</strong> {formData.selectedVMs.length} VMs
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="form-section">
          <h2>Proxmox-Ziel</h2>
          <div className="form-group">
            <label>Proxmox Host</label>
            <input
              type="text"
              value={formData.targetHost}
              onChange={(e) => setFormData({ ...formData, targetHost: e.target.value })}
              placeholder="proxmox.company.local"
            />
          </div>
          <div className="form-group">
            <label>Benutzername</label>
            <input
              type="text"
              value={formData.targetUser}
              onChange={(e) => setFormData({ ...formData, targetUser: e.target.value })}
              placeholder="root@pam"
            />
          </div>
          <div className="form-group">
            <label>Passwort</label>
            <input
              type="password"
              value={formData.targetPassword}
              onChange={(e) => setFormData({ ...formData, targetPassword: e.target.value })}
            />
          </div>
          <div className="form-group">
            <label>Node</label>
            <input
              type="text"
              value={formData.targetNode}
              onChange={(e) => setFormData({ ...formData, targetNode: e.target.value })}
              placeholder="pve-node01"
            />
          </div>
          <div className="form-group">
            <label>Storage</label>
            <input
              type="text"
              value={formData.targetStorage}
              onChange={(e) => setFormData({ ...formData, targetStorage: e.target.value })}
              placeholder="local-lvm"
            />
          </div>
        </div>
      )}

      {step === 4 && (
        <div className="form-section">
          <h2>Bestätigung</h2>
          <div style={{ background: '#f8f9fa', padding: '1.5rem', borderRadius: '8px' }}>
            <p><strong>Quelle:</strong> {formData.sourceHost}</p>
            <p><strong>Ziel:</strong> {formData.targetHost} ({formData.targetNode})</p>
            <p><strong>VMs:</strong> {formData.selectedVMs.join(', ')}</p>
            <p><strong>Anzahl:</strong> {formData.selectedVMs.length} VMs</p>
          </div>
        </div>
      )}

      <div className="wizard-actions">
        {step > 1 && (
          <button className="btn btn-secondary" onClick={handleBack} disabled={loading}>
            ← Zurück
          </button>
        )}
        {step < 4 ? (
          <button className="btn btn-primary" onClick={handleNext} disabled={loading}>
            Weiter →
          </button>
        ) : (
          <button className="btn btn-primary" onClick={handleSubmit} disabled={loading}>
            🚀 Migration starten
          </button>
        )}
      </div>
    </div>
  );
};

export default MigrationWizard;
