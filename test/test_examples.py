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

def test_args():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'args.asm' not in os.listdir(SRC):
        return

    args_exe = os.path.join(BIN, 'args' + EXEEXT)

    def run_args(command_line):
        command_line = ' ' + command_line if command_line else ''
        p = subprocess.run(f"{args_exe}{command_line}", shell=True, capture_output=True)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout.decode("utf-8").splitlines()

    assert run_args("") == []
    assert run_args("    ") == []
    assert run_args("arg1 arg2 arg3") == ['arg1', 'arg2', 'arg3']
    assert run_args('"arg1 arg2" arg3') == ['arg1 arg2', 'arg3']

def test_envvars():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'envvars.asm' not in os.listdir(SRC):
        return

    envvars_exe = os.path.join(BIN, 'envvars' + EXEEXT)

    def run_prog(env):
        p = subprocess.run(f"{envvars_exe}", shell=True, capture_output=True, env=env)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return set(p.stdout.decode("utf-8").splitlines())

    run_prog({})
    assert {'FOO=BAR'}.issubset(run_prog({'FOO': 'BAR'}))
