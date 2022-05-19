from io import StringIO
import json
from typing import List
from .requirements import RequirementsABC


class PipenvLock(RequirementsABC):
    def get_dependencies(self, categories: List[str]) -> str:
        content = json.loads(self.lock_file.read_text())

        with StringIO() as new_requirements:
            for cat in categories:
                if cat in content:
                    for package, item in content[cat].items():
                        if "version" in item:
                            try:
                                markers = "; {}".format(item["markers"])
                            except KeyError:
                                markers = ""
                            new_requirements.write(
                                "{}{}{}\n".format(package, item["version"], markers)
                            )
                        elif "git" in item:
                            new_requirements.write(
                                "-e git+{}@{}#egg={}".format(
                                    item["git"], item["ref"], package
                                )
                            )
                        elif "file" in item:
                            new_requirements.write(
                                "{} @ {}".format(item["file"], package)
                            )
                        else:
                            raise RuntimeError(
                                "Cannot parse package '{}', entry = {}".format(
                                    package, item
                                )
                            )

            return new_requirements.getvalue()
