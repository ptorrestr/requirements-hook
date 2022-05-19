import click
import sys
from pathlib import Path
from .poetry import PoetryLock

@click.command()
@click.argument('lock_file',type=click.Path(exists=True, readable=True))
@click.option('-d', '--dev', is_flag=True)
def main(lock_file:str, dev:bool):
    """Generate the requirement file for Poetry or Pipenv lock files.
    """
    lock_file_ = Path(lock_file)
    requirements_file = lock_file_.parent / "requirements.txt"
    lock = PoetryLock(lock_file_)
    requirements_file_need_update = 0
    requirements_file_dev_need_update = 0
    if lock.generate_requirements(requirements_file, ["default"]):
        click.echo("{} needs to be updated".format(requirements_file))
        requirements_file_need_update = 1
    else:
        click.echo("{} is updated".format(requirements_file))
    if dev:
        requirements_file_dev = lock_file_.parent / "requirements-dev.txt"
        if lock.generate_requirements(requirements_file_dev, ["default", "develop"]):
            click.echo("{} needs to be updated".format(requirements_file_dev))
            requirements_file_dev_need_update = 1
        else:
            click.echo("{} is updated".format(requirements_file_dev))
    sys.exit(requirements_file_need_update + requirements_file_dev_need_update)