import os
import subprocess

def test_exit77():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'exit77.asm' not in os.listdir(SRC):
        return

    exit77_exe = os.path.join(BIN, 'exit77' + EXEEXT)
    p = subprocess.run(exit77_exe, shell=True, capture_output=True)
    assert p.returncode == 77, 'exit77.exe should return exit code 77'
    assert p.stdout.decode("utf-8") == ''
    assert p.stderr.decode("utf-8") == ''

def test_hello():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'hello.asm' not in os.listdir(SRC):
        return

    hello_exe = os.path.join(BIN, 'hello' + EXEEXT)
    p = subprocess.run(hello_exe, shell=True, capture_output=True)
    assert p.returncode == 0, 'hello.exe should exit successfully'
    assert p.stdout.decode("utf-8").strip() == 'Hello world!'
    assert p.stderr.decode("utf-8") == ''
