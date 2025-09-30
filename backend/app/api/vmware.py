"""VMware API endpoints"""
from fastapi import APIRouter, HTTPException, status
from typing import List

from app.connectors.vmware_connector import VMwareConnector
from app.schemas.migration import VMwareConnectionTest, VMInfo

router = APIRouter()


@router.post("/test-connection")
async def test_vmware_connection(connection: VMwareConnectionTest):
    """Test VMware connection"""
    try:
        with VMwareConnector(
            host=connection.host,
            user=connection.user,
            password=connection.password,
            port=connection.port,
            verify_ssl=connection.verify_ssl
        ) as connector:
            return {
                "success": True,
                "message": f"Successfully connected to {connection.host}"
            }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Connection failed: {str(e)}"
        )


@router.post("/list-vms", response_model=List[VMInfo])
async def list_vmware_vms(connection: VMwareConnectionTest):
    """List all VMs on VMware"""
    try:
        with VMwareConnector(
            host=connection.host,
            user=connection.user,
            password=connection.password,
            port=connection.port,
            verify_ssl=connection.verify_ssl
        ) as connector:
            vms = connector.list_vms()
            return vms
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list VMs: {str(e)}"
        )
