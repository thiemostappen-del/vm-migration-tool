"""VMware vSphere connector"""
from pyVim import connect
from pyVmomi import vim
import ssl
from typing import List, Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class VMwareConnector:
    """VMware vSphere API connector"""
    
    def __init__(self, host: str, user: str, password: str, port: int = 443, verify_ssl: bool = False):
        self.host = host
        self.user = user
        self.password = password
        self.port = port
        self.verify_ssl = verify_ssl
        self.connection = None
    
    def connect(self) -> bool:
        """Connect to vCenter/ESXi"""
        try:
            context = None
            if not self.verify_ssl:
                context = ssl._create_unverified_context()
            
            self.connection = connect.SmartConnect(
                host=self.host,
                user=self.user,
                pwd=self.password,
                port=self.port,
                sslContext=context
            )
            logger.info(f"Connected to VMware: {self.host}")
            return True
        except Exception as e:
            logger.error(f"Failed to connect to VMware: {str(e)}")
            raise ConnectionError(f"VMware connection failed: {str(e)}")
    
    def disconnect(self):
        """Disconnect from vCenter/ESXi"""
        if self.connection:
            connect.Disconnect(self.connection)
            logger.info("Disconnected from VMware")
    
    def list_vms(self) -> List[Dict[str, Any]]:
        """List all VMs"""
        if not self.connection:
            self.connect()
        
        content = self.connection.RetrieveContent()
        container = content.viewManager.CreateContainerView(
            content.rootFolder, [vim.VirtualMachine], True
        )
        
        vms = []
        for vm in container.view:
            try:
                vm_info = self._get_vm_info(vm)
                vms.append(vm_info)
            except Exception as e:
                logger.warning(f"Failed to get info for VM {vm.name}: {str(e)}")
        
        container.Destroy()
        return vms
    
    def get_vm_by_name(self, name: str) -> Optional[vim.VirtualMachine]:
        """Get VM object by name"""
        if not self.connection:
            self.connect()
        
        content = self.connection.RetrieveContent()
        container = content.viewManager.CreateContainerView(
            content.rootFolder, [vim.VirtualMachine], True
        )
        
        for vm in container.view:
            if vm.name == name:
                container.Destroy()
                return vm
        
        container.Destroy()
        return None
    
    def _get_vm_info(self, vm: vim.VirtualMachine) -> Dict[str, Any]:
        """Extract VM information"""
        summary = vm.summary
        config = vm.config
        
        # Get disk info
        disks = []
        for device in config.hardware.device:
            if isinstance(device, vim.vm.device.VirtualDisk):
                disks.append({
                    'label': device.deviceInfo.label,
                    'size_gb': round(device.capacityInBytes / (1024**3), 2),
                    'type': type(device.backing).__name__,
                    'thin': getattr(device.backing, 'thinProvisioned', False)
                })
        
        # Get network info
        networks = []
        for device in config.hardware.device:
            if isinstance(device, vim.vm.device.VirtualEthernetCard):
                networks.append({
                    'label': device.deviceInfo.label,
                    'type': type(device).__name__,
                    'mac': getattr(device, 'macAddress', None),
                    'network': device.backing.deviceName if hasattr(device.backing, 'deviceName') else None
                })
        
        return {
            'id': vm._moId,
            'name': vm.name,
            'status': summary.runtime.powerState,
            'cpu_cores': config.hardware.numCPU,
            'memory_mb': config.hardware.memoryMB,
            'disk_size_gb': int(sum(d['size_gb'] for d in disks)),
            'disks': disks,
            'networks': networks,
            'guest_os': config.guestFullName,
            'uuid': config.uuid,
            'instance_uuid': config.instanceUuid
        }
    
    def power_off_vm(self, vm_name: str) -> bool:
        """Power off VM"""
        vm = self.get_vm_by_name(vm_name)
        if not vm:
            raise ValueError(f"VM not found: {vm_name}")
        
        if vm.runtime.powerState == vim.VirtualMachinePowerState.poweredOff:
            logger.info(f"VM {vm_name} already powered off")
            return True
        
        try:
            task = vm.PowerOffVM_Task()
            self._wait_for_task(task)
            logger.info(f"VM {vm_name} powered off")
            return True
        except Exception as e:
            logger.error(f"Failed to power off VM {vm_name}: {str(e)}")
            raise
    
    def create_snapshot(self, vm_name: str, snapshot_name: str) -> str:
        """Create VM snapshot"""
        vm = self.get_vm_by_name(vm_name)
        if not vm:
            raise ValueError(f"VM not found: {vm_name}")
        
        try:
            task = vm.CreateSnapshot_Task(
                name=snapshot_name,
                description="Migration backup snapshot",
                memory=False,
                quiesce=True
            )
            self._wait_for_task(task)
            logger.info(f"Snapshot created for {vm_name}: {snapshot_name}")
            return snapshot_name
        except Exception as e:
            logger.error(f"Failed to create snapshot: {str(e)}")
            raise
    
    def get_disk_path(self, vm_name: str, disk_index: int = 0) -> str:
        """Get disk file path"""
        vm = self.get_vm_by_name(vm_name)
        if not vm:
            raise ValueError(f"VM not found: {vm_name}")
        
        disk_count = 0
        for device in vm.config.hardware.device:
            if isinstance(device, vim.vm.device.VirtualDisk):
                if disk_count == disk_index:
                    return device.backing.fileName
                disk_count += 1
        
        raise ValueError(f"Disk {disk_index} not found for VM {vm_name}")
    
    def _wait_for_task(self, task):
        """Wait for vCenter task to complete"""
        while task.info.state not in [vim.TaskInfo.State.success, vim.TaskInfo.State.error]:
            pass
        
        if task.info.state == vim.TaskInfo.State.error:
            raise Exception(f"Task failed: {task.info.error.msg}")
    
    def __enter__(self):
        self.connect()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.disconnect()
