import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

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


def test_clock():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'clock.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    clock_exe = os.path.join(BIN, 'clock' + EXEEXT)

    before = datetime.now(timezone.utc).replace(microsecond=0)
    p = subprocess.run(clock_exe, shell=True, capture_output=True)
    after = datetime.now(timezone.utc).replace(microsecond=0)

    assert p.returncode == 0, 'clock should exit successfully'
    assert p.stderr.decode("utf-8") == ''

    output = p.stdout.decode("utf-8").strip()
    result = datetime.strptime(output, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)

    assert before <= result <= after, \
        f"clock output {output} not between {before.isoformat()} and {after.isoformat()}"


def test_sleep_0():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'sleep.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    sleep_exe = os.path.join(BIN, 'sleep' + EXEEXT)
    before = time.monotonic()
    p = subprocess.run(f"{sleep_exe} 0", shell=True, capture_output=True)
    elapsed = time.monotonic() - before
    assert p.returncode == 0
    assert p.stdout.decode("utf-8") == ''
    assert p.stderr.decode("utf-8") == ''
    assert elapsed < 2.0, f"sleep 0 took {elapsed:.2f}s, expected < 2s"


def test_sleep_1():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'sleep.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    sleep_exe = os.path.join(BIN, 'sleep' + EXEEXT)
    before = time.monotonic()
    p = subprocess.run(f"{sleep_exe} 1", shell=True, capture_output=True)
    elapsed = time.monotonic() - before
    assert p.returncode == 0
    assert p.stdout.decode("utf-8") == ''
    assert p.stderr.decode("utf-8") == ''
    assert 0.9 <= elapsed <= 3.0, f"sleep 1 took {elapsed:.2f}s, expected ~1s"


def test_rawkey():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'rawkey.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    rawkey_exe = os.path.join(BIN, 'rawkey' + EXEEXT)

    def run_rawkey(input_bytes):
        p = subprocess.run(f"{rawkey_exe}", shell=True, capture_output=True,
                           input=input_bytes)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout.decode("utf-8").splitlines()

    # Printable characters followed by ESC
    assert run_rawkey(bytes([97, 66, 0, 255, 27])) == \
        ["97", "66", "0", "255", "27"]

    # Just ESC
    assert run_rawkey(bytes([27])) == ["27"]

    # EOF without ESC
    assert run_rawkey(bytes([65, 10])) == ["65", "10"]


def test_hexdump():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'hexdump.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    hexdump_exe = os.path.join(BIN, 'hexdump' + EXEEXT)

    def run_hexdump(data):
        f = tempfile.NamedTemporaryFile(delete=False, suffix='.dat')
        try:
            f.write(data)
            f.close()
            p = subprocess.run(f"{hexdump_exe} {f.name}", shell=True,
                               capture_output=True)
            assert p.returncode == 0
            assert p.stderr.decode("utf-8") == ''
            return p.stdout.decode("utf-8").splitlines()
        finally:
            os.unlink(f.name)

    # Empty file
    lines = run_hexdump(b"")
    assert lines == ["00000000"]

    # Exactly 16 bytes
    lines = run_hexdump(b"0123456789abcdef")
    assert len(lines) == 2
    assert lines[0].startswith("00000000  30 31 32 33 34 35 36 37")
    assert "38 39 61 62 63 64 65 66" in lines[0]
    assert "|0123456789abcdef|" in lines[0]
    assert lines[1] == "00000010"

    # 17 bytes (wraps to second line)
    lines = run_hexdump(b"0123456789abcdefX")
    assert len(lines) == 3
    assert lines[1].startswith("00000010  58")
    assert "|X|" in lines[1]
    assert lines[2] == "00000011"

    # Non-printable bytes (all < 0x20 → shown as dots)
    lines = run_hexdump(bytes(range(16)))
    assert lines[0].startswith("00000000  00 01 02 03 04 05 06 07")
    assert "08 09 0a 0b 0c 0d 0e 0f" in lines[0]
    assert "|................|" in lines[0]
    assert lines[1] == "00000010"

    # Partial line (5 bytes) — padding in hex area
    lines = run_hexdump(b"Hello")
    assert len(lines) == 2
    assert lines[0].startswith("00000000  48 65 6c 6c 6f")
    assert "|Hello|" in lines[0]
    assert lines[1] == "00000005"


def test_clear():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'clear.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    clear_exe = os.path.join(BIN, 'clear' + EXEEXT)
    p = subprocess.run(clear_exe, shell=True, capture_output=True)
    assert p.returncode == 0, 'clear should exit successfully'
    assert p.stderr.decode("utf-8") == ''

    ESC = "\x1b"
    output = p.stdout.decode("utf-8")
    assert f"{ESC}[H" in output, "should contain cursor-home sequence"
    assert f"{ESC}[2J" in output, "should contain erase-screen sequence"
    assert f"{ESC}[3J" in output, "should contain erase-scrollback sequence"


def test_progress5():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'progress5.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    progress5_exe = os.path.join(BIN, 'progress5' + EXEEXT)
    p = subprocess.run(progress5_exe, shell=True, capture_output=True)
    assert p.stdout.decode("utf-8") == ''
    assert p.stderr.decode("utf-8") == '\r[##################################################] 100%\n'


def test_sqrt():
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'sqrt.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
        return

    sqrt_exe = os.path.join(BIN, 'sqrt' + EXEEXT)

    def run_sqrt(arg):
        p = subprocess.run(f"{sqrt_exe} {arg}", shell=True, capture_output=True)
        assert p.returncode == 0
        assert p.stderr.decode("utf-8") == ''
        return p.stdout.decode("utf-8").strip()

    assert run_sqrt("0") == "0"
    assert run_sqrt("1") == "1"
    assert run_sqrt("4") == "2"
    assert run_sqrt("100") == "10"
    assert run_sqrt("1000000") == "1000"
    assert run_sqrt("0.25") == "0.5"
    assert run_sqrt("2") == "1.414214"
    assert run_sqrt("-1") == "1i"
    assert run_sqrt("-4") == "2i"
    assert run_sqrt("-2") == "1.414214i"


def _ctrlc_start():
    """Build ctrlc and return a running Popen handle."""
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'ctrlc.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')

    ctrlc_exe = os.path.join(BIN, 'ctrlc' + EXEEXT)

    kwargs = {}
    if sys.platform == 'win32':
        kwargs['creationflags'] = subprocess.CREATE_NEW_PROCESS_GROUP

    return subprocess.Popen(
        ctrlc_exe,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        **kwargs,
    )


def _ctrlc_signal(proc):
    """Send the platform-appropriate Ctrl+C equivalent."""
    if sys.platform == 'win32':
        proc.send_signal(signal.CTRL_BREAK_EVENT)
    else:
        proc.send_signal(signal.SIGINT)


def test_ctrlc_prompt():
    """The program must print its prompt and acknowledge the signal."""
    proc = _ctrlc_start()
    try:
        time.sleep(0.5)
        _ctrlc_signal(proc)
        stdout, stderr = proc.communicate(timeout=5)
        assert b"Press Ctrl+C to exit..." in stdout
        assert b"Received " in stdout  # "Received Ctrl+C" or "Received kill signal"
        assert stderr == b""
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=5)


def test_ctrlc_exit_code():
    """Signal must terminate the process with a non-zero exit code."""
    proc = _ctrlc_start()
    try:
        time.sleep(0.5)
        _ctrlc_signal(proc)
        proc.wait(timeout=5)
        assert proc.returncode != 0, \
            f"expected non-zero exit code, got {proc.returncode}"
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=5)


def test_ctrlc_stays_alive():
    """The program must keep running until it receives a signal."""
    proc = _ctrlc_start()
    try:
        time.sleep(1)
        assert proc.poll() is None, "process exited before Ctrl+C was sent"
    finally:
        _ctrlc_signal(proc)
        proc.wait(timeout=5)


# ---------------------------------------------------------------------------
# brainf — Brainfuck JIT compiler
# ---------------------------------------------------------------------------

def _brainf_run(program, stdin_data=None):
    """Run brainf with the given BF program string."""
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'brainf.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
    brainf = os.path.join(BIN, 'brainf' + EXEEXT)
    return subprocess.run([brainf, program], capture_output=True,
                          input=stdin_data)


def test_brainf_empty():
    p = _brainf_run('')
    assert p.returncode == 0
    assert p.stdout == b''


def test_brainf_single_dot():
    """Output the zero-initialised cell."""
    p = _brainf_run('.')
    assert p.returncode == 0
    assert p.stdout == b'\x00'


def test_brainf_increment():
    p = _brainf_run('+++++.')
    assert p.returncode == 0
    assert p.stdout == b'\x05'


def test_brainf_decrement():
    p = _brainf_run('+++++--.')
    assert p.returncode == 0
    assert p.stdout == b'\x03'


def test_brainf_cell_wrap():
    """Decrementing a zero cell wraps to 255."""
    p = _brainf_run('-.')
    assert p.returncode == 0
    assert p.stdout == b'\xff'


def test_brainf_navigate():
    """Move right then left returns to original cell."""
    p = _brainf_run('+++>++<.')
    assert p.returncode == 0
    assert p.stdout == b'\x03'


def test_brainf_multiple_outputs():
    p = _brainf_run('+++.>++.')
    assert p.returncode == 0
    assert p.stdout == b'\x03\x02'


def test_brainf_simple_loop():
    """Multiplication via loop: 8*8+1 = 65 = 'A'."""
    p = _brainf_run('++++++++[>++++++++<-]>+.')
    assert p.returncode == 0
    assert p.stdout == b'A'


def test_brainf_skip_loop():
    """Loop body is skipped when current cell is zero."""
    p = _brainf_run('[+++.]')
    assert p.returncode == 0
    assert p.stdout == b''


def test_brainf_nested_loops():
    """3 * 4 = 12."""
    p = _brainf_run('+++[>++++<-]>.')
    assert p.returncode == 0
    assert p.stdout == b'\x0c'


def test_brainf_deep_nesting():
    """Deeply nested loops, all skipped."""
    p = _brainf_run('[[[]]]')
    assert p.returncode == 0
    assert p.stdout == b''


def test_brainf_hello_world():
    bf = ('++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]'
          '>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.')
    p = _brainf_run(bf)
    assert p.returncode == 0
    assert p.stdout == b'Hello World!\n'


def test_brainf_input():
    """Read one byte from stdin and echo it."""
    p = _brainf_run(',.', stdin_data=b'X')
    assert p.returncode == 0
    assert p.stdout == b'X'


def test_brainf_ignore_non_bf():
    """Non-BF characters are silently ignored."""
    p = _brainf_run('hello +++++world.')
    assert p.returncode == 0
    assert p.stdout == b'\x05'


def test_brainf_usage():
    """Running without arguments exits with code 1."""
    BIN = os.environ['BIN']
    SRC = os.environ['SRC']
    EXEEXT = os.environ['EXEEXT']
    if 'brainf.asm' not in os.listdir(SRC):
        import pytest
        pytest.skip('Not implemented')
    brainf = os.path.join(BIN, 'brainf' + EXEEXT)
    p = subprocess.run([brainf], capture_output=True)
    assert p.returncode == 1
