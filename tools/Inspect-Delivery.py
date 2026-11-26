"""Read-only comparison of editable ToonKit, release ZIP and an optional client copy."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import sys
import zipfile


def tree(folder):
    return {p.relative_to(folder).as_posix(): p.read_bytes()
            for p in folder.rglob('*') if p.is_file()}


def compare(expected, actual):
    return {
        'missing': sorted(expected.keys() - actual.keys()),
        'different': sorted(k for k in expected.keys() & actual.keys()
                            if expected[k] != actual[k]),
        'extra': sorted(actual.keys() - expected.keys()),
    }


def identity(files):
    text = files.get('ToonKit.toc', b'').decode('utf-8-sig', errors='replace')
    version = re.search(r'^## Version:\s*(.*?)\s*$', text, re.M)
    brand = files.get('Brand.lua', b'').decode('utf-8-sig', errors='replace')
    brand_version = re.search(r'\bversion\s*=\s*"([^"]+)"', brand)
    missing = [line.strip() for line in text.splitlines()
               if line.strip() and not line.lstrip().startswith('#')
               and line.strip().replace('\\', '/') not in files]
    # Hash includes names and exact bytes, so a mixed installation is detectable.
    digest = hashlib.sha256()
    for name, data in sorted(files.items()):
        digest.update(name.encode('utf-8') + b'\0')
        digest.update(hashlib.sha256(data).digest())
    return {'toc_version': version[1] if version else None,
            'brand_version': brand_version[1] if brand_version else None,
            'files': len(files), 'tree_sha256': digest.hexdigest(),
            'missing_load_files': missing}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--installed', type=Path,
                        help='Client Interface/AddOns folder or its ToonKit folder; read only')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    expected = tree(root / 'ToonKit')
    report = {'workspace': str(root / 'ToonKit'), 'source': identity(expected)}
    with zipfile.ZipFile(root / 'Share/ToonKit.zip') as archive:
        if archive.testzip():
            raise ValueError('Release ZIP has a CRC error')
        names = [entry.filename.replace('\\', '/') for entry in archive.infolist()
                 if not entry.is_dir()]
        if len(names) != len(set(names)):
            raise ValueError('Release ZIP contains duplicate paths')
        if any(not name.startswith('ToonKit/') or '..' in name.split('/') for name in names):
            raise ValueError('Release ZIP has files outside the ToonKit folder')
        packaged = {entry.filename.replace('\\', '/')[len('ToonKit/'):]: archive.read(entry)
                    for entry in archive.infolist() if not entry.is_dir()}
    report['package'] = identity(packaged)
    report['package_differences'] = compare(expected, packaged)
    sidecar = (root / 'Share/ToonKit.zip.sha256').read_text().split()[0].lower()
    report['package_checksum_matches'] = sidecar == hashlib.sha256((root / 'Share/ToonKit.zip').read_bytes()).hexdigest()
    if args.installed:
        folder = args.installed.resolve()
        if not (folder / 'ToonKit.toc').is_file():
            folder = folder / 'ToonKit'
        if not (folder / 'ToonKit.toc').is_file():
            parser.error('No ToonKit.toc at the supplied folder or its ToonKit child')
        installed = tree(folder)
        report['installed_path'] = str(folder)
        report['installed'] = identity(installed)
        report['installed_differences'] = compare(expected, installed)
    report['client_runtime_verified'] = False
    print(json.dumps(report, indent=2))
    good = report['package_checksum_matches']
    for key in ('source', 'package', 'installed'):
        if key in report:
            facts = report[key]
            good = good and bool(facts['toc_version']) and facts['toc_version'] == facts['brand_version'] and not facts['missing_load_files']
    for key in ('package_differences', 'installed_differences'):
        if key in report:
            good = good and not any(report[key].values())
    return 0 if good else 1


if __name__ == '__main__':
    sys.exit(main())
