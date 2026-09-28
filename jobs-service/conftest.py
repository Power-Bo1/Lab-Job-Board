import os
# main.py calls create_all() at import time, so the app must be pointed at a
# throwaway SQLite database *before* it is imported. No server required.
os.environ.setdefault("DATABASE_URL", "sqlite://")