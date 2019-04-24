GEOPM QUICK START
=================
This document is designed to assist users of the ALCF Theta system
to quickly integrate their applications with the GEOPM runtime.  The
GEOPM software is available on Theta via the lmod module system and
can be loaded into the user's environment with the command:

    module load geopm

This will add the paths to the user's environment for access to the
libraries, binaries, man pages and source code headers for the system
installed version of GEOPM.  The version of GEOPM installed is
[1.0.0](https://github.com/geopm/geopm/releases/tag/v1.0.0) which is
the latest stable release.  Links to all of the geopm man pages can be
accessed by requesting the GEOPM overview man page
[geopm(7)](https://geopm.github.io/man/geopm.7.html):

    man geopm

The first GEOPM interfaces that are covered here are the
[geopmagent(1)](https://geopm.github.io/man/geopmagent.1.html):

    man geopmagent

and the [geopmlaunch(1)](https://geopm.github.io/man/geopmlaunch.1.html):

    man geopmlaunch

command line utilities.

Profiling and Tracing an Unmodified Application
-----------------------------------------------
The first thing an HPC application user will want to do when
integrating their application with the GEOPM runtime is to analyze
performance of the application without recompiling the application or
modifying its source code.  This can be accomplished by using the
geopmlaunch wrapper script for the ALPS aprun job launcher while
specifying the --geopm-preload option:


    #!/bin/bash
    #COBALT -t 30
    #COBALT -n <NUM_NODE>
    #COBALT -A <CHARGE_ACCOUNT>
    #COBALT -O geopm_quickstart.$jobid
    #COBALT -q debug-cache-quad
    #COBALT --jobname geopm_quickstart
    #COBALT --env JOBID=$jobid

    module load geopm

    # Use GEOPM launcher wrapper script with ALPS's aprun
    geopmlaunch aprun -n NUM_RANK -N NUM_RANK_PER_NODE [OTHER_APRUN_OPTIONS] \
        --geopm-preload --geopm-ctl=process \
        --geopm-report=report.txt --geopm-trace=trace.csv \
        -- APPLICATION APP_OPTIONS


Here "APPLICATION" is a place holder for the path to the application
of choice, and "APP_OPTIONS" is a place holder for the command line
options for the application.  The --geopm-preload command line option
enables the GEOPM library to interpose on MPI using the PMPI interface
though the LD_PRELOAD mechanism.  Linking directly to libgeopm has the
same effect, but preloading GEOPM enables integration with
unmodified binaries.

The above example uses the command line option to the launcher
"--geopm-ctl=process" which launches the controller as an extra MPI
process per node.  Note that the geopmlaunch command will print to
standard output the interpreted command that was executed and that
this output will show an extra rank per node requested.

The primary reason for using the monitor Agent is to create report and
trace files.  The summary report will be created in the file named:

    report.txt

and one trace file will be output for each compute node and the name
of each trace file will be extended with the host name of the node it
describes:

    trace.csv-`hostname`

The report file will contain information about time and energy spent
in MPI regions and outside of MPI regions as well as the average CPU
frequency.

Known Issues
------------

### Conflict with Darshan module

The GEOPM runtime uses the PMPI interface for profiling MPI calls.
The Darshan module also uses the PMPI interface, and this conflicts
with GEOPM's use.  The darshan module should be unloaded prior to
loading the GEOPM module to avoid this conflict.

### Rank/Thread Pinning

The GEOPM job launch script, geopmlaunch, queries and uses the
OMP_NUM_THREADS environment variable to choose affinity masks for each
process.  For this reason, it is required to set the OMP_NUM_THREADS
environment variable in the shell that executes geopmlaunch, and should
not be passed to the application sub-shell with the aprun '-e' option.

GOOD:

    OMP_NUM_THREADS=64 geopmlaunch -N 1 -n 1 ...

BAD:

    geopmlaunch -e 'OMP_NUM_THREADS=64' -N1 -n1 ...

Enabling geopmlaunch to interpret the -e option is tracked as
[issue #360](https://github.com/geopm/geopm/issues/360).

The principal job of the geopmlaunch wrapper to aprun is to set
explicit per-process CPU affinity masks that will optimize performance
while enabling the GEOPM controller thread to run on a core isolated
from the cores used by the primary application.  For this reason it is
important not to provide any affinity related flags to geopmlaunch.
Please do not specify either of the CPU binding aprun options when
using geopmlaunch: '-cc'/'--cpu-binding', or
'-cp'/'--cpu-binding-file'.  The geopmlaunch command does not interpret
the '-j'/'--cpus-per-cu' option and it should not be used.  This option
will either conflict with the explicit per process CPU masks that
GEOPM creates, or it will not effect the affinitization.  With the
asymmetry of the KNL NUMA configuration, the '-S'/'--pes-per-numa-node'
option is not appropriate on the Theta system, but this option is also
not interpreted by the geopmlaunch wrapper.

### Failure of msr-safe

As described in the [Run Requirements : MSR
Driver](https://github.com/geopm/geopm#msr-driver) section of the main GEOPM readme,
msr-safe is being employed on Theta for MSR based I/O.  There is presently an
[issue being tracked](https://github.com/LLNL/msr-safe/issues/43) on the msr-safe repo
regarding an intermittent failure of msr-safe on boot of a compute node.  The
issue renders GEOPM unable to operate on that node until the condition is
resolved.

In order to avoid that node in your allocation, a simple MSR read test can be
performed to determine whether or not msr-safe is functional.  In order to
attempt a read of an MSR through msr-safe, the ```geopmread``` command line
utility can be utilized.  This must be invoked on the compute nodes through
```aprun```.

In order to generate a comma separated list of bad nodes, the
[exclude_nodes.sh](exclude_nodes.sh) script included in this repository
can be utilized.  The script output can be passed directly to
```geopmlaunch``` (or ```aprun```) to avoid those nodes with the
```-E, --exclude-node-list``` option:

```bash
NUM_REQUIRED_NODES= ...
EXCLUDE_NODES=$(./exclude_nodes.sh $NUM_REQUIRED_NODES)
if [ $? -ne 0 ]; then
    exit 1
fi
geopmlaunch $EXCLUDE_NODES ...
```

To account for this issue, you will need to request a few more nodes than are
actually required for your experiment.  In our recent testing, allowing for 4
nodes to fail in a request of 256 appears optimal.  Integration of this fix
into the launcher to make this node exclusion automatic is tracked by
[issue #366](https://github.com/geopm/geopm/issues/366).

Adding GEOPM Mark-up to the Application
---------------------------------------
To take full advantage of GEOPM, a user must add GEOPM function calls
to the application from the set documented by the man page
[geopm_prof_c(3)](https://geopm.github.io/man/geopm_prof_c.3.html):

    man geopm_prof_c

There are Fortran wrappers into these C functions and these are
documented in the man page
[geopm_fortran(3)](https://geopm.github.io/man/geopm_fortran.3.html):

    man geopm_fortran

To have a more fine-grained information in the report, add the
geopm_prof_enter() and geopm_prof_exit() functions around regions of
code.  This will enable GEOPM to extend the report with statistics
gathered specifically while that region of code was executing.

    static uint64_t function1_rid = 0;
    if (function1_rid == 0) {
        geopm_prof_region("function1", GEOPM_HINT_COMPUTE, &function1_rid);
    }
    geopm_prof_enter(function1_rid);
    function1();
    geopm_prof_exit(function1_rid);

The above example creates a region called "function1" and then wraps
the call to function1() in geopm application markup calls.  In
addition to providing a more detailed report, the "energy_efficient"
agent can use this markup to choose efficient processor frequencies
for each region.  To enable effective use of the "power_balancer"
agent, the outer loop of the application must be identified with the
geopm_prof_epoch() call.  One call to this function should be placed
at the beginning of the outer-most loop of an application.

    int main(int argc, char **argv)
    {
        for (int i = 0; i < n; ++i) {
            geopm_prof_epoch();
            do_all_the_things(i);
        }
    }

As a first integration with GEOPM, simply adding calls to:

    geopm_prof_epoch()
    geopm_prof_region()
    geopm_prof_enter()
    geopm_prof_exit()

in your application should enable all of the benefits provided by the
built-in GEOPM Agents.  In addition, there are other APIs documented in
geopm_proc_c(3) (geopm_prof_progress() and geopm_tprof_*()) that can
be used to provide application feedback to the GEOPM Agent algorithm.
The GEOPM runtime does not provide any built-in Agents that use the
feedback provided by these progress and thread APIs.  For this reason
modification of the application to use these additional interfaces
will provide no benefit with built-in Agents.  Extension of the GEOPM
features through an Agent plugin would enable a user to write an Agent
that uses this feedback, but this is beyond the scope of this guide.

Compiling Application Against GEOPM
-----------------------------------
When loading the geopm module, several variables will be added to the
shell environment.  The GEOPM_INC variable defines the path to the
GEOPM header files.  When compiling source that includes a geopm
header file you must add

    -I$GEOPM_INC

to your compile line.  To link your application against libgeopm the
GEOPM_LIB variable defined by the module should be used on your link
line:

    -L$GEOPM_LIB -lgeopm -dynamic

Note that dynamic linking is required with the -dynamic flag.  Once
you have linked your application against libgeopm, the
'--geopm-preload' option to geopmlaunch is no longer required.

Selecting an Agent
------------------
The first example provided uses the monitor agent:

    man geopm_agent_monitor

This agent does not modify any hardware settings, but simply takes
samples throughout the runtime and uses them to generate report and
trace files.  There are three other agents that can be selected and
each of these is documented in a man page:

    man geopm_agent_power_governor
    man geopm_agent_power_balancer
    man geopm_agent_energy_efficient

Please read through the features that these Agents implement, and try
using them with your application.  The agent is selected with the
--geopm-agent command line option for the geopmlaunch(1) command and
the JSON policy file for each agent can be generated with the
geopmagent(1) command line tool.  See links to the web version of each
Agent man page:
[geopm_agent_monitor(7)](https://geopm.github.io/man/geopm_agent_monitor.7.html),
[geopm_agent_power_governor(7)](https://geopm.github.io/man/geopm_agent_power_governor.7.html),
[geopm_agent_power_balancer(7)](https://geopm.github.io/man/geopm_agent_power_balancer.7.html),
[geopm_agent_energy_efficient(7)](https://geopm.github.io/man/geopm_agent_energy_efficient.7.html)

The power_governor and power_balancer both impose a limit on the power
used by the processor socket, and this limit is selected by the user.
We are working on modifications to the power_balancer agent to enable
it to provide some energy saving capabilities when the power limit is
set to TDP (215 Watts on the Theta KNL SKUs) or higher, but this is a
work in progress.
