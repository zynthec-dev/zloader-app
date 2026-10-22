#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
out="$PWD/.build/ContainerFixtures"
mkdir -p "$out"
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun clang -target arm64-apple-ios26.5-simulator -isysroot "$sdk" -fobjc-arc \
    -framework UIKit -framework WebKit -framework SafariServices -framework AuthenticationServices \
    -Wl,-headerpad,0x8000 zLoader/Tests/ContainerFixture/main.m -o "$out/Fixture"
python3 - "$out" <<'PY'
import pathlib,plistlib,shutil,subprocess,sys,zipfile,struct,zlib
out=pathlib.Path(sys.argv[1])
for name in ('Alpha','Beta','NativeCollision'):
    root=out/name
    if root.exists(): shutil.rmtree(root)
    app=root/'Payload'/(name+'.app'); app.mkdir(parents=True)
    shutil.copy2(out/'Fixture',app/'Fixture')
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    color=(28,150,115) if name=='Alpha' else (85,100,220)
    pixels=b''.join(b'\0'+bytes(color)*120 for _ in range(120))
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',120,120,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
    (app/'AppIcon.png').write_bytes(png)
    (app/'Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier':'de.zloader.acceptance.'+name.lower(),
        'CFBundleName':name,'CFBundleDisplayName':name,'CFBundleExecutable':'Fixture',
        'CFBundleIconFiles':['AppIcon'],
        'CFBundleIcons':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['AppIcon']}},
        'CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'1.0',
        'MinimumOSVersion':'26.5','LSRequiresIPhoneOS':True,
        'UIDeviceFamily':[1,2],'UILaunchScreen':{},
        'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False,
            'UISceneConfigurations':{'UIWindowSceneSessionRoleApplication':[
                {'UISceneConfigurationName':'Default','UISceneDelegateClassName':'FixtureSceneDelegate'}]}},
        'CFBundleURLTypes':[{'CFBundleURLSchemes':['fixturecallback']}],
        'NSAppTransportSecurity':{'NSAllowsLocalNetworking':True,'NSAllowsArbitraryLoads':True}
    }))
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(app)],check=True,capture_output=True)
    with zipfile.ZipFile(out/(name+'.ipa'),'w',zipfile.ZIP_DEFLATED) as z:
        for p in sorted(root.rglob('*')):
            if p.is_file(): z.write(p,p.relative_to(root))
print('PASS synthetic Simulator container fixtures (no Apple account)')
PY
