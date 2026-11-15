"""Stop this lab's own processes whose command line holds a word (chat 29; lab rule: never
another lane's). A process is this lab's when its working directory is in the lab.
  python3 killmine.py <word> [<word>...]     SIGKILL (DOSBox ignores SIGTERM)"""
import os, signal, sys
here = os.path.realpath(os.path.dirname(os.path.abspath(__file__)))
me = {os.getpid(), os.getppid()}
for d in os.listdir("/proc"):
    if not d.isdigit() or int(d) in me:
        continue
    try:
        cwd = os.path.realpath(os.readlink("/proc/%s/cwd" % d))
        args = open("/proc/%s/cmdline" % d, "rb").read().replace(b"\0", b" ").decode(errors="replace")
    except OSError:
        continue
    if not (cwd == here or cwd.startswith(here + "/")) or "killmine.py" in args:
        continue
    if any(w in args for w in sys.argv[1:]):
        try:
            os.kill(int(d), signal.SIGKILL)
        except OSError:
            pass
