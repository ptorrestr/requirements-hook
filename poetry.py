import sys
import re
from pathlib import Path
from typing import List

SECTION_REGEX = r"\[[a-z.]+\]+"
MAP_CATEGORY = dict(default="main", develop="dev")

def get_deps(lock_file:str, category:str):
    """Get dependencies from the lock file.

    Parameters
    ----------
    lock_file : str
        The lock file.
    category : str
        The category name to print out.
    """
    content = Path(lock_file).read_text()
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
    for section, block in zip(parsed_sections, parsed_blocks):
        if block["category"] == category:
            print("{}=={}".format(block["name"], block["version"]))
    

if __name__ == "__main__":
    lock_file = sys.argv[1]
    category = sys.argv[2]
    get_deps(lock_file,  MAP_CATEGORY.get(category, category))