#!/usr/bin/env python3
# Run a command on a real terminal, feeding it this script's standard
# input and passing its output on.  Standard error stays a pipe.
import os, pty, select, sys, termios

master, slave = pty.openpty()
attrs = termios.tcgetattr(slave)
attrs[1] &= ~termios.OPOST                  # newlines stay newlines
attrs[3] &= ~termios.ECHO                   # the answers are not output
termios.tcsetattr(slave, termios.TCSANOW, attrs)

pid = os.fork()
if pid == 0:
    os.close(master)
    os.setsid()
    os.dup2(slave, 0)
    os.dup2(slave, 1)
    os.close(slave)
    os.execvp(sys.argv[1], sys.argv[1:])
os.close(slave)

os.write(master, sys.stdin.buffer.read() + b'\x04')
out = sys.stdout.buffer
while True:
    ready, _, _ = select.select([master], [], [], 0.1)
    if ready:
        try:
            data = os.read(master, 65536)
        except OSError:                     # the terminal closed: it finished
            break
        if not data:
            break
        out.write(data)
out.flush()
sys.exit(os.waitstatus_to_exitcode(os.waitpid(pid, 0)[1]))
