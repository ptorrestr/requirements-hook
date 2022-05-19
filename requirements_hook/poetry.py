import sys
import re
from pathlib import Path
from typing import List
from io import StringIO
from .requirements import RequirementsABC

SECTION_REGEX = r"\[[a-z.]+\]+"
MAP_CATEGORY = dict(default="main", develop="dev")

class PoetryLock(RequirementsABC):
    """This is a implementation to generate the requirement files from a poetry.lock
    file using in Poetry system.
    """

    def _transform_categories(self, categories:List[str])->List[str]:
        """ Transform the category names to the schema used by Poetry.
        """
        return [MAP_CATEGORY.get(cat, cat) for cat in categories]

    def get_dependencies(self, categories:List[str]):
        """Get dependencies from the lock file.
        """
        content = self.lock_file.read_text()
        sections = [s.replace('[', '').replace(']', '') for s in re.findall(SECTION_REGEX, content)]
        blocks = re.split(SECTION_REGEX, content)[1:]
        parsed_sections = []
        parsed_blocks = []
        # Parse each block and get the metadata
        for section, block in zip(sections, blocks):
            # only package block are processed
            if section == "package":
                new_block = dict()
                for line in block.split("\n"):
                    line = re.sub(r"\s+", "", line)
                    c = line.split("=")
                    if len(c) == 2:
                        new_block[c[0]] = c[1].replace('"','').replace('"','')
                parsed_sections.append(section)
                parsed_blocks.append(new_block)
        
        # Print the packages and their versions
        categories = self._transform_categories(categories)
        with StringIO() as new_requirements:
            for section, block in zip(parsed_sections, parsed_blocks):
                if block["category"] in categories:
                    new_requirements.write("{}=={}\n".format(block["name"], block["version"]))
            return new_requirements.getvalue()
