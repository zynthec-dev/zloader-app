"""Embed the pinned runtime without replacing zLoader's own UI resources."""
from pathlib import Path
import os, plistlib, shutil, subprocess

root = Path(__file__).resolve().parents[2]
platform = os.environ['PLATFORM_NAME']
if platform not in ('iphoneos', 'iphonesimulator'):
    raise SystemExit(0)
subprocess.run(['sh', str(root / 'zLoader/scripts/build-livecontainer.sh'), platform], check=True)
folder = 'LiveContainerDevice' if platform == 'iphoneos' else 'LiveContainerSimulator'
source = root / '.build' / folder / 'Build/Products' / ('Release-' + platform) / 'LiveContainer.app'
app = Path(os.environ['TARGET_BUILD_DIR']) / os.environ['CONTENTS_FOLDER_PATH']
app.mkdir(parents=True, exist_ok=True)
for name in ('Frameworks', 'PlugIns'):
    target = app / name
    target.mkdir(exist_ok=True)
    for path in (source / name).iterdir():
        # SideStore is not embedded as a second host and must not hook zLoader.
        if path.name == 'SideStoreSupport.framework':
            continue
        out = target / path.name
        if out.exists():
            if out.is_dir(): shutil.rmtree(out)
            else: out.unlink()
        if path.is_dir(): shutil.copytree(path, out, symlinks=True)
        else: shutil.copy2(path, out)
        if path.suffix == '.appex':
            info = plistlib.loads((out / 'Info.plist').read_bytes())
            info['CFBundleShortVersionString'] = os.environ['MARKETING_VERSION']
            info['CFBundleVersion'] = os.environ['CURRENT_PROJECT_VERSION']
            info['ZLoaderContainerHost'] = True
            (out / 'Info.plist').write_bytes(plistlib.dumps(info))

resources = app / 'LiveContainerResources.bundle'
if resources.exists(): shutil.rmtree(resources)
resources.mkdir()
for path in source.iterdir():
    if path.name in ('Info.plist', 'Frameworks', 'PlugIns', 'Extensions', 'LiveContainer', '_CodeSignature', 'embedded.mobileprovision', 'PkgInfo'):
        continue
    if path.is_dir(): shutil.copytree(path, resources / path.name, symlinks=True)
    else: shutil.copy2(path, resources / path.name)
(resources / 'Info.plist').write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'de.zloader.container-resources', 'CFBundlePackageType': 'BNDL',
    'CFBundleName': 'LiveContainer Resources', 'CFBundleVersion': '1'
}))
shutil.copy2(root / 'Vendor/LiveContainer/LICENSE', app / 'LiveContainer-License.md')
print('PASS container frameworks, extensions, independent resources and license embedded')
