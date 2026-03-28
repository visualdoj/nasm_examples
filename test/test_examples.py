import os
import subprocess

def test_exit77():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'exit77.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
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
        import pytest
        pytest.skip('Not implemented')
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
        import pytest
        pytest.skip('Not implemented')
        return

    args_exe = os.path.join(BIN, 'args' + EXEEXT)

    def run_args(command_line):
        command_line = ' ' + command_line if command_line else ''
        p = subprocess.run(f"{args_exe}{command_line}", shell=True, capture_output=True)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        s = p.stdout
        print()
        print()
        print()
        for c in s:
            print(c)
        return p.stdout.decode("utf-8").splitlines()

    assert run_args("") == []
    assert run_args("    ") == []
    assert run_args("arg1 arg2 arg3") == ['arg1', 'arg2', 'arg3']
    assert run_args('"arg1 arg2" arg3') == ['arg1 arg2', 'arg3']
    assert run_args('你好') == ['你好']


def test_envvars():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'envvars.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    envvars_exe = os.path.join(BIN, 'envvars' + EXEEXT)

    def run_prog(env):
        p = subprocess.run(f"{envvars_exe}", shell=True, capture_output=True, env=env)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return set(p.stdout.decode("utf-8").splitlines())

    run_prog(None)
    assert {'FOO=BAR'}.issubset(run_prog({'FOO': 'BAR'}))


def test_count():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'count.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    count_exe = os.path.join(BIN, 'count' + EXEEXT)

    def run_count(n):
        p = subprocess.run(f"{count_exe} {n}", shell=True, capture_output=True)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout.decode("utf-8").splitlines()

    assert run_count(1) == ['1']
    assert run_count(5) == ['1', '2', '3', '4', '5']
    assert run_count(15) == [str(i) for i in range(1, 16)]


def test_upper():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'upper.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    upper_exe = os.path.join(BIN, 'upper' + EXEEXT)

    def run_upper(input_text):
        p = subprocess.run(upper_exe, shell=True, capture_output=True, input=input_text.encode("utf-8"))
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout.decode("utf-8")

    assert run_upper("hello") == "HELLO"
    assert run_upper("Hello World") == "HELLO WORLD"
    assert run_upper("ALREADY UPPER") == "ALREADY UPPER"
    assert run_upper("123 abc!") == "123 ABC!"
    assert run_upper("") == ""
    assert run_upper("line1\nline2\n") == "LINE1\nLINE2\n"


def test_reverse():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'reverse.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    reverse_exe = os.path.join(BIN, 'reverse' + EXEEXT)

    def run_reverse(input_bytes):
        p = subprocess.run(reverse_exe, shell=True, capture_output=True, input=input_bytes)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout

    assert run_reverse(b"") == b""
    assert run_reverse(b"a") == b"a"
    assert run_reverse(b"hello") == b"olleh"
    assert run_reverse(b"Hello World!") == b"!dlroW olleH"
    assert run_reverse(b"racecar") == b"racecar"
    assert run_reverse(b"ab\ncd\n") == b"\ndc\nba"
    # exercise the grow path (exceeds initial 4096-byte buffer)
    large = b"abcdefghij" * 500
    assert run_reverse(large) == large[::-1]


def test_colors():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'colors.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    colors_exe = os.path.join(BIN, 'colors' + EXEEXT)
    p = subprocess.run(colors_exe, shell=True, capture_output=True)
    assert p.returncode == 0, 'colors should exit successfully'
    assert p.stderr.decode("utf-8") == ''

    ESC = "\x1b"
    lines = p.stdout.decode("utf-8").splitlines()
    assert len(lines) == 2, 'colors should output exactly 2 lines'
    assert lines[0] == f"{ESC}[97mWhite {ESC}[91mRed {ESC}[92mGreen {ESC}[93mYellow {ESC}[94mBlue {ESC}[95mMagenta {ESC}[96mCyan {ESC}[0m"
    assert lines[1] == f"{ESC}[37mWhite {ESC}[31mRed {ESC}[32mGreen {ESC}[33mYellow {ESC}[34mBlue {ESC}[35mMagenta {ESC}[36mCyan {ESC}[0m"
