import abc
import hashlib
from pathlib import Path
from typing import List

class RequirementsABC(abc.ABC):
    """Abstract class for processing Lock files.

    Parameters
    ----------
    lock_file : Path
        The path to the lock file.
    """
    def __init__(self, lock_file: Path):
        self.lock_file = lock_file

    def generate_requirements(self, requirements_file:Path, categories:List[str]):
        """Generate a new requirement file and update the current one if they are 
        different.

        Parameters
        ----------
        requirements_file : Path
            The path to the current requirement file.
        categories : list
            List of categories to include in the new requirement file.

        Returns
        -------
        bool
            whether the requirement file was updated or not.
        """
        content = self.get_dependencies(categories)
        # check if there is a change in diff
        if self.validate(content, requirements_file):
            requirements_file.write_text(content)
            return True
        return False

    def validate(self, content:str, requirements_file: Path):
        """Check if the newer requirement file is the sames as the current one using md5

        Parameters
        ----------
        content : str
            The new requirement file content.
        requirements_file : str
            The current requirements file.

        Returns
        -------
        bool
            Whether the newer requirement content is different than the current one.
        """
        if not requirements_file.exists():
            return True
        current_ = hashlib.md5(requirements_file.read_text().encode('utf-8')).hexdigest()
        newer_ = hashlib.md5(content.encode('utf-8')).hexdigest()
        return current_ != newer_

    @abc.abstractmethod
    def get_dependencies(self, categories:List[str])->str:
        """Generate the content of the newer requirement file.

        Parameters
        ----------
        categories : list
            The categories to include in the newer requierment file.

        Returns
        -------
        str
            The content of the nwer requirement file.
        """
        ...
