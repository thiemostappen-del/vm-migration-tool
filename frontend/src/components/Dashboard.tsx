import React, { useEffect, useState } from 'react';
import axios from 'axios';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

interface Job {
  id: number;
  name: string;
  status: string;
  progress_percentage: number;
  current_vm: string | null;
  completed_vms: number;
  total_vms: number;
  transfer_speed_mbps: number;
}

interface Stats {
  completed: number;
  running: number;
  scheduled: number;
}

const Dashboard: React.FC = () => {
  const [activeJobs, setActiveJobs] = useState<Job[]>([]);
  const [stats, setStats] = useState<Stats>({ completed: 0, running: 0, scheduled: 0 });

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000); // Refresh every 5s
    return () => clearInterval(interval);
  }, []);

  const fetchData = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/migrations/`);
      const jobs = response.data;

      // Filter active jobs
      const active = jobs.filter((j: Job) => j.status === 'running');
      setActiveJobs(active);

      // Calculate stats
      const stats = {
        completed: jobs.filter((j: Job) => j.status === 'completed').length,
        running: active.length,
        scheduled: jobs.filter((j: Job) => j.status === 'queued').length,
      };
      setStats(stats);
    } catch (error) {
      console.error('Failed to fetch jobs:', error);
    }
  };

  return (
    <div className="dashboard">
      <div className="stats-row">
        <div className="stat-card">
          <div className="number">{stats.completed}</div>
          <div className="label">Erfolgreich migriert</div>
        </div>
        <div className="stat-card">
          <div className="number">{stats.running}</div>
          <div className="label">Aktuell laufend</div>
        </div>
        <div className="stat-card">
          <div className="number">{stats.scheduled}</div>
          <div className="label">Geplant</div>
        </div>
      </div>

      <h2 style={{ marginBottom: '1rem' }}>Aktive Migrationen</h2>

      {activeJobs.length === 0 ? (
        <div style={{ padding: '2rem', textAlign: 'center', color: '#666' }}>
          Keine aktiven Migrationen
        </div>
      ) : (
        activeJobs.map((job) => (
          <div key={job.id} className="progress-card">
            <div className="progress-header">
              <div className="progress-title">{job.name}</div>
              <div className="progress-percentage">{job.progress_percentage}%</div>
            </div>
            <div className="progress-bar-container">
              <div
                className="progress-bar"
                style={{ width: `${job.progress_percentage}%` }}
              ></div>
            </div>
            <div className="progress-details">
              Status: {job.current_vm || 'Initialisierung'} | 
              {job.completed_vms}/{job.total_vms} VMs | 
              {job.transfer_speed_mbps} MB/s
            </div>
          </div>
        ))
      )}
    </div>
  );
};

export default Dashboard;
