import io, os, zipfile, base64, shutil
DIST='/tmp/dist_en'
if os.path.exists(DIST): shutil.rmtree(DIST)
os.makedirs(DIST+'/AAPS-Builder-Files')
shutil.copy('Build-AAPS-EN.bat', DIST+'/Build-AAPS.bat')
shutil.copy('TEST-FIRST.bat',    DIST+'/TEST-FIRST.bat')
shutil.copy('README-EN.html',    DIST+'/README.html')
shutil.copy('Build-AAPS-EN.ps1', DIST+'/AAPS-Builder-Files/Build-AAPS.ps1')
shutil.copy('READ-ME-FIRST-EN.txt', DIST+'/AAPS-Builder-Files/READ-ME-FIRST.txt')

z='/tmp/payload_en.zip'
if os.path.exists(z): os.remove(z)
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as zf:
    for root,_,files in os.walk(DIST):
        for f in sorted(files):
            full=os.path.join(root,f); zf.write(full, os.path.relpath(full,DIST))
b64=base64.b64encode(open(z,'rb').read()).decode('ascii')
lines=[b64[i:i+76] for i in range(0,len(b64),76)]

hdr = io.open('/home/claude/START-HERE.bat', encoding='ascii', errors='replace').read()
# '::PAYLOAD::' also appears inside the helper code, so cut at the LINE that
# starts with it, not at the first occurrence anywhere.
lines_hdr = hdr.split('\n')
mi = [i for i, l in enumerate(lines_hdr) if l.startswith('::PAYLOAD::')]
if not mi:
    raise SystemExit('marker line not found in source header')
hdr = '\n'.join(lines_hdr[:mi[0] + 1])
hdr = hdr.replace('1. The instructions, in Hebrew - please read them.',
                  '1. The instructions - please read them.')
out='/home/claude/START-HERE-ENGLISH.bat'
with io.open(out,'w',newline='\r\n',encoding='ascii') as f:
    f.write(hdr.replace('\r\n','\n'))
    f.write('\n'+'\n'.join(lines)+'\n')
print('payload %.1f KB -> %s  (%.1f KB)' % (os.path.getsize(z)/1024, os.path.basename(out), os.path.getsize(out)/1024))
