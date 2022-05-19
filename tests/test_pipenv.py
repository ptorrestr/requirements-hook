from pathlib import Path
from requirements_hook.pipenv import PipenvLock


def test_pipenv():
    lock_file = Path("tests/pipenv/Pipfile.lock")
    pl = PipenvLock(lock_file=lock_file)
    content = pl.get_dependencies(["default", "develop"])
    assert len(content) > 100
