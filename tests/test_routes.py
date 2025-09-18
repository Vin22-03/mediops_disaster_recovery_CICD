import os
import sys
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__) + "/.."))
import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_landing_page(client):
    """Landing page should return 200 OK"""
    response = client.get('/')
    assert response.status_code == 200
    assert b"MediOps" in response.data

def test_dashboard_page(client):
    """Dashboard page should return 200 OK"""
    response = client.get('/dashboard')
    assert response.status_code == 200
