from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib, re
root = Path('outputs/ForeverBestiary')
version = re.search(r'F.version = "([^"]+)"', (root/'ForeverBestiary.lua').read_text()).group(1)
manifest = (root/'ForeverBestiary.toc').read_text()
assert manifest == (root/'ForeverBestiary_Camelot.toc').read_text()
assert f'## Version: {version}' in manifest
for path in [root/'CHANGELOG.md', root/'README.md', Path('README.md'), Path('outputs/CURSEFORGE-DESCRIPTION.md')]:
    assert version in path.read_text(), f'Update release description: {path}'
assert (root/'Media/CodexIcon.tga').is_file()
archive = Path(f'outputs/ForeverCodex-{version}.zip')
with ZipFile(archive, 'w', ZIP_DEFLATED) as z:
    for path in sorted(root.rglob('*')):
        if path.is_file(): z.write(path, path.relative_to(root.parent))
with ZipFile(archive) as z: assert z.testzip() is None
print(archive, hashlib.sha256(archive.read_bytes()).hexdigest())
