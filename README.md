# requirements-hook

Git commit hook for the generation of requirement files from a pipenv file

## Usage

Add the folling entry in your `.pre-commit-config.yaml` file.

```yaml
- repo: https://github.com/ptorrestr/requirements-hook
  rev: 'main'
  hooks:
  - id: gen-requirements
    args: ['-d']
```