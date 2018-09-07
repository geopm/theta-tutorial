GEOPM QUICK START
=================
This document is designed to assist users of the ALCF Theta system
to quickly integrate their application with the GEOPM runtime.  The
GEOPM software is available on Theta via the lmod module system and
can be loaded into the user's environment with the command:

    module load geopm

This will add the paths to the user's environment for access to the
libraries, binaries, man pages and source code headers for the system
installed version of GEOPM.  Links to all of the geopm man pages can
be accessed by requesting the GEOPM overview man page:

    man geopm

Step 0: Profiling and Tracing an Unmodified Application
-------------------------------------------------------
The first thing an HPC application user will want to do when
integrating their application with the GEOPM runtime is to analyze
performance of the application without recompiling the application or
modifying its source code.  This can be accomplished by using the
geopmaprun wrapper script for the ALPS aprun job launcher while
specifying the --geopm-preload option:

    geopmagent -a monitor -p None > monitor_policy.json

    geopmaprun -N NUM_RANK_PER_NODE -n NUM_RANK [OTHER_APRUN_OPTIONS] \
        --geopm-preload --geopm-ctl=process \
        --geopm-agent=monitor --geopm-policy=monitor_policy.json \
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
process per node.  Note that the geopmaprun command will print to
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

Step 1: Adding GEOPM Mark-up to the Application
-----------------------------------------------
To take full advantage of GEOPM a user must add GEOPM function calls
to the application from the set documented by the geopm_prof_c(3) man
page.

    man geopm_prof_c

To have a more fine grained information in the report, add the
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
the call to function1() in geopm application mark up calls.  In
addition to providing a more detailed report, the "energy_efficient"
agent can use this mark up to choose efficient processor frequencies
for each region.  To enable effective application of the
"power_balancer" agent, the outer loop of the application must be
identified with the geopm_prof_epoch() call.  One call to this
function should be placed at the beginning of the outer-most loop of
an application.

    int main(int argc, char **argv)
    {
        for (int i = 0; i < n; ++i) {
            geopm_prof_epoch();
            do_all_the_things(i);
        }
    }

As a first integration with GEOPM simply adding calls to:

    geopm_prof_epoch()
    geopm_prof_region()
    geopm_prof_enter()
    geopm_prof_exit()

in your application should enable all of the benefits provided by the
built-in GEOPM Agents.  In addition there are other APIs documented in
geopm_proc_c(3) (geopm_prof_progress() and geopm_tprof_*()) that can
be used to provide application feedback to the GEOPM Agent algorithm.
The GEOPM runtime does not provide any built-in Agents that use the
feedback provided by these progress and thread API's.  For this reason
modification of the application to use these additional interfaces
will provide no benefit with built-in Agents.  Extension of the GEOPM
features through an Agent plugin would enable a user to write an Agent
that uses this feedback, but this is beyond the scope of this guide.

Step 2: Compiling Application Against GEOPM
-------------------------------------------
When loading the geopm module several variables will be added to the
shell environment.  The GEOPM_INC variable defines the path to the
GEOPM header files.  When compiling source that includes a geopm
header file you must add

    -I$GEOPM_INC

to your compile line.  To link your application against libgeopm the
GEOPM_LIB variable defined by the module should be used on your link
line:

    -L$GEOPM_LIB -lgeopm -dynamic

Note that dynamic linking is required with the -dynamic flag.

Step 3: Selecting an Agent
--------------------------
The first example provided in "Step 0" uses the monitor agent:

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
--geopm-agent command line option for the geopmaprun(1) command and
the json policy file for each agent can be generated with the
geopmagent(1) command line tool.
