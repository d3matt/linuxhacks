import ctypes
import os
import pwd
import sys

libcapng = ctypes.cdll.LoadLibrary('libcap-ng.so.0')

TESTFILE='/tmp/foo'

class capng:
    CAPNG_DROP = 0
    CAPNG_ADD = 1
    CAP_CHOWN = 0
    CAPNG_EFFECTIVE = 1
    CAPNG_PERMITTED = 2
    CAPNG_SELECT_BOTH = 48
    CAPNG_DROP_SUPP_GRP = 1
    CAPNG_CLEAR_BOUNDING = 2
    CAPNG_INIT_SUPP_GRP = 4

def dump():
    print('EUID: ', os.geteuid())
    print('UID: ', os.getuid())
    print('GID: ', os.getgid())
    print('groups: ', os.getgroups())
    print('have_cap_chown: ', libcapng.capng_have_capability(capng.CAPNG_EFFECTIVE, capng.CAP_CHOWN))
    print('stat of %s' % TESTFILE, os.stat(TESTFILE))

if not 0 == os.getuid():
    print('ERROR: must be root', file=sys.stderr)
    sys.exit(1)

if os.path.exists(TESTFILE):
    os.unlink(TESTFILE)
with open(TESTFILE, 'w') as fout:
    print('WOOT WOOT', file=fout)



pw_rec = pwd.getpwnam('xsrun')

print('BEFORE: ')
dump()

print('changing user')
libcapng.capng_clear(capng.CAPNG_SELECT_BOTH)
libcapng.capng_update(capng.CAPNG_ADD, capng.CAPNG_EFFECTIVE|capng.CAPNG_PERMITTED, capng.CAP_CHOWN)
libcapng.capng_change_id(pw_rec.pw_uid, pw_rec.pw_gid, capng.CAPNG_INIT_SUPP_GRP | capng.CAPNG_CLEAR_BOUNDING)

print('TRYING CHOWN...')
os.chown(TESTFILE, pw_rec.pw_uid, pw_rec.pw_gid)

print('AFTER: ')
dump()
