import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base, get_db
from app.main import app

# StaticPool keeps ONE connection alive for the whole run. Without it, every new
# connection to "sqlite://" gets its own empty :memory: database and the tables
# created below would be invisible to the next query.
engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


# FastAPI's dependency injection: every route asking for get_db now receives the
# SQLite session instead of the postgres one. This is the "mock the database" part.
app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

VALID_JOB = {
    "title": "Platform Engineer",
    "description": "Own the CI/CD pipeline and the container platform.",
    "company": "TestCo",
    "location": "Remote",
}


@pytest.fixture(autouse=True)
def fresh_schema():
    """Each test starts with an empty database and leaves nothing behind."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


def test_health_returns_healthy():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_create_job_returns_201():
    payload = {"title": "Python Developer", "description": "My Own CI/CD pipeline I create", "company": "POWER", "location": "Remote"}
    response = client.post("/jobs/", json=payload)
    assert response.status_code == 201
    assert response.json()["title"] == "Python Developer"


def test_missing_fields_returns():
    incomplete_payload = {"title": "Python Developer1"}
    response = client.post("/jobs/", json=incomplete_payload)
    assert response.status_code == 422
    errors = response.json()["detail"]
    missing_fields = [err["loc"][-1] for err in errors]
    assert "company" in missing_fields
    assert "location" in missing_fields
    assert "description" in missing_fields


def test_with_non_existent_id_returns():
    non_existent_id = "2"
    response = client.get(f"/jobs/{non_existent_id}")
    assert response.status_code == 404
    assert response.json()["detail"] == f"Job '{non_existent_id}' not found"
