#!/usr/bin/env bash

# fail hard
set -o pipefail
# fail harder
set -eu

if [[ $(uname) == "Darwin" ]]; then
    sedbufarg="-l" # mac/bsd sed: -l buffers on line boundaries
else
    sedbufarg="-u" # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
fi

logs+=( "/tmp/php-fpm.log" "/tmp/php-fpm.www.log" "/tmp/php-fpm.www.slowlog" )

wait_pipe=$(mktemp -t "waitpipe.XXXXXX" -u)
rm -f $wait_pipe
mkfifo $wait_pipe
exec 3<> $wait_pipe

pids=()

# trap SIGQUIT (ctrl+\ on the console), SIGTERM (when we get killed) and EXIT (upon failure of any command due to set -e, or because of the exit 1 at the very end), we then
# 1) restore the trap for the signal in question so it doesn't fire again due to the kill at the end of the trap, as well as for EXIT, because that would fire too
# 2) call cleanup() to
# 2a) remove our FIFO from above
# 2b) kill all the subshells we've spawned - they in turn have their own traps to kill their respective subprocesses, and because we use SIGUSR1, they know it's the parent's cleanup and can handle it differently from an external SIGKILL
# 2c) send STDERR to /dev/null so we don't see "no such process" errors - after all, one of the subshells may be gone
# 2d) || true so that set -e doesn't cause a mess if the kill returns 1 on "no such process" cases (which is likely on Heroku where all processes get killed and not just this top level one)
# 2e) do that in the background and 'wait' on those processes, sending wait's output to /dev/null - this prevents the logs getting cluttered with "vendor/bin/heroku-...: line 309:    96 Terminated" messages (we can't use 'disown' after launching programs for that purpose because that removes the jobs from the shell's jobs table and the we can no longer 'wait' on the program)
# 3) kill ourselves with the correct signal in case we're handling SIGQUIT or SIGTERM (http://www.cons.org/cracauer/sigint.html and http://mywiki.wooledge.org/SignalTrap#Special_Note_On_SIGINT1)
cleanup() { echo "Going down, terminating child processes..." >&2; rm -f ${wait_pipe} || true; kill -USR1 "${pids[@]}" 2> /dev/null || true; }
trap 'trap - QUIT EXIT; cleanup; kill -QUIT $$' QUIT
trap 'trap - TERM EXIT; cleanup; kill -TERM $$' TERM
trap 'trap - EXIT; cleanup' EXIT
# if FD 1 is a TTY (that's the -t 1 check), trap SIGINT/Ctrl+C, then same procedure as for QUIT and TERM above
if [[ -t 1 ]]; then
    trap 'trap - INT EXIT; cleanup; kill -INT $$' INT;
# if FD 1 is not a TTY (e.g. when we're run through 'foreman start'), do nothing on SIGINT; the assumption is that the parent will send us a SIGTERM or something when this happens. With the trap above, Ctrl+C-ing out of a 'foreman start' run would trigger the INT trap both in Foreman and here (because Ctrl+C sends SIGINT to the entire process group, but there is no way to tell the two cases apart), and while the trap is still doing its shutdown work triggered by the SIGTERM from the Ctrl+C, Foreman would then send a SIGTERM because that's what it does when it receives a SIGINT itself.
else
    trap '' INT;
fi

# we are now launching a subshell for each of the tasks (log tail, app server, web server)
# 1) each subshell has a trap on EXIT that echos the command name to FD 3 (see the FIFO set up above)
# 1a) a 'read' at the end of the script will block on reading from that FD and then trigger the exit trap further above, which does the cleanup
# 2) each subshell also has a trap on TERM that
# 2a) kills $! (the last process executed)
# 2b) ... which in turn will hit the EXIT trap and that unblocks the 'wait' in 5) which will cause the parent to clean up when the exit at the end of the script is hit
# 2c) the 'kill' is done in the background and we immediately 'wait' on $!, sending wait's output to /dev/null - this prevents the logs getting cluttered with "vendor/bin/heroku-...: line 309:    96 Terminated" messages (we can't use 'disown' after launching programs for that purpose because that removes the jobs from the shell's jobs table and the we can no longer 'wait' on the program)
# 2d) finally, if $BASHPID exists, the subshell kills itself using the right signal for maximum compliance ($$ doesn't work in subshells, and $BASHPID is not available in Bash 3, but unlike with the parent, it's not that critical to have this)
# 3) each subshell has another trap on USR1 which gets sent when the parent is cleaning up; it works like 2a) but doesn't trigger the EXIT trap to avoid multiple cleanup runs by the parent
# 4) execute the command in the background
# 5) 'wait' on the command (wait is interrupted by an incoming TERM to the subshell, whereas running 4) in the foreground would wait for that process to finish before triggering the trap)
# 6) add the PID of the subshell to the array that the EXIT trap further above uses to clean everything up

echo "Starting log redirection..." >&2
(
    # the TERM trap here is special, because
    # 1) there is a pipeline from tail to sed
    # 2) we thus need to kill several children
    # 3) kill $! will no longer do the job in that case
    # 4) job control (set -m, where we could then kill %% instead) has weird side effects e.g. on ctrl+c (kills the parent terminal after that too)
    # 5) so we try to kill all currently running jobs
    # 5a) gracefully, by redirecting STDERR to /dev/null - one of the children will already be gone
    # 6) the sed with the Darwin/GNU sed arg case used to be a function, but that was even worse with an extra wrapping subshell for sed
    # FIXME: fires when the subshell or the tail is killed, but not when the sed is killed, because... pipes :( maybe we can do http://mywiki.wooledge.org/ProcessManagement#My_script_runs_a_pipeline.__When_the_script_is_killed.2C_I_want_the_pipeline_to_die_too.
    logs_pipe=$(mktemp -t "logspipe-$$.XXXXXX" -u)
    rm -f $logs_pipe
    mkfifo $logs_pipe
    unset logs_procs
    
    trap '' INT;
    trap 'echo "tail" >&3;' EXIT
    trap 'trap - TERM; kill -TERM "${logs_procs[@]}" 2> /dev/null || true & wait "${logs_procs[@]}" 2> /dev/null || true; rm -f $logs_pipe; [[ ${BASHPID:-} ]] && kill -TERM $BASHPID' TERM
    trap 'trap - USR1 EXIT; kill -TERM "${logs_procs[@]}" 2> /dev/null || true & wait "${logs_procs[@]}" 2> /dev/null || true; rm -f $logs_pipe; [[ ${BASHPID:-} ]] && kill -USR1 $BASHPID' USR1
    
    touch "${logs[@]}"
    
    if [[ $(uname) == "Darwin" ]]; then
        sedbufarg="-l" # mac/bsd sed: -l buffers on line boundaries
    else
        sedbufarg="-u" # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
    fi
    
    tail -qF -n 0 "${logs[@]}" > "$logs_pipe" & logs_procs+=($!)
    sed $sedbufarg -E -e 's/^\[[^]]+\] WARNING: \[pool [^]]+\] child [0-9]+ said into std(err|out): "(.*)("|...)$/\2\3/' -e 's/"$//' < "$logs_pipe" 1>&2 & logs_procs+=($!) # messages that are too long are cut off using "..." by FPM instead of closing double quotation marks; we want to preserve those three dots but not the closing double quotes
    
    wait
) & pids+=($!)
disown $!

echo "Starting php-fpm..." >&2
(
    trap '' INT;
    trap 'echo "php-fpm" >&3;' EXIT
    trap 'trap - TERM; kill -TERM $pid 2> /dev/null || true & wait $pid 2> /dev/null || true; [[ ${BASHPID:-} ]] && kill -TERM $BASHPID' TERM
    trap 'trap - USR1 EXIT; kill -TERM $pid 2> /dev/null || true & wait $pid 2> /dev/null || true; [[ ${BASHPID:-} ]] && kill -USR1 $BASHPID' USR1
    
    php-fpm --nodaemonize & pid=$!
    
    wait
) & pids+=($!)
disown $!

# wait for something to come from the FIFO attached to FD 3, which means that the given process was killed or has failed
# this will be interrupted by a SIGTERM or SIGINT in the traps further up
# if the pipe unblocks and this executes, then we won't read it again, so if the traps further up kill the remaining subshells above, their writing to FD 3 will have no effect
read exitproc <&3
# we'll only reach this if one of the processes above has terminated
echo "Process exited unexpectedly: $exitproc" >&2

# this will trigger the EXIT trap further up and kill all remaining children
exit 1