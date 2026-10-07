"""Keep a dormant provider for on-device managed provisioning; no Apple rights granted."""
from pathlib import Path
import hashlib
import plistlib
import shutil
import subprocess
import tempfile
import zipfile


def prepare_bootstrap(app, root):
    provider = app / 'PlugIns/zLoaderTunnel.appex'
    if not provider.is_dir():
        raise ValueError('Build must include the provider before bootstrap packaging')
    info = plistlib.loads((provider / 'Info.plist').read_bytes())
    entitlements = plistlib.loads((root / 'zLoader/Tunnel/zLoaderTunnel.entitlements').read_bytes())
    with tempfile.TemporaryDirectory() as folder:
        path = Path(folder) / 'provider-entitlements.plist'
        path.write_bytes(plistlib.dumps(entitlements))
        for profile in provider.rglob('embedded.mobileprovision'):
            profile.unlink()
        # Metadata for the IPA reader, not authorization. The signing pipeline
        # must obtain and verify an Apple profile before this extension is installed.
        subprocess.run(['codesign', '--force', '--sign', '-', '--timestamp=none',
                        '--entitlements', str(path), str(provider)], check=True, capture_output=True)
        archive = app / 'zLoaderTunnelPayload.zip'
        subprocess.run(['ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(provider), str(archive)], check=True)
        with zipfile.ZipFile(archive) as contents:
            assert contents.testzip() is None
        manifest = {'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'],
                    'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()}
        (app / 'zLoaderTunnelPayload.plist').write_bytes(plistlib.dumps(manifest))
    shutil.rmtree(provider)
