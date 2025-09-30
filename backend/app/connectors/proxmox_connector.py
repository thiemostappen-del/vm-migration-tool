"""Proxmox VE connector"""
from proxmoxer import ProxmoxAPI
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class ProxmoxConnector:
    """Proxmox VE API connector"""
    
    def __init__(self, host: str, user: str, password: str, port: int = 8006, verify_ssl: bool = False):
        self.host = host
        self.user = user
        self.password = password
        self.port = port
        self.verify_ssl = verify_ssl
        self.proxmox = None
    
    def connect(self) -> bool:
        """Connect to Proxmox"""
        try:
            self.proxmox = ProxmoxAPI(
                self.host,
                user=self.user,
                password=self.password,
                port=self.port,
                verify_ssl=self.verify_ssl
            )
            # Test connection
            self.proxmox.version.get()
            logger.info(f"Connected to Proxmox: {self.host}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to Proxmox: {str(e)}")
            raise ConnectionError(f"Proxmox connection failed: {str(e)}")
    
    def list_nodes(self) -> List[str]:
        """List all Proxmox nodes"""
        if not self.proxmox:
            self.connect()
        
        nodes = self.proxmox.nodes.get()
        return [node['node'] for node in nodes]
    
    def list_storage(self, node: str) -> List[Dict[str, Any]]:
        """List storage on a node"""
        if not self.proxmox:
            self.connect()
        
        storage_list = self.proxmox.nodes(node).storage.get()
        return storage_list
    
    def get_next_vmid(self) -> int:
        """Get next available VM ID"""
        if not self.proxmox:
            self.connect()
        
        return self.proxmox.cluster.nextid.get()
    
    def create_vm(self, node: str, vmid: int, name: str, **kwargs) -> int:
        """Create a new VM"""
        if not self.proxmox:
            self.connect()
        
        config = {
            'vmid': vmid,
            'name': name,
            'ostype': kwargs.get('ostype', 'l26'),
            'cores': kwargs.get('cores', 2),
            'sockets': kwargs.get('sockets', 1),
            'memory': kwargs.get('memory', 2048),
            'agent': kwargs.get('agent', 1),
            'bios': kwargs.get('bios', 'seabios')
        }
        
        # Network config
        if 'net0' in kwargs:
            config['net0'] = kwargs['net0']
        else:
            bridge = kwargs.get('bridge', 'vmbr0')
            config['net0'] = f'virtio,bridge={bridge},firewall=1'
        
        try:
            self.proxmox.nodes(node).qemu.create(**config)
            logger.info(f"VM {vmid} created on node {node}")
            return vmid
        except Exception as e:
            logger.error(f"Failed to create VM: {str(e)}")
            raise
    
    def attach_disk(self, node: str, vmid: int, disk_path: str, interface: str = 'scsi0') -> bool:
        """Attach disk to VM"""
        if not self.proxmox:
            self.connect()
        
        try:
            self.proxmox.nodes(node).qemu(vmid).config.put(**{
                interface: disk_path
            })
            logger.info(f"Disk attached to VM {vmid}: {interface} -> {disk_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to attach disk: {str(e)}")
            raise
    
    def start_vm(self, node: str, vmid: int) -> bool:
        """Start VM"""
        if not self.proxmox:
            self.connect()
        
        try:
            self.proxmox.nodes(node).qemu(vmid).status.start.post()
            logger.info(f"VM {vmid} started")
            return True
        except Exception as e:
            logger.error(f"Failed to start VM: {str(e)}")
            raise
    
    def stop_vm(self, node: str, vmid: int) -> bool:
        """Stop VM"""
        if not self.proxmox:
            self.connect()
        
        try:
            self.proxmox.nodes(node).qemu(vmid).status.stop.post()
            logger.info(f"VM {vmid} stopped")
            return True
        except Exception as e:
            logger.error(f"Failed to stop VM: {str(e)}")
            raise
    
    def get_vm_status(self, node: str, vmid: int) -> Dict[str, Any]:
        """Get VM status"""
        if not self.proxmox:
            self.connect()
        
        return self.proxmox.nodes(node).qemu(vmid).status.current.get()
    
    def delete_vm(self, node: str, vmid: int) -> bool:
        """Delete VM"""
        if not self.proxmox:
            self.connect()
        
        try:
            self.proxmox.nodes(node).qemu(vmid).delete()
            logger.info(f"VM {vmid} deleted")
            return True
        except Exception as e:
            logger.error(f"Failed to delete VM: {str(e)}")
            raise
    
    def get_disk_path(self, node: str, storage: str, vmid: int, disk_name: str) -> str:
        """Get full disk path"""
        return f"{storage}:vm-{vmid}-{disk_name}"
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        pass
