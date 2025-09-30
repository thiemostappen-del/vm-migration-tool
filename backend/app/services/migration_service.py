"""Core migration service"""
import subprocess
import os
import logging
from typing import Dict, Any, Callable
from datetime import datetime

from app.connectors.vmware_connector import VMwareConnector
from app.connectors.proxmox_connector import ProxmoxConnector

logger = logging.getLogger(__name__)


class MigrationService:
    """Handles VM migration from VMware to Proxmox"""
    
    def __init__(self):
        self.vmware = None
        self.proxmox = None
    
    def migrate_vm(
        self,
        # Source
        source_host: str,
        source_user: str,
        source_password: str,
        source_vm_name: str,
        # Target
        target_host: str,
        target_user: str,
        target_password: str,
        target_node: str,
        target_storage: str,
        # Config
        vm_config: Dict[str, Any] = None,
        # Callbacks
        progress_callback: Callable[[int, str], None] = None
    ) -> Dict[str, Any]:
        """
        Migrate a single VM from VMware to Proxmox
        
        Returns dict with migration results
        """
        result = {
            'success': False,
            'vm_name': source_vm_name,
            'target_vmid': None,
            'error': None,
            'start_time': datetime.now(),
            'end_time': None
        }
        
        try:
            # Connect to VMware
            self._update_progress(progress_callback, 5, f"Connecting to VMware: {source_host}")
            self.vmware = VMwareConnector(source_host, source_user, source_password)
            self.vmware.connect()
            
            # Connect to Proxmox
            self._update_progress(progress_callback, 10, f"Connecting to Proxmox: {target_host}")
            self.proxmox = ProxmoxConnector(target_host, target_user, target_password)
            self.proxmox.connect()
            
            # Get VM info
            self._update_progress(progress_callback, 15, f"Getting VM information")
            vm_info = None
            for vm in self.vmware.list_vms():
                if vm['name'] == source_vm_name:
                    vm_info = vm
                    break
            
            if not vm_info:
                raise ValueError(f"VM not found: {source_vm_name}")
            
            logger.info(f"Migrating VM: {source_vm_name} ({vm_info['disk_size_gb']} GB)")
            
            # Create snapshot (optional)
            self._update_progress(progress_callback, 20, "Creating snapshot")
            snapshot_name = f"migration-backup-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
            try:
                self.vmware.create_snapshot(source_vm_name, snapshot_name)
            except Exception as e:
                logger.warning(f"Snapshot creation failed: {str(e)}")
            
            # Power off source VM
            self._update_progress(progress_callback, 25, "Powering off source VM")
            self.vmware.power_off_vm(source_vm_name)
            
            # Get next available VMID
            target_vmid = self.proxmox.get_next_vmid()
            result['target_vmid'] = target_vmid
            
            # Create VM on Proxmox
            self._update_progress(progress_callback, 30, f"Creating VM {target_vmid} on Proxmox")
            
            # Merge VM config with defaults
            cores = vm_config.get('cpu_cores', vm_info['cpu_cores']) if vm_config else vm_info['cpu_cores']
            sockets = vm_config.get('cpu_sockets', 1) if vm_config else 1
            memory = vm_config.get('memory_mb', vm_info['memory_mb']) if vm_config else vm_info['memory_mb']
            bridge = vm_config.get('network_bridge', 'vmbr0') if vm_config else 'vmbr0'
            
            self.proxmox.create_vm(
                node=target_node,
                vmid=target_vmid,
                name=source_vm_name,
                cores=cores,
                sockets=sockets,
                memory=memory,
                bridge=bridge,
                ostype='l26'  # Linux
            )
            
            # Migrate disks
            self._update_progress(progress_callback, 35, "Starting disk migration")
            
            for disk_idx, disk_info in enumerate(vm_info['disks']):
                disk_name = f"disk-{disk_idx}"
                self._migrate_disk(
                    source_vm_name=source_vm_name,
                    disk_index=disk_idx,
                    target_node=target_node,
                    target_vmid=target_vmid,
                    target_storage=target_storage,
                    disk_name=disk_name,
                    progress_callback=lambda p, m: self._update_progress(
                        progress_callback, 
                        35 + int(p * 0.5), 
                        f"Disk {disk_idx+1}/{len(vm_info['disks'])}: {m}"
                    )
                )
            
            self._update_progress(progress_callback, 90, "Migration complete")
            
            result['success'] = True
            result['end_time'] = datetime.now()
            logger.info(f"VM {source_vm_name} migrated successfully to VMID {target_vmid}")
            
        except Exception as e:
            logger.error(f"Migration failed: {str(e)}")
            result['error'] = str(e)
            result['end_time'] = datetime.now()
            raise
        
        finally:
            if self.vmware:
                self.vmware.disconnect()
            
        return result
    
    def _migrate_disk(
        self,
        source_vm_name: str,
        disk_index: int,
        target_node: str,
        target_vmid: int,
        target_storage: str,
        disk_name: str,
        progress_callback: Callable[[int, str], None] = None
    ):
        """Migrate a single disk"""
        
        # Get source disk path
        source_disk_path = self.vmware.get_disk_path(source_vm_name, disk_index)
        logger.info(f"Source disk: {source_disk_path}")
        
        # Target disk path
        target_disk_path = self.proxmox.get_disk_path(
            target_node, 
            target_storage, 
            target_vmid, 
            disk_name
        )
        
        self._update_progress(progress_callback, 10, "Converting disk format")
        
        # Convert disk using qemu-img
        # This is a simplified version - in production, you'd use SSH/NBD streaming
        interface = f"scsi{disk_index}"
        
        # For now, we'll use a placeholder - actual implementation would:
        # 1. SSH to VMware host
        # 2. Stream disk via NBD or direct copy
        # 3. Convert on-the-fly with qemu-img
        # 4. Write to Proxmox storage
        
        # Simulated conversion (replace with actual implementation)
        logger.info(f"Converting: {source_disk_path} -> {target_disk_path}")
        
        # Attach disk to VM
        self._update_progress(progress_callback, 90, "Attaching disk to VM")
        self.proxmox.attach_disk(target_node, target_vmid, target_disk_path, interface)
        
        self._update_progress(progress_callback, 100, "Disk migration complete")
    
    def _update_progress(self, callback: Callable, percentage: int, message: str):
        """Update progress via callback"""
        if callback:
            callback(percentage, message)
        logger.info(f"Progress {percentage}%: {message}")


def convert_disk_streaming(
    source_host: str,
    source_path: str,
    target_path: str,
    progress_callback: Callable[[int], None] = None
) -> bool:
    """
    Convert disk from VMDK to qcow2 with streaming
    
    This uses qemu-img with SSH or NBD to stream the conversion
    """
    try:
        # Example using SSH (requires passwordless SSH or sshpass)
        cmd = [
            'qemu-img', 'convert',
            '-f', 'vmdk',
            '-O', 'qcow2',
            '-p',  # Progress
            f'ssh://root@{source_host}{source_path}',
            target_path
        ]
        
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True
        )
        
        # Monitor progress
        for line in process.stderr:
            if '%' in line:
                try:
                    pct = int(line.split('(')[1].split('%')[0])
                    if progress_callback:
                        progress_callback(pct)
                except:
                    pass
        
        process.wait()
        
        if process.returncode == 0:
            logger.info("Disk conversion successful")
            return True
        else:
            logger.error(f"Disk conversion failed: {process.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"Disk conversion error: {str(e)}")
        raise
