"""Check installer dependencies without reading game or user files."""
import sys,json,ctypes,hashlib,zipfile,zlib,pathlib,struct,shutil,uuid,datetime,re,os
print(json.dumps({'ok':sys.version_info>=(3,12),'version':list(sys.version_info[:3]),'bits':struct.calcsize('P')*8,'isolated':bool(sys.flags.isolated),'ignore_environment':bool(sys.flags.ignore_environment)}))
