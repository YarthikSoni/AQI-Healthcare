from sqlalchemy.dialects import mysql
from sqlalchemy.schema import CreateTable

from app.core.database import Base
from app.models.models import ExposureLog, Profile


def test_model_tables_compile_for_mysql():
    for model in (Profile, ExposureLog):
        ddl = str(CreateTable(model.__table__).compile(dialect=mysql.dialect()))
        assert "VARCHAR" in ddl
