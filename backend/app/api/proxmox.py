"""Proxmox API endpoints"""
from fastapi import APIRouter, HTTPException, status
from typing import List, Dict, Any

from app.connectors.proxmox_connector import ProxmoxConnector
from app.schemas.migration import ProxmoxConnectionTest

router = APIRouter()


@router.post("/test-connection")
async def test_proxmox_connection(connection: ProxmoxConnectionTest):
    """Test Proxmox connection"""
    try:
        with ProxmoxConnector(
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


@router.post("/list-nodes", response_model=List[str])
async def list_proxmox_nodes(connection: ProxmoxConnectionTest):
    """List all Proxmox nodes"""
    try:
        with ProxmoxConnector(
            host=connection.host,
            user=connection.user,
            password=connection.password,
            port=connection.port,
            verify_ssl=connection.verify_ssl
        ) as connector:
            nodes = connector.list_nodes()
            return nodes
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list nodes: {str(e)}"
        )


@router.post("/list-storage")
async def list_proxmox_storage(
    connection: ProxmoxConnectionTest,
    node: str
) -> List[Dict[str, Any]]:
    """List storage on a Proxmox node"""
    try:
        with ProxmoxConnector(
            host=connection.host,
            user=connection.user,
            password=connection.password,
            port=connection.port,
            verify_ssl=connection.verify_ssl
        ) as connector:
            storage = connector.list_storage(node)
            return storage
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list storage: {str(e)}"
        )
