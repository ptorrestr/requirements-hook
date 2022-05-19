import abc
import tempfile
import difflib
from pathlib import Path
from typing import List

class RequirementsABC(abc.ABC):
    def __init__(self, lock_file: Path, requirements_file:Path, types:List[str]):
        self.lock_file = lock_file
        self.requirements_file = requirements_file
        self.types = types
        self.requirements_file_needs_update = False
        self.requirements_dev_file_needs_update = False

    def generate_requirements(self):
        content = self.get_dependencies()
        # check if there is a change in diff
        if self.validate(content):
            self.requirements_file.write_text(content)
            return True
        return False

    def validate(self, content:str):
        diff = difflib.ndiff(self.requirements_file.read_text().splitlines(),content.splitlines())
        for elem in diff:
            if len(elem) > 1:
                return False
        return True

    def get_dependencies(self)->str:
        ...
